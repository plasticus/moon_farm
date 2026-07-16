// ═══════════════════════════════════════════════════════════════
//  lib/engine/kovacs_engine.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:math';
import '../config/kovacs_config_service.dart';
import '../models/game_models.dart';

enum SpeakerSide { kovacs, player }

enum ConversationPhase {
  greeting,
  playerTurn1,
  kovacsReact1,
  playerTurn2,
  kovacsSignOff,
  complete,
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

class KovacsEngine {
  static final _rng = Random();

  static KovacsConversation startConversation({
    required GameState game,
    required Set<String> unlockedTopicIds,
  }) {
    final config = KovacsConfigService.instance;
    final mood = game.relay.mood;
    final history = <ConversationBubble>[];

    final moodKey = _moodKey(mood);
    final greetingPool = config.greetingsForMood(moodKey);
    final greetingText = greetingPool.isNotEmpty
        ? _pickStr(greetingPool)
        : 'LC-4 Relay, Kovacs here.';
    history.add(ConversationBubble(
      side: SpeakerSide.kovacs,
      text: _substitute(greetingText, game),
    ));

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

      final unlocks = config.unlocksForTopic(picked.id);
      if (unlocks.isNotEmpty) {
        final targetUnlock = unlocks.first;
        final textLower = responseText.toLowerCase();

        if (picked.id == 'ask_about_breakfast') {
          final containsKeyword = textLower.contains('coffee') ||
              textLower.contains('brew') ||
              textLower.contains('espresso') ||
              textLower.contains('chicory');
          newlyUnlocked = containsKeyword ? targetUnlock : null;

        } else if (picked.id == 'ask_about_background') {
          final containsQuals = textLower.contains('exam') ||
              textLower.contains('command') ||
              textLower.contains('aced');
          newlyUnlocked = containsQuals ? targetUnlock : null;

        } else if (picked.id == 'ask_about_other_sectors') {
          final containsFarmData = textLower.contains('dome') ||
              textLower.contains('facility') ||
              textLower.contains('yield');
          newlyUnlocked = containsFarmData ? targetUnlock : null;

        } else if (picked.id == 'compliment_grooming') {
          final containsCat = textLower.contains('barnaby') ||
              textLower.contains('cat') ||
              textLower.contains('quarters');
          newlyUnlocked = containsCat ? targetUnlock : null;

        } else if (picked.id == 'ask_about_chatter') {
          final containsHonyocker = textLower.contains('honyocker') ||
              textLower.contains('greenhorn') ||
              textLower.contains('infraction');
          newlyUnlocked = containsHonyocker ? targetUnlock : null;

        } else if (picked.id == 'ask_about_noise') {
          final containsComplaint = textLower.contains('scrub') ||
              textLower.contains('complain') ||
              textLower.contains('bridge');
          newlyUnlocked = containsComplaint ? targetUnlock : null;

        } else if (picked.id == 'ask_about_shuttle_traffic') {
          final containsFreighter = textLower.contains('freighter') ||
              textLower.contains('hauler') ||
              textLower.contains('dock');
          newlyUnlocked = containsFreighter ? targetUnlock : null;

        } else {
          newlyUnlocked = targetUnlock;
        }
      }

      final followUps = _buildFollowUps(picked.id, newMood - conv.moodCurrent);

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
      // ════════════ FIXED: TURN 2 MOOD CALCULATIONS ════════════
      final dynamicNewMood = (conv.moodCurrent + picked.moodChange).clamp(0, 100);
      final dynamicNetChange = conv.netMoodChange + picked.moodChange;

      final signOff = _pickSignOff(dynamicNetChange);
      history.add(ConversationBubble(
        side: SpeakerSide.kovacs,
        text: _substitute(signOff, game),
      ));

      return (
      conversation: conv.copyWith(
        phase: ConversationPhase.complete,
        history: history,
        currentOptions: [],
        moodCurrent: dynamicNewMood,
        netMoodChange: dynamicNetChange,
      ),
      newMood: dynamicNewMood,
      newlyUnlockedTopicId: null,
      );
      // ═══════════════════════════════════════════════════════════
    }
  }

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

    for (final t in config.tier1Topics) {
      pool.add(_topicToPlayerLine(t));
    }

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

  static List<PlayerLine> _buildFollowUps(String parentTopicId, int moodDelta) {
    final customLabel = switch (parentTopicId) {
      'ask_wellbeing' => 'Glad the hull is holding together, at least.',
      'ask_about_breakfast' => 'Sounds rough. Let me know if you get real beans.',
      'ask_about_background' => 'With your test scores, you belong on a bridge division.',
      'compliment_grooming' => 'The discipline shows, Specialist. Keep it up.',
      'ask_about_chatter' => 'Must be exhausting dealing with amateurs.',
      'ask_about_noise' => 'That scrubber noise would drive me crazy too.',
      'ask_about_environment' => 'Watch out for that micro-gravity drift.',
      'ask_about_shuttle_traffic' => 'Tedious or not, keep those transit lanes clear.',
      'be_dismissive' => 'Understood. Let\'s access the network manifest directly.',
      'ask_about_ventilation' => 'Fair enough. Standard maintenance keeps things running.',
      'ask_about_screen_brightness' => 'Amber text is a classic choice anyway.',
      'ask_about_time_zones' => 'Makes sync schedules easy to compute.',
      'ask_about_office_supplies' => 'At least your network terminal is solid.',
      'ask_about_inventory_checks' => 'Automated backups are the best safe guard.',
      'ask_about_regulatory_audits' => 'Bureaucrats love their spreadsheet metrics.',
      'ask_about_recreation' => 'Twelve paces doesn\'t leave much room to move.',
      'ask_about_shift_length' => 'Fourteen hours is a brutal data watch.',
      'ask_about_salary' => 'Scrip metrics down here aren\'t much better.',
      'question_efficiency' => 'I\'ll balance my transmitter arrays on this end.',
      'ask_about_coffee' => 'That blend sounds toxic. Wish I could help.',
      'offer_coffee_help' => 'I\'ll get a custom hydroponic tray set up for it.',
      'mock_coffee' => 'Didn\'t realize functional focus was so sensitive.',
      'ask_about_captaincy' => 'A ninety-seventh percentile rank should be respected.',
      'taunt_captaincy_mean' => 'Whoa, just sorting standard data entries over here.',
      'mock_captaincy' => 'My mistake. Let\'s jump to the manifest files.',
      'ask_about_hobbies' => 'Precision trimming takes solid focus.',
      'ask_about_cat' => 'He sounds like an absolute legend.',
      'ask_about_ionuke' => 'Mathematical string scales sound intensely logical.',
      'mock_hobbies' => 'Isolation requires distinct routines to survive.',
      'ask_about_honyockers' => 'Venting an entire payload is dynamic stupidity.',
      'defend_farmers' => 'The telemetry loops down here get pretty chaotic.',
      'ask_about_complaints' => 'Regulatory discipline keeps the arrays clean.',
      'threaten_with_complaint' => 'Let\'s keep this system clear of compliance filings.',
      'ask_about_gravity_glitch' => 'Consoles floating sounds like an absolute mess.',
      'share_weightless_barnaby' => 'An orange ball cat drifting is absolute gold.',
      'ask_about_freighter_crews' => 'Bus drivers with thrusters is a hilarious image.',
      'rant_about_space_cadets' => 'Elegance or not, they need to check their docking clips.',
      'ask_about_other_sectors' => 'Sounds like the regional hub infrastructure is struggling.',
      'ask_about_sector_yields' => 'Appreciate the macro data snapshot, Specialist.',
      'press_honyocker_mockery' => 'Fair enough. I just figured there might be more to it.',
      'honyocker_grief_reveal' => 'That\'s a hard thing to carry. I\'m glad you told me.',
      'ask_about_freighter_envy' => 'Sure. Coordinating counts too, I guess.',
      'admit_freighter_envy' => 'For what it\'s worth, you\'d have made a hell of a captain.',
      _ => moodDelta >= 0 ? 'Understood, Kovacs.' : 'Let\'s drop it.'
    };

    return [
      PlayerLine(id: 'fu_contextual', label: customLabel, moodChange: moodDelta >= 0 ? 1 : 0),
      PlayerLine(id: 'fu_sign_off', label: 'Copy that. Back to work.', moodChange: 0),
    ];
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
      'LC-4 out. Don\'t make this a habit.',
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
        .replaceAll('{name}', game.farmName)
        .replaceAll('{week}', '${game.currentWeek}');
  }
}