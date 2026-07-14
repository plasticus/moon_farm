// ═══════════════════════════════════════════════════════════════
//  lib/config/milestone_config_service.dart
// ═══════════════════════════════════════════════════════════════
// Loads all milestone and difficulty configuration from
// assets/config/milestone_config.yaml.
// Edit that file to rebalance goals without touching Dart code.

import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import '../models/game_models.dart';

class MilestoneConfigService {
  MilestoneConfigService._();
  static final MilestoneConfigService instance = MilestoneConfigService._();

  Map<String, dynamic> _data = {};

  Future<void> load() async {
    final raw = await rootBundle.loadString('assets/config/milestone_config.yaml');
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

  // ─── Difficulty ─────────────────────────────────────────────────────────────

  Map<String, dynamic> _difficultyConfig(Difficulty d) {
    final diff = _data['difficulty'] as Map<String, dynamic>?;
    return (diff?[d.name] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// How many wall breaches are allowed before game over.
  /// 0 = any breach = instant game over.
  int wallStrikes(Difficulty d) =>
      _difficultyConfig(d)['wall_strikes'] as int? ?? 0;

  /// Fraction of crops lost when wall breaks (Easy only).
  double cropLossOnBreach(Difficulty d) =>
      (_difficultyConfig(d)['crop_loss_on_breach'] as num?)?.toDouble() ?? 0.0;

  /// Contract termination message template.
  /// Use {week} and {strikes} as placeholders.
  String terminationMessage(Difficulty d) =>
      _difficultyConfig(d)['contract_termination_message'] as String? ??
          'Contract nullified.';

  // ─── Milestones ─────────────────────────────────────────────────────────────

  List<Milestone> getMilestones(Difficulty difficulty) {
    final milestones = _data['milestones'] as Map<String, dynamic>?;
    final list = milestones?[difficulty.name] as List?;
    if (list == null) return [];

    return list.map((m) {
      final map = m as Map<String, dynamic>;
      return Milestone(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        targetVolumeM3: (map['target_volume_m3'] as num).toDouble(),
        byWeek: map['by_week'] as int,
        rewardScrip: map['reward_scrip'] as int,
        failureMessage: map['failure_message'] as String? ?? '',
        failureDetail: map['failure_detail'] as String? ?? '',
        status: MilestoneStatus.pending,
      );
    }).toList();
  }

  /// Returns the failure message for a specific milestone, with
  /// {actual} and {target} substituted.
  String formatFailureDetail(Milestone m, double actualM3) {
    return m.failureDetail
        .replaceAll('{actual}', actualM3.toStringAsFixed(1))
        .replaceAll('{target}', m.targetVolumeM3.toStringAsFixed(0));
  }

  String formatTerminationMessage(Difficulty d, {int? week, int? strikes}) {
    return terminationMessage(d)
        .replaceAll('{week}', '${week ?? '?'}')
        .replaceAll('{strikes}', '${strikes ?? '?'}');
  }

}