// ═══════════════════════════════════════════════════════════════
//  lib/screens/refinery/refinery_screen.dart
// ═══════════════════════════════════════════════════════════════
// Reads machine data from upgrades_refinery.yaml via UpgradeConfigService.
// One unified card style. Water purifier at top (passive, no craft button).
// Each machine: Craft 1 / Craft 5 / Craft 10 buttons (5/10 hidden if unaffordable).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/game_config_service.dart';
import '../../config/upgrade_config_service.dart';

/// Returns true if the game has enough spare power for [additionalDraw] more KWh.
/// Power never shuts anything off — this only gates NEW construction/upgrades.
bool _hasPowerFor(GameState game, int additionalDraw) {
  if (additionalDraw <= 0) return true;
  return game.powerSurplus >= additionalDraw;
}

/// Shows a brief "not enough power" snackbar.
void _powerSnack(BuildContext context, int needed, int surplus) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('⚡ Not enough power. Needs $needed KWh, only $surplus KWh spare. Build more power first.'),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

class RefineryScreen extends ConsumerWidget {
  const RefineryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(activeGameProvider).value;
    if (game == null) return const SizedBox();

    final refinery = game.refineries.isEmpty ? null : game.refineries.first;
    final installed = refinery?.machines.map((m) => m.type).toSet() ?? {};
    final buildable = MachineType.values.where((t) => !installed.contains(t)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Water purifier — passive, top of list
        _WaterPurifierCard(game: game, ref: ref),
        const SizedBox(height: 10),

        // Installed machines
        if (refinery != null)
          ...refinery.machines.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MachineCard(machine: m, game: game, ref: ref, refinery: refinery),
          )),

        // Buildable machines
        ...buildable.map((type) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _BuildMachineCard(
            type: type, game: game, ref: ref,
            refinery: refinery,
          ),
        )),
      ],
    );
  }
}

// ─── Water Purifier Card ──────────────────────────────────────────────────────

class _WaterPurifierCard extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;
  const _WaterPurifierCard({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final level = game.waterPurifierLevel;
    final output = config.getWaterOutputForLevel(level);
    final levels = config.getWaterPurifierLevels();
    final currentLevelCfg = levels.where((l) => l['level'] == level).firstOrNull;
    final currentPowerDraw = currentLevelCfg?['power_draw_kwh'] as int? ?? 0;
    final nextLevel = level + 1;
    final nextConfig = levels.where((l) => l['level'] == nextLevel).firstOrNull;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MFColors.neonCyan.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💧', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Water Purifier Mk$level', style: MFTextStyles.labelLarge),
                    Text(
                      '+${output}m³/wk passive  ·  ${currentPowerDraw == 0 ? '0 KWh' : '$currentPowerDraw KWh'}',
                      style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonCyan),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (nextConfig != null) ...[
            const Divider(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upgrade to Mk$nextLevel', style: MFTextStyles.bodyLarge),
                      Text(
                        '+${nextConfig['output_water_per_week']}m³/wk  ·  '
                            '${nextConfig['cost_metals']} metals'
                            '${(nextConfig['cost_glass'] as int? ?? 0) > 0 ? '  ·  ${nextConfig['cost_glass']} glass' : ''}'
                            '  ·  ${nextConfig['power_draw_kwh']} KWh',
                        style: MFTextStyles.bodySmall,
                      ),
                      if (!_hasPowerFor(game, (nextConfig['power_draw_kwh'] as int? ?? 0) - currentPowerDraw))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Need ${(nextConfig['power_draw_kwh'] as int? ?? 0) - currentPowerDraw - game.powerSurplus} more KWh spare',
                            style: MFTextStyles.bodySmall.copyWith(
                                color: MFColors.neonPink, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ),
                _MiniButton(
                  label: 'UPGRADE',
                  color: MFColors.neonCyan,
                  canAfford: game.resources.metals >= (nextConfig['cost_metals'] as int? ?? 0) &&
                      game.resources.glass >= (nextConfig['cost_glass'] as int? ?? 0) &&
                      _hasPowerFor(game, (nextConfig['power_draw_kwh'] as int? ?? 0) - currentPowerDraw),
                  onTap: () {
                    final powerDelta = (nextConfig['power_draw_kwh'] as int? ?? 0) - currentPowerDraw;
                    if (!_hasPowerFor(game, powerDelta)) {
                      _powerSnack(context, powerDelta, game.powerSurplus);
                      return;
                    }
                    _upgrade(context, nextConfig);
                  },
                ),
              ],
            ),
          ] else ...[
            const Divider(height: 12),
            Text('Maximum level reached.',
                style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonGreen)),
          ],
        ],
      ),
    );
  }

  void _upgrade(BuildContext context, Map<String, dynamic> cfg) {
    final metalCost = cfg['cost_metals'] as int? ?? 0;
    final glassCost = cfg['cost_glass'] as int? ?? 0;
    if (game.resources.metals < metalCost || game.resources.glass < glassCost) return;
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        waterPurifierLevel: game.waterPurifierLevel + 1,
        resources: game.resources.copyWith(
          metals: game.resources.metals - metalCost,
          glass: game.resources.glass - glassCost,
        ),
      ),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('💧 Water Purifier upgraded to Mk${game.waterPurifierLevel + 1}!'),
      )),
    );
  }
}

// ─── Machine Card (installed) ─────────────────────────────────────────────────

class _MachineCard extends StatelessWidget {
  final RefineryMachine machine;
  final GameState game;
  final WidgetRef ref;
  final Refinery refinery;

  const _MachineCard({
    required this.machine, required this.game,
    required this.ref, required this.refinery,
  });

  Color get _borderColor {
    return switch (machine.type) {
      MachineType.composter         => const Color(0xFF66BB6A),
      MachineType.smelter           => const Color(0xFFFF7043),
      MachineType.zSoilProcessor    => const Color(0xFF8D6E63),
      MachineType.glassFurnace      => const Color(0xFFAB47BC),
      MachineType.componentFabricator => const Color(0xFFEC407A),
    };
  }

  Color get _bgColor => _borderColor.withValues(alpha: 0.06);

  @override
  Widget build(BuildContext context) {
    final upgrades = UpgradeConfigService.instance;
    final levelCfg = upgrades.getMachineLevel(machine.yamlKey, machine.level);
    if (levelCfg == null) return const SizedBox();

    final recipeIn = Map<String, dynamic>.from(levelCfg['recipe_in'] as Map? ?? {});
    final recipeOut = Map<String, dynamic>.from(levelCfg['recipe_out'] as Map? ?? {});
    final maxLevel = upgrades.machineMaxLevel(machine.yamlKey);
    final nextLevel = machine.level + 1;
    final nextCfg = nextLevel <= maxLevel
        ? upgrades.getMachineLevel(machine.yamlKey, nextLevel)
        : null;

    // How many crafts can the player afford? (for showing 5/10 buttons)
    final maxCrafts = _maxAffordableCrafts(recipeIn);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(machine.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${machine.name} Mk${machine.level}',
                        style: MFTextStyles.labelLarge),
                    Text('${levelCfg['power_draw_kwh']} KWh',
                        style: MFTextStyles.bodySmall),
                  ],
                ),
              ),
              if (machine.level >= 10) ...[
                GestureDetector(
                  onTap: () => _toggleAutoRefine(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: machine.autoRefine
                          ? MFColors.neonGreen.withValues(alpha: 0.15)
                          : MFColors.borderSubtle,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: machine.autoRefine
                            ? MFColors.neonGreen
                            : MFColors.borderSubtle,
                      ),
                    ),
                    child: Text(
                      machine.autoRefine ? '🔁 AUTO ON' : '🔁 AUTO OFF',
                      style: MFTextStyles.bodySmall.copyWith(
                        color: machine.autoRefine
                            ? MFColors.neonGreen
                            : MFColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
              // Upgrade button
              if (nextCfg != null)
                _MiniButton(
                  label: 'MK$nextLevel↑',
                  color: MFColors.neonCyan,
                  canAfford: _canAffordUpgrade(nextCfg) &&
                      _hasPowerFor(game, (nextCfg['power_draw_kwh'] as int? ?? 0) - machine.powerDraw),
                  onTap: () {
                    final powerDelta = (nextCfg['power_draw_kwh'] as int? ?? 0) - machine.powerDraw;
                    if (!_hasPowerFor(game, powerDelta)) {
                      _powerSnack(context, powerDelta, game.powerSurplus);
                      return;
                    }
                    _upgrade(context, nextCfg, nextLevel);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Recipe display
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MFColors.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IN (×1)', style: MFTextStyles.bodySmall.copyWith(
                          color: MFColors.neonOrange, fontSize: 9, letterSpacing: 1)),
                      ...recipeIn.entries.map((e) {
                        final needed = (e.value as num).toInt();
                        final have = _getHave(e.key);
                        return Text(
                          '$needed ${e.key.replaceAll('_', ' ')} (have ${have.toInt()})',
                          style: MFTextStyles.bodySmall.copyWith(
                            color: have >= needed ? MFColors.textSecondary : MFColors.neonPink,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Text('→', style: MFTextStyles.labelLarge.copyWith(color: MFColors.neonOrange)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('OUT (×1)', style: MFTextStyles.bodySmall.copyWith(
                          color: MFColors.neonGreen, fontSize: 9, letterSpacing: 1)),
                      ...recipeOut.entries.map((e) => Text(
                        '${(e.value as num).toInt()} ${e.key.replaceAll('_', ' ')}',
                        style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonGreen),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Craft buttons: 1 / 10 / ALL (ALL unlocks at Mk8+)
          Row(
            children: [
              _CraftButton(
                count: 1,
                enabled: maxCrafts >= 1,
                onTap: () => _craft(context, recipeIn, recipeOut, 1),
              ),
              if (maxCrafts >= 10) ...[
                const SizedBox(width: 6),
                _CraftButton(
                  count: 10,
                  enabled: true,
                  onTap: () => _craft(context, recipeIn, recipeOut, 10),
                ),
              ],
              if (machine.level >= 8 && maxCrafts >= 1) ...[
                const SizedBox(width: 6),
                _SmeltAllButton(
                  maxCrafts: maxCrafts,
                  onTap: () => _craft(context, recipeIn, recipeOut, maxCrafts),
                ),
              ],
            ],
          ),

          // Upgrade cost hint
          if (nextCfg != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Mk$nextLevel: ${_costLine(nextCfg['upgrade_cost'] as Map? ?? {})}  ·  ${nextCfg['power_draw_kwh']} KWh',
                style: MFTextStyles.bodySmall.copyWith(color: MFColors.textMuted, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  String _costLine(Map cost) => cost.entries
      .map((e) => '${e.value} ${e.key.toString().replaceAll('_', ' ')}')
      .join(', ');

  double _getHave(String resource) {
    final r = game.resources;
    return switch (resource) {
      'compost' => r.compost,
      'ore' => r.ore,
      'moon_dirt' => r.moonDirt,
      'chemicals' => r.chemicals,
      'water' => r.water,
      'sand' => r.sand,
      'metals' => r.metals,
      'glass' => r.glass,
      'components' => r.components,
      'chitin' => r.chitin,
      _ => 0,
    };
  }

  int _maxAffordableCrafts(Map<String, dynamic> recipeIn) {
    int maxN = 999;
    for (final e in recipeIn.entries) {
      final needed = (e.value as num).toDouble();
      if (needed <= 0) continue;
      final have = _getHave(e.key);
      final n = (have / needed).floor();
      if (n < maxN) maxN = n;
    }
    return maxN.clamp(0, 999);
  }

  bool _canAffordUpgrade(Map<String, dynamic> cfg) {
    final cost = cfg['upgrade_cost'] as Map? ?? {};
    for (final e in cost.entries) {
      final needed = (e.value as num).toDouble();
      final key = e.key.toString();
      double have = _getHave(key);
      if (have < needed) return false;
    }
    return true;
  }

  void _toggleAutoRefine(BuildContext context) {
    final updatedMachine = machine.copyWith(autoRefine: !machine.autoRefine);
    final updatedMachines = refinery.machines
        .map((m) => m.type == machine.type ? updatedMachine : m)
        .toList();
    final updatedRefineries = game.refineries
        .map((r) => r.id == refinery.id ? r.copyWith(machines: updatedMachines) : r)
        .toList();
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(refineries: updatedRefineries),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text(updatedMachine.autoRefine
            ? '🔁 Auto-Refine enabled for ${machine.name}'
            : '🔁 Auto-Refine disabled for ${machine.name}'),
      ),
          duration: const Duration(seconds: 2)),
    );
  }

  void _craft(BuildContext context, Map<String, dynamic> recipeIn,
      Map<String, dynamic> recipeOut, int times) {
    var r = game.resources;
    for (final e in recipeIn.entries) {
      final amt = (e.value as num).toDouble() * times;
      r = _subtract(r, e.key, amt);
    }
    for (final e in recipeOut.entries) {
      final amt = (e.value as num).toDouble() * times;
      r = _add(r, e.key, amt);
    }
    ref.read(activeGameProvider.notifier).updateGameLocal(game.copyWith(resources: r));

    final out = recipeOut.entries
        .map((e) => '+${((e.value as num).toDouble() * times).toInt()} ${e.key.replaceAll('_', ' ')}')
        .join(', ');
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('${machine.emoji} ×$times → $out'),
      ),
          duration: const Duration(seconds: 1)),
    );
  }

  Resources _subtract(Resources r, String key, double amt) {
    return switch (key) {
      'compost' => r.copyWith(compost: r.compost - amt),
      'ore' => r.copyWith(ore: r.ore - amt),
      'moon_dirt' => r.copyWith(moonDirt: r.moonDirt - amt),
      'chemicals' => r.copyWith(chemicals: r.chemicals - amt),
      'water' => r.copyWith(water: r.water - amt),
      'sand' => r.copyWith(sand: r.sand - amt),
      'metals' => r.copyWith(metals: r.metals - amt),
      'glass' => r.copyWith(glass: r.glass - amt),
      'components' => r.copyWith(components: r.components - amt),
      _ => r,
    };
  }

  Resources _add(Resources r, String key, double amt) {
    return switch (key) {
      'z_soil' => r.copyWith(zSoil: r.zSoil + amt),
      'metals' => r.copyWith(metals: r.metals + amt),
      'glass' => r.copyWith(glass: r.glass + amt),
      'components' => r.copyWith(components: r.components + amt),
      'compost' => r.copyWith(compost: r.compost + amt),
      _ => r,
    };
  }

  void _upgrade(BuildContext context, Map<String, dynamic> cfg, int newLevel) {
    if (!_canAffordUpgrade(cfg)) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            child: Text('Not enough resources.'),
          )));
      return;
    }
    var r = game.resources;
    final cost = cfg['upgrade_cost'] as Map? ?? {};
    for (final e in cost.entries) {
      final amt = (e.value as num).toDouble();
      final key = e.key.toString();
      r = key == 'chitin' ? r.copyWith(ore: r.ore - amt) : _subtract(r, key, amt);
    }

    final updatedMachines = refinery.machines.map((m) {
      return m.type == machine.type
          ? m.copyWith(level: newLevel, powerDraw: cfg['power_draw_kwh'] as int)
          : m;
    }).toList();

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        refineries: [refinery.copyWith(machines: updatedMachines)],
        resources: r,
      ),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('${machine.emoji} ${machine.name} upgraded to Mk$newLevel!'),
      )),
    );
  }
}

// ─── Build Machine Card ───────────────────────────────────────────────────────

class _BuildMachineCard extends StatelessWidget {
  final MachineType type;
  final GameState game;
  final WidgetRef ref;
  final Refinery? refinery;

  const _BuildMachineCard({
    required this.type, required this.game,
    required this.ref, required this.refinery,
  });

  @override
  Widget build(BuildContext context) {
    final upgrades = UpgradeConfigService.instance;
    final display = RefineryMachine(type: type, level: 1, powerDraw: 1);
    final level1 = upgrades.getMachineLevel(display.yamlKey, 1);
    if (level1 == null) return const SizedBox();

    final buildCost = Map<String, dynamic>.from(level1['build_cost'] as Map? ?? {});
    final canAfford = _canAfford(buildCost);
    final recipeIn = Map<String, dynamic>.from(level1['recipe_in'] as Map? ?? {});
    final recipeOut = Map<String, dynamic>.from(level1['recipe_out'] as Map? ?? {});

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _borderColorForType(type).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColorForType(type).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Opacity(opacity: 0.5,
                  child: Text(display.emoji, style: const TextStyle(fontSize: 22))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${display.name} (not built)',
                        style: MFTextStyles.labelLarge.copyWith(color: MFColors.textSecondary)),
                    Text(
                      'Makes ${recipeOut.keys.map((k) => k.replaceAll('_', ' ')).join(', ')}'
                          '${recipeIn.isNotEmpty ? ' from ${recipeIn.keys.map((k) => k.replaceAll('_', ' ')).join(', ')}' : ''}',
                      style: MFTextStyles.bodySmall.copyWith(color: MFColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Build cost: ${_costLine(buildCost)}  ·  ${level1['power_draw_kwh']} KWh',
                  style: MFTextStyles.bodySmall.copyWith(
                    color: canAfford ? MFColors.textSecondary : MFColors.neonPink,
                  ),
                ),
              ),
              _MiniButton(
                label: 'BUILD Mk1',
                color: MFColors.neonGreen,
                canAfford: canAfford &&
                    _hasPowerFor(game, level1['power_draw_kwh'] as int? ?? 0),
                onTap: () {
                  final powerNeeded = level1['power_draw_kwh'] as int? ?? 0;
                  if (!_hasPowerFor(game, powerNeeded)) {
                    _powerSnack(context, powerNeeded, game.powerSurplus);
                    return;
                  }
                  _build(context, buildCost, powerNeeded);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _costLine(Map cost) => cost.isEmpty
      ? 'free'
      : cost.entries.map((e) => '${e.value} ${e.key.toString().replaceAll('_', ' ')}').join(', ');

  bool _canAfford(Map<String, dynamic> cost) {
    for (final e in cost.entries) {
      final needed = (e.value as num).toDouble();
      final key = e.key.toString();
      double have = _getHave(key);
      if (have < needed) return false;
    }
    return true;
  }

  double _getHave(String resource) {
    final r = game.resources;
    return switch (resource) {
      'compost' => r.compost, 'ore' => r.ore, 'moon_dirt' => r.moonDirt,
      'chemicals' => r.chemicals, 'water' => r.water, 'sand' => r.sand,
      'metals' => r.metals, 'glass' => r.glass, 'components' => r.components,
      'chitin' => r.chitin,
      _ => 0,
    };
  }

  Color _borderColorForType(MachineType t) => switch (t) {
    MachineType.composter          => const Color(0xFF66BB6A),
    MachineType.smelter            => const Color(0xFFFF7043),
    MachineType.zSoilProcessor     => const Color(0xFF8D6E63),
    MachineType.glassFurnace       => const Color(0xFFAB47BC),
    MachineType.componentFabricator => const Color(0xFFEC407A),
  };

  void _build(BuildContext context, Map<String, dynamic> cost, int powerDraw) {
    if (!_canAfford(cost) || refinery == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            child: Text('Not enough resources.'),
          )));
      return;
    }
    var r = game.resources;
    for (final e in cost.entries) {
      final amt = (e.value as num).toDouble();
      final key = e.key.toString();
      r = switch (key) {
        'compost' => r.copyWith(compost: r.compost - amt),
        'ore' => r.copyWith(ore: r.ore - amt),
        'moon_dirt' => r.copyWith(moonDirt: r.moonDirt - amt),
        'chemicals' => r.copyWith(chemicals: r.chemicals - amt),
        'water' => r.copyWith(water: r.water - amt),
        'sand' => r.copyWith(sand: r.sand - amt),
        'metals' => r.copyWith(metals: r.metals - amt),
        'glass' => r.copyWith(glass: r.glass - amt),
        'components' => r.copyWith(components: r.components - amt),
        'chitin' => r.copyWith(ore: r.ore - amt),
        _ => r,
      };
    }

    final newMachine = RefineryMachine(type: type, level: 1, powerDraw: powerDraw);
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        refineries: [refinery!.copyWith(machines: [...refinery!.machines, newMachine])],
        resources: r,
      ),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('${newMachine.emoji} ${newMachine.name} built!'),
      )),
    );
  }
}

// ─── Shared Buttons ───────────────────────────────────────────────────────────

class _CraftButton extends StatelessWidget {
  final int count;
  final bool enabled;
  final VoidCallback onTap;

  const _CraftButton({required this.count, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: enabled
                ? MFColors.neonOrange.withValues(alpha: 0.15)
                : MFColors.borderSubtle,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled
                  ? MFColors.neonOrange.withValues(alpha: 0.5)
                  : MFColors.borderSubtle,
            ),
          ),
          child: Text(
            'CRAFT $count',
            textAlign: TextAlign.center,
            style: MFTextStyles.labelLarge.copyWith(
              color: enabled ? MFColors.neonOrange : MFColors.textMuted,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmeltAllButton extends StatelessWidget {
  final int maxCrafts;
  final VoidCallback onTap;

  const _SmeltAllButton({required this.maxCrafts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                MFColors.neonOrange.withValues(alpha: 0.3),
                MFColors.neonOrange.withValues(alpha: 0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: MFColors.neonOrange),
          ),
          child: Text(
            'SMELT ALL ($maxCrafts)',
            textAlign: TextAlign.center,
            style: MFTextStyles.labelLarge.copyWith(
              color: MFColors.neonOrange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool canAfford;
  final VoidCallback onTap;

  const _MiniButton({
    required this.label, required this.color,
    required this.canAfford, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canAfford ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: canAfford ? color.withValues(alpha: 0.12) : MFColors.borderSubtle,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: canAfford ? color.withValues(alpha: 0.5) : MFColors.borderSubtle,
          ),
        ),
        child: Text(label,
            style: MFTextStyles.bodySmall.copyWith(
              color: canAfford ? color : MFColors.textMuted,
              fontWeight: FontWeight.bold, fontSize: 11,
            )),
      ),
    );
  }
}