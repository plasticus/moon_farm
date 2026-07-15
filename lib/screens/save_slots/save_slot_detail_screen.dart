// ═══════════════════════════════════════════════════════════════
//  lib/screens/save_slots/save_slot_detail_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../score/score_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/game_config_service.dart';
import '../../engine/end_week_engine.dart';
import '../../database/database_helper.dart';
import '../dome/dome_screen.dart';
import '../week_summary/week_summary_screen.dart';
import '../dev/dev_tools_screen.dart';
import '../main_menu/main_menu_screen.dart';
import '../relay/relay_screen.dart';
import '../operations/operations_screen.dart';
import '../habitat/habitat_screen.dart';
import '../../widgets/ad_banner.dart';
import '../refinery/refinery_screen.dart';
import '../../widgets/space_background.dart';
import '../settings/settings_screen.dart';
import '../../providers/settings_providers.dart';

class SaveSlotDetailScreen extends ConsumerStatefulWidget {
  const SaveSlotDetailScreen({super.key});

  @override
  ConsumerState<SaveSlotDetailScreen> createState() =>
      _SaveSlotDetailScreenState();
}

class _SaveSlotDetailScreenState extends ConsumerState<SaveSlotDetailScreen> {
  int _currentTab = 0;
  // Nudges the player to actually go check on things before ending the
  // week blind — End Week is orange until they've looked at another tab,
  // then settles into its normal color. Resets every new week.
  bool _hasVisitedOtherTab = false;

  static const _tabs = [
    _TabItem(icon: Icons.dashboard, label: 'Dashboard'),
    _TabItem(icon: Icons.circle, label: 'Domes'),
    _TabItem(icon: Icons.science, label: 'Refinery'),
    _TabItem(icon: Icons.terrain, label: 'Operations'),
    _TabItem(icon: Icons.satellite_alt, label: 'Relay'),
    _TabItem(icon: Icons.shield, label: 'Habitat'),
  ];

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(activeGameProvider);

    return gameAsync.when(
      loading: () => Scaffold(
        backgroundColor: MFColors.background,
        body: Center(child: CircularProgressIndicator(color: MFColors.neonCyan)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: MFColors.background,
        body: Center(child: Text('Error: $e')),
      ),
      data: (game) {
        if (game == null) {
          return Scaffold(
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

    final topPad = MediaQuery.of(context).padding.top;
    return PreferredSize(
      // Ad (50) + tight gap (4) + farm name/menu row (~32, PopupMenuButton
      // is the tallest thing in it) + stats row (~20) + bottom pad (4).
      preferredSize: Size.fromHeight(50 + 4 + 32 + 20 + 4 + topPad),
      child: Container(
        color: MFColors.background,
        child: Column(
          children: [
            SizedBox(height: topPad),
            const Center(child: AdBannerWidget()),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Row 1: Farm name full width + menu
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onLongPress: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DevToolsScreen()),
                          ),
                          child: Text(
                            game.farmName.toUpperCase(),
                            style: MFTextStyles.labelLarge,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        color: MFColors.surface,
                        iconColor: MFColors.textSecondary,
                        padding: EdgeInsets.zero,
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'save',
                            child: Text('Save Game', style: MFTextStyles.bodyLarge),
                          ),
                          PopupMenuItem(
                            value: 'settings',
                            child: Text('Settings', style: MFTextStyles.bodyLarge),
                          ),
                          PopupMenuItem(
                            value: 'mainmenu',
                            child: Text('Main Menu', style: TextStyle(color: MFColors.neonPink)),
                          ),
                        ],
                        onSelected: (val) async {
                          if (val == 'save') {
                            await ref.read(activeGameProvider.notifier).persistCurrentState();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: GestureDetector(
                                  onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                                  child: Text('Game saved.'),
                                )),
                              );
                            }
                          } else if (val == 'settings') {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SettingsScreen()),
                            );
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
                  // Row 2: W67 · N  ⚡+236  🎫1893  🌱23  ⚠️2w  📡1
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          'W${game.currentWeek} · ${game.difficulty.name[0].toUpperCase()}  ',
                          style: MFTextStyles.bodySmall.copyWith(color: MFColors.textMuted),
                        ),
                        _StatusChip(
                          label: '${powerSurplus >= 0 ? '+' : ''}$powerSurplus',
                          color: powerSurplus >= 0 ? MFColors.statusOptimal : MFColors.statusCritical,
                          icon: '⚡',
                        ),
                        const SizedBox(width: 4),
                        _StatusChip(
                          label: '${game.resources.starScrip}',
                          color: MFColors.starScrip,
                          icon: '🎫',
                        ),
                        const SizedBox(width: 4),
                        _StatusChip(
                          label: '${game.resources.seeds}',
                          color: MFColors.neonGreen,
                          icon: '🌱',
                        ),
                        // Raid beacon — always show countdown when within 2 weeks
                        if (isRaidWeek) ...[
                          const SizedBox(width: 4),
                          _StatusChip(label: 'R-0w', color: MFColors.neonPink, icon: '🚨'),
                        ] else if (raidWarning) ...[
                          const SizedBox(width: 4),
                          _StatusChip(
                            label: 'R-${game.nextRaidWeek - game.currentWeek}w',
                            color: (game.nextRaidWeek - game.currentWeek) <= 1
                                ? MFColors.neonPink
                                : MFColors.neonOrange,
                            icon: '🚨',
                          ),
                        ],
                        // Kovacs pickup — show spaceship when ship window is open
                        if (game.isShipWindowOpen) ...[
                          const SizedBox(width: 4),
                          _StatusChip(label: '', color: MFColors.neonCyan, icon: '🚀'),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(GameState game) {
    // SpaceBackground wraps all tabs — dashboard gets parallax via its own
    // scroll controller; other tabs get twinkling stars + horizon with no parallax.
    final body = switch (_currentTab) {
      0 => _DashboardTab(
          game: game,
          onEndWeek: () => _doEndWeek(game),
          hasVisitedOtherTab: _hasVisitedOtherTab,
        ),
      1 => const DomeScreen(),
      2 => const RefineryScreen(),
      3 => const OperationsScreen(),
      4 => const RelayScreen(),
      5 => const HabitatScreen(),
      _ => const SizedBox(),
    };
    // Dashboard manages its own SpaceBackground with scroll controller.
    // All other tabs get a static (no parallax) SpaceBackground here.
    if (_currentTab == 0) return body;
    return SpaceBackground(child: body);
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentTab,
      onTap: (i) => setState(() {
        _currentTab = i;
        if (i != 0) _hasVisitedOtherTab = true;
      }),
      items: _tabs
          .map((t) => BottomNavigationBarItem(icon: Icon(t.icon), label: t.label))
          .toList(),
    );
  }

  // ─── End Week ───────────────────────────────────────────────────────────

  Future<void> _doEndWeek(GameState game) async {
    debugPrint('[EndWeek] Button pressed. Current week: ${game.currentWeek}');
    final isRaidWeek = ref.read(isRaidWeekProvider);
    debugPrint('[EndWeek] isRaidWeek = $isRaidWeek '
        '(currentWeek=${game.currentWeek}, nextRaidWeek=${game.nextRaidWeek}, '
        'raidDefendedThisWeek=${game.raidDefendedThisWeek})');
    if (isRaidWeek) {
      debugPrint('[EndWeek] BLOCKED — raid must be defended first.');
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          child: Text('⚠️ Defend the raid first!'),
        )),
      );
      return;
    }

    ref.read(endWeekLoadingProvider.notifier).state = true;

    try {
      debugPrint('[EndWeek] Running engine...');
      final engine = EndWeekEngine();
      final (rawNewState, summary) = engine.processEndWeek(game);
      final newState = rawNewState.copyWith(lastWeekSummary: summary);
      debugPrint('[EndWeek] Engine done. New week: ${newState.currentWeek}, '
          'summary events: ${summary.events.length}');

      // Persist. The autosave-slot mirror only gets refreshed on the
      // cadence set in Settings > Auto-Save Frequency; the manual slot
      // itself is always written above regardless.
      final autoSaveFrequency = ref.read(settingsProvider).autoSaveFrequency;
      final syncAutosave = autoSaveFrequency.weeks > 0 &&
          newState.currentWeek % autoSaveFrequency.weeks == 0;
      await ref.read(activeGameProvider.notifier)
          .updateGame(newState, syncAutosave: syncAutosave);
      debugPrint('[EndWeek] State persisted.');

      // Reset Kovacs conversation for next week
      ref.read(kovacsConversationProvider.notifier).state = null;

      // Set the summary BEFORE the DB log so a log failure can't block the screen.
      ref.read(weekSummaryProvider.notifier).state = summary;

      // Log to DB (non-fatal if it fails)
      try {
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
        debugPrint('[EndWeek] Log entry saved.');
      } catch (e, st) {
        debugPrint('[EndWeek] WARNING: log insert failed (non-fatal): $e\n$st');
      }

      debugPrint('[EndWeek] context.mounted = ${context.mounted}');
      if (context.mounted) {
        setState(() {
          _currentTab = 0;
          _hasVisitedOtherTab = false;
        });
        final justWon = game.status != GameStatus.won &&
            newState.status == GameStatus.won;
        debugPrint('[EndWeek] Pushing WeekSummaryScreen...');
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WeekSummaryScreen(summary: summary, justWon: justWon),
          ),
        );
        debugPrint('[EndWeek] WeekSummaryScreen closed.');

        if (newState.status == GameStatus.terminated && context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => ScoreScreen(game: newState)),
                (route) => route.isFirst,
          );
        } else if (justWon && context.mounted) {
          // Unlike termination, winning doesn't lock the player out — this
          // is a one-time celebration screen. "Keep Playing" pops back here.
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ScoreScreen(game: newState)),
          );
        }
      }
    } catch (e, st) {
      debugPrint('[EndWeek] ERROR: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            child: Text('End week failed: $e'),
          )),
        );
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

class _DashboardTab extends ConsumerStatefulWidget {
  final GameState game;
  final VoidCallback onEndWeek;
  final bool hasVisitedOtherTab;

  const _DashboardTab({
    required this.game,
    required this.onEndWeek,
    required this.hasVisitedOtherTab,
  });

  @override
  ConsumerState<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<_DashboardTab> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final isLoading = ref.watch(endWeekLoadingProvider);
    final isRaidWeek = ref.watch(isRaidWeekProvider);

    return SpaceBackground(
      scrollController: _scrollController,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          // ── End Week button — at top so it's always reachable ───────────
          if (game.lastWeekSummary != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WeekSummaryScreen(summary: game.lastWeekSummary!),
                    ),
                  );
                },
                icon: Icon(Icons.history, size: 16, color: MFColors.textMuted),
                label: Text('View last week\'s summary',
                    style: MFTextStyles.bodySmall.copyWith(color: MFColors.textMuted)),
              ),
            ),
          // Raid week: show message directing to Habitat, gray out End Week
          if (isRaidWeek)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MFColors.neonPink.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MFColors.neonPink.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Text('🚨', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RAID IN PROGRESS',
                            style: MFTextStyles.labelLarge.copyWith(
                                color: MFColors.neonPink)),
                        const SizedBox(height: 2),
                        Text(
                          'Go to Habitat → Wall tab to defend before ending the week.',
                          style: MFTextStyles.bodySmall.copyWith(
                              color: MFColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          _EndWeekButton(
            game: game,
            isLoading: isLoading,
            isRaidWeek: isRaidWeek,
            hasVisitedOtherTab: widget.hasVisitedOtherTab,
            onPressed: widget.onEndWeek,
          ),
          const SizedBox(height: 16),
          const _SectionHeader('RESOURCES'),
          const SizedBox(height: 8),
          _ResourceGrid(resources: game.resources),
          const SizedBox(height: 16),
          const _SectionHeader('INFRASTRUCTURE'),
          const SizedBox(height: 8),
          _InfraCards(game: game),
          const SizedBox(height: 16),
          if (game.pendingSales.any((s) =>
          !(s.resourceId.startsWith('contract_') && s.scripValue == 0))) ...[
            const _SectionHeader('OUTGOING SHIPMENTS'),
            const SizedBox(height: 8),
            _PendingSalesCard(sales: game.pendingSales, deliveryWeek: game.nextShipWindowWeek, currentWeek: game.currentWeek),
            const SizedBox(height: 16),
          ],
          if (game.pendingDeliveries.isNotEmpty) ...[
            const _SectionHeader('INCOMING FROM KOVACS'),
            const SizedBox(height: 8),
            _PendingDeliveriesCard(deliveries: game.pendingDeliveries),
            const SizedBox(height: 16),
          ],
          if (game.siloInventory.isNotEmpty) ...[
            const _SectionHeader('🏚️  CROPS IN SILO'),
            const SizedBox(height: 8),
            _SiloInventoryCard(inventory: game.siloInventory),
            const SizedBox(height: 16),
          ],
          if (game.activeContracts.isNotEmpty) ...[
            const _SectionHeader('📋  ACTIVE CONTRACTS'),
            const SizedBox(height: 8),
            _DashboardContractsCard(game: game),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionHeader('MILESTONES'),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MilestonesTableScreen(game: game)),
                ),
                child: Text(
                  'VIEW ALL →',
                  style: MFTextStyles.bodySmall.copyWith(
                    color: MFColors.neonCyan, letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...(game.milestones
                  .where((m) => m.status == MilestoneStatus.pending || m.status == MilestoneStatus.warned)
                  .toList()
                ..sort((a, b) =>
                    milestoneProgress(b, game).$1.compareTo(milestoneProgress(a, game).$1)))
              .take(5)
              .map((m) => _MilestoneRow(milestone: m, game: game)),
          const SizedBox(height: 24),
        ],
      ), // ListView
    ); // SpaceBackground
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
      ('💧', 'Water',      '${resources.water.toStringAsFixed(1)}m³', MFColors.neonCyan),
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
      ('🥩', 'Meat',       '${resources.meat.toInt()}', const Color(0xFFEF5350)),
      ('🦴', 'Chitin',     '${resources.chitin.toInt()}', const Color(0xFFBCAAA4)),
      ('🟩', 'Moss',       '${resources.moss.toInt()}', MFColors.neonGreen),
      ('🧫', 'Mycoculture', '${resources.mycoculture.toInt()}', MFColors.neonPurple),
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
      ('⚡',  'Power',    '+${game.powerSurplus} kW'),
      ('🔫', 'Sentries', '${game.laserSentries.length}'),
      ('🤖', 'Bots',     '${game.domes.where((d) => d.domeBot != null).length}'),
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
  final int deliveryWeek;
  final int currentWeek;
  const _PendingSalesCard({required this.sales, required this.deliveryWeek, required this.currentWeek});

  @override
  Widget build(BuildContext context) {
    final pickupLabel = 'pickup W$deliveryWeek';

    // Partial/staged contract submissions ($0 reward, contract not yet
    // complete) aren't shown here — progress is already visible under
    // Active Contracts, so this would just be redundant clutter.
    final visible = sales.where((s) {
      final (label, _) = _typeFor(s.resourceId);
      return !(label == 'contract' && s.scripValue == 0);
    }).toList();

    final scrapSales = visible.where((s) => _typeFor(s.resourceId).$2).toList();
    final otherSales = visible.where((s) => !_typeFor(s.resourceId).$2).toList();
    final rowCount = otherSales.length + (scrapSales.isEmpty ? 0 : 1);

    final bulk = GameConfigService.instance.scrapDealerBulkAmount;
    final scrapTotalScrip = scrapSales.fold(0, (sum, s) => sum + s.scripValue);
    final scrapDamVolume = (scrapSales.length * bulk) / 1000;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MFColors.starScrip.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📦', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text('$rowCount shipment${rowCount == 1 ? '' : 's'} ready for pickup',
                  style: MFTextStyles.labelLarge),
            ],
          ),
          const SizedBox(height: 8),
          if (scrapSales.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${scrapDamVolume.toStringAsFixed(1)}dam³  ·  +$scrapTotalScrip 🎫  ·  scrap  ·  $pickupLabel',
                style: MFTextStyles.bodySmall.copyWith(color: MFColors.starScrip),
              ),
            ),
          ...otherSales.map((sale) {
            final (label, _) = _typeFor(sale.resourceId);
            // Food supply doesn't show a pickup week — it can only ever
            // ship on a Kovacs ship window to begin with, so the reminder
            // is redundant. Contracts get it since those are queued
            // ahead of time and the week is genuinely useful context.
            final showWeek = label != 'food supply';
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${sale.amount.toStringAsFixed(1)}m³  ·  +${sale.scripValue} 🎫  ·  $label'
                    '${showWeek ? '  ·  $pickupLabel' : ''}',
                style: MFTextStyles.bodySmall.copyWith(color: MFColors.starScrip),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Classifies a PendingSale by its resourceId prefix (set at creation
  // time in relay_screen.dart). Returns (display label, isScrap).
  (String, bool) _typeFor(String resourceId) {
    if (resourceId.startsWith('scrap_')) return ('scrap', true);
    if (resourceId.startsWith('contract_')) return ('contract', false);
    return ('food supply', false);
  }
}

class _PendingDeliveriesCard extends StatelessWidget {
  final List<PendingDelivery> deliveries;
  const _PendingDeliveriesCard({required this.deliveries});

  @override
  Widget build(BuildContext context) {
    // Group by arrival week for a tidy summary.
    final byWeek = <int, List<PendingDelivery>>{};
    for (final d in deliveries) {
      byWeek.putIfAbsent(d.arrivalWeek, () => []).add(d);
    }
    final weeks = byWeek.keys.toList()..sort();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MFColors.neonCyan.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚚', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Text('${deliveries.length} order${deliveries.length == 1 ? '' : 's'} incoming',
                  style: MFTextStyles.labelLarge),
            ],
          ),
          const SizedBox(height: 6),
          ...weeks.map((wk) {
            final items = byWeek[wk]!;
            final summary = items
                .map((d) => '${d.amount.toInt()} ${d.resourceKey}')
                .join(', ');
            return Padding(
              padding: const EdgeInsets.only(left: 32, top: 2),
              child: Text('Week $wk: $summary',
                  style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonCyan)),
            );
          }),
        ],
      ),
    );
  }
}

/// (progress 0.0-1.0, "current / target" label) — shape depends on
/// checkType, since "current" means something different for each. Shared
/// by the Dashboard summary (for "closest to done" sorting) and both
/// milestone list widgets below.
(double, String) milestoneProgress(Milestone m, GameState game) {
  switch (m.checkType) {
    case 'power_capacity':
      final current = game.totalPowerProduction.toDouble();
      return (current / m.target, '${current.toInt()} / ${m.target.toInt()} kW');
    case 'contracts_completed':
      final current = game.completedContracts.length.toDouble();
      return (current / m.target, '${current.toInt()} / ${m.target.toInt()} contracts');
    case 'fauna_killed':
      final current = game.totalFaunaKilled.toDouble();
      return (current / m.target, '${current.toInt()} / ${m.target.toInt()} fauna');
    case 'crop_diversity':
      final tierCrops = GameConfigService.instance.getCropsByTier(m.target.toInt());
      final discovered = tierCrops.where((c) => (game.cropHarvestCounts[c.id] ?? 0) > 0).length;
      final total = tierCrops.isEmpty ? 1 : tierCrops.length;
      return (discovered / total, 'Tier ${m.target.toInt()}: $discovered / $total crops');
    case 'volume_delivered':
    default:
      final current = game.totalVolumeDeliveredM3;
      return (current / m.target, '${current.toStringAsFixed(1)} / ${m.target.toStringAsFixed(0)}m³');
  }
}

class _MilestoneRow extends StatelessWidget {
  final Milestone milestone;
  final GameState game;
  const _MilestoneRow({required this.milestone, required this.game});

  @override
  Widget build(BuildContext context) {
    final (progressRaw, progressLabel) = milestoneProgress(milestone, game);
    final progress = progressRaw.clamp(0.0, 1.0);
    final hasDeadline = milestone.byWeek != null;
    final weeksLeft = hasDeadline ? milestone.byWeek! - game.currentWeek : 0;
    final isLate = hasDeadline && weeksLeft <= 0;
    final isWarned = milestone.status == MilestoneStatus.warned;
    final isCompleted = milestone.status == MilestoneStatus.completed;
    final isFailed = milestone.status == MilestoneStatus.failed;

    final borderColor = isCompleted
        ? MFColors.neonGreen
        : (isFailed || isLate || isWarned)
            ? MFColors.neonPink
            : MFColors.borderSubtle;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isCompleted) ...[
                const Text('✅ ', style: TextStyle(fontSize: 13)),
              ] else if (isFailed) ...[
                const Text('❌ ', style: TextStyle(fontSize: 13)),
              ],
              Expanded(child: Text(milestone.name, style: MFTextStyles.labelLarge)),
              Text(
                '${milestone.rewardScrip} 🎫',
                style: MFTextStyles.bodySmall.copyWith(
                  color: isCompleted ? MFColors.neonGreen : MFColors.starScrip,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(milestone.description, style: MFTextStyles.bodyMedium),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: isCompleted ? 1.0 : progress,
            backgroundColor: MFColors.borderSubtle,
            valueColor: AlwaysStoppedAnimation(
              isCompleted ? MFColors.neonGreen : (isLate ? MFColors.neonPink : MFColors.neonGreen),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isCompleted ? 'Complete' : progressLabel, style: MFTextStyles.bodySmall),
              Text(
                isCompleted
                    ? 'Done'
                    : isFailed
                        ? 'Failed'
                        : hasDeadline
                            ? (isLate ? 'OVERDUE' : 'Due Wk ${milestone.byWeek} ($weeksLeft left)')
                            : 'No deadline',
                style: MFTextStyles.bodySmall.copyWith(
                  color: isCompleted
                      ? MFColors.neonGreen
                      : (isFailed || isLate)
                          ? MFColors.neonPink
                          : MFColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── All Milestones Table ──────────────────────────────────────────────────

class MilestonesTableScreen extends StatelessWidget {
  final GameState game;
  const MilestonesTableScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final warned = game.milestones.where((m) => m.status == MilestoneStatus.warned).toList();
    final pending = game.milestones.where((m) => m.status == MilestoneStatus.pending).toList()
      ..sort((a, b) =>
          milestoneProgress(b, game).$1.compareTo(milestoneProgress(a, game).$1));
    final completed = game.milestones.where((m) => m.status == MilestoneStatus.completed).toList();
    final failed = game.milestones.where((m) => m.status == MilestoneStatus.failed).toList();

    return Scaffold(
      backgroundColor: MFColors.background,
      appBar: AppBar(
        title: const Text('ALL MILESTONES'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: MFColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (warned.isNotEmpty) ...[
            const _SectionHeader('NEEDS ATTENTION'),
            const SizedBox(height: 8),
            ...warned.map((m) => _MilestoneRow(milestone: m, game: game)),
            const SizedBox(height: 16),
          ],
          if (pending.isNotEmpty) ...[
            const _SectionHeader('IN PROGRESS'),
            const SizedBox(height: 8),
            ...pending.map((m) => _MilestoneRow(milestone: m, game: game)),
            const SizedBox(height: 16),
          ],
          if (completed.isNotEmpty) ...[
            _SectionHeader('COMPLETED (${completed.length})'),
            const SizedBox(height: 8),
            ...completed.map((m) => _MilestoneRow(milestone: m, game: game)),
            const SizedBox(height: 16),
          ],
          if (failed.isNotEmpty) ...[
            const _SectionHeader('MISSED'),
            const SizedBox(height: 8),
            ...failed.map((m) => _MilestoneRow(milestone: m, game: game)),
          ],
        ],
      ),
    );
  }
}

class _EndWeekButton extends StatelessWidget {
  final GameState game;
  final bool isLoading;
  final bool isRaidWeek;
  final bool hasVisitedOtherTab;
  final VoidCallback onPressed;

  const _EndWeekButton({
    required this.game,
    required this.isLoading,
    required this.isRaidWeek,
    required this.hasVisitedOtherTab,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Nudge color — orange until the player has actually looked at another
    // tab this week, so ending the week blind (without checking domes,
    // contracts, etc.) at least looks deliberate rather than a reflex tap.
    final readyColor = hasVisitedOtherTab ? MFColors.neonCyan : MFColors.neonOrange;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isRaidWeek
              ? MFColors.borderSubtle
              : readyColor,
          foregroundColor: MFColors.background,
        ),
        onPressed: (isLoading || isRaidWeek) ? null : onPressed,
        child: isLoading
            ? CircularProgressIndicator(color: MFColors.background, strokeWidth: 2)
            : Text(
          '⏭  END WEEK ${game.currentWeek}',
          style: MFTextStyles.labelLarge.copyWith(
            color: isRaidWeek ? MFColors.textMuted : MFColors.background,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ─── Silo Inventory Card ──────────────────────────────────────────────────────

class _SiloInventoryCard extends StatelessWidget {
  final Map<String, double> inventory;
  const _SiloInventoryCard({required this.inventory});

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MFColors.borderSubtle),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: inventory.entries.where((e) => e.value > 0.0001).map((entry) {
          final crop = config.getCrop(entry.key);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: MFColors.surfaceElevated,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: MFColors.borderDefault),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(crop?.emoji ?? '?', style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '${entry.value.toInt()}',
                  style: MFTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Dashboard Active Contracts Card ──────────────────────────────────────────
// Same card styling as the Relay/Sell screen's "Active Contracts" preview,
// but shows every active contract regardless of current silo contents —
// the Relay version only shows ones you can submit to right now.

class _DashboardContractsCard extends StatelessWidget {
  final GameState game;
  const _DashboardContractsCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MFColors.neonGold.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: game.activeContracts.map((c) {
          final crop = config.getCrop(c.cropId);
          final inSilo = game.siloInventory[c.cropId] ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MFColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: MFColors.neonGold.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Text(crop?.emoji ?? '?', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: MFTextStyles.labelLarge),
                      Text(
                        '${c.currentAmount}/${c.requiredAmount}  ·  ${inSilo.toInt()} in silo',
                        style: MFTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text('+${c.rewardScrip} 🎫',
                    style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonGold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}