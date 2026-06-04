// ═══════════════════════════════════════════════════════════════
//  lib/screens/operations/operations_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/game_config_service.dart';

class OperationsScreen extends ConsumerWidget {
  const OperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(activeGameProvider).value;
    if (game == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Power Grid ───────────────────────────────────────────────────
        _PowerSection(game: game, ref: ref),
        const SizedBox(height: 16),

        // ── Mining Drones ────────────────────────────────────────────────
        _DroneSection(game: game, ref: ref),
        const SizedBox(height: 16),

        // ── Sentry Defense ───────────────────────────────────────────────
        _SentrySection(game: game, ref: ref),
      ],
    );
  }
}

// ─── Power Section ────────────────────────────────────────────────────────────

class _PowerSection extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;

  const _PowerSection({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final opsBuildings = config.getOperationsBuildings();
    final powerBuildings = opsBuildings['power'] as Map<String, dynamic>? ?? {};

    final surplus = game.powerSurplus;
    final surplusColor =
    surplus >= 0 ? MFColors.neonGreen : MFColors.neonPink;

    return _OpsCard(
      icon: '⚡',
      title: 'POWER GRID',
      subtitle:
      '${game.totalPowerProduction} KWh  −  ${game.totalPowerDraw} KWh  =  '
          '${surplus >= 0 ? '+' : ''}$surplus KWh',
      subtitleColor: surplusColor,
      children: [
        // Current sources
        if (game.powerSources.isNotEmpty) ...[
          ...game.powerSources.map((p) => _PowerSourceRow(source: p)),
          const Divider(height: 14),
        ],

        // Build options
        Text('BUILD POWER SOURCE',
            style: MFTextStyles.bodySmall
                .copyWith(color: MFColors.textMuted, letterSpacing: 2, fontSize: 9)),
        const SizedBox(height: 8),
        ...powerBuildings.entries.map((entry) {
          final b = entry.value as Map<String, dynamic>;
          final costScrip = b['cost_scrip'] as int;
          final costMetals = b['cost_metals'] as int? ?? 0;
          final costGlass = b['cost_glass'] as int? ?? 0;
          final costComponents = b['cost_components'] as int? ?? 0;
          final canAfford = game.resources.starScrip >= costScrip &&
              game.resources.metals >= costMetals &&
              game.resources.glass >= costGlass &&
              game.resources.components >= costComponents;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BuildRow(
              emoji: b['emoji'] as String,
              name: b['name'] as String,
              description: b['description'] as String,
              costLine: _costLine(costScrip, costMetals, costGlass, costComponents),
              outputLine: '+${b['power_output_kwh']} KWh',
              outputColor: MFColors.neonGreen,
              canAfford: canAfford,
              onBuild: () => _buildPower(context, entry.key, b, game),
            ),
          );
        }),
      ],
    );
  }

  String _costLine(int scrip, int metals, int glass, int components) {
    final parts = <String>['$scrip 🎫'];
    if (metals > 0) parts.add('$metals metals');
    if (glass > 0) parts.add('$glass glass');
    if (components > 0) parts.add('$components components');
    return parts.join('  ·  ');
  }

  void _buildPower(
      BuildContext context,
      String key,
      Map<String, dynamic> b,
      GameState game,
      ) {
    final costScrip = b['cost_scrip'] as int;
    final costMetals = b['cost_metals'] as int? ?? 0;
    final costGlass = b['cost_glass'] as int? ?? 0;
    final costComponents = b['cost_components'] as int? ?? 0;

    final type = switch (key) {
      'solar_array' => PowerSourceType.solarArray,
      'wind_turbine' => PowerSourceType.windTurbine,
      'geothermal_tap' => PowerSourceType.geothermalTap,
      _ => PowerSourceType.solarArray,
    };

    final newSource = PowerSource(
      id: '${key}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      outputKwh: b['power_output_kwh'] as int,
    );

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        powerSources: [...game.powerSources, newSource],
        resources: game.resources.copyWith(
          starScrip: game.resources.starScrip - costScrip,
          metals: game.resources.metals - costMetals,
          glass: game.resources.glass - costGlass,
          components: game.resources.components - costComponents,
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${b['emoji']} ${b['name']} built! +${b['power_output_kwh']} KWh')),
    );
  }
}

class _PowerSourceRow extends StatelessWidget {
  final PowerSource source;
  const _PowerSourceRow({required this.source});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(source.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(source.name, style: MFTextStyles.bodyLarge)),
          Text('+${source.outputKwh} KWh',
              style: MFTextStyles.labelLarge.copyWith(color: MFColors.neonGreen)),
        ],
      ),
    );
  }
}

// ─── Drone Section ────────────────────────────────────────────────────────────

class _DroneSection extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;

  const _DroneSection({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final opsBuildings = config.getOperationsBuildings();
    final droneConfig = opsBuildings['mining_drone'] as Map<String, dynamic>? ?? {};
    final costScrip = droneConfig['cost_scrip'] as int? ?? 250;
    final costMetals = droneConfig['cost_metals'] as int? ?? 15;
    final costComponents = droneConfig['cost_components'] as int? ?? 5;
    final outputPerWeek = (droneConfig['output_per_week'] as num?)?.toDouble() ?? 8.0;
    final canAfford = game.resources.starScrip >= costScrip &&
        game.resources.metals >= costMetals &&
        game.resources.components >= costComponents;

    // Tally drone assignments
    final drones = game.miningDrones;
    final dirtCount = drones.where((d) => d.assignedResource == 'moon_dirt').length;
    final oreCount = drones.where((d) => d.assignedResource == 'ore').length;
    final sandCount = drones.where((d) => d.assignedResource == 'sand').length;
    final idleCount = drones.where((d) => d.isIdle).length;

    return _OpsCard(
      icon: '⛏️',
      title: 'MINING DRONES',
      subtitle: '${drones.length} drones  ·  '
          '${(dirtCount * outputPerWeek).toInt()} dirt  '
          '${(oreCount * outputPerWeek).toInt()} ore  '
          '${(sandCount * outputPerWeek).toInt()} sand / week',
      subtitleColor: MFColors.textSecondary,
      children: [
        // Assignment summary
        if (drones.isNotEmpty) ...[
          _AssignmentBar(
            dirtCount: dirtCount,
            oreCount: oreCount,
            sandCount: sandCount,
            idleCount: idleCount,
            outputPerWeek: outputPerWeek,
            onReassign: () => _showAssignmentDialog(context, game),
          ),
          const Divider(height: 14),
        ],

        // Build drone
        _BuildRow(
          emoji: '🤖',
          name: 'Harvesting Drone',
          description: 'Assign to Moon Dirt, Ore, or Sand. '
              '+${outputPerWeek.toInt()} units/wk when active.',
          costLine: '$costScrip 🎫  ·  $costMetals metals  ·  $costComponents components',
          outputLine: '+${outputPerWeek.toInt()}/wk',
          outputColor: MFColors.neonOrange,
          canAfford: canAfford,
          onBuild: () => _buildDrone(context, costScrip, costMetals, costComponents, outputPerWeek, game),
        ),
      ],
    );
  }

  void _buildDrone(BuildContext context, int costScrip, int costMetals,
      int costComponents, double output, GameState game) {
    final newDrone = MiningDrone(
      id: 'drone_${DateTime.now().millisecondsSinceEpoch}',
      assignedResource: null,
      outputPerWeek: output,
    );
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        miningDrones: [...game.miningDrones, newDrone],
        resources: game.resources.copyWith(
          starScrip: game.resources.starScrip - costScrip,
          metals: game.resources.metals - costMetals,
          components: game.resources.components - costComponents,
        ),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🤖 Mining drone built! Assign it a resource.')),
    );
  }

  void _showAssignmentDialog(BuildContext context, GameState game) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MFColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: MFColors.borderDefault),
      ),
      builder: (ctx) => _DroneAssignmentSheet(game: game, ref: ref),
    );
  }
}

class _AssignmentBar extends StatelessWidget {
  final int dirtCount, oreCount, sandCount, idleCount;
  final double outputPerWeek;
  final VoidCallback onReassign;

  const _AssignmentBar({
    required this.dirtCount,
    required this.oreCount,
    required this.sandCount,
    required this.idleCount,
    required this.outputPerWeek,
    required this.onReassign,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onReassign,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: MFColors.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: MFColors.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ASSIGNMENTS', style: MFTextStyles.bodySmall.copyWith(
                    color: MFColors.textMuted, letterSpacing: 1, fontSize: 9)),
                Text('TAP TO REASSIGN', style: MFTextStyles.bodySmall.copyWith(
                    color: MFColors.neonCyan, fontSize: 9)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _AssignChip('🌑', '$dirtCount', 'Moon Dirt', MFColors.textSecondary),
                const SizedBox(width: 8),
                _AssignChip('🪨', '$oreCount', 'Ore', MFColors.neonOrange),
                const SizedBox(width: 8),
                _AssignChip('🏖️', '$sandCount', 'Sand', MFColors.neonYellow),
                const SizedBox(width: 8),
                _AssignChip('💤', '$idleCount', 'Idle', MFColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignChip extends StatelessWidget {
  final String emoji, count, label;
  final Color color;

  const _AssignChip(this.emoji, this.count, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        Text(count, style: MFTextStyles.labelLarge.copyWith(color: color, fontSize: 12)),
        Text(label, style: MFTextStyles.bodySmall.copyWith(fontSize: 8)),
      ],
    );
  }
}

class _DroneAssignmentSheet extends StatefulWidget {
  final GameState game;
  final WidgetRef ref;

  const _DroneAssignmentSheet({required this.game, required this.ref});

  @override
  State<_DroneAssignmentSheet> createState() => _DroneAssignmentSheetState();
}

class _DroneAssignmentSheetState extends State<_DroneAssignmentSheet> {
  late Map<String, int> _assignments;
  @override
  void initState() {
    super.initState();
    _assignments = {
      'moon_dirt': widget.game.miningDrones.where((d) => d.assignedResource == 'moon_dirt').length,
      'ore': widget.game.miningDrones.where((d) => d.assignedResource == 'ore').length,
      'sand': widget.game.miningDrones.where((d) => d.assignedResource == 'sand').length,
      'idle': widget.game.miningDrones.where((d) => d.isIdle).length,
    };
  }

  int get total => widget.game.miningDrones.length;
  int get assigned => _assignments.values.fold(0, (a, b) => a + b);

  void _apply() {
    final drones = <MiningDrone>[];
    int idx = 0;
    for (final entry in {
      'moon_dirt': _assignments['moon_dirt']!,
      'ore': _assignments['ore']!,
      'sand': _assignments['sand']!,
      'idle': _assignments['idle']!,
    }.entries) {
      for (int i = 0; i < entry.value; i++) {
        final original = widget.game.miningDrones[idx++];
        drones.add(original.copyWith(
          assignedResource: entry.key == 'idle' ? null : entry.key,
        ));
      }
    }
    widget.ref.read(activeGameProvider.notifier).updateGameLocal(
      widget.game.copyWith(miningDrones: drones),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ASSIGN $total DRONES',
              style: MFTextStyles.labelLarge.copyWith(letterSpacing: 2)),
          const SizedBox(height: 16),
          ...['moon_dirt', 'ore', 'sand', 'idle'].map((key) {
            final label = switch (key) {
              'moon_dirt' => '🌑 Moon Dirt',
              'ore' => '🪨 Ore',
              'sand' => '🏖️ Sand',
              _ => '💤 Idle',
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: MFTextStyles.bodyLarge)),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: MFColors.neonPink),
                    onPressed: (_assignments[key] ?? 0) > 0
                        ? () => setState(() => _assignments[key] = (_assignments[key] ?? 0) - 1)
                        : null,
                  ),
                  Text('${_assignments[key] ?? 0}',
                      style: MFTextStyles.labelLarge),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: MFColors.neonGreen),
                    onPressed: assigned < total
                        ? () => setState(() => _assignments[key] = (_assignments[key] ?? 0) + 1)
                        : null,
                  ),
                ],
              ),
            );
          }),
          Text('$assigned / $total assigned',
              style: MFTextStyles.bodySmall.copyWith(
                color: assigned == total ? MFColors.neonGreen : MFColors.neonYellow,
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _apply,
              child: const Text('APPLY'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sentry Section ───────────────────────────────────────────────────────────

class _SentrySection extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;

  const _SentrySection({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final opsBuildings = config.getOperationsBuildings();
    final sentryLevels = (opsBuildings['laser_sentry']?['levels'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    final weeksToRaid = game.nextRaidWeek - game.currentWeek;
    final isRaidWeek = weeksToRaid <= 0 && !game.raidDefendedThisWeek;
    final raidWarning = weeksToRaid <= 2 && weeksToRaid > 0;

    return _OpsCard(
      icon: '🔫',
      title: 'SENTRY DEFENSE',
      subtitle: game.laserSentries.isEmpty
          ? 'No sentries — base is undefended!'
          : '${game.laserSentries.length} sentry${game.laserSentries.length == 1 ? '' : 'ies'} active',
      subtitleColor: game.laserSentries.isEmpty
          ? MFColors.neonOrange
          : MFColors.neonGreen,
      children: [
        // Raid status
        _RaidStatus(game: game, isRaidWeek: isRaidWeek, raidWarning: raidWarning,
            weeksToRaid: weeksToRaid),
        const SizedBox(height: 10),

        // Existing sentries
        if (game.laserSentries.isNotEmpty) ...[
          ...game.laserSentries.map((s) => _SentryRow(sentry: s)),
          const Divider(height: 14),
        ],

        // Build options
        Text('BUILD SENTRIES',
            style: MFTextStyles.bodySmall
                .copyWith(color: MFColors.textMuted, letterSpacing: 2, fontSize: 9)),
        const SizedBox(height: 8),
        ...sentryLevels.map((s) {
          final costScrip = s['cost_scrip'] as int;
          final costMetals = s['cost_metals'] as int;
          final costComponents = s['cost_components'] as int;
          final canAfford = game.resources.starScrip >= costScrip &&
              game.resources.metals >= costMetals &&
              game.resources.components >= costComponents;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BuildRow(
              emoji: '🔫',
              name: s['name'] as String,
              description:
              '${s['damage']} dmg  ·  fire rate ${s['fire_rate']}  ·  range ${s['range']}',
              costLine:
              '$costScrip 🎫  ·  $costMetals metals  ·  $costComponents components',
              outputLine: '${s['power_draw_kwh']} KWh draw',
              outputColor: MFColors.neonOrange,
              canAfford: canAfford,
              onBuild: () => _buildSentry(context, s, game),
            ),
          );
        }),
      ],
    );
  }

  void _buildSentry(
      BuildContext context, Map<String, dynamic> cfg, GameState game) {
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
          starScrip: game.resources.starScrip - (cfg['cost_scrip'] as int),
          metals: game.resources.metals - (cfg['cost_metals'] as int),
          components: game.resources.components - (cfg['cost_components'] as int),
        ),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🔫 ${cfg['name']} deployed!')),
    );
  }
}

class _SentryRow extends StatelessWidget {
  final LaserSentry sentry;
  const _SentryRow({required this.sentry});

  @override
  Widget build(BuildContext context) {
    final healthColor = MFStatusColor.forPercent(sentry.healthPercent);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Text('🔫', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sentry Mk${sentry.level}  ·  ${sentry.damage} dmg  ·  range ${sentry.range}',
              style: MFTextStyles.bodyLarge,
            ),
          ),
          Text('${sentry.health}%',
              style: MFTextStyles.bodySmall.copyWith(color: healthColor)),
        ],
      ),
    );
  }
}

class _RaidStatus extends StatelessWidget {
  final GameState game;
  final bool isRaidWeek, raidWarning;
  final int weeksToRaid;

  const _RaidStatus({
    required this.game,
    required this.isRaidWeek,
    required this.raidWarning,
    required this.weeksToRaid,
  });

  @override
  Widget build(BuildContext context) {
    Color color = MFColors.textMuted;
    String msg = 'Next raid: Week ${game.nextRaidWeek} ($weeksToRaid weeks away)';
    if (isRaidWeek) {
      color = MFColors.neonPink;
      msg = '🚨 RAID IN PROGRESS — defend from Dashboard';
    } else if (raidWarning) {
      color = MFColors.neonOrange;
      msg = '⚠️ Raid incoming in $weeksToRaid week${weeksToRaid == 1 ? '' : 's'}! Prepare defenses.';
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isRaidWeek
            ? MFColors.neonPink.withValues(alpha: 0.08)
            : MFColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(msg, style: MFTextStyles.bodySmall.copyWith(color: color)),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _OpsCard extends StatelessWidget {
  final String icon, title, subtitle;
  final Color subtitleColor;
  final List<Widget> children;

  const _OpsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MFColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: MFTextStyles.labelLarge),
                    Text(subtitle,
                        style: MFTextStyles.bodySmall
                            .copyWith(color: subtitleColor)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _BuildRow extends StatelessWidget {
  final String emoji, name, description, costLine, outputLine;
  final Color outputColor;
  final bool canAfford;
  final VoidCallback onBuild;

  const _BuildRow({
    required this.emoji,
    required this.name,
    required this.description,
    required this.costLine,
    required this.outputLine,
    required this.outputColor,
    required this.canAfford,
    required this.onBuild,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name, style: MFTextStyles.bodyLarge),
                  const SizedBox(width: 8),
                  Text(outputLine,
                      style: MFTextStyles.bodySmall
                          .copyWith(color: outputColor, fontWeight: FontWeight.bold)),
                ],
              ),
              Text(description,
                  style: MFTextStyles.bodySmall.copyWith(color: MFColors.textMuted)),
              Text(costLine,
                  style: MFTextStyles.bodySmall.copyWith(
                    color: canAfford ? MFColors.textSecondary : MFColors.neonPink,
                  )),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: canAfford ? onBuild : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            child: Text('BUILD',
                style: MFTextStyles.bodySmall.copyWith(
                  color: canAfford ? MFColors.neonCyan : MFColors.textMuted,
                  fontWeight: FontWeight.bold,
                )),
          ),
        ),
      ],
    );
  }
}