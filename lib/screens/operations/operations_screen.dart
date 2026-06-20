// ═══════════════════════════════════════════════════════════════
//  lib/screens/operations/operations_screen.dart
// ═══════════════════════════════════════════════════════════════
// Power grid and scavenger drones.
// Sentries moved to Habitat. Dome bots handled here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/game_config_service.dart';
import '../../config/upgrade_config_service.dart';
import '../../utils/game_factory.dart';

/// Returns true if the game has enough spare power to add [additionalDraw] kW.
/// Power never shuts anything off — this only gates NEW construction.
bool _hasPowerFor(GameState game, int additionalDraw) {
  if (additionalDraw <= 0) return true;
  return game.powerSurplus >= additionalDraw;
}

/// Shows a brief "not enough power" message at the bottom of the screen.
void _powerSnack(BuildContext context, int needed, int surplus) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('⚡ Not enough power. Needs $needed kW, only $surplus kW spare. Build more power first.'),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

void _missingSnack(BuildContext context, List<String> missingParts) {
  if (missingParts.isEmpty) return;
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('Need: ${missingParts.join(', ')}'),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

class OperationsScreen extends ConsumerWidget {
  const OperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(activeGameProvider).value;
    if (game == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PowerSection(game: game, ref: ref),
        const SizedBox(height: 16),
        _DroneSection(game: game, ref: ref),
        const SizedBox(height: 16),
        _DomeBuildSection(game: game, ref: ref),
        const SizedBox(height: 16),
        _DomeBotSection(game: game, ref: ref),
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
    final reactorUnlocked = game.unlockedFeatures.contains('mycovault_reactor');
    final buildablePower = Map<String, dynamic>.fromEntries(
      powerBuildings.entries.where((e) => e.key != 'mycovault_reactor' || reactorUnlocked),
    );
    final surplus = game.powerSurplus;
    final surplusColor = surplus >= 0 ? MFColors.neonGreen : MFColors.neonPink;

    // Group power sources by type
    final grouped = <PowerSourceType, int>{};
    final outputByType = <PowerSourceType, int>{};
    for (final p in game.powerSources) {
      grouped[p.type] = (grouped[p.type] ?? 0) + 1;
      outputByType[p.type] = (outputByType[p.type] ?? 0) + p.outputKwh;
    }
    // Fixed display order — solar always listed first.
    const displayOrder = [
      PowerSourceType.solarArray,
      PowerSourceType.windTurbine,
      PowerSourceType.geothermalTap,
      PowerSourceType.mycovaultReactor,
    ];
    final sortedGrouped = grouped.entries.toList()
      ..sort((a, b) => displayOrder.indexOf(a.key).compareTo(displayOrder.indexOf(b.key)));

    return _OpsCard(
      icon: '⚡',
      title: 'POWER GRID',
      subtitle: '${game.totalPowerProduction} kW produced  ·  '
          '${game.totalPowerDraw} kW drawn  ·  '
          '${surplus >= 0 ? '+' : ''}$surplus kW',
      subtitleColor: surplusColor,
      children: [
        // Grouped existing sources
        if (grouped.isNotEmpty) ...[
          ...sortedGrouped.map((entry) {
            final count = entry.value;
            final output = outputByType[entry.key] ?? 0;
            final source = game.powerSources
                .firstWhere((p) => p.type == entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(source.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      count > 1
                          ? '${source.name} (×$count)'
                          : source.name,
                      style: MFTextStyles.bodyLarge,
                    ),
                  ),
                  Text('+$output kW',
                      style: MFTextStyles.labelLarge
                          .copyWith(color: MFColors.neonGreen)),
                ],
              ),
            );
          }),
          const Divider(height: 14),
        ],

        // Build options
        Text('BUILD POWER SOURCE',
            style: MFTextStyles.bodySmall.copyWith(
                color: MFColors.textMuted, letterSpacing: 2, fontSize: 9)),
        const SizedBox(height: 8),
        ...buildablePower.entries.map((entry) {
          final b = entry.value as Map<String, dynamic>;
          // Count how many of this type the player already owns
          final typeKey = entry.key;
          final ownedCount = game.powerSources.where((p) {
            return switch (typeKey) {
              'solar_array'    => p.type == PowerSourceType.solarArray,
              'wind_turbine'   => p.type == PowerSourceType.windTurbine,
              'geothermal_tap' => p.type == PowerSourceType.geothermalTap,
              'mycovault_reactor' => p.type == PowerSourceType.mycovaultReactor,
              _ => false,
            };
          }).length;
          // 1.5x multiplier per owned unit of this type
          final multiplier = ownedCount == 0 ? 1.0 : (1.5 * ownedCount);
          final baseScrip = b['cost_scrip'] as int? ?? 0;
          final costScrip = (baseScrip * multiplier).round();
          final costMetals = b['cost_metals'] as int? ?? 0;
          final costGlass = b['cost_glass'] as int? ?? 0;
          final costComponents = b['cost_components'] as int? ?? 0;
          final costMycoculture = b['cost_mycoculture'] as int? ?? 0;

          final canAfford = game.resources.starScrip >= costScrip &&
              game.resources.metals >= costMetals &&
              game.resources.glass >= costGlass &&
              game.resources.components >= costComponents &&
              game.resources.mycoculture >= costMycoculture;

          final costParts = <String>[];
          if (costScrip > 0) costParts.add('$costScrip 🎫');
          if (costMetals > 0) costParts.add('$costMetals metals');
          if (costGlass > 0) costParts.add('$costGlass glass');
          if (costComponents > 0) costParts.add('$costComponents comp');
          if (costMycoculture > 0) costParts.add('$costMycoculture culture');

          final missing = <String>[];
          if (game.resources.starScrip < costScrip)
            missing.add('${costScrip - game.resources.starScrip} more 🎫');
          if (game.resources.metals < costMetals)
            missing.add('${costMetals - game.resources.metals.toInt()} more metals');
          if (game.resources.glass < costGlass)
            missing.add('${costGlass - game.resources.glass.toInt()} more glass');
          if (game.resources.components < costComponents)
            missing.add('${costComponents - game.resources.components.toInt()} more comp');
          if (game.resources.mycoculture < costMycoculture)
            missing.add('${costMycoculture - game.resources.mycoculture.toInt()} more culture');

          // Show existing count
          final existingLabel = ownedCount > 0 ? '  (own $ownedCount)' : '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BuildRow(
              emoji: b['emoji'] as String,
              name: '${b['name'] as String}$existingLabel',
              description: b['description'] as String,
              costLine: costParts.join('  ·  '),
              outputLine: '+${b['power_output_kwh']} kW',
              outputColor: MFColors.neonGreen,
              canAfford: canAfford,
              missingText: missing.isEmpty ? '' : 'Need: ${missing.join(', ')}',
              onBuild: () => _buildPower(context, entry.key, b, game,
                  scripCost: costScrip),
            ),
          );
        }),
      ],
    );
  }


  void _buildPower(BuildContext context, String key, Map<String, dynamic> b,
      GameState game, {int? scripCost}) {
    final type = switch (key) {
      'solar_array'    => PowerSourceType.solarArray,
      'wind_turbine'   => PowerSourceType.windTurbine,
      'geothermal_tap' => PowerSourceType.geothermalTap,
      'mycovault_reactor' => PowerSourceType.mycovaultReactor,
      _ => PowerSourceType.solarArray,
    };
    final newSource = PowerSource(
      id: '${key}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      outputKwh: b['power_output_kwh'] as int,
    );
    final actualScripCost = scripCost ?? (b['cost_scrip'] as int? ?? 0);
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        powerSources: [...game.powerSources, newSource],
        resources: game.resources.copyWith(
          starScrip: game.resources.starScrip - actualScripCost,
          metals: game.resources.metals - (b['cost_metals'] as int? ?? 0),
          glass: game.resources.glass - (b['cost_glass'] as int? ?? 0),
          components: game.resources.components - (b['cost_components'] as int? ?? 0),
          mycoculture: game.resources.mycoculture - (b['cost_mycoculture'] as int? ?? 0),
        ),
      ),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('${b['emoji']} ${b['name']} built! +${b['power_output_kwh']} kW'),
      )),
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
    final droneTiers = (opsBuildings['mining_drone']?['tiers'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    final drones = game.miningDrones;
    final balanced = drones.where((d) => d.isBalanced).length;
    final dirtCount = drones.where((d) => d.assignedResource == 'moon_dirt').length;
    final oreCount = drones.where((d) => d.assignedResource == 'ore').length;
    final sandCount = drones.where((d) => d.assignedResource == 'sand').length;
    final chemCount = drones.where((d) => d.assignedResource == 'chemicals').length;

    // Output per week summary
    double totalOutput = drones.fold(0.0, (sum, d) => sum + d.outputPerWeek);

    return _OpsCard(
      icon: '⛏️',
      title: 'SCAVENGER DRONES',
      subtitle: '${drones.length} drones  ·  '
          '${totalOutput.toStringAsFixed(1)} units/wk total',
      subtitleColor: MFColors.textSecondary,
      children: [
        // Current assignment summary
        if (drones.isNotEmpty) ...[
          GestureDetector(
            onTap: () => _showAssignmentDialog(context, game),
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
                      Text('ASSIGNMENTS',
                          style: MFTextStyles.bodySmall.copyWith(
                              color: MFColors.textMuted, letterSpacing: 1, fontSize: 9)),
                      Text('TAP TO REASSIGN',
                          style: MFTextStyles.bodySmall.copyWith(
                              color: MFColors.neonCyan, fontSize: 9)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _AssignChip('⚖️', '$balanced', 'Balanced', MFColors.neonCyan),
                      const SizedBox(width: 8),
                      _AssignChip('🌑', '$dirtCount', 'Dirt', MFColors.textSecondary),
                      const SizedBox(width: 8),
                      _AssignChip('🪨', '$oreCount', 'Ore', MFColors.neonOrange),
                      const SizedBox(width: 8),
                      _AssignChip('🏖️', '$sandCount', 'Sand', MFColors.neonYellow),
                      const SizedBox(width: 8),
                      _AssignChip('⚗️', '$chemCount', 'Chem', MFColors.neonPurple),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Upgrade button if any Mk1/Mk2 drones exist
          if (drones.any((d) => d.tier < 3)) ...[
            const SizedBox(height: 8),
            _UpgradeDroneButton(game: game, ref: ref, droneTiers: droneTiers),
          ],
          const Divider(height: 14),
        ],

        // Build new drone tiers
        Text('BUILD DRONES',
            style: MFTextStyles.bodySmall.copyWith(
                color: MFColors.textMuted, letterSpacing: 2, fontSize: 9)),
        const SizedBox(height: 8),
        ...droneTiers.map((tier) {
          final costMetals = tier['cost_metals'] as int;
          final costComponents = tier['cost_components'] as int? ?? 0;
          final powerNeeded = tier['power_draw_kwh'] as int;
          final hasPower = _hasPowerFor(game, powerNeeded);
          final canAfford = game.resources.metals >= costMetals &&
              game.resources.components >= costComponents &&
              hasPower;

          final costParts = ['$costMetals metals'];
          if (costComponents > 0) costParts.add('$costComponents comp');

          final missing = <String>[];
          if (game.resources.metals < costMetals)
            missing.add('${costMetals - game.resources.metals.toInt()} more metals');
          if (game.resources.components < costComponents)
            missing.add('${costComponents - game.resources.components.toInt()} more comp');
          if (!hasPower)
            missing.add('${powerNeeded - game.powerSurplus} more kW spare power');

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BuildRow(
              emoji: tier['emoji'] as String,
              name: tier['name'] as String,
              description: '${tier['output_per_week']}/wk  ·  ${tier['power_draw_kwh']} kW',
              costLine: costParts.join('  ·  '),
              outputLine: 'Mk${tier['tier']}',
              outputColor: MFColors.neonOrange,
              canAfford: canAfford,
              missingText: missing.isEmpty ? '' : 'Need: ${missing.join(', ')}',
              onBuild: () => _buildDrone(context, tier, game),
            ),
          );
        }),
      ],
    );
  }

  void _buildDrone(BuildContext context, Map<String, dynamic> tier, GameState game) {
    final powerNeeded = tier['power_draw_kwh'] as int;
    if (!_hasPowerFor(game, powerNeeded)) {
      _powerSnack(context, powerNeeded, game.powerSurplus);
      return;
    }
    final newDrone = MiningDrone(
      id: 'drone_${DateTime.now().millisecondsSinceEpoch}',
      tier: tier['tier'] as int,
      assignedResource: null, // balanced by default
      outputPerWeek: (tier['output_per_week'] as num).toDouble(),
      powerDraw: tier['power_draw_kwh'] as int,
    );

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        miningDrones: [...game.miningDrones, newDrone],
        resources: game.resources.copyWith(
          metals: game.resources.metals - (tier['cost_metals'] as int),
          components: game.resources.components - (tier['cost_components'] as int? ?? 0),
        ),
      ),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('🤖 ${tier['name']} built!'),
      )),
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

class _UpgradeDroneButton extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;
  final List<Map<String, dynamic>> droneTiers;

  const _UpgradeDroneButton({
    required this.game, required this.ref, required this.droneTiers,
  });

  @override
  Widget build(BuildContext context) {
    // Find lowest tier drone to upgrade
    final toUpgrade = game.miningDrones
        .where((d) => d.tier < 3)
        .toList()
      ..sort((a, b) => a.tier.compareTo(b.tier));

    if (toUpgrade.isEmpty) return const SizedBox();

    final drone = toUpgrade.first;
    final nextTier = drone.tier + 1;
    final nextConfig = droneTiers.where((t) => t['tier'] == nextTier).firstOrNull;
    if (nextConfig == null) return const SizedBox();

    final costMetals = nextConfig['cost_metals'] as int;
    final costComponents = nextConfig['cost_components'] as int? ?? 0;
    // Upgrading changes power draw — gate on the DELTA only.
    final powerDelta = (nextConfig['power_draw_kwh'] as int) - drone.powerDraw;
    final hasPower = _hasPowerFor(game, powerDelta);
    final canAfford = game.resources.metals >= costMetals &&
        game.resources.components >= costComponents &&
        hasPower;

    return GestureDetector(
      onTap: canAfford
          ? () => _doUpgrade(context, drone, nextConfig)
          : () {
        if (!hasPower) {
          _powerSnack(context, powerDelta, game.powerSurplus);
          return;
        }
        final missing = <String>[];
        if (game.resources.metals < costMetals) {
          missing.add('${(costMetals - game.resources.metals).toInt()} more metals');
        }
        if (game.resources.components < costComponents) {
          missing.add('${(costComponents - game.resources.components).toInt()} more comp');
        }
        _missingSnack(context, missing);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: canAfford
              ? MFColors.neonCyan.withValues(alpha: 0.1)
              : MFColors.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: canAfford
                ? MFColors.neonCyan.withValues(alpha: 0.5)
                : MFColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Upgrade 1 Mk${drone.tier} → Mk$nextTier  ·  $costMetals metals'
                    '${costComponents > 0 ? '  ·  $costComponents comp' : ''}',
                style: MFTextStyles.bodySmall.copyWith(
                  color: canAfford ? MFColors.neonCyan : MFColors.textMuted,
                ),
              ),
            ),
            Text('MK$nextTier↑',
                style: MFTextStyles.bodySmall.copyWith(
                  color: canAfford ? MFColors.neonCyan : MFColors.textMuted,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
      ),
    );
  }

  void _doUpgrade(BuildContext context, MiningDrone drone,
      Map<String, dynamic> nextConfig) {
    final idx = game.miningDrones.indexWhere((d) => d.id == drone.id);
    if (idx < 0) return;

    final upgraded = drone.copyWith(
      tier: nextConfig['tier'] as int,
      outputPerWeek: (nextConfig['output_per_week'] as num).toDouble(),
      powerDraw: nextConfig['power_draw_kwh'] as int,
    );

    final updatedDrones = List<MiningDrone>.from(game.miningDrones);
    updatedDrones[idx] = upgraded;

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        miningDrones: updatedDrones,
        resources: game.resources.copyWith(
          metals: game.resources.metals - (nextConfig['cost_metals'] as int),
          components: game.resources.components - (nextConfig['cost_components'] as int? ?? 0),
        ),
      ),
    );

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('🤖 Drone upgraded to Mk${nextConfig['tier']}!'),
      )),
    );
  }
}

// ─── Drone Assignment Sheet ───────────────────────────────────────────────────

class _DroneAssignmentSheetState extends State<_DroneAssignmentSheet> {
  int _selectedTier = 1;
  // Assignments stored per tier: {tier: {resource: count}}
  late Map<int, Map<String, int>> _assignmentsByTier;

  @override
  void initState() {
    super.initState();
    _assignmentsByTier = {};
    final tiers = widget.game.miningDrones.map((d) => d.tier).toSet();
    for (final tier in tiers) {
      final tierDrones = widget.game.miningDrones.where((d) => d.tier == tier).toList();
      _assignmentsByTier[tier] = {
        'balanced':  tierDrones.where((d) => d.isBalanced).length,
        'moon_dirt': tierDrones.where((d) => d.assignedResource == 'moon_dirt').length,
        'ore':       tierDrones.where((d) => d.assignedResource == 'ore').length,
        'sand':      tierDrones.where((d) => d.assignedResource == 'sand').length,
        'chemicals': tierDrones.where((d) => d.assignedResource == 'chemicals').length,
      };
    }
    // Default selected tier to lowest available
    if (tiers.isNotEmpty) _selectedTier = tiers.reduce((a, b) => a < b ? a : b);
  }

  List<int> get availableTiers =>
      widget.game.miningDrones.map((d) => d.tier).toSet().toList()..sort();

  int totalForTier(int tier) =>
      widget.game.miningDrones.where((d) => d.tier == tier).length;

  int assignedForTier(int tier) =>
      (_assignmentsByTier[tier] ?? {}).values.fold(0, (a, b) => a + b);

  void _apply() {
    final drones = List<MiningDrone>.from(widget.game.miningDrones);
    // Apply assignments tier by tier
    for (final tier in availableTiers) {
      final assignments = _assignmentsByTier[tier] ?? {};
      final tierIndices = drones.asMap().entries
          .where((e) => e.value.tier == tier)
          .map((e) => e.key)
          .toList();
      int idx = 0;
      for (final entry in assignments.entries) {
        for (int i = 0; i < entry.value && idx < tierIndices.length; i++, idx++) {
          drones[tierIndices[idx]] = drones[tierIndices[idx]].copyWith(
            assignedResource: entry.key == 'balanced' ? null : entry.key,
          );
        }
      }
    }
    widget.ref.read(activeGameProvider.notifier).updateGameLocal(
      widget.game.copyWith(miningDrones: drones),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tiers = availableTiers;
    final assignments = _assignmentsByTier[_selectedTier] ?? {};
    final total = totalForTier(_selectedTier);
    final assigned = assignedForTier(_selectedTier);

    final options = [
      ('balanced',  '⚖️', 'Balanced'),
      ('moon_dirt', '🌑', 'Moon Dirt'),
      ('ore',       '🪨', 'Ore'),
      ('sand',      '🏖️', 'Sand'),
      ('chemicals', '⚗️', 'Chemicals'),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tier toggle
          if (tiers.length > 1) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: tiers.map((t) {
                final isActive = t == _selectedTier;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTier = t),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? MFColors.neonCyan.withValues(alpha: 0.2)
                          : MFColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive ? MFColors.neonCyan : MFColors.borderSubtle,
                      ),
                    ),
                    child: Text('Mk$t',
                        style: MFTextStyles.labelLarge.copyWith(
                          color: isActive ? MFColors.neonCyan : MFColors.textMuted,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          Text('ASSIGN $total Mk$_selectedTier DRONES',
              style: MFTextStyles.labelLarge.copyWith(letterSpacing: 1)),
          const SizedBox(height: 4),
          Text('Balanced splits output evenly across all 4 resources.',
              style: MFTextStyles.bodySmall.copyWith(color: MFColors.textMuted)),
          const SizedBox(height: 12),
          ...options.map((opt) {
            final (key, emoji, label) = opt;
            final count = assignments[key] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(label, style: MFTextStyles.bodyLarge)),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: MFColors.neonPink),
                    onPressed: count > 0
                        ? () => setState(() {
                      _assignmentsByTier[_selectedTier]![key] = count - 1;
                    })
                        : null,
                  ),
                  Text('$count', style: MFTextStyles.labelLarge),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: MFColors.neonGreen),
                    onPressed: assigned < total
                        ? () => setState(() {
                      _assignmentsByTier[_selectedTier]![key] =
                          (assignments[key] ?? 0) + 1;
                    })
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

class _DroneAssignmentSheet extends StatefulWidget {
  final GameState game;
  final WidgetRef ref;
  const _DroneAssignmentSheet({required this.game, required this.ref});

  @override
  State<_DroneAssignmentSheet> createState() => _DroneAssignmentSheetState();
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _OpsCard extends StatelessWidget {
  final String icon, title, subtitle;
  final Color subtitleColor;
  final List<Widget> children;

  const _OpsCard({
    required this.icon, required this.title, required this.subtitle,
    required this.subtitleColor, required this.children,
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
                        style: MFTextStyles.bodySmall.copyWith(color: subtitleColor)),
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

class _AssignChip extends StatelessWidget {
  final String emoji, count, label;
  final Color color;
  const _AssignChip(this.emoji, this.count, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        Text(count,
            style: MFTextStyles.labelLarge.copyWith(color: color, fontSize: 12)),
        Text(label, style: MFTextStyles.bodySmall.copyWith(fontSize: 8)),
      ],
    );
  }
}

class _BuildRow extends StatelessWidget {
  final String emoji, name, description, costLine, outputLine, missingText;
  final Color outputColor;
  final bool canAfford;
  final VoidCallback onBuild;

  const _BuildRow({
    required this.emoji, required this.name, required this.description,
    required this.costLine, required this.outputLine, required this.outputColor,
    required this.canAfford, required this.missingText, required this.onBuild,
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
                  Flexible(
                    child: Text(name, style: MFTextStyles.bodyLarge,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  Text(outputLine,
                      style: MFTextStyles.bodySmall.copyWith(
                          color: outputColor, fontWeight: FontWeight.bold)),
                ],
              ),
              Text(description,
                  style: MFTextStyles.bodySmall.copyWith(color: MFColors.textMuted),
                  overflow: TextOverflow.ellipsis, maxLines: 2),
              Text(
                canAfford ? costLine : missingText.isNotEmpty ? missingText : costLine,
                style: MFTextStyles.bodySmall.copyWith(
                  color: canAfford ? MFColors.textSecondary : MFColors.neonPink,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: canAfford ? onBuild : () => _showMissing(context),
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

  void _showMissing(BuildContext context) {
    if (missingText.isEmpty) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          child: Text(missingText),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ─── Dome Bot Section ─────────────────────────────────────────────────────────

class _DomeBotSection extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;
  const _DomeBotSection({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final botLevels = config.getDomeBotLevels();

    return _OpsCard(
      icon: '🤖',
      title: 'DOME BOTS',
      subtitle: '${game.domes.where((d) => d.domeBot != null).length} / ${game.domes.length} domes automated',
      subtitleColor: MFColors.textSecondary,
      children: [
        ...game.domes.asMap().entries.map((entry) {
          final dome = entry.value;
          final bot = dome.domeBot;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MFColors.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: bot != null
                    ? MFColors.neonCyan.withValues(alpha: 0.3)
                    : MFColors.borderSubtle,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(bot != null ? '🤖' : '○',
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dome.name, style: MFTextStyles.labelLarge),
                          Text(
                            bot != null
                                ? 'Dome Bot Mk${bot.level}  ·  ${_botActions(bot)}'
                                : 'No bot installed',
                            style: MFTextStyles.bodySmall.copyWith(
                              color: bot != null
                                  ? MFColors.neonCyan
                                  : MFColors.textMuted,
                            ),
                          ),
                          if (bot?.canPlant == true)
                            Text(
                              'Planting: ${bot!.plantCropId?.replaceAll('_', ' ') ?? 'not set — tap to configure'}',
                              style: MFTextStyles.bodySmall.copyWith(
                                color: bot.plantCropId != null
                                    ? MFColors.neonGreen
                                    : MFColors.neonOrange,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (bot != null)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _showBotOptions(context, dome, bot, botLevels),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: MFColors.neonCyan.withValues(alpha: 0.4)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('MANAGE',
                                  style: MFTextStyles.bodySmall.copyWith(
                                      color: MFColors.neonCyan, fontSize: 10)),
                            ),
                          ),
                          if (bot.canPlant && bot.plantCropId != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              GameConfigService.instance.getCrop(bot.plantCropId!)?.emoji ?? '🌱',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),

                // Install / Upgrade button
                if (bot == null) ...[
                  const SizedBox(height: 8),
                  _buildInstallButton(context, dome, botLevels),
                ] else if (bot.level < 4) ...[
                  const SizedBox(height: 8),
                  _buildUpgradeButton(context, dome, bot, botLevels),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  String _botActions(DomeBot bot) {
    final parts = <String>[];
    if (bot.canWater) parts.add('waters');
    if (bot.canHarvest) parts.add('harvests');
    if (bot.canFertilize) parts.add('fertilizes');
    if (bot.canPlant) parts.add('plants');
    return parts.join(' · ');
  }

  Widget _buildInstallButton(
      BuildContext context, Dome dome, List<Map<String, dynamic>> botLevels) {
    if (botLevels.isEmpty) return const SizedBox();
    final mk1 = botLevels.first;
    final buildCost = (mk1['build_cost'] as Map?)?.cast<String, dynamic>() ?? {};
    final costMetals = buildCost['metals'] as int? ?? mk1['cost_metals'] as int? ?? 0;
    final powerNeeded = mk1['power_draw_kwh'] as int? ?? 2;
    final hasPower = _hasPowerFor(game, powerNeeded);
    final canAfford = game.resources.metals >= costMetals && hasPower;

    return GestureDetector(
      onTap: canAfford
          ? () => _installBot(context, dome, mk1)
          : () {
        if (!hasPower) _powerSnack(context, powerNeeded, game.powerSurplus);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: canAfford
              ? MFColors.neonCyan.withValues(alpha: 0.1)
              : MFColors.borderSubtle,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: canAfford
                ? MFColors.neonCyan.withValues(alpha: 0.4)
                : MFColors.borderSubtle,
          ),
        ),
        child: Center(
          child: Text(
            !hasPower
                ? 'Need ${powerNeeded - game.powerSurplus} more kW spare'
                : canAfford
                ? 'INSTALL Mk1  ·  $costMetals metals'
                : 'Need $costMetals metals',
            style: MFTextStyles.bodySmall.copyWith(
              color: canAfford ? MFColors.neonCyan : MFColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpgradeButton(BuildContext context, Dome dome, DomeBot bot,
      List<Map<String, dynamic>> botLevels) {
    final nextLevel = bot.level + 1;
    final nextConfig =
        botLevels.where((l) => l['level'] == nextLevel).firstOrNull;
    if (nextConfig == null) {
      // Max level — show MAX badge
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: MFColors.neonOrange.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: MFColors.neonOrange.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Text('✦ FULLY UPGRADED',
              style: MFTextStyles.bodySmall.copyWith(
                  color: MFColors.neonOrange, fontWeight: FontWeight.bold)),
        ),
      );
    }

    final costMetals = nextConfig['cost_metals'] as int? ??
        (nextConfig['upgrade_cost'] as Map?)?['metals'] as int? ?? 0;
    final costComponents = nextConfig['cost_components'] as int? ??
        (nextConfig['upgrade_cost'] as Map?)?['components'] as int? ?? 0;
    final costChemicals = nextConfig['cost_chemicals'] as int? ??
        (nextConfig['upgrade_cost'] as Map?)?['chemicals'] as int? ?? 0;
    final costChitin = (nextConfig['upgrade_cost'] as Map?)?['chitin'] as int? ?? 0;
    final unlockText = nextConfig['unlock_preview'] as String? ?? '';
    final nextUnlockPreview = unlockText.isNotEmpty ? 'Upgrade → $unlockText' : '';

    final hasPower = _hasPowerFor(game,
        (nextConfig['power_draw_kwh'] as int? ?? 0) - bot.powerDraw);
    final canAfford = game.resources.metals >= costMetals &&
        game.resources.components >= costComponents &&
        game.resources.chemicals >= costChemicals &&
        game.resources.chitin >= costChitin &&
        hasPower;

    final costParts = <String>[];
    if (costMetals > 0) costParts.add('$costMetals metals');
    if (costComponents > 0) costParts.add('$costComponents comp');
    if (costChemicals > 0) costParts.add('$costChemicals chem');
    if (costChitin > 0) costParts.add('$costChitin chitin');
    final powerDelta = (nextConfig['power_draw_kwh'] as int? ?? 0) - bot.powerDraw;
    if (powerDelta > 0) costParts.add('+$powerDelta kW');

    return GestureDetector(
      onTap: canAfford
          ? () => _upgradeBot(context, dome, bot, nextConfig)
          : () {
        final missing = <String>[];
        if (game.resources.metals < costMetals) {
          missing.add('${(costMetals - game.resources.metals).toInt()} more metals');
        }
        if (game.resources.components < costComponents) {
          missing.add('${(costComponents - game.resources.components).toInt()} more comp');
        }
        if (game.resources.chemicals < costChemicals) {
          missing.add('${(costChemicals - game.resources.chemicals).toInt()} more chem');
        }
        if (game.resources.chitin < costChitin) {
          missing.add('${(costChitin - game.resources.chitin).toInt()} more chitin');
        }
        if (!hasPower) {
          _powerSnack(context, powerDelta, game.powerSurplus);
          return;
        }
        _missingSnack(context, missing);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: canAfford
              ? MFColors.neonOrange.withValues(alpha: 0.1)
              : MFColors.borderSubtle,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: canAfford
                ? MFColors.neonOrange.withValues(alpha: 0.4)
                : MFColors.borderSubtle,
          ),
        ),
        child: Column(
          children: [
            Text(
              'UPGRADE TO Mk$nextLevel  ·  ${costParts.join('  ·  ')}',
              style: MFTextStyles.bodySmall.copyWith(
                color: canAfford ? MFColors.neonOrange : MFColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (nextUnlockPreview.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                nextUnlockPreview,
                style: MFTextStyles.bodySmall.copyWith(
                  color: canAfford
                      ? MFColors.neonGreen
                      : MFColors.textMuted,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _installBot(BuildContext context, Dome dome,
      Map<String, dynamic> cfg) {
    final buildCost = (cfg['build_cost'] as Map?)?.cast<String, dynamic>() ?? {};
    final costMetals = buildCost['metals'] as int? ?? cfg['cost_metals'] as int? ?? 0;
    final newBot = DomeBot(
      level: 1,
      powerDraw: cfg['power_draw_kwh'] as int,
    );
    _applyBotChange(dome, newBot, costMetals, 0, 0, 0);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('🤖 Dome Bot Mk1 installed in ${dome.name}!'),
      )),
    );
  }

  void _upgradeBot(BuildContext context, Dome dome, DomeBot bot,
      Map<String, dynamic> cfg) {
    final cost = (cfg['upgrade_cost'] as Map?)?.cast<String, dynamic>() ?? {};
    final upgraded = bot.copyWith(
      level: cfg['level'] as int,
      powerDraw: cfg['power_draw_kwh'] as int,
    );
    _applyBotChange(
      dome,
      upgraded,
      cost['metals'] as int? ?? cfg['cost_metals'] as int? ?? 0,
      cost['components'] as int? ?? cfg['cost_components'] as int? ?? 0,
      cost['chemicals'] as int? ?? cfg['cost_chemicals'] as int? ?? 0,
      cost['chitin'] as int? ?? cfg['cost_chitin'] as int? ?? 0,
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            child: Text(
                '🤖 ${dome.name} bot upgraded to Mk${cfg['level']}!'),
          )),
    );
  }

  void _applyBotChange(Dome dome, DomeBot newBot,
      int costMetals, int costComponents, int costChemicals, int costChitin) {
    final updatedDomes = game.domes
        .map((d) => d.id == dome.id ? d.copyWith(domeBot: newBot) : d)
        .toList();
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        domes: updatedDomes,
        resources: game.resources.copyWith(
          metals: game.resources.metals - costMetals,
          components: game.resources.components - costComponents,
          chemicals: game.resources.chemicals - costChemicals,
          chitin: game.resources.chitin - costChitin,
        ),
      ),
    );
  }

  void _showBotOptions(BuildContext context, Dome dome, DomeBot bot,
      List<Map<String, dynamic>> botLevels) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MFColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: MFColors.borderDefault),
      ),
      builder: (_) => _BotConfigSheet(
        dome: dome,
        bot: bot,
        game: game,
        ref: ref,
      ),
    );
  }
}

// ─── Bot Config Sheet ─────────────────────────────────────────────────────────

class _BotConfigSheet extends StatelessWidget {
  final Dome dome;
  final DomeBot bot;
  final GameState game;
  final WidgetRef ref;

  const _BotConfigSheet({
    required this.dome, required this.bot,
    required this.game, required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    // Only show crops matching this dome's tier
    final crops = config.getCropsForDomeTier(dome.tier);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: MFColors.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('${dome.name} — Bot Mk${bot.level}',
                style: MFTextStyles.labelLarge.copyWith(letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(
              bot.canPlant
                  ? 'Choose which crop the bot will auto-plant.'
                  : 'Upgrade to Mk4 to enable auto-planting.',
              style: MFTextStyles.bodySmall.copyWith(color: MFColors.textMuted),
            ),
            const SizedBox(height: 16),
            if (bot.canPlant)
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // "None" option — bot harvests/waters/fertilizes but won't replant
                    Builder(builder: (context) {
                      final isNoneSelected = bot.plantCropId == null;
                      return GestureDetector(
                        onTap: () {
                          final updatedBot = bot.withNoCrop();
                          final updatedDomes = game.domes
                              .map((d) => d.id == dome.id
                              ? d.copyWith(domeBot: updatedBot)
                              : d)
                              .toList();
                          ref.read(activeGameProvider.notifier).updateGameLocal(
                            game.copyWith(domes: updatedDomes),
                          );
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isNoneSelected
                                ? MFColors.neonOrange.withValues(alpha: 0.1)
                                : MFColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isNoneSelected
                                  ? MFColors.neonOrange
                                  : MFColors.borderSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('🚫', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('None',
                                        style: MFTextStyles.bodyLarge),
                                    Text('Bot won\'t auto-plant this dome',
                                        style: MFTextStyles.bodySmall
                                            .copyWith(color: MFColors.textMuted)),
                                  ],
                                ),
                              ),
                              if (isNoneSelected)
                                const Text('✓', style: TextStyle(
                                    color: MFColors.neonOrange, fontSize: 16)),
                            ],
                          ),
                        ),
                      );
                    }),
                    ...crops.map((crop) {
                      final isSelected = bot.plantCropId == crop.id;
                      return GestureDetector(
                        onTap: () {
                          final updatedBot = bot.withCrop(crop.id);
                          final updatedDomes = game.domes
                              .map((d) => d.id == dome.id
                              ? d.copyWith(domeBot: updatedBot)
                              : d)
                              .toList();
                          ref.read(activeGameProvider.notifier).updateGameLocal(
                            game.copyWith(domes: updatedDomes),
                          );
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? MFColors.neonGreen.withValues(alpha: 0.1)
                                : MFColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? MFColors.neonGreen
                                  : MFColors.borderSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(crop.emoji, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(crop.name,
                                  style: MFTextStyles.bodyLarge)),
                              if (isSelected)
                                const Text('✓', style: TextStyle(
                                    color: MFColors.neonGreen, fontSize: 16)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Dome Build Section ───────────────────────────────────────────────────────

class _DomeBuildSection extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;
  const _DomeBuildSection({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final domeCfg = config.getDomeBuildingConfig();
    final matCost = domeCfg['material_cost'] as Map<String, dynamic>? ?? {};
    final glassCost = matCost['glass'] as int? ?? 20;
    final metalsCost = matCost['metals'] as int? ?? 5;
    final componentsCost = matCost['components'] as int? ?? 1;
    final scripCost = config.getNextDomeScripCost(game.difficulty, game.domes.length);
    final newDomePowerDraw = UpgradeConfigService.instance.domeTierPowerDraw(1);

    final canAfford = game.resources.starScrip >= scripCost &&
        game.resources.glass >= glassCost &&
        game.resources.metals >= metalsCost &&
        game.resources.components >= componentsCost &&
        _hasPowerFor(game, newDomePowerDraw);

    final missing = <String>[];
    if (game.resources.starScrip < scripCost)
      missing.add('${scripCost - game.resources.starScrip} more 🎫');
    if (game.resources.glass < glassCost)
      missing.add('${glassCost - game.resources.glass.toInt()} more glass');
    if (game.resources.metals < metalsCost)
      missing.add('${metalsCost - game.resources.metals.toInt()} more metals');
    if (game.resources.components < componentsCost)
      missing.add('${componentsCost - game.resources.components.toInt()} more comp');
    if (!_hasPowerFor(game, newDomePowerDraw))
      missing.add('${newDomePowerDraw - game.powerSurplus} more kW spare');

    return _OpsCard(
      icon: '🏠',
      title: 'DOMES',
      subtitle: '${game.domes.length} domes built',
      subtitleColor: MFColors.textSecondary,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MFColors.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: MFColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Build Dome ${game.domes.length + 1}',
                  style: MFTextStyles.bodyLarge),
              const SizedBox(height: 4),
              Text(
                '$scripCost 🎫  ·  $glassCost glass  ·  $metalsCost metals  ·  $componentsCost comp  ·  $newDomePowerDraw kW',
                style: MFTextStyles.bodySmall.copyWith(
                  color: canAfford ? MFColors.textSecondary : MFColors.neonPink,
                ),
              ),
              Text(
                'Land-rights cost rises with each dome.',
                style: MFTextStyles.bodySmall.copyWith(
                    color: MFColors.textMuted, fontSize: 10),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: canAfford
                      ? () => _buildDome(context, scripCost, glassCost, metalsCost, componentsCost)
                      : () {
                    if (!_hasPowerFor(game, newDomePowerDraw)) {
                      _powerSnack(context, newDomePowerDraw, game.powerSurplus);
                      return;
                    }
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: GestureDetector(
                          onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                          child: Text('Need: ${missing.join(', ')}'),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: canAfford
                          ? MFColors.neonGreen.withValues(alpha: 0.12)
                          : MFColors.borderSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: canAfford
                            ? MFColors.neonGreen.withValues(alpha: 0.5)
                            : MFColors.borderSubtle,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        canAfford ? '🏠 BUILD NEW DOME' : 'INSUFFICIENT RESOURCES',
                        style: MFTextStyles.labelLarge.copyWith(
                          color: canAfford ? MFColors.neonGreen : MFColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Per-dome tier upgrade cards
        if (game.domes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('DOME TIERS',
              style: MFTextStyles.bodySmall.copyWith(
                  color: MFColors.textMuted, letterSpacing: 1, fontSize: 9)),
          const SizedBox(height: 6),
          ...game.domes.map((dome) => _domeTierRow(context, dome)),
        ],
      ],
    );
  }

  Widget _domeTierRow(BuildContext context, Dome dome) {
    final upgrades = UpgradeConfigService.instance;
    final maxTier = upgrades.domeMaxTier;
    final currentDraw = upgrades.domeTierPowerDraw(dome.tier);
    final nextTier = dome.tier + 1;
    final nextCfg = nextTier <= maxTier ? upgrades.getDomeTier(nextTier) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MFColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MFColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${dome.name}  ·  Tier ${dome.tier}',
                    style: MFTextStyles.bodyLarge),
                Text(
                  nextCfg != null
                      ? 'Grows T${dome.tier} crops  ·  $currentDraw kW'
                      : 'Max tier  ·  grows T${dome.tier} crops  ·  $currentDraw kW',
                  style: MFTextStyles.bodySmall.copyWith(color: MFColors.textMuted),
                ),
                if (nextCfg != null)
                  Text(
                    '→ T$nextTier: ${_tierCostLine(nextCfg['upgrade_cost'] as Map? ?? {})}  ·  '
                        '+${(nextCfg['power_draw_kwh'] as int) - currentDraw} kW',
                    style: MFTextStyles.bodySmall.copyWith(
                      color: _canAffordTier(nextCfg) ? MFColors.textSecondary : MFColors.neonPink,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          if (nextCfg != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _canAffordTier(nextCfg)
                  ? () => _upgradeDome(context, dome, nextCfg, nextTier)
                  : () {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                    child: Text('Need: ${_tierMissing(nextCfg)}'),
                  ),
                      duration: const Duration(seconds: 2)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _canAffordTier(nextCfg)
                      ? MFColors.neonCyan.withValues(alpha: 0.12)
                      : MFColors.borderSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _canAffordTier(nextCfg)
                        ? MFColors.neonCyan.withValues(alpha: 0.5)
                        : MFColors.borderSubtle,
                  ),
                ),
                child: Text('T$nextTier↑',
                    style: MFTextStyles.bodySmall.copyWith(
                      color: _canAffordTier(nextCfg) ? MFColors.neonCyan : MFColors.textMuted,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _tierCostLine(Map cost) => cost.entries
      .map((e) => '${e.value} ${e.key.toString().replaceAll('_', ' ')}')
      .join(', ');

  double _haveFor(String key) {
    final r = game.resources;
    return switch (key) {
      'glass' => r.glass,
      'metals' => r.metals,
      'components' => r.components,
      'chitin' => r.chitin,
      'ore' => r.ore,
      'mycoculture' => r.mycoculture,
      _ => 0,
    };
  }

  bool _canAffordTier(Map<String, dynamic> cfg) {
    final cost = cfg['upgrade_cost'] as Map? ?? {};
    for (final e in cost.entries) {
      if (_haveFor(e.key.toString()) < (e.value as num).toDouble()) return false;
    }
    return true;
  }

  String _tierMissing(Map<String, dynamic> cfg) {
    final cost = cfg['upgrade_cost'] as Map? ?? {};
    final parts = <String>[];
    for (final e in cost.entries) {
      final need = (e.value as num).toDouble();
      final have = _haveFor(e.key.toString());
      if (have < need) {
        parts.add('${(need - have).toInt()} more ${e.key.toString().replaceAll('_', ' ')}');
      }
    }
    return parts.join(', ');
  }

  void _upgradeDome(BuildContext context, Dome dome,
      Map<String, dynamic> cfg, int newTier) {
    // Gate on the power delta between current and new tier draw.
    final newDraw = cfg['power_draw_kwh'] as int;
    final powerDelta = newDraw - dome.powerDraw;
    if (!_hasPowerFor(game, powerDelta)) {
      _powerSnack(context, powerDelta, game.powerSurplus);
      return;
    }

    var r = game.resources;
    final cost = cfg['upgrade_cost'] as Map? ?? {};
    for (final e in cost.entries) {
      final amt = (e.value as num).toDouble();
      final key = e.key.toString();
      r = switch (key) {
        'glass' => r.copyWith(glass: r.glass - amt),
        'metals' => r.copyWith(metals: r.metals - amt),
        'components' => r.copyWith(components: r.components - amt),
        'chitin' => r.copyWith(chitin: r.chitin - amt),
        'ore' => r.copyWith(ore: r.ore - amt),
        'mycoculture' => r.copyWith(mycoculture: r.mycoculture - amt),
        _ => r,
      };
    }

    final updatedDomes = game.domes
        .map((d) => d.id == dome.id
        ? d.copyWith(tier: newTier, powerDraw: newDraw)
        : d)
        .toList();

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(domes: updatedDomes, resources: r),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('🏠 ${dome.name} upgraded to Tier $newTier! Now grows T$newTier crops.'),
      )),
    );
  }

  void _buildDome(BuildContext context, int scripCost, int glassCost,
      int metalsCost, int componentsCost) {
    final newDome = GameFactory.createNewDome(
      name: 'Dome ${game.domes.length + 1}',
      tier: 1,
    );

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        domes: [...game.domes, newDome],
        resources: game.resources.copyWith(
          starScrip: game.resources.starScrip - scripCost,
          glass: game.resources.glass - glassCost,
          metals: game.resources.metals - metalsCost,
          components: game.resources.components - componentsCost,
        ),
      ),
    );

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: Text('🏠 Dome ${game.domes.length + 1} built!'),
      )),
    );
  }
}