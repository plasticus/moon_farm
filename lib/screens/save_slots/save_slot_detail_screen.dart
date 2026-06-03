// ═══════════════════════════════════════════════════════════════
//  lib/screens/save_slots/save_slot_detail_screen.dart
// ═══════════════════════════════════════════════════════════════

// The main game hub — shows after loading/starting a game.
// Phase 1: scaffold with bottom nav, stub screens for all sections.
// Phase 2+: real implementations replace stubs.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';

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
        body: Center(
          child: CircularProgressIndicator(color: MFColors.neonCyan),
        ),
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
          // ── Top status bar ────────────────────────────────────────────────
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
            // Farm name
            Expanded(
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

            // Power indicator
            _StatusChip(
              label: '${powerSurplus >= 0 ? '+' : ''}$powerSurplus KWh',
              color: powerSurplus >= 0
                  ? MFColors.statusOptimal
                  : MFColors.statusCritical,
              icon: '⚡',
            ),
            const SizedBox(width: 8),

            // Star-Scrip
            _StatusChip(
              label: '${game.resources.starScrip}',
              color: MFColors.starScrip,
              icon: '🎫',
            ),
            const SizedBox(width: 8),

            // Notifications
            if (isRaidWeek)
              _StatusChip(label: 'RAID!', color: MFColors.neonPink, icon: '🚨')
            else if (raidWarning)
              _StatusChip(
                label: 'RAID ×${game.nextRaidWeek - game.currentWeek}w',
                color: MFColors.neonOrange,
                icon: '⚠️',
              ),
            if (unreadRadio > 0) ...[
              const SizedBox(width: 4),
              _StatusChip(
                label: '$unreadRadio',
                color: MFColors.neonCyan,
                icon: '📡',
              ),
            ],

            // Menu
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
                  child: Text(
                    'Main Menu',
                    style: TextStyle(color: MFColors.neonPink),
                  ),
                ),
              ],
              onSelected: (val) async {
                if (val == 'save') {
                  await ref
                      .read(activeGameProvider.notifier)
                      .persistCurrentState();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Game saved.')),
                    );
                  }
                } else if (val == 'mainmenu') {
                  ref.read(activeGameProvider.notifier).clearGame();
                  if (context.mounted) {
                    Navigator.of(context).pop();
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
      case 0:
        return _DashboardStub(game: game);
      case 1:
        return _DomesStub(game: game);
      case 2:
        return _RefineryStub(game: game);
      case 3:
        return _RelayStub(game: game);
      case 4:
        return _HabitatStub(game: game);
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentTab,
      onTap: (i) => setState(() => _currentTab = i),
      items: _tabs
          .map(
            (t) => BottomNavigationBarItem(
          icon: Icon(t.icon),
          label: t.label,
        ),
      )
          .toList(),
    );
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

  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

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
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stub Screens (replaced in later phases) ─────────────────────────────────

class _DashboardStub extends ConsumerWidget {
  final GameState game;
  const _DashboardStub({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Banner ad placeholder
        _AdBannerPlaceholder(),
        const SizedBox(height: 16),

        _SectionHeader('RESOURCES'),
        const SizedBox(height: 8),
        _ResourceGrid(resources: game.resources),
        const SizedBox(height: 16),

        _SectionHeader('INFRASTRUCTURE'),
        const SizedBox(height: 8),
        _InfraCards(game: game),
        const SizedBox(height: 16),

        _SectionHeader('MILESTONES'),
        const SizedBox(height: 8),
        ...game.milestones
            .where((m) => m.status == MilestoneStatus.pending)
            .map((m) => _MilestoneRow(milestone: m, game: game)),
        const SizedBox(height: 16),

        // End Week button
        _EndWeekButton(game: game),
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
          'AD BANNER PLACEHOLDER — AdMob goes here',
          style: MFTextStyles.bodySmall.copyWith(
            color: MFColors.textMuted,
            fontSize: 10,
            letterSpacing: 1,
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
        color: MFColors.textMuted,
        letterSpacing: 2,
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
      ('☀', 'Star-Scrip', '${resources.starScrip}', MFColors.starScrip),
      ('💧', 'Water', '${resources.water.toInt()}', MFColors.neonCyan),
      ('🌑', 'Moon Dirt', '${resources.moonDirt.toInt()}', MFColors.textSecondary),
      ('⚗️', 'Chemicals', '${resources.chemicals.toInt()}', MFColors.neonPurple),
      ('🌱', 'Z Soil', '${resources.zSoil.toInt()}', MFColors.neonGreen),
      ('🔩', 'Metals', '${resources.metals.toInt()}', MFColors.neonOrange),
      ('🏖️', 'Sand', '${resources.sand.toInt()}', MFColors.neonYellow),
      ('🪟', 'Glass', '${resources.glass.toInt()}', MFColors.statusFlawless),
      ('⚙️', 'Components', '${resources.components.toInt()}', MFColors.neonPurple),
      ('🪨', 'Ore', '${resources.ore.toInt()}', MFColors.textSecondary),
      ('♻️', 'Compost', '${resources.compost.toInt()}', MFColors.neonGreen),
      ('🌾', 'Seeds', '${resources.seeds}', MFColors.neonGreen),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: MFColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: MFColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: MFTextStyles.bodySmall.copyWith(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Text(
                value,
                style: MFTextStyles.labelLarge.copyWith(color: color),
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
      ('🔵', 'Domes', '${game.domes.length}'),
      ('🏗️', 'Silos', '${game.silos.length}'),
      ('⚡', 'Power', '${game.totalPowerProduction} KWh'),
      ('🔫', 'Sentries', '${game.laserSentries.length}'),
      ('🤖', 'Robots', '${game.domes.where((d) => d.robot != null).length}'),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: MFColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: MFColors.borderSubtle),
            ),
            child: Column(
              children: [
                Text(item.$1, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text(item.$3, style: MFTextStyles.labelLarge),
                Text(item.$2, style: MFTextStyles.bodySmall.copyWith(fontSize: 9)),
              ],
            ),
          ),
        );
      }).toList(),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isLate ? MFColors.neonPink : MFColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(milestone.name, style: MFTextStyles.labelLarge),
              ),
              Text(
                '${milestone.rewardScrip} 🎫',
                style: MFTextStyles.bodySmall.copyWith(color: MFColors.starScrip),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(milestone.description, style: MFTextStyles.bodySmall),
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
                '${game.totalVolumeDeliveredM3} / ${milestone.targetVolumeM3} cal',
                style: MFTextStyles.bodySmall,
              ),
              Text(
                isLate
                    ? 'OVERDUE'
                    : 'Due Week ${milestone.byWeek} ($weeksLeft left)',
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

class _EndWeekButton extends ConsumerWidget {
  final GameState game;
  const _EndWeekButton({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRaidWeek = ref.watch(isRaidWeekProvider);
    final isLoading = ref.watch(endWeekLoadingProvider);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
          isRaidWeek ? MFColors.neonPink : MFColors.neonCyan,
          foregroundColor: MFColors.background,
        ),
        onPressed: isLoading
            ? null
            : () {
          if (isRaidWeek) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ Defend the raid first before ending the week!',
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'End Week coming in Phase 2 — game engine not built yet.',
                ),
              ),
            );
          }
        },
        child: isLoading
            ? const CircularProgressIndicator(
          color: MFColors.background,
          strokeWidth: 2,
        )
            : Text(
          isRaidWeek ? '🚨 DEFEND RAID FIRST' : '⏭  END WEEK ${game.currentWeek}',
          style: MFTextStyles.labelLarge.copyWith(
            color: MFColors.background,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ── Dome stub ──────────────────────────────────────────────────────────────────

class _DomesStub extends StatelessWidget {
  final GameState game;
  const _DomesStub({required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔵', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'DOME MANAGEMENT',
              style: MFTextStyles.headlineMedium.copyWith(
                color: MFColors.neonCyan,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have ${game.domes.length} dome${game.domes.length == 1 ? '' : 's'}. '
                  'The 3×3 crop grid, robot controls, and manual farming actions are coming in Phase 2.',
              style: MFTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Refinery stub ──────────────────────────────────────────────────────────────

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
            Text(
              'REFINERY',
              style: MFTextStyles.headlineMedium.copyWith(
                color: MFColors.neonCyan,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Material processing and refinement come in Phase 3.',
              style: MFTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Relay stub ─────────────────────────────────────────────────────────────────

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
            Text(
              'RELAY — SPECIALIST KOVACS',
              style: MFTextStyles.headlineMedium.copyWith(
                color: MFColors.neonCyan,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Contracts, buying, selling, and Kovacs\' mood management coming in Phase 3.',
              style: MFTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
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
                style: MFTextStyles.bodyMedium.copyWith(
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Habitat stub ───────────────────────────────────────────────────────────────

class _HabitatStub extends StatelessWidget {
  final GameState game;
  const _HabitatStub({required this.game});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
          child: Text('🏠', style: TextStyle(fontSize: 64)),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            game.farmName.toUpperCase(),
            style: MFTextStyles.headlineLarge.copyWith(
              color: MFColors.neonCyan,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Stats preview
        _SectionHeader('LIFETIME STATS'),
        const SizedBox(height: 12),
        _StatRow('Weeks Survived', '${game.currentWeek}'),
        _StatRow('Crops Harvested', '${game.totalCropsHarvested}'),
        _StatRow(
          'Calories Delivered',
          '${game.totalVolumeDeliveredM3}',
        ),
        _StatRow('Lifetime Star-Scrip Earned', '${game.lifetimeScripEarned}'),
        _StatRow('Compost Generated', '${game.totalCompostGenerated}'),
        const SizedBox(height: 24),

        // Trophy preview
        _SectionHeader('TROPHIES'),
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

        // Radio feed
        _SectionHeader('RADIO TRANSMISSIONS'),
        const SizedBox(height: 12),
        ...game.radioFeed.reversed.map(
              (r) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MFColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: r.isRead
                    ? MFColors.borderSubtle
                    : MFColors.neonCyan.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'W${r.week}',
                  style: MFTextStyles.bodySmall.copyWith(
                    color: MFColors.neonCyan,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(r.message, style: MFTextStyles.bodyMedium),
                ),
                if (!r.isRead)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: MFColors.neonCyan,
                      shape: BoxShape.circle,
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