// ═══════════════════════════════════════════════════════════════
//  lib/screens/save_slots/save_slot_detail_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../engine/end_week_engine.dart';
import '../../database/database_helper.dart';
import '../dome/dome_screen.dart';
import '../week_summary/week_summary_screen.dart';
import '../dev/dev_tools_screen.dart';
import '../main_menu/main_menu_screen.dart';

class SaveSlotDetailScreen extends ConsumerStatefulWidget {
  const SaveSlotDetailScreen({super.key});

  @override
  ConsumerState<SaveSlotDetailScreen> createState() =>
      _SaveSlotDetailScreenState();
}

class _SaveSlotDetailScreenState extends ConsumerState<SaveSlotDetailScreen> {
  int _currentTab = 0;

  static const _tabs = [
    _TabItem(icon: Icons.dashboard, label: 'Dashboard'),
    _TabItem(icon: Icons.circle, label: 'Domes'),
    _TabItem(icon: Icons.science, label: 'Refinery'),
    _TabItem(icon: Icons.satellite_alt, label: 'Relay'),
    _TabItem(icon: Icons.home, label: 'Habitat'),
  ];

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(activeGameProvider);

    return gameAsync.when(
      loading: () => const Scaffold(
        backgroundColor: MFColors.background,
        body: Center(child: CircularProgressIndicator(color: MFColors.neonCyan)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: MFColors.background,
        body: Center(child: Text('Error: $e')),
      ),
      data: (game) {
        if (game == null) {
          return const Scaffold(
            backgroundColor: MFColors.background,
            body: Center(child: Text('No game loaded.')),
          );
        }
        return Scaffold(
          backgroundColor: MFColors.background,
          appBar: _buildAppBar(context, game),
          body: _buildBody(game),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, GameState game) {
    final powerSurplus = game.powerSurplus;
    final raidWarning = ref.watch(raidWarningProvider);
    final isRaidWeek = ref.watch(isRaidWeekProvider);
    final unreadRadio = ref.watch(unreadRadioCountProvider);

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Farm name — long press opens dev tools
            Expanded(
              child: GestureDetector(
                onLongPress: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DevToolsScreen()),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.farmName.toUpperCase(),
                      style: MFTextStyles.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Week ${game.currentWeek}  ·  ${game.difficulty.name.toUpperCase()}',
                      style: MFTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            _StatusChip(
              label: '${powerSurplus >= 0 ? '+' : ''}$powerSurplus',
              color: powerSurplus >= 0 ? MFColors.statusOptimal : MFColors.statusCritical,
              icon: '⚡',
            ),
            const SizedBox(width: 6),
            _StatusChip(
              label: '${game.resources.starScrip}',
              color: MFColors.starScrip,
              icon: '🎫',
            ),
            const SizedBox(width: 6),
            if (isRaidWeek)
              _StatusChip(label: 'RAID!', color: MFColors.neonPink, icon: '🚨')
            else if (raidWarning)
              _StatusChip(
                label: '${game.nextRaidWeek - game.currentWeek}w',
                color: MFColors.neonOrange,
                icon: '⚠️',
              ),
            if (unreadRadio > 0) ...[
              const SizedBox(width: 4),
              _StatusChip(label: '$unreadRadio', color: MFColors.neonCyan, icon: '📡'),
            ],
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              color: MFColors.surface,
              iconColor: MFColors.textSecondary,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'save',
                  child: Text('Save Game', style: MFTextStyles.bodyLarge),
                ),
                const PopupMenuItem(
                  value: 'mainmenu',
                  child: Text('Main Menu', style: TextStyle(color: MFColors.neonPink)),
                ),
              ],
              onSelected: (val) async {
                if (val == 'save') {
                  await ref.read(activeGameProvider.notifier).persistCurrentState();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Game saved.')),
                    );
                  }
                } else if (val == 'mainmenu') {
                  ref.read(activeGameProvider.notifier).clearGame();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainMenuScreen()),
                          (route) => false,
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(GameState game) {
    switch (_currentTab) {
      case 0: return _DashboardTab(game: game, onEndWeek: () => _doEndWeek(game));
      case 1: return const DomeScreen();
      case 2: return _RefineryStub(game: game);
      case 3: return _RelayStub(game: game);
      case 4: return _HabitatStub(game: game);
      default: return const SizedBox();
    }
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentTab,
      onTap: (i) => setState(() => _currentTab = i),
      items: _tabs
          .map((t) => BottomNavigationBarItem(icon: Icon(t.icon), label: t.label))
          .toList(),
    );
  }

  // ─── End Week ───────────────────────────────────────────────────────────

  Future<void> _doEndWeek(GameState game) async {
    final isRaidWeek = ref.read(isRaidWeekProvider);
    if (isRaidWeek) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Defend the raid first!')),
      );
      return;
    }

    ref.read(endWeekLoadingProvider.notifier).state = true;

    try {
      final engine = EndWeekEngine();
      final (newState, summary) = engine.processEndWeek(game);

      // Persist
      await ref.read(activeGameProvider.notifier).updateGame(newState);

      // Log to DB
      await DatabaseHelper.instance.insertLogEntry(
        newState.slotNumber,
        WeeklyLogEntry(
          week: summary.week,
          events: summary.events,
          scripGained: summary.scripReceived,
          scripSpent: summary.scripSpent,
          cropsHarvested: summary.cropsHarvested,
          volumeDeliveredM3: summary.volumeToColonyM3,
          raidOccurred: summary.raidOccurred,
          raidSucceeded: false,
          timestamp: DateTime.now(),
        ),
      );

      ref.read(weekSummaryProvider.notifier).state = summary;

      if (context.mounted) {
        // If game terminated, push summary then pop to main menu on close
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WeekSummaryScreen(summary: summary),
          ),
        );

        if (newState.status == GameStatus.terminated && context.mounted) {
          ref.read(activeGameProvider.notifier).clearGame();
          Navigator.of(context).pop();
        }
      }
    } finally {
      ref.read(endWeekLoadingProvider.notifier).state = false;
    }
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}

// ─── Status Chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final String icon;

  const _StatusChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
          Text(
            label,
            style: MFTextStyles.bodySmall.copyWith(
              color: color, fontWeight: FontWeight.bold, fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard Tab ────────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerWidget {
  final GameState game;
  final VoidCallback onEndWeek;

  const _DashboardTab({required this.game, required this.onEndWeek});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(endWeekLoadingProvider);
    final isRaidWeek = ref.watch(isRaidWeekProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AdBannerPlaceholder(),
        const SizedBox(height: 16),
        const _SectionHeader('RESOURCES'),
        const SizedBox(height: 8),
        _ResourceGrid(resources: game.resources),
        const SizedBox(height: 16),
        const _SectionHeader('INFRASTRUCTURE'),
        const SizedBox(height: 8),
        _InfraCards(game: game),
        const SizedBox(height: 16),
        if (game.pendingSales.isNotEmpty) ...[
          const _SectionHeader('PENDING SALES'),
          const SizedBox(height: 8),
          _PendingSalesCard(sales: game.pendingSales),
          const SizedBox(height: 16),
        ],
        const _SectionHeader('MILESTONES'),
        const SizedBox(height: 8),
        ...game.milestones
            .where((m) => m.status == MilestoneStatus.pending || m.status == MilestoneStatus.warned)
            .map((m) => _MilestoneRow(milestone: m, game: game)),
        const SizedBox(height: 16),
        _EndWeekButton(
          game: game,
          isLoading: isLoading,
          isRaidWeek: isRaidWeek,
          onPressed: onEndWeek,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AdBannerPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: MFColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: MFColors.borderSubtle),
      ),
      child: Center(
        child: Text(
          'AD BANNER — AdMob goes here',
          style: MFTextStyles.bodySmall.copyWith(
            color: MFColors.textMuted, fontSize: 10, letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: MFTextStyles.bodySmall.copyWith(
        color: MFColors.textSecondary, letterSpacing: 2,
      ),
    );
  }
}

class _ResourceGrid extends StatelessWidget {
  final Resources resources;
  const _ResourceGrid({required this.resources});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('🎫', 'Star-Scrip', '${resources.starScrip}',   MFColors.starScrip),
      ('💧', 'Water',      '${resources.water.toInt()}', MFColors.neonCyan),
      ('🌑', 'Moon Dirt',  '${resources.moonDirt.toInt()}', MFColors.textSecondary),
      ('⚗️', 'Chemicals',  '${resources.chemicals.toInt()}', MFColors.neonPurple),
      ('🌱', 'Z Soil',     '${resources.zSoil.toInt()}', MFColors.neonGreen),
      ('🔩', 'Metals',     '${resources.metals.toInt()}', MFColors.neonOrange),
      ('🏖️', 'Sand',       '${resources.sand.toInt()}', MFColors.neonYellow),
      ('🪟', 'Glass',      '${resources.glass.toInt()}', MFColors.statusFlawless),
      ('⚙️', 'Components', '${resources.components.toInt()}', MFColors.neonPurple),
      ('🪨', 'Ore',        '${resources.ore.toInt()}', MFColors.textSecondary),
      ('♻️', 'Compost',    '${resources.compost.toInt()}', MFColors.neonGreen),
      ('🌾', 'Seeds',      '${resources.seeds}', MFColors.neonGreen),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (emoji, label, value, color) = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: MFColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: MFColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 11)),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      label,
                      style: MFTextStyles.bodySmall.copyWith(
                        fontSize: 9, color: MFColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfraCards extends StatelessWidget {
  final GameState game;
  const _InfraCards({required this.game});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('🔵', 'Domes',    '${game.domes.length}'),
      ('🏗️', 'Silos',    '${game.silos.length}'),
      ('⚡',  'Power',    '${game.totalPowerProduction}'),
      ('🔫', 'Sentries', '${game.laserSentries.length}'),
      ('🤖', 'Robots',   '${game.domes.where((d) => d.robot != null).length}'),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: MFColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: MFColors.borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.$1, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 2),
                Text(item.$3, style: MFTextStyles.labelLarge.copyWith(fontSize: 12)),
                Text(item.$2, style: MFTextStyles.bodySmall.copyWith(fontSize: 9)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PendingSalesCard extends StatelessWidget {
  final List<PendingSale> sales;
  const _PendingSalesCard({required this.sales});

  @override
  Widget build(BuildContext context) {
    final totalScrip = sales.fold(0, (sum, s) => sum + s.scripValue);
    final totalVolume = sales.fold(0.0, (sum, s) => sum + s.amount);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MFColors.starScrip.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('📦', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${sales.length} shipment${sales.length == 1 ? '' : 's'} en route',
                    style: MFTextStyles.labelLarge),
                Text(
                  '${totalVolume.toStringAsFixed(1)}m³ · +$totalScrip 🎫 on delivery',
                  style: MFTextStyles.bodySmall.copyWith(color: MFColors.starScrip),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final Milestone milestone;
  final GameState game;
  const _MilestoneRow({required this.milestone, required this.game});

  @override
  Widget build(BuildContext context) {
    final progress = game.totalVolumeDeliveredM3 / milestone.targetVolumeM3;
    final weeksLeft = milestone.byWeek - game.currentWeek;
    final isLate = weeksLeft <= 0;
    final isWarned = milestone.status == MilestoneStatus.warned;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isLate || isWarned ? MFColors.neonPink : MFColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(milestone.name, style: MFTextStyles.labelLarge)),
              Text(
                '${milestone.rewardScrip} 🎫',
                style: MFTextStyles.bodySmall.copyWith(color: MFColors.starScrip),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(milestone.description, style: MFTextStyles.bodyMedium),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: MFColors.borderSubtle,
            valueColor: AlwaysStoppedAnimation(
              isLate ? MFColors.neonPink : MFColors.neonGreen,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${game.totalVolumeDeliveredM3.toStringAsFixed(1)} / ${milestone.targetVolumeM3}m³',
                style: MFTextStyles.bodySmall,
              ),
              Text(
                isLate ? 'OVERDUE' : 'Due Wk ${milestone.byWeek} ($weeksLeft left)',
                style: MFTextStyles.bodySmall.copyWith(
                  color: isLate ? MFColors.neonPink : MFColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EndWeekButton extends StatelessWidget {
  final GameState game;
  final bool isLoading;
  final bool isRaidWeek;
  final VoidCallback onPressed;

  const _EndWeekButton({
    required this.game,
    required this.isLoading,
    required this.isRaidWeek,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isRaidWeek ? MFColors.neonPink : MFColors.neonCyan,
          foregroundColor: MFColors.background,
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const CircularProgressIndicator(color: MFColors.background, strokeWidth: 2)
            : Text(
          isRaidWeek ? '🚨 DEFEND RAID FIRST' : '⏭  END WEEK ${game.currentWeek}',
          style: MFTextStyles.labelLarge.copyWith(
            color: MFColors.background, letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ─── Stub Screens ─────────────────────────────────────────────────────────────

class _RefineryStub extends StatelessWidget {
  final GameState game;
  const _RefineryStub({required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚗️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('REFINERY',
                style: MFTextStyles.headlineMedium.copyWith(color: MFColors.neonCyan)),
            const SizedBox(height: 8),
            Text('Material processing arrives in Phase 3.',
                style: MFTextStyles.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _RelayStub extends StatelessWidget {
  final GameState game;
  const _RelayStub({required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📡', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('RELAY — SPECIALIST KOVACS',
                style: MFTextStyles.headlineMedium.copyWith(color: MFColors.neonCyan)),
            const SizedBox(height: 8),
            Text('Contracts and selling arrive in Phase 3.',
                style: MFTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MFColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MFColors.borderDefault),
              ),
              child: Text(
                '"I passed my captain\'s exam. Again. '
                    'For what it\'s worth out here in the middle of nowhere."'
                    '\n\n— Specialist Kovacs',
                style: MFTextStyles.bodyMedium.copyWith(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitatStub extends StatelessWidget {
  final GameState game;
  const _HabitatStub({required this.game});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(child: Text('🏠', style: TextStyle(fontSize: 64))),
        const SizedBox(height: 16),
        Center(
          child: Text(
            game.farmName.toUpperCase(),
            style: MFTextStyles.headlineLarge.copyWith(color: MFColors.neonCyan),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeader('LIFETIME STATS'),
        const SizedBox(height: 12),
        _StatRow('Weeks Survived',     '${game.currentWeek}'),
        _StatRow('Crops Harvested',    '${game.totalCropsHarvested}'),
        _StatRow('Volume Delivered',   '${game.totalVolumeDeliveredM3.toStringAsFixed(1)}m³'),
        _StatRow('Lifetime Star-Scrip','${game.lifetimeScripEarned}'),
        _StatRow('Compost Generated',  '${game.totalCompostGenerated}'),
        const SizedBox(height: 24),
        const _SectionHeader('TROPHIES'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MFColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MFColors.borderSubtle),
          ),
          child: Center(
            child: Text(
              '${game.trophies.where((t) => t.status == TrophyStatus.unlocked).length}'
                  ' / ${game.trophies.length} trophies unlocked\n\nFull trophy room in Phase 5.',
              style: MFTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeader('RADIO TRANSMISSIONS'),
        const SizedBox(height: 12),
        ...game.radioFeed.reversed.map(
              (r) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MFColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: r.isRead ? MFColors.borderSubtle : MFColors.neonCyan.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('W${r.week}',
                    style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonCyan, fontSize: 10)),
                const SizedBox(width: 8),
                Expanded(child: Text(r.message, style: MFTextStyles.bodyMedium)),
                if (!r.isRead)
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                      color: MFColors.neonCyan, shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: MFTextStyles.bodyMedium),
          Text(value, style: MFTextStyles.labelLarge),
        ],
      ),
    );
  }
}