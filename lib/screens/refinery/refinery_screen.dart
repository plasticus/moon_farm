// ═══════════════════════════════════════════════════════════════
//  lib/screens/refinery/refinery_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/game_config_service.dart';

class RefineryScreen extends ConsumerWidget {
  const RefineryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(activeGameProvider).value;
    if (game == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Water Purifier ───────────────────────────────────────────────
        _WaterPurifierCard(game: game, ref: ref),
        const SizedBox(height: 16),

        // ── Refinery upgrade ─────────────────────────────────────────
        _RefineryUpgradeCard(game: game, ref: ref),
        const SizedBox(height: 16),

        // ── Recipes ──────────────────────────────────────────────────────
        Text(
          'RECIPES',
          style: MFTextStyles.bodySmall.copyWith(
            color: MFColors.textMuted,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        ..._buildRecipes(context, game, ref),
      ],
    );
  }

  List<Widget> _buildRecipes(
      BuildContext context,
      GameState game,
      WidgetRef ref,
      ) {
    final config = GameConfigService.instance;
    final allRecipes = config.getAllRecipes();

    // Get all unlocked recipes across all refineries
    final unlockedIds = game.refineries
        .expand((r) => r.unlockedRecipes)
        .toSet();

    return allRecipes.map((recipe) {
      final isUnlocked = unlockedIds.contains(recipe['id']);
      return _RecipeCard(
        recipe: recipe,
        game: game,
        isUnlocked: isUnlocked,
        onCraft: isUnlocked
            ? () => _doCraft(context, ref, recipe, game)
            : null,
      );
    }).toList();
  }

  void _doCraft(
      BuildContext context,
      WidgetRef ref,
      Map<String, dynamic> recipe,
      GameState game,
      ) {
    final inputs = recipe['inputs'] as Map<String, dynamic>;
    final outputs = recipe['outputs'] as Map<String, dynamic>;

    // Check resources
    var resources = game.resources;
    for (final entry in inputs.entries) {
      final key = entry.key;
      final required = (entry.value as num).toDouble();
      final available = _getResource(resources, key);
      if (available < required) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough ${key.replaceAll('_', ' ')}. '
                  'Need ${required.toInt()}, have ${available.toInt()}.',
            ),
          ),
        );
        return;
      }
    }

    // Deduct inputs
    for (final entry in inputs.entries) {
      final amount = (entry.value as num).toDouble();
      resources = _subtractResource(resources, entry.key, amount);
    }

    // Add outputs
    for (final entry in outputs.entries) {
      final amount = (entry.value as num).toDouble();
      resources = _addResource(resources, entry.key, amount);
    }

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(resources: resources),
    );

    final recipeName = recipe['name'] as String;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('⚗️ $recipeName complete!')),
    );
  }

  double _getResource(Resources r, String key) {
    switch (key) {
      case 'moon_dirt': return r.moonDirt;
      case 'chemicals': return r.chemicals;
      case 'water': return r.water;
      case 'compost': return r.compost;
      case 'z_soil': return r.zSoil;
      case 'metals': return r.metals;
      case 'sand': return r.sand;
      case 'glass': return r.glass;
      case 'components': return r.components;
      case 'ore': return r.ore;
      default: return 0;
    }
  }

  Resources _subtractResource(Resources r, String key, double amount) {
    switch (key) {
      case 'moon_dirt': return r.copyWith(moonDirt: r.moonDirt - amount);
      case 'chemicals': return r.copyWith(chemicals: r.chemicals - amount);
      case 'water': return r.copyWith(water: r.water - amount);
      case 'compost': return r.copyWith(compost: r.compost - amount);
      case 'z_soil': return r.copyWith(zSoil: r.zSoil - amount);
      case 'metals': return r.copyWith(metals: r.metals - amount);
      case 'sand': return r.copyWith(sand: r.sand - amount);
      case 'glass': return r.copyWith(glass: r.glass - amount);
      case 'components': return r.copyWith(components: r.components - amount);
      case 'ore': return r.copyWith(ore: r.ore - amount);
      default: return r;
    }
  }

  Resources _addResource(Resources r, String key, double amount) {
    switch (key) {
      case 'moon_dirt': return r.copyWith(moonDirt: r.moonDirt + amount);
      case 'chemicals': return r.copyWith(chemicals: r.chemicals + amount);
      case 'water': return r.copyWith(water: r.water + amount);
      case 'compost': return r.copyWith(compost: r.compost + amount);
      case 'z_soil': return r.copyWith(zSoil: r.zSoil + amount);
      case 'metals': return r.copyWith(metals: r.metals + amount);
      case 'sand': return r.copyWith(sand: r.sand + amount);
      case 'glass': return r.copyWith(glass: r.glass + amount);
      case 'components': return r.copyWith(components: r.components + amount);
      case 'ore': return r.copyWith(ore: r.ore + amount);
      default: return r;
    }
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
    final currentLevel = game.waterPurifierLevel;
    final currentOutput = config.getWaterOutputForLevel(currentLevel);
    final levels = config.getWaterPurifierLevels();
    final nextLevel = currentLevel + 1;
    final nextConfig = levels.where((l) => l['level'] == nextLevel).firstOrNull;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: currentLevel > 0
              ? MFColors.neonCyan.withValues(alpha: 0.4)
              : MFColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💧', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Water Purifier Mk$currentLevel',
                      style: MFTextStyles.labelLarge,
                    ),
                    Text(
                      '+${currentOutput}m³/wk output',
                      style: MFTextStyles.bodySmall.copyWith(
                        color: MFColors.neonCyan,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (nextConfig != null) ...[
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to Mk$nextLevel',
                        style: MFTextStyles.bodyLarge,
                      ),
                      Text(
                        '+${nextConfig['output_water_per_week']}L/wk  ·  '
                            '${nextConfig['cost_scrip']} 🎫  ·  '
                            '${nextConfig['cost_metals']} metals',
                        style: MFTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _UpgradeButton(
                  canAfford: game.resources.starScrip >=
                      (nextConfig['cost_scrip'] as int) &&
                      game.resources.metals >=
                          (nextConfig['cost_metals'] as int),
                  onTap: () => _doUpgrade(context, nextConfig, game),
                ),
              ],
            ),
          ] else if (currentLevel > 0) ...[
            const Divider(height: 12),
            Text(
              'Maximum level reached.',
              style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonGreen),
            ),
          ],
        ],
      ),
    );
  }

  void _doUpgrade(
      BuildContext context,
      Map<String, dynamic> levelConfig,
      GameState game,
      ) {
    final cost = levelConfig['cost_scrip'] as int;
    final metalCost = levelConfig['cost_metals'] as int;
    final powerDraw = levelConfig['power_draw_kwh'] as int;

    if (game.resources.starScrip < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough Star-Scrip.')),
      );
      return;
    }
    if (game.resources.metals < metalCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough metals.')),
      );
      return;
    }
    if (game.powerSurplus < powerDraw) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Not enough power. Need $powerDraw KWh more capacity.',
          ),
        ),
      );
      return;
    }

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        waterPurifierLevel: game.waterPurifierLevel + 1,
        resources: game.resources.copyWith(
          starScrip: game.resources.starScrip - cost,
          metals: game.resources.metals - metalCost,
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '💧 Water Purifier upgraded to Mk${game.waterPurifierLevel + 1}!',
        ),
      ),
    );
  }
}

// ─── Refinery Upgrade Card ────────────────────────────────────────────────────

class _RefineryUpgradeCard extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;

  const _RefineryUpgradeCard({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final currentTier = game.refineries.isEmpty ? 0 : game.refineries.first.tier;
    final nextTier = currentTier + 1;

    // Check if next tier exists
    Map<String, dynamic>? nextConfig;
    try {
      nextConfig = config.getRefineryTier(nextTier);
    } catch (_) {
      nextConfig = null;
    }

    final tierNames = {1: 'Basic', 2: 'Standard', 3: 'Industrial'};
    final currentName = tierNames[currentTier] ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MFColors.neonCyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚗️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$currentName Refinery', style: MFTextStyles.labelLarge),
                    Text(
                      'Tier $currentTier  ·  ${game.refineries.isEmpty ? 0 : game.refineries.first.unlockedRecipes.length} recipes unlocked',
                      style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonCyan),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (nextConfig != null) ...[
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to ${tierNames[nextTier] ?? 'Tier $nextTier'} Refinery',
                        style: MFTextStyles.bodyLarge,
                      ),
                      Text(
                        '${nextConfig['cost_solars'] ?? nextConfig['cost_scrip'] ?? 0} 🎫  ·  '
                            '${nextConfig['cost_metals'] ?? 0} metals  ·  '
                            'unlocks ${(nextConfig['unlocked_recipes'] as List).length} recipes',
                        style: MFTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _UpgradeButton(
                  canAfford: _canAffordUpgrade(game, nextConfig),
                  onTap: () => _doUpgrade(context, nextConfig!, game),
                ),
              ],
            ),
          ] else ...[
            const Divider(height: 12),
            Text(
              'Maximum tier reached.',
              style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonGreen),
            ),
          ],
        ],
      ),
    );
  }

  bool _canAffordUpgrade(GameState game, Map<String, dynamic> nextConfig) {
    final cost = nextConfig['cost_solars'] as int? ?? nextConfig['cost_scrip'] as int? ?? 0;
    final metalCost = nextConfig['cost_metals'] as int? ?? 0;
    return game.resources.starScrip >= cost && game.resources.metals >= metalCost;
  }

  void _doUpgrade(
      BuildContext context,
      Map<String, dynamic> nextConfig,
      GameState game,
      ) {
    final cost = nextConfig['cost_solars'] as int? ?? nextConfig['cost_scrip'] as int? ?? 0;
    final metalCost = nextConfig['cost_metals'] as int? ?? 0;
    final nextTier = (nextConfig['tier'] as int);
    final powerDraw = nextConfig['power_draw_kwh'] as int;

    if (!_canAffordUpgrade(game, nextConfig)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough resources.')),
      );
      return;
    }
    if (game.powerSurplus < powerDraw) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Need $powerDraw more KWh capacity.')),
      );
      return;
    }

    final updatedRefinery = game.refineries.isEmpty
        ? Refinery(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tier: nextTier,
      powerDraw: powerDraw,
      unlockedRecipes: List<String>.from(nextConfig['unlocked_recipes'] as List),
    )
        : game.refineries.first.copyWith(
      tier: nextTier,
      powerDraw: powerDraw,
      unlockedRecipes: List<String>.from(nextConfig['unlocked_recipes'] as List),
    );

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(
        refineries: [updatedRefinery],
        resources: game.resources.copyWith(
          starScrip: game.resources.starScrip - cost,
          metals: game.resources.metals - metalCost,
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('⚗️ Refinery upgraded to Tier $nextTier!')),
    );
  }
}


// ─── Recipe Card ──────────────────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final GameState game;
  final bool isUnlocked;
  final VoidCallback? onCraft;

  const _RecipeCard({
    required this.recipe,
    required this.game,
    required this.isUnlocked,
    this.onCraft,
  });

  bool _canAfford(GameState game) {
    final inputs = recipe['inputs'] as Map<String, dynamic>;
    final r = game.resources;
    for (final entry in inputs.entries) {
      final required = (entry.value as num).toDouble();
      double available = 0;
      switch (entry.key) {
        case 'moon_dirt': available = r.moonDirt;
        case 'chemicals': available = r.chemicals;
        case 'water': available = r.water;
        case 'compost': available = r.compost;
        case 'ore': available = r.ore;
        case 'sand': available = r.sand;
      }
      if (available < required) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final canAfford = isUnlocked && _canAfford(game);
    final inputs = recipe['inputs'] as Map<String, dynamic>;
    final outputs = recipe['outputs'] as Map<String, dynamic>;
    final emoji = recipe['emoji'] as String? ?? '⚗️';
    final name = recipe['name'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: !isUnlocked
              ? MFColors.borderSubtle
              : canAfford
              ? MFColors.neonCyan.withValues(alpha: 0.3)
              : MFColors.borderDefault,
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: MFTextStyles.labelLarge),
                const SizedBox(height: 4),
                // Inputs
                Text(
                  'IN: ${inputs.entries.map((e) => '${(e.value as num).toInt()} ${e.key.replaceAll('_', ' ')}').join(', ')}',
                  style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonOrange),
                ),
                // Outputs
                Text(
                  'OUT: ${outputs.entries.map((e) => '${(e.value as num).toInt()} ${e.key.replaceAll('_', ' ')}').join(', ')}',
                  style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonGreen),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isUnlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: MFColors.textMuted.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'UPGRADE REFINERY',
                style: MFTextStyles.bodySmall.copyWith(
                  color: MFColors.textMuted, fontSize: 9,
                ),
              ),
            )
          else
            _UpgradeButton(
              canAfford: canAfford,
              label: 'CRAFT',
              onTap: onCraft,
            ),
        ],
      ),
    );
  }
}

// ─── Upgrade Button ───────────────────────────────────────────────────────────

class _UpgradeButton extends StatelessWidget {
  final bool canAfford;
  final String label;
  final VoidCallback? onTap;

  const _UpgradeButton({
    required this.canAfford,
    this.label = 'UPGRADE',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canAfford ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        child: Text(
          label,
          style: MFTextStyles.bodySmall.copyWith(
            color: canAfford ? MFColors.neonCyan : MFColors.textMuted,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}