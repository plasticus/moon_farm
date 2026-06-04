// ═══════════════════════════════════════════════════════════════
//  lib/engine/kovacs_engine.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:math';
import '../data/kovacs_script.dart';
import '../models/game_models.dart';

// ─── Conversation Models ──────────────────────────────────────────────────────

enum SpeakerSide { kovacs, player }

enum ConversationPhase {
  greeting,       // Kovacs greeting (+ optional contextual line)
  playerTurn1,    // Player picks from 3 options
  kovacsReact1,   // Kovacs reacts to player's choice
  playerTurn2,    // Player picks follow-up
  kovacsSignOff,  // Kovacs signs off — conversation done, tabs unlock
  complete,       // Tabs unlocked
}

/// A single bubble in the conversation UI.
class ConversationBubble {
  final SpeakerSide side;
  final String text;
  final String? reactionNote; // italic stage direction before text (Kovacs only)
  final bool isSelected;      // player bubble that was picked

  const ConversationBubble({
    required this.side,
    required this.text,
    this.reactionNote,
    this.isSelected = false,
  });
}

/// The full conversation state for a given week.
class KovacsConversation {
  final ConversationPhase phase;
  final List<ConversationBubble> history;   // what's been said so far
  final List<PlayerLine> currentOptions;    // current 3 options (empty if not player turn)
  final int moodAtStart;
  final int moodCurrent;
  final int netMoodChange;

  const KovacsConversation({
    required this.phase,
    required this.history,
    required this.currentOptions,
    required this.moodAtStart,
    required this.moodCurrent,
    required this.netMoodChange,
  });

  bool get isComplete => phase == ConversationPhase.complete;
  bool get isPlayerTurn =>
      phase == ConversationPhase.playerTurn1 ||
          phase == ConversationPhase.playerTurn2;

  KovacsConversation copyWith({
    ConversationPhase? phase,
    List<ConversationBubble>? history,
    List<PlayerLine>? currentOptions,
    int? moodAtStart,
    int? moodCurrent,
    int? netMoodChange,
  }) {
    return KovacsConversation(
      phase: phase ?? this.phase,
      history: history ?? this.history,
      currentOptions: currentOptions ?? this.currentOptions,
      moodAtStart: moodAtStart ?? this.moodAtStart,
      moodCurrent: moodCurrent ?? this.moodCurrent,
      netMoodChange: netMoodChange ?? this.netMoodChange,
    );
  }
}

// ─── Kovacs Engine ────────────────────────────────────────────────────────────

class KovacsEngine {
  static final _rng = Random();

  /// Start a fresh conversation for the week.
  /// Pass [gameState] for variable substitution and contextual lines.
  /// Pass [unlockedTopicIds] — the set of Tier 2 topic IDs unlocked so far.
  /// Pass [contextualEvents] — set of event keys that occurred this week.
  static KovacsConversation startConversation({
    required GameState game,
    required Set<String> unlockedTopicIds,
    required Set<String> contextualEvents,
  }) {
    final mood = game.relay.mood;
    final history = <ConversationBubble>[];

    // 1. Kovacs greeting based on mood tier
    final greetingPool = _greetingPool(mood);
    final greeting = _pick(greetingPool);
    history.add(ConversationBubble(
      side: SpeakerSide.kovacs,
      text: _substitute(greeting.text, game),
      reactionNote: greeting.reactionNote,
    ));

    // 2. Contextual line if any events occurred
    for (final event in contextualEvents) {
      final pool = KovacsScript.contextualLines[event];
      if (pool != null && pool.isNotEmpty) {
        final line = _pick(pool);
        history.add(ConversationBubble(
          side: SpeakerSide.kovacs,
          text: _substitute(line.text, game),
          reactionNote: line.reactionNote,
        ));
        break; // max one contextual line per week
      }
    }

    // 3. Build player options pool (Tier 1 + unlocked Tier 2)
    final options = _buildPlayerOptions(unlockedTopicIds);

    return KovacsConversation(
      phase: ConversationPhase.playerTurn1,
      history: history,
      currentOptions: options,
      moodAtStart: mood,
      moodCurrent: mood,
      netMoodChange: 0,
    );
  }

  /// Player picks an option. Returns updated conversation.
  /// Also returns the new mood value and any newly unlocked topic ID.
  static ({
  KovacsConversation conversation,
  int newMood,
  String? newlyUnlockedTopicId,
  }) playerPicked({
    required KovacsConversation conv,
    required PlayerLine picked,
    required GameState game,
    required Set<String> unlockedTopicIds,
  }) {
    final newMood = (conv.moodCurrent + picked.moodChange).clamp(0, 100);
    final netChange = conv.netMoodChange + picked.moodChange;

    // Add player bubble (selected)
    final history = List<ConversationBubble>.from(conv.history)
      ..add(ConversationBubble(
        side: SpeakerSide.player,
        text: picked.label,
        isSelected: true,
      ));

    String? newlyUnlocked;

    if (conv.phase == ConversationPhase.playerTurn1) {
      // Kovacs reacts to exchange 1
      final reaction = _kovacsReaction(picked, newMood, conv.moodCurrent, unlockedTopicIds, game);
      history.add(ConversationBubble(
        side: SpeakerSide.kovacs,
        text: _substitute(reaction.text, game),
        reactionNote: reaction.reactionNote,
      ));

      // Check if this unlocks a Tier 2 topic (only if Kovacs responded positively)
      final moodDelta = newMood - conv.moodCurrent;
      if (picked.unlocksTopicId != null && moodDelta >= 0) {
        // Unlock on neutral or positive reaction
        newlyUnlocked = picked.unlocksTopicId;
      }

      // Build follow-up options
      final followUpPool = _followUpPool(moodDelta);

      return (
      conversation: conv.copyWith(
        phase: ConversationPhase.playerTurn2,
        history: history,
        currentOptions: followUpPool,
        moodCurrent: newMood,
        netMoodChange: netChange,
      ),
      newMood: newMood,
      newlyUnlockedTopicId: newlyUnlocked,
      );

    } else {
      // Exchange 2 — Kovacs signs off
      final signOff = _pickSignOff(netChange, game);
      history.add(ConversationBubble(
        side: SpeakerSide.kovacs,
        text: _substitute(signOff.text, game),
        reactionNote: signOff.reactionNote,
      ));

      return (
      conversation: conv.copyWith(
        phase: ConversationPhase.complete,
        history: history,
        currentOptions: [],
        moodCurrent: newMood,
        netMoodChange: netChange,
      ),
      newMood: newMood,
      newlyUnlockedTopicId: newlyUnlocked,
      );
    }
  }

  // ─── Private helpers ────────────────────────────────────────────

  static List<KovacsLine> _greetingPool(int mood) {
    if (mood >= 85) return KovacsScript.greetings['elated']!;
    if (mood >= 65) return KovacsScript.greetings['happy']!;
    if (mood >= 40) return KovacsScript.greetings['neutral']!;
    if (mood >= 20) return KovacsScript.greetings['sour']!;
    return KovacsScript.greetings['hostile']!;
  }

  static List<PlayerLine> _buildPlayerOptions(Set<String> unlockedTopicIds) {
    final pool = <PlayerLine>[...KovacsScript.tier1Starters];

    // Add unlocked Tier 2 topics
    for (final topic in KovacsScript.tier2Topics) {
      if (unlockedTopicIds.contains(topic.id)) {
        pool.add(topic);
      }
    }

    // Shuffle and take 3
    pool.shuffle();
    return pool.take(3).toList();
  }

  static KovacsLine _kovacsReaction(
      PlayerLine picked,
      int newMood,
      int oldMood,
      Set<String> unlockedTopicIds,
      GameState game,
      ) {
    // Check for a specific Tier 2 reaction first
    if (KovacsScript.tier2Reactions.containsKey(picked.id)) {
      return KovacsScript.tier2Reactions[picked.id]!;
    }

    // Otherwise pick from pool by mood delta
    final delta = newMood - oldMood;
    String poolKey;
    if (delta >= 4) poolKey = 'friendly';
    else if (delta >= 1) poolKey = 'positive';
    else if (delta == 0) poolKey = 'neutral';
    else if (delta >= -3) poolKey = 'negative';
    else poolKey = 'hostile';

    return _pick(KovacsScript.reactions[poolKey]!);
  }

  static List<PlayerLine> _followUpPool(int moodDelta) {
    String key;
    if (moodDelta >= 4) key = 'after_friendly';
    else if (moodDelta >= 1) key = 'after_positive';
    else if (moodDelta == 0) key = 'after_neutral';
    else if (moodDelta >= -3) key = 'after_negative';
    else key = 'after_hostile';

    final pool = List<PlayerLine>.from(KovacsScript.followUps[key]!);
    pool.shuffle();
    return pool.take(3).toList();
  }

  static KovacsLine _pickSignOff(int netMoodChange, GameState game) {
    String key;
    if (netMoodChange > 0) key = 'positive';
    else if (netMoodChange == 0) key = 'neutral';
    else key = 'negative';

    return _pick(KovacsScript.signOffs[key]!);
  }

  static T _pick<T>(List<T> pool) => pool[_rng.nextInt(pool.length)];

  /// Replace {farm_name} and {week} placeholders in Kovacs' text.
  static String _substitute(String text, GameState game) {
    return text
        .replaceAll('{farm_name}', game.farmName)
        .replaceAll('{week}', '${game.currentWeek}');
  }
}