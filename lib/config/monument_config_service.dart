// ═══════════════════════════════════════════════════════════════
//  lib/config/monument_config_service.dart
// ═══════════════════════════════════════════════════════════════
// Loads the 10 monument types from assets/config/monuments.yaml.
// Edit that file to rebalance costs/score or rewrite lore — no Dart
// changes needed.

import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class MonumentConfig {
  final int mkLevel; // 1-10
  final String id;
  final String name;
  final String lore;
  final String emoji;
  final double costMoonDirt;
  final double costMetals;
  final double costWater;
  final int scoreValue;

  const MonumentConfig({
    required this.mkLevel,
    required this.id,
    required this.name,
    required this.lore,
    required this.emoji,
    required this.costMoonDirt,
    required this.costMetals,
    required this.costWater,
    required this.scoreValue,
  });
}

class MonumentConfigService {
  MonumentConfigService._();
  static final MonumentConfigService instance = MonumentConfigService._();

  List<MonumentConfig> _monuments = [];

  Future<void> load() async {
    final raw = await rootBundle.loadString('assets/config/monuments.yaml');
    final doc = loadYaml(raw) as YamlMap;
    final list = doc['monuments'] as YamlList;

    _monuments = list.map((m) {
      final map = m as YamlMap;
      return MonumentConfig(
        mkLevel: map['mk_level'] as int,
        id: map['id'] as String,
        name: map['name'] as String,
        lore: map['lore'] as String,
        emoji: map['emoji'] as String? ?? '🗿',
        costMoonDirt: (map['cost_moon_dirt'] as num).toDouble(),
        costMetals: (map['cost_metals'] as num).toDouble(),
        costWater: (map['cost_water'] as num).toDouble(),
        scoreValue: map['score_value'] as int,
      );
    }).toList()
      ..sort((a, b) => a.mkLevel.compareTo(b.mkLevel));
  }

  List<MonumentConfig> getAllMonuments() => _monuments;

  MonumentConfig? getMonumentByMkLevel(int mkLevel) {
    for (final m in _monuments) {
      if (m.mkLevel == mkLevel) return m;
    }
    return null;
  }
}
