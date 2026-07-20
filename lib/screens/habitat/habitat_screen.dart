// ═══════════════════════════════════════════════════════════════
//  lib/screens/habitat/habitat_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/game_config_service.dart';
import '../../widgets/animated_action_button.dart';
import '../../config/monument_config_service.dart';
import '../../engine/end_week_engine.dart';
import '../raid/raid_screen.dart';
import '../score/score_screen.dart';

class HabitatScreen extends ConsumerStatefulWidget {
  const HabitatScreen({super.key});

  @override
  ConsumerState<HabitatScreen> createState() => _HabitatScreenState();
}

class _HabitatScreenState extends ConsumerState<HabitatScreen> {
  int _section = 0; // 0=wall, 1=sentries, 2=grenades, 3=radio, 4=monuments, 5=contract, 6=stats

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(activeGameProvider).value;
    if (game == null) return const SizedBox();

    return Column(
      children: [
        // ── Section tabs ─────────────────────────────────────────────────
        _HabitatTabBar(
          currentSection: _section,
          onSelected: (i) => setState(() => _section = i),
        ),
        Expanded(child: _buildSection(game)),
      ],
    );
  }

  Widget _buildSection(GameState game) {
    switch (_section) {
      case 0: return _WallSection(game: game, ref: ref);
      case 1: return _SentriesSection(game: game, ref: ref);
      case 2: return _GrenadeSection(game: game, ref: ref);
      case 3: return _RadioSection(game: game);
      case 4: return _MonumentsSection(game: game, ref: ref);
      case 5: return _ContractSection(game: game, ref: ref);
      case 6: return _StatsSection(game: game);
      default: return const SizedBox();
    }
  }
}

class _HabitatTabBar extends StatelessWidget {
  final int currentSection;
  final ValueChanged<int> onSelected;

  const _HabitatTabBar({required this.currentSection, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('🧱', 'WALL'),
      ('🔫', 'SENTRIES'),
      ('💥', 'GRENADES'),
      ('📻', 'RADIO'),
      ('🗿', 'MONUMENTS'),
      ('📜', 'CONTRACT'),
      ('📊', 'STATS'),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: MFColors.borderSubtle)),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final i = entry.key;
          final (emoji, label) = entry.value;
          final isSelected = currentSection == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? MFColors.neonCyan : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(label,
                        style: MFTextStyles.bodySmall.copyWith(
                          fontSize: 9,
                          color: isSelected ? MFColors.neonCyan : MFColors.textMuted,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Radio Section ────────────────────────────────────────────────────────────

class _RadioSection extends StatelessWidget {
  final GameState game;
  const _RadioSection({required this.game});

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final tips = config.getRadioTips();

    // Get scripted tips for weeks already passed, plus random transmissions
    final messages = <_RadioMessage>[];

    // Scripted weekly tips
    for (final tip in tips) {
      final week = tip['week'] as int;
      if (week <= game.currentWeek) {
        messages.add(_RadioMessage(
          week: week,
          text: tip['message'] as String,
          isHint: true,
        ));
      }
    }

    // Existing radio feed from game
    for (final r in game.radioFeed) {
      messages.add(_RadioMessage(
        week: r.week,
        text: r.message,
        isHint: false,
      ));
    }

    // Sort by week desc
    messages.sort((a, b) => b.week.compareTo(a.week));

    return messages.isEmpty
        ? Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '📻\n\nNo transmissions yet.',
          style: MFTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    )
        : ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final msg = messages[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MFColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: msg.isHint
                  ? MFColors.neonCyan.withValues(alpha: 0.3)
                  : MFColors.borderSubtle,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'W${msg.week}',
                style: MFTextStyles.bodySmall.copyWith(
                  color: msg.isHint
                      ? MFColors.neonCyan
                      : MFColors.textMuted,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(msg.text, style: MFTextStyles.bodySmall),
              ),
              if (msg.isHint)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text('💡',
                      style: TextStyle(fontSize: 10)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RadioMessage {
  final int week;
  final String text;
  final bool isHint;
  const _RadioMessage({required this.week, required this.text, required this.isHint});
}

// ─── Monuments Section ─────────────────────────────────────────────────────────

class _MonumentsSection extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;

  const _MonumentsSection({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final catalog = MonumentConfigService.instance.getAllMonuments();
    final builtCounts = <int, int>{};
    for (final m in game.monuments) {
      builtCounts[m.mkLevel] = (builtCounts[m.mkLevel] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (game.monuments.isNotEmpty) ...[
          Text('MONUMENT VIEWING ROOM',
              style: MFTextStyles.bodySmall.copyWith(
                  color: MFColors.textMuted, letterSpacing: 2)),
          const SizedBox(height: 8),
          ...catalog.where((c) => builtCounts.containsKey(c.mkLevel)).map(
                (c) => _BuiltMonumentRow(config: c, count: builtCounts[c.mkLevel]!),
          ),
          const SizedBox(height: 16),
        ],
        Text('BUILD',
            style: MFTextStyles.bodySmall.copyWith(
                color: MFColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 8),
        ...catalog.map((cfg) => _MonumentBuildRow(
          config: cfg,
          game: game,
          onBuild: () => _buildMonument(context, cfg),
        )),
      ],
    );
  }

  void _buildMonument(BuildContext context, MonumentConfig cfg) {
    final newMonument = Monument(
      id: 'monument_${DateTime.now().millisecondsSinceEpoch}',
      mkLevel: cfg.mkLevel,
      weekBuilt: game.currentWeek,
    );
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        monuments: [...game.monuments, newMonument],
        resources: game.resources.copyWith(
          moonDirt: game.resources.moonDirt - cfg.costMoonDirt,
          metals: game.resources.metals - cfg.costMetals,
          water: game.resources.water - cfg.costWater,
        ),
      ),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('${cfg.emoji} ${cfg.name} built!'),
      )),
    );
  }
}

class _BuiltMonumentRow extends StatelessWidget {
  final MonumentConfig config;
  final int count;

  const _BuiltMonumentRow({required this.config, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.neonGold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MFColors.neonGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(config.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Mk${config.mkLevel} — ${config.name}',
                          style: MFTextStyles.labelLarge.copyWith(color: MFColors.neonGold)),
                    ),
                    if (count > 1)
                      Text('×$count',
                          style: MFTextStyles.bodyMedium.copyWith(color: MFColors.neonGold)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(config.lore, style: MFTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonumentBuildRow extends StatelessWidget {
  final MonumentConfig config;
  final GameState game;
  final VoidCallback onBuild;

  const _MonumentBuildRow({
    required this.config,
    required this.game,
    required this.onBuild,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = game.resources.moonDirt >= config.costMoonDirt &&
        game.resources.metals >= config.costMetals &&
        game.resources.water >= config.costWater;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MFColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(config.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mk${config.mkLevel} — ${config.name}', style: MFTextStyles.labelLarge),
                    Text(config.lore, style: MFTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${config.costMoonDirt.toInt()} dirt · ${config.costMetals.toInt()} metals · '
                      '${config.costWater.toInt()} water',
                  style: MFTextStyles.bodySmall.copyWith(
                    color: canAfford ? MFColors.textMuted : MFColors.neonPink,
                  ),
                ),
              ),
              GestureDetector(
                onTap: canAfford ? onBuild : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: canAfford
                        ? MFColors.neonGold.withValues(alpha: 0.15)
                        : MFColors.borderSubtle.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: canAfford ? MFColors.neonGold : MFColors.borderSubtle,
                    ),
                  ),
                  child: Text(
                    'BUILD',
                    style: MFTextStyles.bodySmall.copyWith(
                      color: canAfford ? MFColors.neonGold : MFColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Wall Section ─────────────────────────────────────────────────────────────

class _WallSection extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;

  const _WallSection({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final wall = game.defenseWall;
    final levels = config.getDefenseWallLevels();
    final nextLevel = wall.level + 1;
    final nextConfig = levels.where((l) => l['level'] == nextLevel).firstOrNull;
    final healthPct = wall.healthPercent;
    final healthColor = healthPct > 0.5
        ? MFColors.neonGreen
        : healthPct > 0.25
        ? MFColors.neonOrange
        : MFColors.neonPink;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current wall status
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MFColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: healthColor.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🧱', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Defense Wall Mk${wall.level}',
                            style: MFTextStyles.labelLarge),
                        Text('${wall.currentHp} / ${wall.maxHp} HP',
                            style: MFTextStyles.bodySmall
                                .copyWith(color: healthColor)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: healthPct.clamp(0.0, 1.0),
                backgroundColor: MFColors.borderSubtle,
                valueColor: AlwaysStoppedAnimation(healthColor),
                minHeight: 8,
              ),
              if (wall.needsRepair) ...[
                const SizedBox(height: 12),
                _buildRepairButton(context, wall, levels),
              ],
              // Defend raid button — only tappable on the actual raid week.
              // On the warning week (nextRaidWeek - 1) it's a read-only
              // info banner so the player can't accidentally trigger the raid
              // a week early by tapping it.
              if (game.currentWeek >= game.nextRaidWeek && !game.raidDefendedThisWeek) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MFColors.neonPink,
                      foregroundColor: MFColors.background,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => RaidScreen(game: game)),
                    ),
                    child: Text('🚨 DEFEND RAID NOW',
                        style: MFTextStyles.labelLarge.copyWith(color: MFColors.background)),
                  ),
                ),
              ] else if (game.currentWeek == game.nextRaidWeek - 1 && !game.raidDefendedThisWeek) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: MFColors.neonOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MFColors.neonOrange.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '⚠️ RAID INCOMING NEXT WEEK',
                    textAlign: TextAlign.center,
                    style: MFTextStyles.labelLarge.copyWith(color: MFColors.neonOrange),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Upgrade
        if (nextConfig != null) ...[
          Text('UPGRADE',
              style: MFTextStyles.bodySmall
                  .copyWith(color: MFColors.textMuted, letterSpacing: 2)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MFColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MFColors.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upgrade to Mk$nextLevel',
                          style: MFTextStyles.bodyLarge),
                      Text(
                        '${nextConfig['hp']} HP max  ·  '
                            '${_upgradeCostLine(nextConfig)}',
                        style: MFTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                _buildUpgradeButton(context, wall, nextConfig),
              ],
            ),
          ),
          if (wall.needsRepair) ...[
            const SizedBox(height: 6),
            Text('Wall must be fully repaired before upgrading.',
                style: MFTextStyles.bodySmall
                    .copyWith(color: MFColors.neonPink, fontSize: 11)),
          ],
        ] else ...[
          Text('Maximum wall level reached.',
              style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonGreen)),
        ],

        const SizedBox(height: 16),
        _buildTriggerRaidSection(context),

        const SizedBox(height: 16),
        Text('WALL HISTORY',
            style: MFTextStyles.bodySmall
                .copyWith(color: MFColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MFColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: MFColors.borderSubtle),
          ),
          child: Column(
            children: [
              _StatRow('Raids Defended', '${game.totalRaidsDefended}'),
              _StatRow('Total Fauna Killed', '${game.totalFaunaKilled}'),
              _StatRow('Total Chitin Collected', '${game.totalChitinCollected}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTriggerRaidSection(BuildContext context) {
    const meatCost = 10;
    const chemCost = 10;
    final raidIncoming = game.currentWeek >= game.nextRaidWeek - 1;
    final canAfford = game.resources.meat >= meatCost &&
        game.resources.chemicals >= chemCost &&
        !game.manualRaidTriggeredThisWeek &&
        !raidIncoming;
    final isRaidActive = game.currentWeek >= game.nextRaidWeek;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TRIGGER RAID',
            style: MFTextStyles.bodySmall
                .copyWith(color: MFColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MFColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: MFColors.neonPink.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bait the local fauna into an early raid by mixing up '
                    'some meat and local chemicals. The raid defense '
                    'will begin immediately.',
                style: MFTextStyles.bodySmall
                    .copyWith(color: MFColors.textMuted),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$meatCost 🥩  ·  $chemCost ⚗️',
                      style: MFTextStyles.bodyLarge.copyWith(
                        color: canAfford
                            ? MFColors.textSecondary
                            : MFColors.neonPink,
                      ),
                    ),
                  ),
                  if (isRaidActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: MFColors.neonPink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: MFColors.neonPink.withValues(alpha: 0.4)),
                      ),
                      child: Text('RAID ACTIVE',
                          style: MFTextStyles.bodySmall
                              .copyWith(color: MFColors.neonPink)),
                    )
                  else if (raidIncoming)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: MFColors.neonOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: MFColors.neonOrange.withValues(alpha: 0.4)),
                      ),
                      child: Text('RAID INCOMING',
                          style: MFTextStyles.bodySmall
                              .copyWith(color: MFColors.neonOrange)),
                    )
                  else if (game.manualRaidTriggeredThisWeek)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: MFColors.borderSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: MFColors.borderSubtle),
                      ),
                      child: Text('USED THIS TURN',
                          style: MFTextStyles.bodySmall
                              .copyWith(color: MFColors.textMuted)),
                    )
                  else
                    GestureDetector(
                      onTap: canAfford ? () => _triggerRaid(context) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: canAfford
                              ? MFColors.neonPink.withValues(alpha: 0.12)
                              : MFColors.borderSubtle,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: canAfford
                                ? MFColors.neonPink.withValues(alpha: 0.5)
                                : MFColors.borderSubtle,
                          ),
                        ),
                        child: Text(
                          'TRIGGER',
                          style: MFTextStyles.bodySmall.copyWith(
                            color: canAfford
                                ? MFColors.neonPink
                                : MFColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (!canAfford && !game.manualRaidTriggeredThisWeek && !raidIncoming)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Builder(builder: (context) {
                    final parts = <String>[];
                    if (game.resources.meat < meatCost) {
                      parts.add('${(meatCost - game.resources.meat).ceil()} more 🥩');
                    }
                    if (game.resources.chemicals < chemCost) {
                      parts.add('${(chemCost - game.resources.chemicals).ceil()} more ⚗️');
                    }
                    if (parts.isEmpty) return const SizedBox();
                    return Text(
                      'Need ${parts.join('  ·  ')}',
                      style: MFTextStyles.bodySmall
                          .copyWith(color: MFColors.neonPink, fontSize: 10),
                    );
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _triggerRaid(BuildContext context) {
    const meatCost = 10;
    const chemCost = 10;

    // 1. Deduct farming costs from the local state immediately, and lock
    //    out further manual triggers until the week advances.
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        resources: game.resources.copyWith(
          meat: game.resources.meat - meatCost,
          chemicals: game.resources.chemicals - chemCost,
        ),
        manualRaidTriggeredThisWeek: true,
      ),
    );

    // 2. Fetch the freshly updated state snapshot
    final updatedGame = ref.read(activeGameProvider).value ?? game;

    // 3. Sweep the player straight into an isolated farming instance!
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RaidScreen(game: updatedGame, isManualTrigger: true),
      ),
    );

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          child: Text('🚨 Pheromone bait deployed! Local swarm incoming...'),
        ),
        backgroundColor: MFColors.neonPink,
      ),
    );
  }

  String _upgradeCostLine(Map<String, dynamic> cfg) {
    final parts = <String>[];
    if ((cfg['upgrade_cost_ore'] as int) > 0) parts.add('${cfg['upgrade_cost_ore']} ore');
    if ((cfg['upgrade_cost_moon_dirt'] as int) > 0) parts.add('${cfg['upgrade_cost_moon_dirt']} dirt');
    if ((cfg['upgrade_cost_chitin'] as int? ?? 0) > 0) parts.add('${cfg['upgrade_cost_chitin']} chitin');
    if ((cfg['upgrade_cost_metals'] as int? ?? 0) > 0) parts.add('${cfg['upgrade_cost_metals']} metals');
    return parts.join('  ·  ');
  }

  Widget _buildRepairButton(
      BuildContext context, DefenseWall wall, List<Map<String, dynamic>> levels) {
    final cfg = levels.firstWhere(
          (l) => l['level'] == wall.level,
      orElse: () => levels.first,
    );
    final oreCost = cfg['repair_cost_ore'] as int? ?? 10;
    final dirtCost = cfg['repair_cost_moon_dirt'] as int? ?? 8;
    final canAfford = game.resources.ore >= oreCost &&
        game.resources.moonDirt >= dirtCost;
    final hpToRepair = wall.maxHp - wall.currentHp;

    final missing = <String>[];
    if (game.resources.ore < oreCost)
      missing.add('${oreCost - game.resources.ore.toInt()} more ore');
    if (game.resources.moonDirt < dirtCost)
      missing.add('${dirtCost - game.resources.moonDirt.toInt()} more moon dirt');

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Repair +$hpToRepair HP', style: MFTextStyles.bodyLarge),
              Text('$oreCost ore  ·  $dirtCost moon dirt',
                  style: MFTextStyles.bodySmall),
            ],
          ),
        ),
        AnimatedActionButton(
          label: 'REPAIR',
          canAfford: canAfford,
          color: MFColors.neonGreen,
          missingText: missing.isEmpty ? '' : 'Need: ${missing.join(', ')}',
          onTap: () => _doRepair(context, cfg),
        ),
      ],
    );
  }

  void _doRepair(BuildContext context, Map<String, dynamic> cfg) {
    final oreCost = cfg['repair_cost_ore'] as int;
    final dirtCost = cfg['repair_cost_moon_dirt'] as int;
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        defenseWall: game.defenseWall.fullyRepaired(),
        resources: game.resources.copyWith(
          ore: game.resources.ore - oreCost,
          moonDirt: game.resources.moonDirt - dirtCost,
        ),
      ),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('🧱 Wall repaired!'),
      )),
    );
  }

  Widget _buildUpgradeButton(
      BuildContext context, DefenseWall wall, Map<String, dynamic> cfg) {
    final oreCost = cfg['upgrade_cost_ore'] as int;
    final dirtCost = cfg['upgrade_cost_moon_dirt'] as int;
    final chitinCost = cfg['upgrade_cost_chitin'] as int? ?? 0;
    final metalsCost = cfg['upgrade_cost_metals'] as int? ?? 0;
    final canAfford = game.resources.ore >= oreCost &&
        game.resources.moonDirt >= dirtCost &&
        game.resources.chitin >= chitinCost &&
        game.resources.metals >= metalsCost &&
        !wall.needsRepair;

    return GestureDetector(
      onTap: canAfford ? () => _doUpgrade(context, cfg) : null,
      child: _ActionButton(label: 'UPGRADE', canAfford: canAfford,
          color: MFColors.neonCyan),
    );
  }

  void _doUpgrade(BuildContext context, Map<String, dynamic> cfg) {
    final newLevel = cfg['level'] as int;
    final newMaxHp = cfg['hp'] as int;
    final oreCost = cfg['upgrade_cost_ore'] as int;
    final dirtCost = cfg['upgrade_cost_moon_dirt'] as int;
    final metalsCost = cfg['upgrade_cost_metals'] as int? ?? 0;

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        defenseWall: DefenseWall(
          level: newLevel,
          currentHp: newMaxHp,
          maxHp: newMaxHp,
        ),
        resources: game.resources.copyWith(
          ore: game.resources.ore - oreCost,
          moonDirt: game.resources.moonDirt - dirtCost,
          metals: game.resources.metals - metalsCost,
        ),
      ),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('🧱 Defense Wall upgraded to Mk$newLevel!'),
      )),
    );
  }
}

// ─── Sentries Section ─────────────────────────────────────────────────────────

class _SentriesSection extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;

  const _SentriesSection({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final sentryLevels = (config.getOperationsBuildings()['laser_sentry']?['levels'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Existing sentries with upgrade buttons
        if (game.laserSentries.isNotEmpty) ...[
          Text('YOUR SENTRIES',
              style: MFTextStyles.bodySmall.copyWith(
                  color: MFColors.textMuted, letterSpacing: 2)),
          const SizedBox(height: 8),
          ...game.laserSentries.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            final nextLevel = s.level + 1;
            final currentCfg = sentryLevels
                .where((l) => l['level'] == s.level)
                .firstOrNull;
            final nextCfg = sentryLevels
                .where((l) => l['level'] == nextLevel)
                .firstOrNull;

            // Upgrade cost = next tier's cost minus current tier's cost —
            // you're upgrading an existing sentry, not building a new one
            // from scratch, so you shouldn't pay the new tier's full price.
            int delta(String key) {
              final next = nextCfg?[key] as int? ?? 0;
              final current = currentCfg?[key] as int? ?? 0;
              return (next - current).clamp(0, next);
            }
            final costMetals = delta('cost_metals');
            final costComponents = delta('cost_components');
            final costChitin = delta('cost_chitin');
            final costMycoculture = delta('cost_mycoculture');
            final powerDelta = nextCfg != null
                ? (nextCfg['power_draw_kwh'] as int) - s.powerDraw
                : 0;
            final hasPower = powerDelta <= 0 || game.powerSurplus >= powerDelta;
            final canAfford = nextCfg != null &&
                game.resources.metals >= costMetals &&
                game.resources.components >= costComponents &&
                game.resources.chitin >= costChitin &&
                game.resources.mycoculture >= costMycoculture &&
                hasPower;

            final color = mkColor(s.level);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('🔫', style: TextStyle(fontSize: 20, color: color)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sentry Mk${s.level}',
                                style: MFTextStyles.labelLarge.copyWith(color: color)),
                            Text(
                              '${s.damage} dmg  ·  ${s.fireRate}/sec  ·  '
                                  '${s.powerDraw} kW',
                              style: MFTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (nextCfg != null)
                        GestureDetector(
                          onTap: canAfford
                              ? () => _upgradeSentry(context, idx, s, nextCfg,
                              costMetals, costComponents, costChitin, costMycoculture)
                              : () {
                            final parts = <String>[];
                            if (game.resources.metals < costMetals)
                              parts.add('${costMetals - game.resources.metals.toInt()} metals');
                            if (game.resources.components < costComponents)
                              parts.add('$costComponents comp');
                            if (game.resources.chitin < costChitin)
                              parts.add('${costChitin - game.resources.chitin.toInt()} chitin');
                            if (game.resources.mycoculture < costMycoculture)
                              parts.add('${costMycoculture - game.resources.mycoculture.toInt()} mycoculture');
                            if (!hasPower)
                              parts.add('$powerDelta kW spare');
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: GestureDetector(
                                  onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                                  child: Text('Need: ${parts.join(', ')}'),
                                ),
                                    duration: const Duration(seconds: 2)));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: canAfford
                                  ? MFColors.neonCyan.withValues(alpha: 0.12)
                                  : MFColors.borderSubtle,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: canAfford
                                    ? MFColors.neonCyan.withValues(alpha: 0.5)
                                    : MFColors.borderSubtle,
                              ),
                            ),
                            child: Text('MK$nextLevel↑',
                                style: MFTextStyles.bodySmall.copyWith(
                                  color: canAfford
                                      ? MFColors.neonCyan
                                      : MFColors.textMuted,
                                  fontWeight: FontWeight.bold,
                                )),
                          ),
                        ),
                      if (nextCfg == null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: MFColors.neonOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('MAX',
                              style: MFTextStyles.bodySmall.copyWith(
                                  color: MFColors.neonOrange, fontSize: 10)),
                        ),
                    ],
                  ),
                  if (nextCfg != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '→ Mk$nextLevel: $costMetals metals'
                          '${costComponents > 0 ? '  ·  $costComponents comp' : ''}'
                          '${costChitin > 0 ? '  ·  $costChitin chitin' : ''}'
                          '${costMycoculture > 0 ? '  ·  $costMycoculture culture' : ''}'
                          '${powerDelta > 0 ? '  ·  +$powerDelta kW' : ''}',
                      style: MFTextStyles.bodySmall.copyWith(
                        color: canAfford ? MFColors.textMuted : MFColors.neonPink,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // Build new sentries
        Text('BUILD SENTRIES',
            style: MFTextStyles.bodySmall.copyWith(
                color: MFColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 8),
        ...sentryLevels.map((cfg) {
          final costMetals = cfg['cost_metals'] as int;
          final costComponents = cfg['cost_components'] as int;
          final costChitin = cfg['cost_chitin'] as int? ?? 0;
          final costMycoculture = cfg['cost_mycoculture'] as int? ?? 0;
          final powerNeeded = cfg['power_draw_kwh'] as int;
          final hasPower = game.powerSurplus >= powerNeeded;
          final canAfford = game.resources.metals >= costMetals &&
              game.resources.components >= costComponents &&
              game.resources.chitin >= costChitin &&
              game.resources.mycoculture >= costMycoculture &&
              hasPower;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MFColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: MFColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Text('🔫', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cfg['name'] as String, style: MFTextStyles.bodyLarge),
                        Text(
                          '$costMetals metals'
                              '${costComponents > 0 ? '  ·  $costComponents comp' : ''}'
                              '${costChitin > 0 ? '  ·  $costChitin chitin' : ''}'
                              '${costMycoculture > 0 ? '  ·  $costMycoculture culture' : ''}',
                          style: MFTextStyles.bodySmall.copyWith(
                            color: canAfford ? MFColors.textSecondary : MFColors.neonPink,
                          ),
                        ),
                        Text(
                          '${cfg['damage']} dmg  ·  ${cfg['fire_rate']}/sec  ·  '
                              '${cfg['power_draw_kwh']} kW'
                              '${!hasPower ? '  ·  need ${powerNeeded - game.powerSurplus} more kW' : ''}',
                          style: MFTextStyles.bodySmall.copyWith(
                              color: hasPower ? MFColors.textMuted : MFColors.neonPink),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: canAfford
                        ? () => _buildSentry(context, cfg)
                        : () {
                      if (!hasPower) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: GestureDetector(
                            onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                            child: Text(
                                '⚡ Not enough power. Needs $powerNeeded kW, '
                                    'only ${game.powerSurplus} kW spare.'),
                          ),
                              duration: const Duration(seconds: 3)),
                        );
                      }
                    },
                    child: _ActionButton(
                        label: 'BUILD', canAfford: canAfford, color: MFColors.neonCyan),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _upgradeSentry(BuildContext context, int idx,
      LaserSentry sentry, Map<String, dynamic> cfg,
      int costMetals, int costComponents, int costChitin, int costMycoculture) {
    final upgraded = LaserSentry(
      id: sentry.id,
      level: cfg['level'] as int,
      health: sentry.health,
      powerDraw: cfg['power_draw_kwh'] as int,
      damage: cfg['damage'] as int,
      fireRate: cfg['fire_rate'] as int,
      range: cfg['range'] as int,
    );

    final updatedSentries = List<LaserSentry>.from(game.laserSentries);
    updatedSentries[idx] = upgraded;

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        laserSentries: updatedSentries,
        resources: game.resources.copyWith(
          metals: game.resources.metals - costMetals,
          components: game.resources.components - costComponents,
          chitin: game.resources.chitin - costChitin,
          mycoculture: game.resources.mycoculture - costMycoculture,
        ),
      ),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('🔫 Sentry upgraded to Mk${cfg['level']}!'),
      )),
    );
  }

  void _buildSentry(BuildContext context, Map<String, dynamic> cfg) {
    final newSentry = LaserSentry(
      id: 'sentry_${DateTime.now().millisecondsSinceEpoch}',
      level: cfg['level'] as int,
      health: 100,
      powerDraw: cfg['power_draw_kwh'] as int,
      damage: cfg['damage'] as int,
      fireRate: cfg['fire_rate'] as int,
      range: cfg['range'] as int,
    );
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        laserSentries: [...game.laserSentries, newSentry],
        resources: game.resources.copyWith(
          metals: game.resources.metals - (cfg['cost_metals'] as int),
          components: game.resources.components - (cfg['cost_components'] as int),
          chitin: game.resources.chitin - (cfg['cost_chitin'] as int? ?? 0),
          mycoculture: game.resources.mycoculture - (cfg['cost_mycoculture'] as int? ?? 0),
        ),
      ),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('🔫 ${cfg['name']} deployed!'),
      )),
    );
  }
}

// ─── Grenade Section ──────────────────────────────────────────────────────────

class _GrenadeSection extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;

  const _GrenadeSection({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final benchLevel = game.grenades.benchLevel;
    final allGrenades = config.getGrenadeTypes();
    final benchLevels = (config.getGrenadeBenchConfig()['levels'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final nextBenchLevel = benchLevel + 1;
    final nextBenchConfig = benchLevels
        .where((l) => l['level'] == nextBenchLevel)
        .firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Bench level
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: MFColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MFColors.neonOrange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Text('🏭', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Grenade Bench Mk$benchLevel',
                        style: MFTextStyles.labelLarge),
                    Text(
                      'Unlocks grenade types up to level $benchLevel',
                      style: MFTextStyles.bodySmall,
                    ),
                    if (nextBenchConfig != null)
                      Text(
                        'Mk$nextBenchLevel: '
                            '${nextBenchConfig['cost_metals'] ?? 0} metals'
                            '${(nextBenchConfig['cost_components'] as int? ?? 0) > 0 ? '  ·  ${nextBenchConfig['cost_components']} comp' : ''}',
                        style: MFTextStyles.bodySmall.copyWith(
                          color: _canAffordBench(nextBenchConfig)
                              ? MFColors.textMuted
                              : MFColors.neonPink,
                        ),
                      ),
                  ],
                ),
              ),
              if (nextBenchConfig != null)
                GestureDetector(
                  onTap: _canAffordBench(nextBenchConfig)
                      ? () => _upgradeBench(context, nextBenchConfig)
                      : null,
                  child: _ActionButton(
                    label: 'MK$nextBenchLevel↑',
                    canAfford: _canAffordBench(nextBenchConfig),
                    color: MFColors.neonOrange,
                  ),
                ),
            ],
          ),
        ),

        Text('CRAFT GRENADES',
            style: MFTextStyles.bodySmall.copyWith(
                color: MFColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 8),

        ...allGrenades.map((g) {
          final unlockLevel = g['unlock_level'] as int;
          final isUnlocked = unlockLevel <= benchLevel;
          final grenadeId = g['id'] as String;
          final currentCount = game.grenades.countOf(grenadeId);
          final craftCost = g['craft_cost'] as Map<String, dynamic>;
          final craftYield = g['craft_yield'] as int;
          final canCraft = isUnlocked && _canAffordCraft(craftCost);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MFColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isUnlocked
                    ? MFColors.borderDefault
                    : MFColors.borderSubtle,
              ),
            ),
            child: Row(
              children: [
                Text(g['emoji'] as String,
                    style: TextStyle(
                      fontSize: 22,
                      color: isUnlocked ? null : Colors.white24,
                    )),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(g['name'] as String, style: MFTextStyles.bodyLarge),
                          const SizedBox(width: 8),
                          Text('×$currentCount',
                              style: MFTextStyles.bodySmall
                                  .copyWith(color: MFColors.neonCyan)),
                        ],
                      ),
                      Text(g['description'] as String, style: MFTextStyles.bodySmall),
                      if (isUnlocked)
                        Text(
                          'Craft: ${_craftCostLine(craftCost)} → ×$craftYield',
                          style: MFTextStyles.bodySmall.copyWith(
                            color: canCraft ? MFColors.textMuted : MFColors.neonPink,
                          ),
                        )
                      else
                        Text(
                          'Requires Bench Mk$unlockLevel',
                          style: MFTextStyles.bodySmall
                              .copyWith(color: MFColors.textMuted),
                        ),
                    ],
                  ),
                ),
                if (isUnlocked)
                  GestureDetector(
                    onTap: canCraft
                        ? () => _craftGrenade(context, grenadeId, craftCost, craftYield)
                        : null,
                    child: _ActionButton(
                        label: 'CRAFT', canAfford: canCraft, color: MFColors.neonOrange),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  bool _canAffordBench(Map<String, dynamic> cfg) {
    return game.resources.metals >= (cfg['cost_metals'] as int? ?? 0) &&
        game.resources.components >= (cfg['cost_components'] as int? ?? 0);
  }

  void _upgradeBench(BuildContext context, Map<String, dynamic> cfg) {
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        grenades: game.grenades.copyWith(benchLevel: cfg['level'] as int),
        resources: game.resources.copyWith(
          metals: game.resources.metals - (cfg['cost_metals'] as int? ?? 0),
          components: game.resources.components - (cfg['cost_components'] as int? ?? 0),
        ),
      ),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('🏭 Grenade Bench upgraded to Mk${cfg['level']}!'),
      )),
    );
  }

  bool _canAffordCraft(Map<String, dynamic> cost) {
    for (final entry in cost.entries) {
      final needed = entry.value as int;
      double have = 0;
      switch (entry.key) {
        case 'chemicals': have = game.resources.chemicals;
        case 'metals': have = game.resources.metals;
        case 'components': have = game.resources.components;
        case 'ore': have = game.resources.ore;
        case 'chitin': have = game.resources.chitin;
        case 'meat': have = game.resources.meat;
        case 'moss': have = game.resources.moss;
      }
      if (have < needed) return false;
    }
    return true;
  }

  String _craftCostLine(Map<String, dynamic> cost) {
    return cost.entries.map((e) => '${e.value} ${e.key}').join(' + ');
  }

  void _craftGrenade(
      BuildContext context, String id, Map<String, dynamic> cost, int yield_) {
    var r = game.resources;
    for (final entry in cost.entries) {
      final amount = (entry.value as int).toDouble();
      switch (entry.key) {
        case 'chemicals': r = r.copyWith(chemicals: r.chemicals - amount);
        case 'metals': r = r.copyWith(metals: r.metals - amount);
        case 'components': r = r.copyWith(components: r.components - amount);
        case 'ore': r = r.copyWith(ore: r.ore - amount);
        case 'chitin': r = r.copyWith(chitin: r.chitin - amount);
        case 'meat': r = r.copyWith(meat: r.meat - amount);
        case 'moss': r = r.copyWith(moss: r.moss - amount);
      }
    }

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        resources: r,
        grenades: game.grenades.add(id, yield_),
      ),
    );

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('Crafted ×$yield_ ${id.replaceAll('_', ' ')}!'),
      )),
    );
  }
}

// ─── Contract Section ─────────────────────────────────────────────────────────

class _ContractSection extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;

  const _ContractSection({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final milestone = game.milestones.where((m) => m.isWinCondition).firstOrNull;

    if (milestone == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('📜\n\nNo contract on file.',
              style: MFTextStyles.bodyMedium, textAlign: TextAlign.center),
        ),
      );
    }

    final target = milestone.target;
    final current = game.resources.starScrip.toDouble();
    final progress = (current / target).clamp(0.0, 1.0);
    final isPaidOff = game.status == GameStatus.won;
    final isEligible = current >= target;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('THE COLONY CONTRACT',
            style: MFTextStyles.bodySmall.copyWith(
                color: MFColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MFColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isPaidOff ? MFColors.neonGreen : MFColors.borderDefault),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Every shipment out of this dome belongs to the colony until '
                'the contract is paid off in full. ${_formatTarget(target)} '
                'Star-Scrip on hand, all at once, buys it out for good.',
                style: MFTextStyles.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (isPaidOff) ...[
                Row(
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Contract paid off. This farm is yours.',
                          style: MFTextStyles.bodyLarge
                              .copyWith(color: MFColors.neonGreen)),
                    ),
                  ],
                ),
              ] else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: MFColors.borderSubtle,
                    valueColor: AlwaysStoppedAnimation(
                        isEligible ? MFColors.neonGreen : MFColors.starScrip),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${game.resources.starScrip} / ${_formatTarget(target)} Star-Scrip',
                  style: MFTextStyles.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEligible
                            ? 'You can buy out the contract now.'
                            : 'Need ${_formatTarget(target - current)} more Star-Scrip.',
                        style: MFTextStyles.bodySmall,
                      ),
                    ),
                    AnimatedActionButton(
                      label: 'BUY THE FARM',
                      canAfford: isEligible,
                      color: MFColors.neonGreen,
                      missingText: isEligible
                          ? ''
                          : 'Need ${_formatTarget(target - current)} more Star-Scrip',
                      onTap: () => _confirmBuyTheFarm(context),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatTarget(double v) {
    final i = v.round();
    final s = i.toString();
    final parts = <String>[];
    for (int idx = s.length; idx > 0; idx -= 3) {
      parts.insert(0, s.substring((idx - 3).clamp(0, s.length), idx));
    }
    return parts.join(',');
  }

  Future<void> _confirmBuyTheFarm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MFColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: MFColors.neonGreen, width: 1),
        ),
        title: Text('BUY THE FARM?',
            style: MFTextStyles.headlineMedium.copyWith(color: MFColors.neonGreen)),
        content: Text(
          'This pays off the colony contract in full. The operation is '
          'yours — no more indentured shipments. You can keep farming '
          'afterward if you want; this just ends the contract.',
          style: MFTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('NOT YET', style: MFTextStyles.labelLarge),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('BUY IT OUT',
                style: MFTextStyles.labelLarge.copyWith(color: MFColors.neonGreen)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final engine = EndWeekEngine();
    final newState = engine.buyTheFarm(game);
    if (newState.status != GameStatus.won) return; // not actually eligible

    await ref.read(activeGameProvider.notifier).updateGame(newState);
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScoreScreen(game: newState)),
    );
  }
}

// ─── Stats Section ────────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  final GameState game;
  const _StatsSection({required this.game});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(child: Text('🏠', style: TextStyle(fontSize: 48))),
        const SizedBox(height: 8),
        Center(
          child: Text(
            game.displayName.toUpperCase(),
            style: MFTextStyles.headlineLarge.copyWith(color: MFColors.neonCyan),
          ),
        ),
        const SizedBox(height: 24),

        _StatCard('LIFETIME STATS', [
          _StatRow('Weeks Survived', '${game.currentWeek}'),
          _StatRow('Crops Harvested', '${game.totalCropsHarvested}'),
          _StatRow('Volume Delivered', '${game.totalVolumeDeliveredM3.toStringAsFixed(1)}m³'),
          _StatRow('Lifetime Star-Scrip', '${game.lifetimeScripEarned}'),
          _StatRow('Compost Generated', '${game.totalCompostGenerated}'),
        ]),
        const SizedBox(height: 16),

        _StatCard('DEFENSE', [
          _StatRow('Raids Defended', '${game.totalRaidsDefended}'),
          _StatRow('Fauna Killed', '${game.totalFaunaKilled}'),
          _StatRow('Chitin Collected', '${game.totalChitinCollected}'),
          _StatRow('Wall Level', 'Mk${game.defenseWall.level}'),
          _StatRow('Sentries', '${game.laserSentries.length}'),
        ]),
        const SizedBox(height: 16),

        if (game.radioFeed.isNotEmpty) ...[
          Text('RADIO LOG',
              style: MFTextStyles.bodySmall.copyWith(
                  color: MFColors.textMuted, letterSpacing: 2)),
          const SizedBox(height: 8),
          ...game.radioFeed.reversed.take(10).map(
                (r) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
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
                  Text('W${r.week}',
                      style: MFTextStyles.bodySmall
                          .copyWith(color: MFColors.neonCyan, fontSize: 10)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r.message, style: MFTextStyles.bodySmall)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final List<Widget> rows;

  const _StatCard(this.title, this.rows);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: MFTextStyles.bodySmall
                .copyWith(color: MFColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MFColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MFColors.borderSubtle),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
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

class _ActionButton extends StatelessWidget {
  final String label;
  final bool canAfford;
  final Color color;

  const _ActionButton({required this.label, required this.canAfford, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: canAfford ? color.withValues(alpha: 0.12) : MFColors.borderSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: canAfford ? color.withValues(alpha: 0.5) : MFColors.borderSubtle,
        ),
      ),
      child: Text(
        label,
        style: MFTextStyles.bodySmall.copyWith(
          color: canAfford ? color : MFColors.textMuted,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}