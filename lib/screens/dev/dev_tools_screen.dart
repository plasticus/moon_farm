// ═══════════════════════════════════════════════════════════════
//  lib/screens/dev/dev_tools_screen.dart
// ═══════════════════════════════════════════════════════════════
//
// Hidden dev panel. Access: long-press the farm name in the app bar.
// Only useful during development — does not affect release builds
// in any breaking way, but should be removed before publishing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/game_factory.dart';
import '../../database/database_helper.dart';

class DevToolsScreen extends ConsumerWidget {
  const DevToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(activeGameProvider).value;
    if (game == null) return const SizedBox();

    return Scaffold(
      backgroundColor: MFColors.background,
      appBar: AppBar(
        title: const Text('⚙️ DEV TOOLS'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: MFColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Warning banner
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: MFColors.neonPink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: MFColors.neonPink.withValues(alpha: 0.5)),
            ),
            child: Text(
              '⚠️ DEV ONLY — Remove before publishing',
              style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonPink),
              textAlign: TextAlign.center,
            ),
          ),

          // Current state summary
          _DevSection(
            title: 'CURRENT STATE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DevStat('Farm', game.farmName),
                _DevStat('Week', '${game.currentWeek}'),
                _DevStat('Difficulty', game.difficulty.name),
                _DevStat('Star-Scrip', '${game.resources.starScrip}'),
                _DevStat('Seeds', '${game.resources.seeds}'),
                _DevStat('Z Soil', '${game.resources.zSoil.toInt()}'),
                _DevStat('Water', '${game.resources.water.toInt()}'),
                _DevStat('Compost', '${game.resources.compost.toInt()}'),
                _DevStat('Moss', '${game.resources.moss.toInt()}'),
                _DevStat('Mycoculture', '${game.resources.mycoculture.toInt()}'),
                _DevStat('Metals', '${game.resources.metals.toInt()}'),
                _DevStat('Volume Delivered', '${game.totalVolumeDeliveredM3.toStringAsFixed(1)}m³'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Resource injectors
          _DevSection(
            title: 'INJECT RESOURCES',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DevButton('+500 🎫', MFColors.starScrip, () => _addResources(ref, game, scrip: 500)),
                _DevButton('+5000 🎫', MFColors.starScrip, () => _addResources(ref, game, scrip: 5000)),
                _DevButton('+20 Seeds', MFColors.neonGreen, () => _addResources(ref, game, seeds: 20)),
                _DevButton('+20 Z Soil', MFColors.neonGreen, () => _addResources(ref, game, zSoil: 20)),
                _DevButton('+50 Water', MFColors.neonCyan, () => _addResources(ref, game, water: 50)),
                _DevButton('+20 Compost', MFColors.neonGreen, () => _addResources(ref, game, compost: 20)),
                _DevButton('+20 Metals', MFColors.neonOrange, () => _addResources(ref, game, metals: 20)),
                _DevButton('+20 Chemicals', MFColors.neonPurple, () => _addResources(ref, game, chemicals: 20)),
                _DevButton('+20 Sand', MFColors.neonYellow, () => _addResources(ref, game, sand: 20)),
                _DevButton('+20 Glass', MFColors.statusFlawless, () => _addResources(ref, game, glass: 20)),
                _DevButton('+20 Components', MFColors.neonPurple, () => _addResources(ref, game, components: 20)),
                _DevButton('+20 Ore', MFColors.textSecondary, () => _addResources(ref, game, ore: 20)),
                _DevButton('+20 Moon Dirt', MFColors.textSecondary, () => _addResources(ref, game, moonDirt: 20)),
                _DevButton('+50 Chitin', MFColors.textPrimary, () => _addResources(ref, game, chitin: 50)),
                _DevButton('+20 Meat', MFColors.neonPink, () => _addResources(ref, game, meat: 20)),
                _DevButton('+20 Moss', MFColors.neonGreen, () => _addResources(ref, game, moss: 20)),
                _DevButton('+20 Mycoculture', MFColors.neonPurple, () => _addResources(ref, game, mycoculture: 20)),
                _DevButton('FILL ALL', MFColors.neonCyan, () => _fillAll(ref, game)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Week manipulation
          _DevSection(
            title: 'TIME CONTROL',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DevButton('+1 Week', MFColors.neonYellow, () => _addWeeks(ref, game, 1)),
                _DevButton('+5 Weeks', MFColors.neonYellow, () => _addWeeks(ref, game, 5)),
                _DevButton('+10 Weeks', MFColors.neonYellow, () => _addWeeks(ref, game, 10)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Feature unlocks — skips the normal discovery trigger (e.g. growing
          // an 8-week Hyper-Mycelium crop) for quick testing.
          _DevSection(
            title: 'FEATURE UNLOCKS',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DevButton(
                  game.unlockedFeatures.contains('mycoculture_vat')
                      ? '✅ Mycoculture Vat'
                      : 'Unlock Mycoculture Vat',
                  MFColors.neonPurple,
                  () => _unlockFeature(ref, game, 'mycoculture_vat'),
                ),
                _DevButton(
                  game.unlockedFeatures.contains('mycovault_reactor')
                      ? '✅ Mycovault Reactor'
                      : 'Unlock Mycovault Reactor',
                  MFColors.neonCyan,
                  () => _unlockFeature(ref, game, 'mycovault_reactor'),
                ),
                _DevButton(
                  '+10 Hyper-Mycelium (silo)',
                  MFColors.neonPink,
                  () => _addSilo(ref, game, 'hyper_mycelium', 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pre-built scenarios — skip hours of real playthrough to reach
          // a specific testing state. Loaded into a save slot, not the
          // active session — back out to the main menu to play it.
          _DevSection(
            title: 'DEV PRESETS',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DevButton(
                  'Load Dev75 → Slot 3',
                  MFColors.neonOrange,
                  () => _loadDev75Preset(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Kovacs mood (0-100 scale)
          _DevSection(
            title: 'KOVACS MOOD (currently ${game.relay.mood})',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DevButton('-10 Mood', MFColors.neonPink, () => _adjustMood(ref, game, -10)),
                _DevButton('+10 Mood', MFColors.neonGreen, () => _adjustMood(ref, game, 10)),
                _DevButton('Set to 0', MFColors.neonPink, () => _setMood(ref, game, 0)),
                _DevButton('Set to 50', MFColors.textSecondary, () => _setMood(ref, game, 50)),
                _DevButton('Set to 100', MFColors.neonGreen, () => _setMood(ref, game, 100)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dome tools
          _DevSection(
            title: 'DOME TOOLS',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DevButton('Harvest All Ready', MFColors.neonGreen, () => _harvestAll(ref, game)),
                _DevButton('Water All Crops', MFColors.neonCyan, () => _waterAll(ref, game)),
                _DevButton('Clear All Dead', MFColors.neonPink, () => _clearDead(ref, game)),
                _DevButton('Grow All +1 Week', MFColors.neonGreen, () => _growAll(ref, game)),
                _DevButton('Ripen All Crops', MFColors.neonGreen, () => _ripenAll(ref, game)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Danger zone
          _DevSection(
            title: 'DANGER ZONE',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DevButton(
                  'Kill All Crops 💀',
                  MFColors.neonPink,
                      () => _killAll(ref, game),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Resource helpers ─────────────────────────────────────────────────────

  void _addResources(
      WidgetRef ref,
      GameState game, {
        int scrip = 0,
        int seeds = 0,
        double zSoil = 0,
        double water = 0,
        double compost = 0,
        double metals = 0,
        double chemicals = 0,
        double sand = 0,
        double glass = 0,
        double components = 0,
        double ore = 0,
        double moonDirt = 0,
        double chitin = 0,
        double meat = 0,
        double moss = 0,
        double mycoculture = 0,
      }) {
    final updated = game.copyWith(
      resources: game.resources.copyWith(
        starScrip: game.resources.starScrip + scrip,
        seeds: game.resources.seeds + seeds,
        zSoil: game.resources.zSoil + zSoil,
        water: game.resources.water + water,
        compost: game.resources.compost + compost,
        metals: game.resources.metals + metals,
        chemicals: game.resources.chemicals + chemicals,
        sand: game.resources.sand + sand,
        glass: game.resources.glass + glass,
        components: game.resources.components + components,
        ore: game.resources.ore + ore,
        moonDirt: game.resources.moonDirt + moonDirt,
        chitin: game.resources.chitin + chitin,
        meat: game.resources.meat + meat,
        moss: game.resources.moss + moss,
        mycoculture: game.resources.mycoculture + mycoculture,
      ),
    );
    ref.read(activeGameProvider.notifier).updateGameLocal(updated);
  }

  void _fillAll(WidgetRef ref, GameState game) {
    _addResources(
      ref, game,
      scrip: 10000, seeds: 50, zSoil: 50, water: 200,
      compost: 50, metals: 100, chemicals: 50, sand: 50,
      glass: 50, components: 50, ore: 50, moonDirt: 100,
      chitin: 50, meat: 20, moss: 50, mycoculture: 20,
    );
  }

  void _adjustMood(WidgetRef ref, GameState game, int delta) {
    final newMood = (game.relay.mood + delta).clamp(0, 100);
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(relay: game.relay.copyWith(mood: newMood)),
    );
  }

  void _setMood(WidgetRef ref, GameState game, int value) {
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(relay: game.relay.copyWith(mood: value.clamp(0, 100))),
    );
  }

  void _addWeeks(WidgetRef ref, GameState game, int weeks) {
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(currentWeek: game.currentWeek + weeks),
    );
  }

  void _unlockFeature(WidgetRef ref, GameState game, String key) {
    if (game.unlockedFeatures.contains(key)) return;
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(unlockedFeatures: [...game.unlockedFeatures, key]),
    );
  }

  Future<void> _loadDev75Preset(BuildContext context, WidgetRef ref) async {
    final preset = GameFactory.createDev75Preset(slotNumber: 3);
    final db = DatabaseHelper.instance;
    await db.ensureSlotExists(3);
    await db.saveGameState(preset);
    // saveGameState writes straight to the DB — the main menu's save-slot
    // list is a cached AsyncNotifierProvider that has no way to know that
    // happened, so without this it'll keep showing Slot 3 as it looked
    // before this write (usually empty) until something else happens to
    // refresh it.
    await ref.read(saveSlotsProvider.notifier).refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        child: const Text('Dev75 preset saved to Slot 3. Back out to the main menu to load it.'),
      ), duration: const Duration(seconds: 4)),
    );
  }

  void _addSilo(WidgetRef ref, GameState game, String cropId, double amount) {
    final updated = Map<String, double>.from(game.siloInventory);
    updated[cropId] = (updated[cropId] ?? 0) + amount;
    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(siloInventory: updated),
    );
  }

  void _harvestAll(WidgetRef ref, GameState game) {
    final updatedDomes = game.domes.map((dome) {
      final updatedCells = dome.cells.map((cell) {
        if (cell.state == CropState.ready) return cell.cleared();
        return cell;
      }).toList();
      return dome.copyWith(cells: updatedCells);
    }).toList();

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(domes: updatedDomes),
    );
  }

  void _waterAll(WidgetRef ref, GameState game) {
    final updatedDomes = game.domes.map((dome) {
      final updatedCells = dome.cells.map((cell) {
        if (cell.state == CropState.growing) {
          return cell.copyWith(wateredThisWeek: true);
        }
        return cell;
      }).toList();
      return dome.copyWith(cells: updatedCells);
    }).toList();

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(domes: updatedDomes),
    );
  }

  void _clearDead(WidgetRef ref, GameState game) {
    final updatedDomes = game.domes.map((dome) {
      final updatedCells = dome.cells.map((cell) {
        if (cell.state == CropState.dead) return cell.cleared();
        return cell;
      }).toList();
      return dome.copyWith(cells: updatedCells);
    }).toList();

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(domes: updatedDomes),
    );
  }

  void _growAll(WidgetRef ref, GameState game) {
    final updatedDomes = game.domes.map((dome) {
      final updatedCells = dome.cells.map((cell) {
        if (cell.state == CropState.growing) {
          return cell.copyWith(weeksGrown: cell.weeksGrown + 1);
        }
        return cell;
      }).toList();
      return dome.copyWith(cells: updatedCells);
    }).toList();

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(domes: updatedDomes),
    );
  }

  void _ripenAll(WidgetRef ref, GameState game) {
    final updatedDomes = game.domes.map((dome) {
      final updatedCells = dome.cells.map((cell) {
        if (cell.state == CropState.growing) {
          return cell.copyWith(state: CropState.ready);
        }
        return cell;
      }).toList();
      return dome.copyWith(cells: updatedCells);
    }).toList();

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(domes: updatedDomes),
    );
  }

  void _killAll(WidgetRef ref, GameState game) {
    final updatedDomes = game.domes.map((dome) {
      final updatedCells = dome.cells.map((cell) {
        if (cell.state == CropState.growing || cell.state == CropState.ready) {
          return cell.copyWith(state: CropState.dead);
        }
        return cell;
      }).toList();
      return dome.copyWith(cells: updatedCells);
    }).toList();

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(domes: updatedDomes),
    );
  }

}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _DevSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DevSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MFColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MFTextStyles.bodySmall.copyWith(
              color: MFColors.textMuted,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DevButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DevButton(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: MFTextStyles.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _DevStat extends StatelessWidget {
  final String label;
  final String value;

  const _DevStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: MFTextStyles.bodySmall),
          Text(value, style: MFTextStyles.bodySmall.copyWith(
            color: MFColors.neonCyan,
            fontWeight: FontWeight.bold,
          )),
        ],
      ),
    );
  }
}
