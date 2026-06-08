// ═══════════════════════════════════════════════════════════════
//  lib/screens/week_summary/week_summary_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/game_config_service.dart';

class WeekSummaryScreen extends ConsumerWidget {
  final WeekSummary summary;

  const WeekSummaryScreen({super.key, required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(activeGameProvider).value;

    return Scaffold(
      backgroundColor: MFColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: MFColors.borderSubtle),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'WEEK ${summary.week} COMPLETE',
                    style: MFTextStyles.displayMedium.copyWith(
                      color: MFColors.neonCyan,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Entering Week ${summary.newWeek}',
                    style: MFTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),

            // ── Scrollable content ────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Star-Scrip received
                  if (summary.scripReceived > 0)
                    _SummaryCard(
                      icon: '🎫',
                      title: 'Star-Scrip Received',
                      value: '+${summary.scripReceived}',
                      valueColor: MFColors.starScrip,
                      highlight: true,
                    ),

                  const SizedBox(height: 8),

                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          icon: '🌾',
                          label: 'Harvested',
                          value: '${summary.cropsHarvested}',
                          color: MFColors.neonGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatBox(
                          icon: '💀',
                          label: 'Died',
                          value: '${summary.cropsDied}',
                          color: summary.cropsDied > 0
                              ? MFColors.neonPink
                              : MFColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatBox(
                          icon: '📦',
                          label: 'Delivered',
                          value: '${summary.volumeToColonyM3.toStringAsFixed(1)}m³',
                          color: MFColors.neonCyan,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Robot actions
                  if (summary.robotActions.isNotEmpty) ...[
                    _SectionLabel('ROBOT ACTIVITY'),
                    const SizedBox(height: 6),
                    ...summary.robotActions.map(
                          (a) => _EventRow(text: '🤖 $a', color: MFColors.neonCyan),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Milestone updates
                  if (summary.milestoneUpdates.isNotEmpty) ...[
                    _SectionLabel('COLONY MILESTONES'),
                    const SizedBox(height: 6),
                    ...summary.milestoneUpdates.map(
                          (m) => _EventRow(
                        text: m,
                        color: m.contains('❌')
                            ? MFColors.neonPink
                            : MFColors.neonGreen,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // New trophies
                  if (summary.newTrophies.isNotEmpty) ...[
                    _SectionLabel('TROPHIES'),
                    const SizedBox(height: 6),
                    ...summary.newTrophies.map(
                          (t) => _EventRow(text: t, color: MFColors.neonGold),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // All events log
                  if (summary.events.isNotEmpty) ...[
                    _SectionLabel('WEEK LOG'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MFColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: MFColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _groupEvents(summary.events)
                            .map(
                              (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              e,
                              style: MFTextStyles.bodySmall.copyWith(
                                color: _eventColor(e),
                              ),
                            ),
                          ),
                        )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Game over state
                  if (game?.status == GameStatus.terminated) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MFColors.neonPink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: MFColors.neonPink),
                      ),
                      child: Column(
                        children: [
                          const Text('📡', style: TextStyle(fontSize: 32)),
                          const SizedBox(height: 8),
                          Text(
                            'CONTRACT TERMINATED',
                            style: MFTextStyles.headlineMedium.copyWith(
                              color: MFColors.neonPink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'The colony has ended your agricultural contract. '
                                'Operation shut down.',
                            style: MFTextStyles.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Radio transmission ───────────────────────────────────
                  _RadioTipCard(week: summary.newWeek),
                  const SizedBox(height: 80),
                ],
              ),
            ),

            // ── Continue button ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(weekSummaryProvider.notifier).state = null;
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: game?.status == GameStatus.terminated
                        ? MFColors.neonPink
                        : MFColors.neonCyan,
                    foregroundColor: MFColors.background,
                  ),
                  child: Text(
                    game?.status == GameStatus.terminated
                        ? 'RETURN TO MAIN MENU'
                        : '▶  BEGIN WEEK ${summary.newWeek}',
                    style: MFTextStyles.labelLarge.copyWith(
                      color: MFColors.background,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Collapse duplicate event lines into "message (x3)" format
  List<String> _groupEvents(List<String> events) {
    if (events.isEmpty) return events;
    final grouped = <String>[];
    int count = 1;
    for (int i = 0; i < events.length; i++) {
      if (i + 1 < events.length && events[i] == events[i + 1]) {
        count++;
      } else {
        grouped.add(count > 1 ? '${events[i]} (x$count)' : events[i]);
        count = 1;
      }
    }
    return grouped;
  }

  Color _eventColor(String event) {
    if (event.contains('💀') || event.contains('❌')) return MFColors.neonPink;
    if (event.contains('✅') || event.contains('🎖️')) return MFColors.neonGreen;
    if (event.contains('⚠️')) return MFColors.neonOrange;
    if (event.contains('🏆')) return MFColors.neonGold;
    return MFColors.textSecondary;
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final Color valueColor;
  final bool highlight;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.valueColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? valueColor.withValues(alpha: 0.08) : MFColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? valueColor.withValues(alpha: 0.4) : MFColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: MFTextStyles.bodyLarge),
          ),
          Text(
            value,
            style: MFTextStyles.headlineMedium.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MFColors.borderSubtle),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            value,
            style: MFTextStyles.labelLarge.copyWith(color: color),
          ),
          Text(label, style: MFTextStyles.bodySmall.copyWith(fontSize: 9)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: MFTextStyles.bodySmall.copyWith(
        color: MFColors.textMuted,
        letterSpacing: 2,
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final String text;
  final Color color;
  const _EventRow({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: MFTextStyles.bodySmall.copyWith(color: color),
      ),
    );
  }
}

// ─── Radio Tip Card ───────────────────────────────────────────────────────────

class _RadioTipCard extends StatelessWidget {
  final int week;
  const _RadioTipCard({required this.week});

  @override
  Widget build(BuildContext context) {
    final tips = GameConfigService.instance.getRadioTips();
    // Find the most recent tip at or before this week
    Map<String, dynamic>? tip;
    for (final t in tips) {
      final tWeek = t['week'] as int;
      if (tWeek <= week) {
        if (tip == null || tWeek > (tip['week'] as int)) {
          tip = t;
        }
      }
    }

    if (tip == null) return const SizedBox();

    final isRaidWarning = (tip['message'] as String).contains('⚠️') ||
        (tip['message'] as String).contains('Raid') ||
        (tip['message'] as String).contains('raid') ||
        (tip['message'] as String).contains('fauna');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRaidWarning
              ? MFColors.neonPink.withValues(alpha: 0.5)
              : MFColors.neonCyan.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isRaidWarning ? '📻⚠️' : '📻',
              style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip['message'] as String,
              style: MFTextStyles.bodySmall.copyWith(
                color: isRaidWarning ? MFColors.neonPink : MFColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}