// ═══════════════════════════════════════════════════════════════
//  lib/config/upgrade_config_service.dart
// ═══════════════════════════════════════════════════════════════
// Loads the three upgrade-path YAML files and exposes typed queries.
//   - upgrades_refinery.yaml
//   - upgrades_defense.yaml
//   - upgrades_domebots.yaml

import 'dart:math';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class UpgradeConfigService {
  UpgradeConfigService._();
  static final UpgradeConfigService instance = UpgradeConfigService._();

  Map<String, dynamic>? _refinery;
  Map<String, dynamic>? _defense;
  Map<String, dynamic>? _domebots;
  Map<String, dynamic>? _domeTiers;
  Map<String, dynamic>? _raids;

  bool get isLoaded =>
      _refinery != null && _defense != null && _domebots != null &&
          _domeTiers != null && _raids != null;

  Future<void> load() async {
    _refinery = await _loadYaml('assets/config/upgrades_refinery.yaml');
    _defense = await _loadYaml('assets/config/upgrades_defense.yaml');
    _domebots = await _loadYaml('assets/config/upgrades_domebots.yaml');
    _domeTiers = await _loadYaml('assets/config/upgrades_dome.yaml');
    _raids = await _loadYaml('assets/config/raids.yaml');
  }

  Future<Map<String, dynamic>> _loadYaml(String path) async {
    final raw = await rootBundle.loadString(path);
    final doc = loadYaml(raw);
    final converted = _deepConvert(doc);
    if (converted is Map<String, dynamic>) return converted;
    // Empty or malformed YAML — return empty map rather than crashing.
    return <String, dynamic>{};
  }

  // YAML returns YamlMap/YamlList — convert to plain Dart maps/lists recursively.
  dynamic _deepConvert(dynamic node) {
    if (node is YamlMap) {
      return node.map((k, v) => MapEntry(k.toString(), _deepConvert(v)));
    } else if (node is YamlList) {
      return node.map(_deepConvert).toList();
    } else {
      return node;
    }
  }

  // ─── REFINERY ──────────────────────────────────────────────────

  /// All machine keys: composter, smelter, z_soil_processor, glass_furnace, component_fabricator
  Map<String, dynamic> get refineryMachines => _refinery ?? {};

  Map<String, dynamic>? getMachine(String key) =>
      _refinery?[key] as Map<String, dynamic>?;

  /// Returns the level config map for a given machine + level (1-indexed).
  Map<String, dynamic>? getMachineLevel(String key, int level) {
    final machine = getMachine(key);
    if (machine == null) return null;
    final levels = machine['levels'] as List?;
    if (levels == null) return null;
    for (final l in levels) {
      if ((l as Map)['level'] == level) return Map<String, dynamic>.from(l);
    }
    return null;
  }

  int machineMaxLevel(String key) {
    final machine = getMachine(key);
    if (machine == null) return 1;
    // Honor caps_at_level if present (composter caps at 3)
    if (machine['caps_at_level'] != null) return machine['caps_at_level'] as int;
    final levels = machine['levels'] as List?;
    return levels?.length ?? 1;
  }

  // ─── DEFENSE ───────────────────────────────────────────────────

  List<Map<String, dynamic>> get wallLevels {
    final w = _defense?['defense_wall'] as Map<String, dynamic>?;
    final levels = w?['levels'] as List?;
    return levels?.map((l) => Map<String, dynamic>.from(l as Map)).toList() ?? [];
  }

  Map<String, dynamic>? getWallLevel(int level) {
    for (final l in wallLevels) {
      if (l['level'] == level) return l;
    }
    return null;
  }

  List<Map<String, dynamic>> get sentryLevels {
    final s = _defense?['sentries'] as Map<String, dynamic>?;
    final levels = s?['levels'] as List?;
    return levels?.map((l) => Map<String, dynamic>.from(l as Map)).toList() ?? [];
  }

  Map<String, dynamic>? getSentryLevel(int level) {
    for (final l in sentryLevels) {
      if (l['level'] == level) return l;
    }
    return null;
  }

  List<Map<String, dynamic>> get grenadeBenchLevels {
    final b = _defense?['grenade_bench'] as Map<String, dynamic>?;
    final levels = b?['levels'] as List?;
    return levels?.map((l) => Map<String, dynamic>.from(l as Map)).toList() ?? [];
  }

  List<Map<String, dynamic>> get grenades {
    final g = _defense?['grenades'] as List?;
    return g?.map((l) => Map<String, dynamic>.from(l as Map)).toList() ?? [];
  }

  Map<String, dynamic>? getGrenade(String id) {
    for (final g in grenades) {
      if (g['id'] == id) return g;
    }
    return null;
  }

  // ─── DOME BOTS ─────────────────────────────────────────────────

  List<Map<String, dynamic>> get domeBotLevels {
    final d = _domebots?['dome_bots'] as Map<String, dynamic>?;
    final levels = d?['levels'] as List?;
    return levels?.map((l) => Map<String, dynamic>.from(l as Map)).toList() ?? [];
  }

  Map<String, dynamic>? getDomeBotLevel(int level) {
    for (final l in domeBotLevels) {
      if (l['level'] == level) return l;
    }
    return null;
  }

  int get domeBotMaxLevel => domeBotLevels.length;

  // ─── DOME TIERS ────────────────────────────────────────────────

  List<Map<String, dynamic>> get domeTiers {
    final levels = _domeTiers?['dome_tiers'] as List?;
    return levels?.map((l) => Map<String, dynamic>.from(l as Map)).toList() ?? [];
  }

  Map<String, dynamic>? getDomeTier(int tier) {
    for (final t in domeTiers) {
      if (t['tier'] == tier) return t;
    }
    return null;
  }

  int domeTierPowerDraw(int tier) {
    final t = getDomeTier(tier);
    return t?['power_draw_kwh'] as int? ?? 25;
  }

  int get domeMaxTier => domeTiers.length;

  // ─── RAIDS ─────────────────────────────────────────────────────

  Map<String, dynamic> get raidScheduling =>
      (_raids?['scheduling'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get raidScaling =>
      (_raids?['scaling'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get raidFaunaTypes =>
      (_raids?['fauna_types'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get raidDrops =>
      (_raids?['drops'] as Map?)?.cast<String, dynamic>() ?? {};

  int get firstRaidWeek => raidScheduling['first_raid_week'] as int? ?? 10;

  int raidInterval(String difficulty) {
    return switch (difficulty) {
      'easy' => raidScheduling['raid_interval_easy'] as int? ?? 12,
      'hard' => raidScheduling['raid_interval_hard'] as int? ?? 6,
      _ => raidScheduling['raid_interval_normal'] as int? ?? 10,
    };
  }

  // ─── FAUNA TYPES ────────────────────────────────────────────────

  List<Map<String, dynamic>> get faunaTypes {
    final list = _raids?['fauna_types'] as List?;
    return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  Map<String, dynamic>? getFaunaType(String id) {
    for (final f in faunaTypes) {
      if (f['id'] == id) return f;
    }
    return null;
  }

  /// Pick a fauna type based on spawn_chance ordering.
  /// Types are checked in list order; first one whose spawn_chance roll passes wins.
  Map<String, dynamic> pickFaunaType(Random rng) {
    for (final f in faunaTypes) {
      final chance = (f['spawn_chance'] as num?)?.toDouble() ?? 1.0;
      if (rng.nextDouble() < chance) return f;
    }
    return faunaTypes.last; // fallback
  }
}