// ═══════════════════════════════════════════════════════════════
//  lib/engine/radio_trigger_engine.dart
// ═══════════════════════════════════════════════════════════════
// Evaluates the trigger definitions in radio_triggers.toml against
// the current GameState and fires off any that have newly become
// true. Pure function — takes a GameState, returns a (possibly)
// updated GameState. No side effects of its own.
//
// Called from two places:
//   1. end_week_engine.dart, once per week, after all other state
//      changes for the week are settled — this is what catches
//      week/lifetime-counter/dome-count triggers reliably.
//   2. Directly from a few gameplay screens (dome_screen.dart,
//      refinery_screen.dart) right after they flip an unlockedFeatures
//      flag mid-week, so a feature_unlocked trigger's radio message
//      still shows up immediately instead of waiting for next
//      "End Week" — same as the old hardcoded behavior.
// Calling it twice for the same trigger is always safe: each trigger
// id can only ever fire once, tracked via firedRadioTriggers.

import '../config/radio_config_service.dart';
import '../models/game_models.dart';

GameState checkRadioTriggers(GameState s) {
  final triggers = RadioConfigService.instance.triggers;
  if (triggers.isEmpty) return s;

  var fired = List<String>.from(s.firedRadioTriggers);
  var feed = List<RadioTransmission>.from(s.radioFeed);
  var changed = false;

  for (final trig in triggers) {
    final id = trig['id'] as String?;
    if (id == null || fired.contains(id)) continue;

    if (_evaluateTrigger(s, trig['kind'] as String?, trig['value'])) {
      fired.add(id);
      feed.add(RadioTransmission(
        week: s.currentWeek,
        message: _applyTemplate(trig['message'] as String? ?? '', s),
        isRead: false,
      ));
      changed = true;
    }
  }

  if (!changed) return s;
  return s.copyWith(firedRadioTriggers: fired, radioFeed: feed);
}

bool _evaluateTrigger(GameState s, String? kind, dynamic value) {
  return switch (kind) {
    'game_start' => true,
    'week' => s.currentWeek >= (value as num).toInt(),
    'dome_count' => s.domes.length >= (value as num).toInt(),
    'dome_tier_reached' =>
        s.domes.any((d) => d.tier >= (value as num).toInt()),
    'feature_unlocked' => s.unlockedFeatures.contains(value as String),
    'crops_harvested_total' =>
        s.totalCropsHarvested >= (value as num).toInt(),
    'volume_delivered_total' =>
        s.totalVolumeDeliveredM3 >= (value as num).toDouble(),
    'lifetime_scrip_earned' =>
        s.lifetimeScripEarned >= (value as num).toInt(),
    'raids_survived' => s.totalRaidsDefended >= (value as num).toInt(),
    'fauna_killed_total' => s.totalFaunaKilled >= (value as num).toInt(),
    'chitin_collected_total' =>
        s.totalChitinCollected >= (value as num).toInt(),
    'compost_generated_total' =>
        s.totalCompostGenerated >= (value as num).toInt(),
    'contracts_completed' =>
        s.completedContracts.length >= (value as num).toInt(),
    _ => false, // unknown kind — ignore rather than crash on a typo
  };
}

String _applyTemplate(String message, GameState s) {
  var out = message.replaceAll('{week}', '${s.currentWeek}');
  final colonyPercent =
  ((s.totalVolumeDeliveredM3 / 100) * 100).clamp(0, 100).toInt();
  out = out.replaceAll('{colony_food_percent}', '$colonyPercent');
  return out;
}
