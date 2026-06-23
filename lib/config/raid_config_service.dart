// ═══════════════════════════════════════════════════════════════
//  lib/config/raid_config_service.dart
// ═══════════════════════════════════════════════════════════════
// Single source of truth for all raid and fauna configuration.
// Reads from assets/config/raids.yaml via UpgradeConfigService.
//
// INFINITE STAIR-STEP UPDATE:
//   This service now uses a deterministic formula matrix for wave layouts
//   and infinitely scales stats (+100 HP, +14 DMG per level).

import 'dart:math';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import '../models/game_models.dart';

/// Small data container for a creature's dynamically calculated stats.
class ScaledFaunaStats {
  final int hp;
  final int damage;
  final double speed;

  ScaledFaunaStats({
    required this.hp,
    required this.damage,
    required this.speed,
  });
}

/// Description of an individual bug inside our pre-calculated wave queue.
class SpawnInstruction {
  final String baseName;
  final int level;

  SpawnInstruction({required this.baseName, required this.level});
}

class RaidConfigService {
  RaidConfigService._();
  static final RaidConfigService instance = RaidConfigService._();

  Map<String, dynamic> _data = {};

  Future<void> load() async {
    final raw = await rootBundle.loadString('assets/config/raids.yaml');
    final doc = loadYaml(raw);
    _data = _deepConvert(doc) as Map<String, dynamic>;
  }

  dynamic _deepConvert(dynamic node) {
    if (node is YamlMap) {
      return node.map((k, v) => MapEntry(k.toString(), _deepConvert(v)));
    } else if (node is YamlList) {
      return node.map(_deepConvert).toList();
    }
    return node;
  }

  // ─── Convenience accessors ──────────────────────────────────────────────────

  Map<String, dynamic> get _scheduling =>
      (_data['raid_scheduling'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _scaling =>
      (_data['raid_scaling'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _drops =>
      (_data['raid_drops'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _intervals =>
      (_data['raid_intervals'] as Map?)?.cast<String, dynamic>() ?? {};

  /// Fauna types as a map keyed by display name (your new YAML format).
  Map<String, dynamic> get _faunaMap =>
      (_data['fauna_types'] as Map?)?.cast<String, dynamic>() ?? {};

  // ─── Scheduling ─────────────────────────────────────────────────────────────

  int get firstRaidWeek =>
      _scheduling['first_raid_week'] as int? ?? 10;

  int raidInterval(Difficulty difficulty) {
    return switch (difficulty) {
      Difficulty.easy   => _intervals['easy'] as int? ?? 4,
      Difficulty.normal => _intervals['normal'] as int? ?? 3,
      Difficulty.hard   => _intervals['hard'] as int? ?? 2,
    };
  }

  int get raidWarningWeeksBefore =>
      _scheduling['raid_warning_weeks_before'] as int? ?? 2;

  // ─── Scaling ────────────────────────────────────────────────────────────────

  Map<String, dynamic> get scaling => _scaling;

  int get baseFaunaCount => 5; // handled by generateSpawnQueueForWave

  int get faunaPerWeek => 1;

  int get faunaPerWeekDivisor => 3;

  double get spawnIntervalBase =>
      (_scaling['spawn_interval_base'] as num?)?.toDouble() ?? 3.0;

  double get spawnIntervalMin =>
      (_scaling['spawn_interval_min'] as num?)?.toDouble() ?? 1.5;

  int get raidDurationMax =>
      _scaling['raid_duration_max'] as int? ?? 60;

  int faunaCountForWeek(int wave) {
    // Total spawns come from the wave queue, not this formula — but preserved for compat.
    return generateSpawnQueueForWave(wave).length;
  }

  // ─── Infinite Stat Generator Math ──────────────────────────────────────────

  /// Dynamically calculates stats for ANY creature at ANY level to infinity.
  /// Looks up baseline L1 stats from raids.yaml and slaps on +100 HP / +14 DMG per level.
  ScaledFaunaStats getScaledStats(String baseName, int level) {
    final base = getFaunaType(baseName);

    // Safety fallback defaults if YAML structure doesn't respond
    int baseHp = base?['hp'] ?? 20;
    int baseDamage = base?['damage'] ?? 8;
    double speed = (base?['speed'] ?? 1.5).toDouble();

    if (level <= 1) {
      return ScaledFaunaStats(hp: baseHp, damage: baseDamage, speed: speed);
    }

    // Dynamic linear math: +100 HP and +14 Damage for every level above 1
    int finalHp = baseHp + ((level - 1) * 100);
    int finalDamage = baseDamage + ((level - 1) * 14);

    return ScaledFaunaStats(hp: finalHp, damage: finalDamage, speed: speed);
  }

  // ─── Deterministic Wave Queue Generator ─────────────────────────────────────

  // Generate a wave of fauna
  List<SpawnInstruction> generateSpawnQueueForWave(int wave) {
    final List<SpawnInstruction> queue = [];
    final Map<String, int> composition = _getWaveComposition(wave);

    composition.forEach((spawnKey, count) {
      // Split key syntax like "Lunar Crawler_v2" into component variables
      final parts = spawnKey.split('_v');
      final baseName = parts[0];
      final level = int.parse(parts[1]);

      for (int i = 0; i < count; i++) {
        queue.add(SpawnInstruction(baseName: baseName, level: level));
      }
    });

    queue.shuffle(); //we don't want them to come out in power order, so shuffle

    return queue;
  }

  /// Internal engine map mimicking your exact row/column stair-step progression.
  Map<String, int> _getWaveComposition(int wave) {
    // Manual overrides matching your exact custom early balancing grid (Waves 1-4)
    if (wave == 1) {
      return {'Lunar Crawler_v1': 8};
    }
    if (wave == 2) {
      return {
        'Lunar Crawler_v1': 8,
        'Lunar Scout_v1': 4,
        'Dust Swarmer_v1': 4,
      };
    }
    if (wave == 3) {
      return {
        'Lunar Crawler_v1': 12,
        'Lunar Scout_v1': 8,
        'Dust Swarmer_v1': 4,
        'Chitin Leech_v1': 4,
        'Dune Vanguard_v1': 2,
        'Shell-Back_v1': 1,
        'Sledge Wrecker_v1': 1,
      };
    }
    if (wave == 4) {
      return {
        'Lunar Crawler_v1': 32,
        'Lunar Scout_v1': 16,
        'Dust Swarmer_v1': 8,
        'Chitin Leech_v1': 4,
        'Dune Vanguard_v1': 2,
        'Shell-Back_v1': 1,
        'Sledge Wrecker_v1': 1,
      };
    }

    // Infinite automated layout (Wave 5+)
    final Map<String, int> composition = {};

    // Core 10 creatures matching your spreadsheet row array exactly
    final List<String> baseCreatures = [
      'Lunar Crawler',
      'Lunar Scout',
      'Dust Swarmer',
      'Chitin Leech',
      'Dune Vanguard',
      'Shell-Back',
      'Sledge Wrecker',
      'Crater Brute',
      'Ridge Goliath',
      'Apex Stalker'
    ];

    int globalStaircaseIndex = wave - 5;
    int currentSpawnAmount = 64;

    for (int i = 0; i < 7; i++) {
      int targetIndex = globalStaircaseIndex + i;

      String baseName = baseCreatures[targetIndex % 10];
      int creatureLevel = (targetIndex ~/ 10) + 1;

      String spawnKey = "${baseName}_v$creatureLevel";
      composition[spawnKey] = currentSpawnAmount;

      if (currentSpawnAmount > 1) {
        currentSpawnAmount ~/= 2;
      }
    }

    return composition;
  }

  // ─── Native Fauna Accessors ────────────────────────────────────────────────

  /// All fauna as a list of maps, each including the display_name as 'id'.
  List<Map<String, dynamic>> get allFaunaTypes {
    return _faunaMap.entries.map((e) {
      final m = Map<String, dynamic>.from(e.value as Map);
      m['id'] = e.key; // key is the display name
      return m;
    }).toList();
  }

  /// Look up by display name (e.g. "Lunar Crawler").
  Map<String, dynamic>? getFaunaType(String id) {
    final entry = _faunaMap[id];
    if (entry == null) return null;
    final m = Map<String, dynamic>.from(entry as Map);
    m['id'] = id;
    return m;
  }

  /// Preserved so old random code doesn't crash during conversion.
  List<Map<String, dynamic>> faunaAvailableAtRaid(int raidNumber) =>
      allFaunaTypes;

  /// Preserved for legacy call sites — returns last fauna as fallback.
  Map<String, dynamic> pickFaunaType(Random rng, {required int raidNumber}) {
    final available = allFaunaTypes;
    if (available.isEmpty) return {};
    return available.last;
  }

  // ─── Drops ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> get drops => _drops;

  double get meatChance =>
      (_drops['meat_chance'] as num?)?.toDouble() ?? 0.7;

  double get chitinChanceClimbPerKill =>
      (_drops['chitin_chance_climb_per_kill'] as num?)?.toDouble() ?? 0.02;

  /// Base chitin drop chance for a given fauna type, before the per-kill
  /// climb is added on top. Falls back to a modest default if a type is
  /// missing the field (e.g. a fauna type added without updating the yaml).
  double chitinChanceFor(String faunaTypeId) =>
      (getFaunaType(faunaTypeId)?['chitin_chance'] as num?)?.toDouble() ?? 0.1;
}