// ═══════════════════════════════════════════════════════════════
//  lib/screens/score/score_screen.dart
// ═══════════════════════════════════════════════════════════════
// Shown when the game ends — contract terminated (wall breach,
// missed milestone, or manual termination). Also shown when loading
// a save slot that is in terminated status.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/game_config_service.dart';
import '../../widgets/space_background.dart';
import '../main_menu/main_menu_screen.dart';

class ScoreScreen extends ConsumerWidget {
  final GameState game;

  const ScoreScreen({super.key, required this.game});

  // ── Score formula ────────────────────────────────────────────
  // Base:         totalVolumeDeliveredM3 * 100
  // Combat:       totalFaunaKilled * 25
  // Economy:      lifetimeScripEarned * 2
  // Survival:     currentWeek * 50
  // Efficiency:   raidsDefended * 500
  // Penalty:      strikeCount * -2000
  static int calculateScore(GameState g) {
    final base = (g.totalVolumeDeliveredM3 * 100).round();
    final combat = g.totalFaunaKilled * 25;
    final economy = g.lifetimeScripEarned * 2;
    final survival = g.currentWeek * 50;
    final raids = g.totalRaidsDefended * 500;
    final penalty = g.strikeCount * 2000;
    return (base + combat + economy + survival + raids - penalty).clamp(0, 999999999);
  }

  static String _scoreGrade(int score) {
    if (score >= 500000) return 'S';
    if (score >= 200000) return 'A';
    if (score >= 100000) return 'B';
    if (score >= 50000)  return 'C';
    if (score >= 20000)  return 'D';
    return 'F';
  }

  static Color _gradeColor(String grade) => switch (grade) {
    'S' => const Color(0xFFFFD700),   // gold
    'A' => const Color(0xFF00BCD4),   // cyan
    'B' => const Color(0xFF66BB6A),   // green
    'C' => const Color(0xFFFF9800),   // orange
    'D' => const Color(0xFF9E9E9E),   // gray
    _   => const Color(0xFFE53935),   // red
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = calculateScore(game);
    final grade = _scoreGrade(score);
    final gradeColor = _gradeColor(grade);
    final config = GameConfigService.instance;
    final won = game.status == GameStatus.won;
    final headerColor = won ? MFColors.neonGreen : MFColors.neonPink;

    // Top 5 crops by harvest count
    final sortedCrops = game.cropHarvestCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedCrops.take(5).toList();

    return Scaffold(
      backgroundColor: MFColors.background,
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),

                      // ── Header ──────────────────────────────────────────
                      Text(
                        won ? 'FREE AND CLEAR' : 'CONTRACT VOID',
                        style: MFTextStyles.labelLarge.copyWith(
                          color: headerColor,
                          fontSize: 11,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        game.farmName.toUpperCase(),
                        style: MFTextStyles.labelLarge.copyWith(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Week ${game.currentWeek}  ·  ${game.difficulty.name.toUpperCase()}',
                        style: MFTextStyles.bodySmall.copyWith(
                            color: MFColors.textMuted),
                      ),

                      const SizedBox(height: 20),

                      // ── Termination reason / win message ─────────────────
                      if (won)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: MFColors.neonGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: MFColors.neonGreen.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'You paid off the colony contract in full at Week '
                            '${game.currentWeek}. No more indentured shipments — '
                            'this land is yours now.',
                            style: MFTextStyles.bodySmall.copyWith(
                                color: MFColors.neonGreen),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else if (game.terminationReason != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: MFColors.neonPink.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: MFColors.neonPink.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            game.terminationReason!,
                            style: MFTextStyles.bodySmall.copyWith(
                                color: MFColors.neonPink),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // ── Score ────────────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: gradeColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: gradeColor.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            Text('FINAL SCORE',
                                style: MFTextStyles.bodySmall.copyWith(
                                    color: MFColors.textMuted, letterSpacing: 3,
                                    fontSize: 9)),
                            const SizedBox(height: 8),
                            Text(
                              _formatScore(score),
                              style: TextStyle(
                                color: gradeColor,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 6),
                              decoration: BoxDecoration(
                                color: gradeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'GRADE  $grade',
                                style: TextStyle(
                                  color: gradeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Stats ────────────────────────────────────────────
                      _StatsCard(
                        title: 'CAREER SUMMARY',
                        rows: [
                          _StatRow('🎫', 'Star-Scrip Earned',
                              '${game.lifetimeScripEarned}',
                              highlight: true),
                          _StatRow('📦', 'Cargo Delivered',
                              '${game.totalVolumeDeliveredM3.toStringAsFixed(1)}m³'),
                          _StatRow('📅', 'Weeks Survived',
                              '${game.currentWeek}'),
                          _StatRow('🛡️', 'Raids Defended',
                              '${game.totalRaidsDefended}'),
                          _StatRow('💀', 'Fauna Killed',
                              '${game.totalFaunaKilled}'),
                          _StatRow('🦴', 'Chitin Collected',
                              '${game.totalChitinCollected}'),
                          _StatRow('🌾', 'Crops Harvested',
                              '${game.totalCropsHarvested}'),
                          _StatRow('⚡', 'Domes Built',
                              '${game.domes.length}'),
                        ],
                      ),

                      // ── Top crops ────────────────────────────────────────
                      if (top5.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _StatsCard(
                          title: 'TOP CROPS GROWN',
                          rows: top5.map((e) {
                            final crop = config.getCrop(e.key);
                            final label = crop?.name ?? e.key;
                            final emoji = crop?.emoji ?? '🌱';
                            return _StatRow(emoji, label, '×${e.value}');
                          }).toList(),
                        ),
                      ],

                      // ── Score breakdown ──────────────────────────────────
                      const SizedBox(height: 12),
                      _StatsCard(
                        title: 'SCORE BREAKDOWN',
                        rows: [
                          _StatRow('📦', 'Cargo (×100/m³)',
                              '+${(game.totalVolumeDeliveredM3 * 100).round()}'),
                          _StatRow('💀', 'Combat (×25/kill)',
                              '+${game.totalFaunaKilled * 25}'),
                          _StatRow('🎫', 'Economy (×2/scrip)',
                              '+${game.lifetimeScripEarned * 2}'),
                          _StatRow('📅', 'Survival (×50/week)',
                              '+${game.currentWeek * 50}'),
                          _StatRow('🛡️', 'Raids (×500)',
                              '+${game.totalRaidsDefended * 500}'),
                          if (game.strikeCount > 0)
                            _StatRow('⚠️', 'Breach penalty',
                                '-${game.strikeCount * 2000}',
                                highlight: false, negative: true),
                        ],
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

              // ── Return / keep playing buttons ───────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    if (won) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MFColors.neonGreen,
                            foregroundColor: MFColors.background,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('KEEP PLAYING',
                              style: MFTextStyles.labelLarge.copyWith(
                                  color: MFColors.background, letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: won ? 44 : 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: won ? MFColors.borderDefault : MFColors.neonCyan),
                          backgroundColor:
                              won ? Colors.transparent : MFColors.neonCyan,
                          foregroundColor: won
                              ? MFColors.textSecondary
                              : MFColors.background,
                        ),
                        onPressed: () {
                          ref.read(activeGameProvider.notifier).clearGame();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const MainMenuScreen()),
                                (route) => false,
                          );
                        },
                        child: Text('RETURN TO MAIN MENU',
                            style: MFTextStyles.labelLarge.copyWith(
                                color: won
                                    ? MFColors.textSecondary
                                    : MFColors.background,
                                letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatScore(int score) {
    if (score >= 1000000) {
      return '${(score / 1000000).toStringAsFixed(1)}M';
    }
    if (score >= 1000) {
      final s = score.toString();
      final parts = <String>[];
      for (int i = s.length; i > 0; i -= 3) {
        parts.insert(0, s.substring((i - 3).clamp(0, s.length), i));
      }
      return parts.join(',');
    }
    return '$score';
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final String title;
  final List<_StatRow> rows;
  const _StatsCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MFColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: MFTextStyles.bodySmall.copyWith(
                  color: MFColors.textMuted, letterSpacing: 2, fontSize: 9)),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final bool highlight;
  final bool negative;

  const _StatRow(this.emoji, this.label, this.value,
      {this.highlight = false, this.negative = false});

  @override
  Widget build(BuildContext context) {
    final valueColor = negative
        ? MFColors.neonPink
        : highlight
        ? MFColors.neonCyan
        : MFColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: MFTextStyles.bodySmall.copyWith(
                    color: highlight ? MFColors.textPrimary : MFColors.textSecondary,
                    fontWeight: highlight ? FontWeight.bold : FontWeight.normal)),
          ),
          Text(value,
              style: MFTextStyles.labelLarge.copyWith(
                  color: valueColor, fontSize: 13)),
        ],
      ),
    );
  }
}