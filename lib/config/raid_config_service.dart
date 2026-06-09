// ═══════════════════════════════════════════════════════════════
//  lib/config/raid_config_service.dart
// ═══════════════════════════════════════════════════════════════
// Single source of truth for all raid and fauna configuration.
// Reads from assets/config/raids.yaml via UpgradeConfigService.
//
// FAUNA UNLOCK SYSTEM:
//   Each fauna type has a spawn_chance (probability) and optionally an
//   unlock_week field (added in raids.yaml comments as "UNLOCKS AT WEEK X").
//   We derive the unlock week from list position: fauna are sorted from
//   rarest/strongest (top) to common/weakest (bottom/fallback).
//   The unlock sequence is encoded in raids.yaml comments, but the actual
//   gate is: a fauna type is eligible if currentRaidNumber >= its unlock_raid.
//   unlock_raid is inferred from spawn_chance — types with lower spawn_chance
//   unlock later. You can also add an explicit `unlock_raid: N` field to any
//   fauna entry in raids.yaml to hard-lock it until raid N.

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'upgrade_config_service.dart';
import '../models/game_models.dart';

class RaidConfigService {
  RaidConfigService._();
  static final RaidConfigService instance = RaidConfigService._();

  // ─── Convenience accessor ───────────────────────────────────────────────────

  UpgradeConfigService get _uc => UpgradeConfigService.instance;

  // ─── Scheduling ─────────────────────────────────────────────────────────────

  int get firstRaidWeek =>
      _uc.raidScheduling['first_raid_week'] as int? ?? 10;

  int raidInterval(Difficulty difficulty) =>
      _uc.raidInterval(difficulty.name);

  int get raidWarningWeeksBefore =>
      _uc.raidScheduling['raid_warning_weeks_before'] as int? ?? 2;

  // ─── Scaling ────────────────────────────────────────────────────────────────

  Map<String, dynamic> get scaling => _uc.raidScaling;

  int get baseFaunaCount =>
      scaling['base_fauna_count'] as int? ?? 5;

  int get faunaPerWeek =>
      scaling['fauna_per_week'] as int? ?? 1;

  int get faunaPerWeekDivisor =>
      scaling['fauna_per_week_divisor'] as int? ?? 3;

  int get maxFaunaCount =>
      scaling['max_fauna_count'] as int? ?? 60;

  double get spawnIntervalBase =>
      (scaling['spawn_interval_base'] as num?)?.toDouble() ?? 3.0;

  double get spawnIntervalMin =>
      (scaling['spawn_interval_min'] as num?)?.toDouble() ?? 1.5;

  int get raidDurationMax =>
      scaling['raid_duration_max'] as int? ?? 90;

  /// How many fauna spawn in a raid at the given week.
  int faunaCountForWeek(int week) {
    final count = baseFaunaCount + (week ~/ faunaPerWeekDivisor) * faunaPerWeek;
    return count.clamp(baseFaunaCount, maxFaunaCount);
  }

  // ─── Fauna Types ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get allFaunaTypes => _uc.faunaTypes;

  Map<String, dynamic>? getFaunaType(String id) => _uc.getFaunaType(id);

  /// Returns fauna types unlocked at or before the given raid number.
  ///
  /// Unlock logic (in priority order):
  ///   1. If a fauna entry has `unlock_raid: N`, it unlocks at raid N.
  ///   2. Otherwise, inferred from list position: the last entry (highest
  ///      spawn_chance / fallback) unlocks at raid 1. Each entry above it
  ///      unlocks one raid later, counting from the bottom.
  ///
  /// This means your raids.yaml list order IS the unlock order — put
  /// the hardest enemies at the top, the starting crawlers at the bottom.
  List<Map<String, dynamic>> faunaAvailableAtRaid(int raidNumber) {
    final all = allFaunaTypes;
    if (all.isEmpty) return [];

    return all.where((f) {
      // Explicit unlock_raid field takes priority
      if (f.containsKey('unlock_raid')) {
        return raidNumber >= (f['unlock_raid'] as int);
      }
      // Infer from position: bottom entry = raid 1, each entry above = +1 raid
      final idx = all.indexOf(f);
      final inferredUnlockRaid = all.length - idx;
      return raidNumber >= inferredUnlockRaid;
    }).toList();
  }

  /// Picks a fauna type for this raid using spawn_chance ordering,
  /// respecting the unlock gate for the current raid number.
  ///
  /// Types are checked in list order (rarest first). First one whose
  /// spawn_chance roll passes AND is unlocked wins.
  /// The last unlocked entry acts as the fallback default.
  Map<String, dynamic> pickFaunaType(Random rng, {required int raidNumber}) {
    final available = faunaAvailableAtRaid(raidNumber);
    if (available.isEmpty) return allFaunaTypes.last;

    for (final f in available) {
      final chance = (f['spawn_chance'] as num?)?.toDouble() ?? 1.0;
      if (rng.nextDouble() < chance) return f;
    }

    // Fallback — should always be caught by the 1.0 entry, but just in case
    debugPrint('[RaidConfig] Warning: no fauna type matched, using last available');
    return available.last;
  }

  // ─── Drops ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> get drops => _uc.raidDrops;

  double get meatChance =>
      (drops['meat_chance'] as num?)?.toDouble() ?? 0.7;

  double get chitinChanceNonBrute =>
      (drops['chitin_chance_non_brute'] as num?)?.toDouble() ?? 0.15;
}