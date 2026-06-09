// ═══════════════════════════════════════════════════════════════
//  lib/engine/kovacs_engine.dart
// ═══════════════════════════════════════════════════════════════
// Kovacs conversation engine — reads all dialogue from
// assets/config/kovacs_dialog.json via KovacsConfigService.

import 'dart:math';
import '../config/kovacs_config_service.dart';
import '../models/game_models.dart';

// ─── Conversation Models ──────────────────────────────────────────────────────

enum SpeakerSide { kovacs, player }

enum ConversationPhase {
  greeting,     // Kovacs greeting
  playerTurn1,  // Player picks topic
  kovacsReact1, // Kovacs responds to topic
  playerTurn2,  // Player picks follow-up
  kovacsSignOff,// Kovacs signs off
  complete,     // Done
}

class ConversationBubble {
  final SpeakerSide side;
  final String text;
  final String? reactionNote;
  final bool isSelected;

  const ConversationBubble({
    required this.side,
    required this.text,
    this.reactionNote,
    this.isSelected = false,
  });
}

/// A player-selectable option backed by a JSON topic.
class PlayerLine {
  final String id;
  final String label;
  final int moodChange;
  final String? unlocksTopicId;

  const PlayerLine({
    required this.id,
    required this.label,
    required this.moodChange,
    this.unlocksTopicId,
  });
}

class KovacsConversation {
  final ConversationPhase phase;
  final List<ConversationBubble> history;
  final List<PlayerLine> currentOptions;
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

  static KovacsConversation startConversation({
    required GameState game,
    required Set<String> unlockedTopicIds,
    required Set<String> contextualEvents,
  }) {
    final config = KovacsConfigService.instance;
    final mood = game.relay.mood;
    final history = <ConversationBubble>[];

    // 1. Greeting from JSON based on mood tier
    final moodKey = _moodKey(mood);
    final greetingPool = config.greetingsForMood(moodKey);
    final greetingText = greetingPool.isNotEmpty
        ? _pickStr(greetingPool)
        : 'LC-4 Relay, Kovacs here.';
    history.add(ConversationBubble(
      side: SpeakerSide.kovacs,
      text: _substitute(greetingText, game),
    ));

    // 2. Build player options (tier 1 + unlocked tier 2), shuffle, take 3
    final options = _buildOptions(unlockedTopicIds);

    return KovacsConversation(
      phase: ConversationPhase.playerTurn1,
      history: history,
      currentOptions: options,
      moodAtStart: mood,
      moodCurrent: mood,
      netMoodChange: 0,
    );
  }

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
    final config = KovacsConfigService.instance;
    final newMood = (conv.moodCurrent + picked.moodChange).clamp(0, 100);
    final netChange = conv.netMoodChange + picked.moodChange;

    final history = List<ConversationBubble>.from(conv.history)
      ..add(ConversationBubble(
        side: SpeakerSide.player,
        text: picked.label,
        isSelected: true,
      ));

    String? newlyUnlocked;

    if (conv.phase == ConversationPhase.playerTurn1) {
      // Kovacs responds using topic's response_pool
      final responses = config.responsesForTopic(picked.id);
      final hint = config.moodHintForTopic(picked.id);
      final responseText = responses.isNotEmpty
          ? _pickStr(responses)
          : 'Copy that.';
      history.add(ConversationBubble(
        side: SpeakerSide.kovacs,
        text: _substitute(responseText, game),
        reactionNote: hint,
      ));

      // Unlock topics listed in this topic's "unlocks" array
      final unlocks = config.unlocksForTopic(picked.id);
      if (unlocks.isNotEmpty) {
        newlyUnlocked = unlocks.first;
      }

      // Build follow-up options
      final followUps = _buildFollowUps(newMood - conv.moodCurrent);

      return (
      conversation: conv.copyWith(
        phase: ConversationPhase.playerTurn2,
        history: history,
        currentOptions: followUps,
        moodCurrent: newMood,
        netMoodChange: netChange,
      ),
      newMood: newMood,
      newlyUnlockedTopicId: newlyUnlocked,
      );
    } else {
      // Exchange 2 — sign off
      final signOff = _pickSignOff(netChange);
      history.add(ConversationBubble(
        side: SpeakerSide.kovacs,
        text: _substitute(signOff, game),
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
      newlyUnlockedTopicId: null,
      );
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  static String _moodKey(int mood) {
    if (mood >= 85) return 'elated';
    if (mood >= 65) return 'happy';
    if (mood >= 40) return 'neutral';
    if (mood >= 20) return 'sour';
    return 'hostile';
  }

  static List<PlayerLine> _buildOptions(Set<String> unlockedTopicIds) {
    final config = KovacsConfigService.instance;
    final pool = <PlayerLine>[];

    // All tier 1 topics
    for (final t in config.tier1Topics) {
      pool.add(_topicToPlayerLine(t));
    }

    // Unlocked tier 2 topics
    for (final t in config.tier2Topics) {
      if (unlockedTopicIds.contains(t['id'] as String)) {
        pool.add(_topicToPlayerLine(t));
      }
    }

    pool.shuffle(_rng);
    return pool.take(3).toList();
  }

  static PlayerLine _topicToPlayerLine(Map<String, dynamic> topic) {
    final unlocks = topic['unlocks'] as List?;
    return PlayerLine(
      id: topic['id'] as String,
      label: topic['visible_label'] as String,
      moodChange: topic['mood_change'] as int? ?? 0,
      unlocksTopicId: (unlocks != null && unlocks.isNotEmpty)
          ? unlocks.first.toString()
          : null,
    );
  }

  // Generic follow-ups for exchange 2 — not in JSON, inline here.
  // These are intentionally bland so the topic response is the memorable moment.
  static List<PlayerLine> _buildFollowUps(int moodDelta) {
    final options = moodDelta >= 0
        ? [
      PlayerLine(id: 'fu_thanks', label: 'Appreciated, Kovacs.', moodChange: 1),
      PlayerLine(id: 'fu_noted', label: 'Noted. Anything else I should know?', moodChange: 0),
      PlayerLine(id: 'fu_good', label: 'Good to know. Stay sharp out there.', moodChange: 1),
      PlayerLine(id: 'fu_understood', label: 'Understood. I will keep that in mind.', moodChange: 0),
    ]
        : [
      PlayerLine(id: 'fu_sorry', label: 'Fair enough. Sorry to bother you.', moodChange: 1),
      PlayerLine(id: 'fu_copy', label: 'Copy that. Signing off.', moodChange: 0),
      PlayerLine(id: 'fu_drop', label: "Let's drop it.", moodChange: -1),
    ];
    options.shuffle(_rng);
    return options.take(3).toList();
  }

  static String _pickSignOff(int netMoodChange) {
    final positive = [
      'Good talk. LC-4 standing by.',
      'Alright. You know where to find me.',
      'LC-4 out. Keep it together down there.',
      'Copy. Stay productive.',
    ];
    final neutral = [
      'LC-4 out.',
      'Acknowledged. LC-4 standing by.',
      'Right. LC-4 clear.',
      'Copy that. Kovacs out.',
    ];
    final negative = [
      'LC-4 out. Do not make this a habit.',
      'Acknowledged. Try not to call again soon.',
      "Fine. LC-4 out.",
    ];

    if (netMoodChange > 0) return _pickStr(positive);
    if (netMoodChange < 0) return _pickStr(negative);
    return _pickStr(neutral);
  }

  static String _pickStr(List<String> pool) =>
      pool[_rng.nextInt(pool.length)];

  static String _substitute(String text, GameState game) {
    return text
        .replaceAll('{farm_name}', game.farmName)
        .replaceAll('{week}', '${game.currentWeek}');
  }
}