// ═══════════════════════════════════════════════════════════════
//  lib/data/kovacs_script.dart
// ═══════════════════════════════════════════════════════════════
//
// This file is the complete script for Specialist Kovacs.
// Edit it freely — add lines, change mood values, unlock new topics.
//
// HOW IT WORKS:
//   1. Kovacs picks up → greeting based on his current mood tier
//   2. If a game event occurred this week → contextual line injected
//   3. Player sees 3 random options from available pool (Tier 1 + unlocked Tier 2)
//   4. Player picks one → mood changes by that option's moodChange value
//   5. Kovacs reacts from the pool matching the mood delta
//   6. Player gets 3 follow-up options based on Kovacs' reaction tier
//   7. Player picks one → small secondary mood change
//   8. Kovacs signs off based on net mood change across whole conversation
//   9. The other Relay tabs (Buy/Sell/Contracts) unlock for the week
//
// VARIABLES YOU CAN USE IN TEXT:
//   {farm_name}  → player's farm name
//   {week}       → current week number
//
// MOOD TIERS:
//   elated   ≥ 85
//   happy    65–84
//   neutral  40–64
//   sour     20–39
//   hostile  0–19
//
// REACTION TIERS (based on mood delta from player's choice):
//   friendly  delta ≥ +4
//   positive  delta +1 to +3
//   neutral   delta 0
//   negative  delta -1 to -3
//   hostile   delta ≤ -4

// ─────────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────────

/// A line Kovacs speaks. reactionNote is a stage direction shown in italics.
class KovacsLine {
  final String text;
  final String? reactionNote; // e.g. "Kovacs frowns." shown before text

  const KovacsLine(this.text, {this.reactionNote});
}

/// A thing the player can say.
class PlayerLine {
  final String id;
  final String label;           // button text
  final int moodChange;         // effect on Kovacs' mood (-10 to +10 recommended)
  final String? unlocksTopicId; // permanently adds a Tier 2 topic to the pool

  const PlayerLine({
    required this.id,
    required this.label,
    required this.moodChange,
    this.unlocksTopicId,
  });
}

/// A Tier 2 topic — only enters the pool after being unlocked.
class Tier2Topic extends PlayerLine {
  const Tier2Topic({
    required super.id,
    required super.label,
    required super.moodChange,
    super.unlocksTopicId,
  });
}

// ─────────────────────────────────────────────────────────────────
// THE KOVACS SCRIPT
// ─────────────────────────────────────────────────────────────────

class KovacsScript {
  KovacsScript._(); // static only

  // ── GREETINGS ──────────────────────────────────────────────────
  // Kovacs picks one at random when you open the Relay.
  // Add as many as you want per mood tier.

  static const Map<String, List<KovacsLine>> greetings = {

    'hostile': [
      KovacsLine('What.', reactionNote: 'Kovacs does not look up.'),
      KovacsLine('MF-7. Make it fast.', reactionNote: 'He sounds exhausted.'),
      KovacsLine("I'm going to need you to have a good reason for this."),
      KovacsLine('Kovacs. Go.'),
      KovacsLine("You again. Fine. What is it, {farm_name}."),
    ],

    'sour': [
      KovacsLine('Kovacs. What do you need.'),
      KovacsLine('MF-7 relay. Make it quick.'),
      KovacsLine("Yes. Still here. What."),
      KovacsLine('Kovacs. I was in the middle of something.'),
      KovacsLine("MF-7. Don't make this painful."),
    ],

    'neutral': [
      KovacsLine('MF-7 relay. Go ahead.'),
      KovacsLine('Kovacs here.'),
      KovacsLine('Relay MF-7. What is it.'),
      KovacsLine("You've reached Specialist Kovacs. Relay station MF-7."),
      KovacsLine('MF-7. Yes.'),
      KovacsLine('{farm_name}. Week {week}. What do you need.'),
    ],

    'happy': [
      KovacsLine('Kovacs here. Good timing actually.'),
      KovacsLine("MF-7. I'll admit, things could be worse today."),
      KovacsLine('Relay MF-7. You caught me in a reasonable mood.'),
      KovacsLine('Kovacs. Yes. What can I do for you.'),
      KovacsLine("MF-7. {farm_name}. What's going on."),
    ],

    'elated': [
      KovacsLine("MF-7. I was just — yes. Hi. Good to hear from you."),
      KovacsLine("Kovacs. Surprisingly decent day. What do you need."),
      KovacsLine("Relay MF-7. {farm_name}. How are things down there."),
    ],

  };

  // ── CONTEXTUAL LINES ───────────────────────────────────────────
  // Injected AFTER the greeting if a game event occurred this week.
  // Kovacs picks one at random from the matching pool.
  // These are in addition to the greeting, not a replacement.

  static const Map<String, List<KovacsLine>> contextualLines = {

    'missed_milestone': [
      KovacsLine(
        'Colony flagged a missed delivery milestone on your account. '
            'I am required to inform you. I am informing you.',
        reactionNote: 'He reads from a screen.',
      ),
      KovacsLine(
        "Missed milestone on record, {farm_name}. "
            "That's not my problem, but I was told to mention it.",
      ),
      KovacsLine(
        'The colony sent a formal notice about your output. '
            "I've forwarded it. I don't write these things, I just relay them.",
        reactionNote: 'He says "relay" without any apparent irony.',
      ),
    ],

    'silo_full': [
      KovacsLine(
        "Your silo readings are maxed. "
            "Whatever you're growing, you might want to ship some of it.",
        reactionNote: 'He glances at his instruments.',
      ),
      KovacsLine(
        "Telemetry says your silos are at capacity, {farm_name}. "
            "I mention this purely as a professional courtesy.",
      ),
    ],

    'raid_occurred': [
      KovacsLine(
        'Sensor logs show a fauna incursion at your installation last cycle. '
            'How bad was it.',
        reactionNote: 'He actually sounds mildly concerned.',
      ),
      KovacsLine(
        "I picked up some unusual activity near your domes. "
            "Fauna, probably. They don't file incident reports, unfortunately.",
      ),
      KovacsLine(
        "Saw the fauna alert. Looks like you're still transmitting, so. "
            "Good, I suppose.",
        reactionNote: 'As close to warmth as he gets.',
      ),
    ],

    'first_harvest': [
      KovacsLine(
        'Telemetry shows your first harvest logged. '
            "The colony will be pleased. I'm — that's good news.",
        reactionNote: 'A brief pause.',
      ),
    ],

    'ship_window_open': [
      KovacsLine(
        "Pickup window is open, {farm_name}. "
            "I'll be overhead at the scheduled time. Have your manifest ready.",
      ),
      KovacsLine(
        "Week {week}. Ship window is open. "
            "Don't keep me waiting.",
        reactionNote: 'He taps something on his console.',
      ),
    ],

  };

  // ── PLAYER TIER 1 STARTERS ─────────────────────────────────────
  // Always in the pool. 3 are drawn at random each session.
  // These are your opening lines — small talk, requests, attitude.
  //
  // ADD MORE HERE — aim for 30+ eventually. Mix of positive/neutral/negative.
  // moodChange range: -8 to +4 for Tier 1 (friendly responses are rare here)
  //
  // unlocksTopicId: set to a Tier 2 topic ID to permanently unlock it
  // after Kovacs responds positively to this line.

  static const List<PlayerLine> tier1Starters = [

    // ── Neutral / small talk ──────────────────────────────────────
    PlayerLine(
      id: 't1_hey',
      label: "Hey Kovacs. How's it going.",
      moodChange: 1,
      unlocksTopicId: 't2_captaincy',
    ),
    PlayerLine(
      id: 't1_just_business',
      label: "Let's keep this professional.",
      moodChange: 0,
    ),
    PlayerLine(
      id: 't1_nice_day',
      label: "Nice day up there?",
      moodChange: 1,
    ),
    PlayerLine(
      id: 't1_week_check',
      label: "Week {week} already. Time flies.",
      moodChange: 0,
    ),
    PlayerLine(
      id: 't1_checking_in',
      label: "Just checking in.",
      moodChange: 0,
    ),
    PlayerLine(
      id: 't1_long_week',
      label: "Been a long week down here.",
      moodChange: 1,
      unlocksTopicId: 't2_other_farmers',
    ),
    PlayerLine(
      id: 't1_quiet',
      label: "Pretty quiet out here.",
      moodChange: 0,
    ),

    // ── Positive / friendly ───────────────────────────────────────
    PlayerLine(
      id: 't1_glad_hear',
      label: "Always glad to hear your voice, Kovacs.",
      moodChange: 3,
      unlocksTopicId: 't2_captaincy',
    ),
    PlayerLine(
      id: 't1_appreciate',
      label: "Appreciate everything you do up there.",
      moodChange: 3,
    ),
    PlayerLine(
      id: 't1_good_work',
      label: "You run a tight relay, Kovacs.",
      moodChange: 4,
      unlocksTopicId: 't2_captaincy',
    ),
    PlayerLine(
      id: 't1_hope_well',
      label: "Hope you're doing well.",
      moodChange: 2,
    ),
    PlayerLine(
      id: 't1_compliment_uniform',
      label: "You always look sharp on the feed.",
      moodChange: 3,
    ),

    // ── Negative / rude ───────────────────────────────────────────
    PlayerLine(
      id: 't1_rush',
      label: "Let's make this quick, I'm busy.",
      moodChange: -2,
    ),
    PlayerLine(
      id: 't1_discount',
      label: "How about a discount today, K-man.",
      moodChange: -3,
    ),
    PlayerLine(
      id: 't1_dork',
      label: "What's up, dork.",
      moodChange: -5,
    ),
    PlayerLine(
      id: 't1_hurry',
      label: "Hurry up, I don't have all day.",
      moodChange: -3,
    ),
    PlayerLine(
      id: 't1_whatever',
      label: "Whatever. Just need some stuff.",
      moodChange: -2,
    ),
    PlayerLine(
      id: 't1_hostile',
      label: "Listen here, relay boy.",
      moodChange: -6,
    ),
    PlayerLine(
      id: 't1_demand',
      label: "I need everything at half price. Now.",
      moodChange: -8,
    ),
    PlayerLine(
      id: 't1_boring',
      label: "You always this boring?",
      moodChange: -5,
    ),

    // ── ADD MORE TIER 1 STARTERS BELOW THIS LINE ──────────────────
    // Copy this template:
    //
    // PlayerLine(
    //   id: 't1_your_id_here',    // must be unique
    //   label: "What the player says.",
    //   moodChange: 0,            // negative, zero, or positive integer
    //   unlocksTopicId: null,     // or 't2_some_topic_id'
    // ),

  ];

  // ── KOVACS REACTION POOLS ──────────────────────────────────────
  // Kovacs picks one at random from the pool matching the mood delta.
  // Add more reactions to any pool freely.

  static const Map<String, List<KovacsLine>> reactions = {

    'hostile': [
      KovacsLine(
        "And that's getting reported.",
        reactionNote: 'Kovacs reaches for something off-screen.',
      ),
      KovacsLine(
        "How dare you.",
        reactionNote: 'Complete silence for a moment.',
      ),
      KovacsLine(
        "I've had about enough of your mouth, {farm_name}. "
            "Tell me what you need and clear the line.",
        reactionNote: 'His voice goes very flat.',
      ),
      KovacsLine(
        "That's logged. Everything's logged.",
        reactionNote: 'He types something.',
      ),
      KovacsLine(
        "You know what. Fine.",
        reactionNote: 'He makes a sound that is not quite a laugh.',
      ),
    ],

    'negative': [
      KovacsLine(
        "Color me unimpressed, {farm_name}.",
        reactionNote: 'Kovacs raises an eyebrow.',
      ),
      KovacsLine(
        '...',
        reactionNote: 'Kovacs furrows his brow.',
      ),
      KovacsLine(
        "Hm.",
        reactionNote: 'He stares at the feed.',
      ),
      KovacsLine(
        "Right.",
        reactionNote: 'Something in his expression hardens.',
      ),
      KovacsLine(
        "I'm going to pretend I didn't hear that.",
        reactionNote: 'He looks away briefly.',
      ),
      KovacsLine(
        "That's one way to open a conversation.",
        reactionNote: 'Distinctly unamused.',
      ),
    ],

    'neutral': [
      KovacsLine("Okay.", reactionNote: 'Kovacs nods once.'),
      KovacsLine("Right.", reactionNote: 'He waits.'),
      KovacsLine("Fine.", reactionNote: 'Neutral.'),
      KovacsLine("That's fine.", reactionNote: 'He adjusts something.'),
      KovacsLine("Understood.", reactionNote: 'Professional.'),
      KovacsLine("MF-7, copy.", reactionNote: 'By the book.'),
    ],

    'positive': [
      KovacsLine(
        "Well. That's — yes. Thank you.",
        reactionNote: 'Kovacs looks mildly surprised.',
      ),
      KovacsLine(
        "That's nice to hear.",
        reactionNote: 'A brief pause before he continues.',
      ),
      KovacsLine(
        "Appreciated.",
        reactionNote: 'Something relaxes in his posture.',
      ),
      KovacsLine(
        "I'll — yes. Thank you.",
        reactionNote: 'He clears his throat.',
      ),
    ],

    'friendly': [
      KovacsLine(
        "{farm_name}, you know — you're not bad at this.",
        reactionNote: 'He almost smiles.',
      ),
      KovacsLine(
        "I genuinely appreciate that. Most operators never bother.",
        reactionNote: 'He seems to mean it.',
      ),
      KovacsLine(
        "You know, {farm_name}, you're a lot better at this than the others.",
        reactionNote: 'Said quietly, like he almost didn\'t mean to say it.',
      ),
      KovacsLine(
        "That's — yes. Good. Thank you. That actually helps.",
        reactionNote: 'He sits up a little straighter.',
      ),
    ],

  };

  // ── PLAYER FOLLOW-UPS ──────────────────────────────────────────
  // Shown after Kovacs reacts. Pool is chosen by Kovacs' reaction tier.
  // Secondary mood effect is smaller — usually -2 to +2.
  // These are generic — they don't need to match the opening topic.
  // ADD MORE to any pool freely.

  static const Map<String, List<PlayerLine>> followUps = {

    // After a HOSTILE reaction from Kovacs
    'after_hostile': [
      PlayerLine(id: 'fu_h_sorry', label: "Look, I'm sorry. I didn't mean that.", moodChange: 2),
      PlayerLine(id: 'fu_h_joking', label: "Just kidding! Totally joking.", moodChange: 1),
      PlayerLine(id: 'fu_h_back_off', label: "Fine. Whatever. Forget it.", moodChange: 0),
      PlayerLine(id: 'fu_h_stand', label: "You heard what I said.", moodChange: -3),
      PlayerLine(id: 'fu_h_ok', label: "Okay. Let's just move on.", moodChange: 1),
    ],

    // After a NEGATIVE reaction from Kovacs
    'after_negative': [
      PlayerLine(id: 'fu_n_sorry', label: "Sorry, that came out wrong.", moodChange: 2),
      PlayerLine(id: 'fu_n_fair', label: "Fair enough.", moodChange: 0),
      PlayerLine(id: 'fu_n_still', label: "I stand by it.", moodChange: -2),
      PlayerLine(id: 'fu_n_ok', label: "Okay, okay. Moving on.", moodChange: 1),
      PlayerLine(id: 'fu_n_exactly', label: "Exactly. That's what I said.", moodChange: -2),
      PlayerLine(id: 'fu_n_ignore', label: "Anyway.", moodChange: -1),
    ],

    // After a NEUTRAL reaction from Kovacs
    'after_neutral': [
      PlayerLine(id: 'fu_0_good', label: "Good. Just making conversation.", moodChange: 0),
      PlayerLine(id: 'fu_0_thanks', label: "Right. Thanks, Kovacs.", moodChange: 1),
      PlayerLine(id: 'fu_0_alright', label: "Alright then.", moodChange: 0),
      PlayerLine(id: 'fu_0_push', label: "You could be a little warmer, you know.", moodChange: -1),
      PlayerLine(id: 'fu_0_anyway', label: "Anyway, let's get to business.", moodChange: 0),
      PlayerLine(id: 'fu_0_cool', label: "Cool.", moodChange: 0),
    ],

    // After a POSITIVE reaction from Kovacs
    'after_positive': [
      PlayerLine(id: 'fu_p_great', label: "Great. Glad to hear it.", moodChange: 1),
      PlayerLine(id: 'fu_p_family', label: "Tell the family I said hi!", moodChange: 2),
      PlayerLine(id: 'fu_p_good', label: "Good. That's what I like to hear.", moodChange: 1),
      PlayerLine(id: 'fu_p_keep', label: "Keep up the good work up there.", moodChange: 2),
      PlayerLine(id: 'fu_p_business', label: "Glad to hear it. Now, business.", moodChange: 0),
      PlayerLine(id: 'fu_p_push', label: "While you're in a good mood — discount?", moodChange: -2),
    ],

    // After a FRIENDLY reaction from Kovacs
    'after_friendly': [
      PlayerLine(id: 'fu_f_means', label: "That means a lot, actually.", moodChange: 2),
      PlayerLine(id: 'fu_f_same', label: "Same to you, Kovacs. Same to you.", moodChange: 2),
      PlayerLine(id: 'fu_f_thanks', label: "Thanks. You're not so bad yourself.", moodChange: 2),
      PlayerLine(id: 'fu_f_modest', label: "I'm just doing my job.", moodChange: 1),
      PlayerLine(id: 'fu_f_awkward', label: "...right. So. About those prices.", moodChange: -1),
    ],

  };

  // ── KOVACS SIGN-OFFS ───────────────────────────────────────────
  // Final word from Kovacs. Based on net mood change this conversation.
  // net > 0 → positive pool
  // net = 0 → neutral pool
  // net < 0 → negative pool
  // Add more to any pool freely.

  static const Map<String, List<KovacsLine>> signOffs = {

    'positive': [
      KovacsLine("Good talk. MF-7 out.", reactionNote: 'He almost smiles.'),
      KovacsLine("See you next week, {farm_name}.", reactionNote: 'Brief but genuine.'),
      KovacsLine("Been good talking to you. Stay alive down there."),
      KovacsLine("Alright. MF-7 standing by.", reactionNote: 'Satisfied.'),
      KovacsLine("Not a bad call. MF-7 out."),
    ],

    'neutral': [
      KovacsLine("MF-7 out.", reactionNote: 'Businesslike.'),
      KovacsLine("Copy. Standing by."),
      KovacsLine("Understood. MF-7 standing by."),
      KovacsLine("Relay clear."),
      KovacsLine("Right. MF-7 out."),
    ],

    'negative': [
      KovacsLine("MF-7 out.", reactionNote: 'He cuts the feed.'),
      KovacsLine("Just — just go do your farming. MF-7 out."),
      KovacsLine("Get off my relay. Out.", reactionNote: 'Clipped.'),
      KovacsLine("Noted. Don't call again until you've thought about what you said."),
      KovacsLine("I'm logging this conversation. MF-7 out."),
    ],

  };

  // ── TIER 2 TOPICS ─────────────────────────────────────────────
  // These join the random pool PERMANENTLY once unlocked.
  //
  // HOW UNLOCKING WORKS — a working example:
  //
  //   1. Player picks "Hey Kovacs, how's it going." (id: t1_hey, moodChange: +1)
  //   2. Kovacs reacts from the 'positive' pool (e.g. "Well. That's — yes. Thank you.")
  //   3. Because moodChange was >= 0 AND t1_hey has unlocksTopicId: 't2_captaincy'...
  //      → 't2_captaincy' is added to this save's unlockedTopicIds PERMANENTLY
  //   4. Next week and forever after, "Any news on the captaincy front?" can
  //      appear in the player's 3 random options
  //   5. When the player picks 't2_captaincy', Kovacs gives his SPECIFIC reaction
  //      from tier2Reactions['t2_captaincy'] instead of a generic pool response
  //   6. Because t2_captaincy has unlocksTopicId: 't2_aurelius', if Kovacs
  //      responds positively, "Whatever happened to the Aurelius-IV?" unlocks too
  //
  // TO ADD YOUR OWN TIER 2 TOPIC:
  //   1. Add a Tier2Topic entry below (give it a unique id starting with 't2_')
  //   2. Add its specific response to tier2Reactions below (optional but recommended)
  //   3. On a Tier 1 starter, set unlocksTopicId to your new topic's id
  //   4. That's it — the engine handles the rest

  static const List<Tier2Topic> tier2Topics = [

    // Unlocked by: asking how he's doing + positive reaction
    // or: complimenting him + positive reaction
    Tier2Topic(
      id: 't2_captaincy',
      label: "Any news on the captaincy front?",
      moodChange: 3,
      unlocksTopicId: 't2_aurelius',
    ),

    // Unlocked by: mentioning a long week + positive reaction
    Tier2Topic(
      id: 't2_other_farmers',
      label: "How are the other moon farmers doing?",
      moodChange: 4,
    ),

    // Unlocked by: captaincy topic + positive reaction
    Tier2Topic(
      id: 't2_aurelius',
      label: "Whatever happened to that posting on the Aurelius-IV?",
      moodChange: 4,
      unlocksTopicId: 't2_outer_belt',
    ),

    // Unlocked by: aurelius topic + positive reaction
    Tier2Topic(
      id: 't2_outer_belt',
      label: "What's out there past the outer belt?",
      moodChange: 5,
    ),

    // ADD MORE TIER 2 TOPICS BELOW THIS LINE ────────────────────
    // Copy this template:
    //
    // Tier2Topic(
    //   id: 't2_your_id_here',
    //   label: "What the player says.",
    //   moodChange: 2,           // Tier 2 topics tend to be positive (2-5)
    //   unlocksTopicId: null,    // or another tier 2/3 id
    // ),

  ];

  // ── TIER 2 KOVACS REACTIONS ────────────────────────────────────
  // Specific responses to specific Tier 2 topics.
  // Key = topic id. If not found, falls back to the standard reaction pool.
  // Add entries here as you add Tier 2 topics above.

  static const Map<String, KovacsLine> tier2Reactions = {

    't2_captaincy': KovacsLine(
      "Form 7-C Navigation Exam. 97th percentile. "
          "Still no posting. Still here. "
          "But I appreciate you asking.",
      reactionNote: 'He says it like he\'s recited it before. Which he has.',
    ),

    't2_other_farmers': KovacsLine(
      "MF-4 missed three shipments in a row. "
          "MF-9 got half their crops eaten by something large. "
          "You're doing fine by comparison. Don't tell them I said that.",
      reactionNote: 'He lowers his voice slightly.',
    ),

    't2_aurelius': KovacsLine(
      "She's on a deep survey run past the outer markers. "
          "I've been tracking her logs. "
          "Should be me on that bridge. "
          "But I'm here. So.",
      reactionNote: 'A long pause.',
    ),

    't2_outer_belt': KovacsLine(
      "Nobody really knows. That's the point. "
          "Three candidate systems for deep-field nav. "
          "I have a binder. "
          "I've been charting it in my off hours.",
      reactionNote: 'Something comes alive in his voice.',
    ),

    // ADD TIER 2 REACTIONS BELOW THIS LINE ───────────────────────
    // Copy this template:
    //
    // 't2_your_topic_id': KovacsLine(
    //   "What Kovacs says when asked about this topic.",
    //   reactionNote: 'Optional stage direction.',
    // ),

  };

}