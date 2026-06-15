// ═══════════════════════════════════════════════════════════════
//  lib/screens/dome/dome_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/game_config_service.dart';

/// Mk-level quality color. Mk1=gray, Mk2=green, Mk3=blue, Mk4=purple, Mk5+=orange
Color mkColor(int level) => switch (level) {
  1 => const Color(0xFF9E9E9E),
  2 => const Color(0xFF66BB6A),
  3 => const Color(0xFF42A5F5),
  4 => const Color(0xFFAB47BC),
  _ => const Color(0xFFFF9800),
};

// ─── Dome Action Enum ─────────────────────────────────────────────────────────

enum DomeAction { water, fertilize, harvest, plant, clearDead }

// ─── Main Dome Screen ─────────────────────────────────────────────────────────

class DomeScreen extends ConsumerStatefulWidget {
  const DomeScreen({super.key});

  @override
  ConsumerState<DomeScreen> createState() => _DomeScreenState();
}

class _DomeScreenState extends ConsumerState<DomeScreen>
    with TickerProviderStateMixin {
  DomeAction? _selectedAction;
  String? _selectedCropId;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _changeDome(int newIndex, int direction) {
    // direction: -1 = swiping left (going to next dome), 1 = swiping right (going to prev)
    final outOffset = Offset(direction * 0.3, 0); // slide out in swipe direction
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: outOffset,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeIn));

    _slideController.forward(from: 0).then((_) {
      ref.read(activeDomeIndexProvider.notifier).state = newIndex;
      // New dome slides in from opposite side
      _slideAnimation = Tween<Offset>(
        begin: Offset(-direction * 0.3, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
      _slideController.forward(from: 0);
    });
  } // for planting

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(activeGameProvider).value;
    if (game == null) return const SizedBox();

    final domeIndex = ref.watch(activeDomeIndexProvider);
    if (game.domes.isEmpty) return _NoDomesView();

    final clampedIndex = domeIndex.clamp(0, game.domes.length - 1);
    final dome = game.domes[clampedIndex];

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -300 && clampedIndex < game.domes.length - 1) {
          _changeDome(clampedIndex + 1, -1);
        } else if (details.primaryVelocity! > 300 && clampedIndex > 0) {
          _changeDome(clampedIndex - 1, 1);
        }
      },
      child: Column(
        children: [
          // ── Dome navigator ───────────────────────────────────────────────
          _DomeNavigator(
            domes: game.domes,
            currentIndex: clampedIndex,
            onPrevious: clampedIndex > 0
                ? () => _changeDome(clampedIndex - 1, 1)
                : null,
            onNext: clampedIndex < game.domes.length - 1
                ? () => _changeDome(clampedIndex + 1, -1)
                : null,
          ),

          // ── Action toolbar ───────────────────────────────────────────────
          _ActionToolbar(
            selectedAction: _selectedAction,
            selectedCropId: _selectedCropId,
            dome: dome,
            game: game,
            onActionSelected: (action) {
              if (action == DomeAction.plant) {
                if (_selectedAction == DomeAction.plant && _selectedCropId != null) {
                  _showCropPickerForToolbar(context, ref, game, dome, clampedIndex);
                } else if (_selectedAction == DomeAction.plant) {
                  setState(() { _selectedAction = null; _selectedCropId = null; });
                } else {
                  _showCropPickerForToolbar(context, ref, game, dome, clampedIndex);
                }
              } else {
                setState(() {
                  _selectedAction = _selectedAction == action ? null : action;
                  _selectedCropId = null;
                });
              }
            },
          ),

          // ── Robot status banner ──────────────────────────────────────────
          if (dome.robot != null) _RobotBanner(dome: dome),

          // ── 3x3 Grid with slide animation ───────────────────────────────
          Expanded(
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _DomeGrid(
                  dome: dome,
                  game: game,
                  selectedAction: _selectedAction,
                  selectedCropId: _selectedCropId,
                  onCellTap: (position) => _handleCellTap(
                    context, ref, game, dome, position, clampedIndex,
                  ),
                  onCropSelected: (cropId) {
                    setState(() => _selectedCropId = cropId);
                  },
                ),
              ),
            ),
          ),

          // ── Dome info footer ─────────────────────────────────────────────
          _DomeInfoFooter(dome: dome, game: game),
        ],
      ), // Column
    ); // GestureDetector
  }

  void _handleCellTap(
      BuildContext context,
      WidgetRef ref,
      GameState game,
      Dome dome,
      int position,
      int domeIndex,
      ) {
    if (_selectedAction == null) {
      // Show cell info
      _showCellInfo(context, dome.cells[position], game);
      return;
    }

    final cell = dome.cells[position];

    switch (_selectedAction!) {
      case DomeAction.water:
        _doWater(ref, game, dome, cell, domeIndex);
      case DomeAction.fertilize:
        _doFertilize(ref, game, dome, cell, domeIndex);
      case DomeAction.harvest:
        _doHarvest(ref, game, dome, cell, domeIndex);
      case DomeAction.plant:
        if (_selectedCropId != null) {
          _doPlant(ref, game, dome, cell, domeIndex, _selectedCropId!);
        }
      case DomeAction.clearDead:
        _doClearDead(ref, game, dome, cell, domeIndex);
    }
  }

  void _doWater(WidgetRef ref, GameState game, Dome dome, CropCell cell, int domeIndex) {
    // Dome bot handles watering automatically — player can't manually water.
    if (dome.domeBot != null && dome.domeBot!.canWater) {
      _snack(ref.context, '🤖 Dome Bot handles watering automatically.');
      return;
    }
    if (cell.state != CropState.growing) {
      _snack(ref.context, 'Nothing to water here.');
      return;
    }
    if (cell.wateredThisWeek) {
      _snack(ref.context, 'Already watered this week.');
      return;
    }

    final crop = GameConfigService.instance.getCrop(cell.cropId ?? '');
    if (crop == null) return;

    final resources = game.resources;
    if (resources.water < crop.waterPerWeek) {
      _snack(ref.context, 'Not enough water. Need ${crop.waterPerWeek}m³.');
      return;
    }

    _updateCell(
      ref, game, dome, domeIndex,
      cell.copyWith(wateredThisWeek: true),
      game.resources.copyWith(water: resources.water - crop.waterPerWeek),
    );
  }

  void _doFertilize(WidgetRef ref, GameState game, Dome dome, CropCell cell, int domeIndex) {
    if (dome.domeBot != null && dome.domeBot!.canFertilize) {
      _snack(ref.context, '🤖 Dome Bot handles fertilizing automatically.');
      return;
    }
    if (cell.state != CropState.growing) {
      _snack(ref.context, 'Nothing to fertilize here.');
      return;
    }
    if (cell.fertilizedThisWeek) {
      _snack(ref.context, 'Already fertilized this week.');
      return;
    }
    final crop = GameConfigService.instance.getCrop(cell.cropId ?? '');
    if (crop == null) return;
    // Max once per 3 growth-weeks
    if (cell.fertilizeCount >= crop.maxFertilizations) {
      _snack(ref.context, 'This crop can\'t be fertilized any more times.');
      return;
    }
    if (cell.weeksGrown - cell.lastFertilizeWeek < 3 && cell.lastFertilizeWeek >= 0) {
      _snack(ref.context, 'Must wait 3 weeks between fertilizing.');
      return;
    }
    if (game.resources.compost < 1) {
      _snack(ref.context, 'No compost available.');
      return;
    }

    _updateCell(
      ref, game, dome, domeIndex,
      cell.copyWith(
        fertilizedThisWeek: true,
        fertilizeCount: cell.fertilizeCount + 1,
        lastFertilizeWeek: cell.weeksGrown,
      ),
      game.resources.copyWith(compost: game.resources.compost - 1),
    );
  }

  void _doHarvest(WidgetRef ref, GameState game, Dome dome, CropCell cell, int domeIndex) {
    if (cell.state != CropState.ready) {
      _snack(ref.context, 'Crop is not ready to harvest yet.');
      return;
    }

    final crop = GameConfigService.instance.getCrop(cell.cropId ?? '');
    if (crop == null) return;

    // Compute actual yield: base 1 × decay multiplier × fertilizer stacking
    final healthMult = (cell.healthPercent / 100.0).clamp(0.0, 1.0);
    double fertMult = 1.0;
    for (int i = 0; i < cell.fertilizeCount; i++) {
      fertMult *= crop.fertilizerBonus;
    }
    final yieldAmount = (1.0 * healthMult * fertMult).clamp(0.0, 999.0);

    final updatedInventory = Map<String, double>.from(game.siloInventory);
    var newResources = game.resources;

    // Resource crops deposit raw materials; food crops go to silo.
    if (crop.yieldsResource != null) {
      final amt = crop.resourceYieldAmount * yieldAmount;
      switch (crop.yieldsResource!) {
        case 'metals':
          newResources = newResources.copyWith(metals: newResources.metals + amt);
        case 'sand':
          newResources = newResources.copyWith(sand: newResources.sand + amt);
        case 'ore':
          newResources = newResources.copyWith(ore: newResources.ore + amt);
        case 'components':
          newResources = newResources.copyWith(components: newResources.components + amt);
        case 'moon_dirt':
          newResources = newResources.copyWith(moonDirt: newResources.moonDirt + amt);
        case 'chemicals':
          newResources = newResources.copyWith(chemicals: newResources.chemicals + amt);
        case 'glass':
          newResources = newResources.copyWith(glass: newResources.glass + amt);
      }
    } else {
      updatedInventory[cell.cropId!] =
          (updatedInventory[cell.cropId!] ?? 0) + yieldAmount;
    }

    // Compost byproduct on harvest
    newResources = newResources.copyWith(
      compost: newResources.compost + crop.compostYield,
    );

    final newHarvestCount = game.totalCropsHarvested + 1;
    var updatedGame = game.copyWith(
      resources: newResources,
      siloInventory: updatedInventory,
      totalCropsHarvested: newHarvestCount,
    );

    // Check first harvest trophy
    if (newHarvestCount == 1) {
      final updatedTrophies = updatedGame.trophies.map((t) {
        if (t.id == 'first_harvest') return t.unlock(game.currentWeek);
        return t;
      }).toList();
      updatedGame = updatedGame.copyWith(trophies: updatedTrophies);
      _updateCellInGame(ref, updatedGame, dome, domeIndex, cell.cleared());
      _snack(ref.context, '🏆 First Harvest! ${crop.name} stored in silo.');
      return;
    }

    _updateCellInGame(ref, updatedGame, dome, domeIndex, cell.cleared());
    _snack(ref.context, '✅ ${crop.name} stored in silo. Sell via Relay.');
  }

  void _doPlant(
      WidgetRef ref,
      GameState game,
      Dome dome,
      CropCell cell,
      int domeIndex,
      String cropId,
      ) {
    if (cell.state != CropState.empty) {
      _snack(ref.context, 'Cell is not empty.');
      return;
    }

    final crop = GameConfigService.instance.getCrop(cropId);
    if (crop == null) return;

    if (crop.domeTierRequired != dome.tier) {
      _snack(ref.context, '${crop.name} needs a Tier ${crop.domeTierRequired} dome. This dome is Tier ${dome.tier}.');
      return;
    }
    if (game.resources.seeds < 1) {
      _snack(ref.context, 'No seeds available.');
      return;
    }
    if (game.resources.zSoil < 1) {
      _snack(ref.context, 'No Z Soil available. Refine some Moon Dirt first.');
      return;
    }

    final newCell = CropCell(
      position: cell.position,
      cropId: cropId,
      state: CropState.growing,
      weeksGrown: 0,
      wateredThisWeek: false,
      fertilizedThisWeek: false,
      healthPercent: 100,
    );

    _updateCell(
      ref, game, dome, domeIndex, newCell,
      game.resources.copyWith(
        seeds: game.resources.seeds - 1,
        zSoil: game.resources.zSoil - 1,
      ),
    );
  }

  void _doClearDead(WidgetRef ref, GameState game, Dome dome, CropCell cell, int domeIndex) {
    if (cell.state == CropState.empty) {
      _snack(ref.context, 'Nothing to clear here.');
      return;
    }
    if (cell.state == CropState.ready) {
      _snack(ref.context, 'Harvest first, then clear.');
      return;
    }

    // Clearing dead cells gives compost; clearing live/planted cells loses seeds.
    final compostGain = cell.state == CropState.dead ? 1 : 0;
    final message = cell.state == CropState.dead
        ? 'Cleared. +1 compost.'
        : 'Cleared. Seeds lost.';

    _updateCell(
      ref, game, dome, domeIndex,
      cell.cleared(),
      game.resources.copyWith(compost: game.resources.compost + compostGain),
    );
    _snack(ref.context, message);
  }

  // ─── Cell update helpers ──────────────────────────────────────────────────

  void _updateCell(
      WidgetRef ref,
      GameState game,
      Dome dome,
      int domeIndex,
      CropCell updatedCell,
      Resources updatedResources,
      ) {
    final updatedCells = List<CropCell>.from(dome.cells);
    updatedCells[updatedCell.position] = updatedCell;
    final updatedDome = dome.copyWith(cells: updatedCells);
    final updatedDomes = List<Dome>.from(game.domes);
    updatedDomes[domeIndex] = updatedDome;

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(domes: updatedDomes, resources: updatedResources),
    );
  }

  void _updateCellInGame(
      WidgetRef ref,
      GameState game,
      Dome dome,
      int domeIndex,
      CropCell updatedCell,
      ) {
    final updatedCells = List<CropCell>.from(dome.cells);
    updatedCells[updatedCell.position] = updatedCell;
    final updatedDome = dome.copyWith(cells: updatedCells);
    final updatedDomes = List<Dome>.from(game.domes);
    updatedDomes[domeIndex] = updatedDome;

    ref.read(activeGameProvider.notifier).updateGameLocal(
      game.copyWith(domes: updatedDomes),
    );
  }

  // ─── Crop picker dialog ───────────────────────────────────────────────────

  // Called when Plant toolbar button is tapped — picker shown before any cell is tapped
  void _showCropPickerForToolbar(
      BuildContext context,
      WidgetRef ref,
      GameState game,
      Dome dome,
      int domeIndex,
      ) {
    final availableCrops = GameConfigService.instance.getCropsForDomeTier(dome.tier);

    showModalBottomSheet(
      context: context,
      backgroundColor: MFColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: MFColors.borderDefault),
      ),
      builder: (ctx) => _CropPickerSheet(
        crops: availableCrops,
        game: game,
        onCropSelected: (cropId) {
          Navigator.of(ctx).pop();
          setState(() {
            _selectedAction = DomeAction.plant;
            _selectedCropId = cropId;
          });
        },
      ),
    );
  }


  // ─── Cell info dialog ─────────────────────────────────────────────────────

  void _showCellInfo(BuildContext context, CropCell cell, GameState game) {
    if (cell.state == CropState.empty) return;

    final crop = cell.cropId != null
        ? GameConfigService.instance.getCrop(cell.cropId!)
        : null;
    if (crop == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MFColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: MFColors.borderDefault),
        ),
        title: Row(
          children: [
            Text(crop.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Text(crop.name, style: MFTextStyles.headlineMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow('Status', _stateLabel(cell.state)),
            _InfoRow('Growth', '${cell.weeksGrown} / ${crop.growthWeeks} weeks'),
            _InfoRow('Watered', cell.wateredThisWeek ? '✅ Yes' : '❌ No'),
            _InfoRow('Fertilized', cell.fertilizedThisWeek ? '✅ Yes' : '❌ No'),
            _InfoRow('Value', '${crop.baseScrip} 🎫 / unit'),
            _InfoRow('Volume', '${crop.volumeM3}m³'),
            const SizedBox(height: 8),
            Text(crop.description, style: MFTextStyles.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  String _stateLabel(CropState state) {
    switch (state) {
      case CropState.empty: return 'Empty';
      case CropState.planted: return 'Just planted';
      case CropState.growing: return '🌱 Growing';
      case CropState.ready: return '✅ Ready!';
      case CropState.dead: return '💀 Dead';
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// ─── Dome Navigator ───────────────────────────────────────────────────────────

class _DomeNavigator extends StatelessWidget {
  final List<Dome> domes;
  final int currentIndex;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _DomeNavigator({
    required this.domes,
    required this.currentIndex,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final dome = domes[currentIndex];
    final tierEmojis = ['', '🔵', '🟢', '🟡', '🟠'];
    final tierEmoji = tierEmojis[dome.tier.clamp(1, 4)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MFColors.borderSubtle)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            color: onPrevious != null ? MFColors.neonCyan : MFColors.textMuted,
            iconSize: 28,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(tierEmoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      dome.name.toUpperCase(),
                      style: MFTextStyles.labelLarge,
                    ),
                  ],
                ),
                Text(
                  '${currentIndex + 1} / ${domes.length}  ·  Tier ${dome.tier}  ·  '
                      '${dome.activeCropCount}/8 planted',
                  style: MFTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            color: onNext != null ? MFColors.neonCyan : MFColors.textMuted,
            iconSize: 28,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ─── Action Toolbar ───────────────────────────────────────────────────────────

class _ActionToolbar extends StatelessWidget {
  final DomeAction? selectedAction;
  final String? selectedCropId;
  final Dome dome;
  final GameState game;
  final ValueChanged<DomeAction> onActionSelected;

  const _ActionToolbar({
    required this.selectedAction,
    required this.selectedCropId,
    required this.dome,
    required this.game,
    required this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final plantedCrop = selectedCropId != null ? config.getCrop(selectedCropId!) : null;
    final actions = [
      (DomeAction.plant, plantedCrop?.emoji ?? '🌱', plantedCrop != null ? plantedCrop.name.toUpperCase().substring(0, plantedCrop.name.length > 5 ? 5 : plantedCrop.name.length) : 'PLANT'),
      (DomeAction.water,     '💧', 'WATER'),
      (DomeAction.fertilize, '♻️', 'FERT.'),
      (DomeAction.harvest,   '🌾', 'HARVEST'),
      (DomeAction.clearDead, '💀', 'CLEAR'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MFColors.borderSubtle)),
      ),
      child: Row(
        children: actions.map((item) {
          final (action, emoji, label) = item;
          final isSelected = selectedAction == action;
          return Expanded(
            child: GestureDetector(
              onTap: () => onActionSelected(action),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? MFColors.neonCyan.withValues(alpha: 0.15)
                      : MFColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? MFColors.neonCyan : MFColors.borderSubtle,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: MFTextStyles.bodySmall.copyWith(
                        fontSize: 9,
                        color: isSelected ? MFColors.neonCyan : MFColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
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

// ─── Robot Banner ─────────────────────────────────────────────────────────────

class _RobotBanner extends StatelessWidget {
  final Dome dome;
  const _RobotBanner({required this.dome});

  @override
  Widget build(BuildContext context) {
    final robot = dome.robot!;
    final healthColor = MFStatusColor.forPercent(robot.healthPercent);
    final capabilities = <String>[];
    if (robot.canWater) capabilities.add('water');
    if (robot.canFertilize) capabilities.add('fert');
    if (robot.canHarvest) capabilities.add('harvest');
    if (robot.canTurnSoil) capabilities.add('soil');
    if (robot.canPlant) capabilities.add('plant');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: MFColors.surfaceElevated,
      child: Row(
        children: [
          Text(
            robot.state == RobotState.offline ? '💤' : '🤖',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${robot.robotName}  ·  ${capabilities.join(' · ')}',
              style: MFTextStyles.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: healthColor.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${robot.health}%',
              style: MFTextStyles.bodySmall.copyWith(
                color: healthColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dome Grid ────────────────────────────────────────────────────────────────
//
// Visual layout:
// [0][1][2]
// [3][C][4]   C = center robot slot
// [5][6][7]
//
// Cell positions 0-7 map to grid positions:
// pos 0→(0,0), 1→(0,1), 2→(0,2)
// pos 3→(1,0), CENTER→(1,1), 4→(1,2)
// pos 5→(2,0), 6→(2,1), 7→(2,2)

class _DomeGrid extends StatelessWidget {
  final Dome dome;
  final GameState game;
  final DomeAction? selectedAction;
  final String? selectedCropId;
  final ValueChanged<int> onCellTap;
  final ValueChanged<String> onCropSelected;

  const _DomeGrid({
    required this.dome,
    required this.game,
    required this.selectedAction,
    required this.selectedCropId,
    required this.onCellTap,
    required this.onCropSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Map 8 cell positions to 3x3 grid (center = robot)
    // Grid index 0-8, center = index 4
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(9, (gridIndex) {
        if (gridIndex == 4) {
          // Center = robot slot
          return _RobotCell(dome: dome, game: game);
        }
        // Map grid index to cell position
        final cellPos = gridIndex < 4 ? gridIndex : gridIndex - 1;
        final cell = dome.cells[cellPos];
        return _CropCell(
          cell: cell,
          dome: dome,
          selectedAction: selectedAction,
          onTap: () => onCellTap(cellPos),
        );
      }),
    );
  }
}

// ─── Crop Cell Widget ─────────────────────────────────────────────────────────

class _CropCell extends StatelessWidget {
  final CropCell cell;
  final Dome dome;
  final DomeAction? selectedAction;
  final VoidCallback onTap;

  const _CropCell({
    required this.cell,
    required this.dome,
    required this.selectedAction,
    required this.onTap,
  });

  // Bot handles a chore → don't flag it as needed
  bool get _botWaters => dome.domeBot?.canWater == true;
  bool get _botFertilizes => dome.domeBot?.canFertilize == true;

  bool get _needsWater =>
      !_botWaters &&
          cell.state == CropState.growing &&
          !cell.wateredThisWeek;

  bool get _needsFertilizer {
    if (_botFertilizes) return false;
    if (cell.state != CropState.growing) return false;
    if (cell.fertilizedThisWeek) return false;
    final config = GameConfigService.instance;
    final crop = cell.cropId != null ? config.getCrop(cell.cropId!) : null;
    if (crop == null) return false;
    if (cell.fertilizeCount >= crop.maxFertilizations) return false;
    if (cell.lastFertilizeWeek >= 0 &&
        cell.weeksGrown - cell.lastFertilizeWeek < 3) return false;
    return true;
  }

  Color get _borderColor {
    if (selectedAction != null) return MFColors.neonCyan.withValues(alpha: 0.6);
    switch (cell.state) {
      case CropState.empty:
        return const Color(0xFF4E342E); // dark brown border
      case CropState.planted:
        return MFColors.neonGreen.withValues(alpha: 0.5);
      case CropState.growing:
        if (_needsWater) return const Color(0xFFFF8F00); // orange
        if (_needsFertilizer) return const Color(0xFF78909C); // sickly gray-blue
        return const Color(0xFF66BB6A); // healthy green
      case CropState.ready:
        return const Color(0xFF00BCD4); // cyan — action needed: harvest me!
      case CropState.dead:
        return const Color(0xFFE53935); // red
    }
  }

  Color get _bgColor {
    switch (cell.state) {
      case CropState.empty:
        return const Color(0xFF2E1A0E); // dark brown
      case CropState.planted:
        return MFColors.neonGreen.withValues(alpha: 0.05);
      case CropState.growing:
        if (_needsWater) return const Color(0xFFFF8F00).withValues(alpha: 0.08);
        if (_needsFertilizer) return const Color(0xFF78909C).withValues(alpha: 0.08);
        return const Color(0xFF66BB6A).withValues(alpha: 0.08);
      case CropState.ready:
        return const Color(0xFF00BCD4).withValues(alpha: 0.1);
      case CropState.dead:
        return const Color(0xFFE53935).withValues(alpha: 0.08);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final crop = cell.cropId != null ? config.getCrop(cell.cropId!) : null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (cell.state == CropState.empty) ...[
              Icon(
                Icons.add,
                color: selectedAction == DomeAction.plant
                    ? MFColors.neonCyan
                    : const Color(0xFF6D4C41), // muted brown
                size: 24,
              ),
            ] else ...[
              Text(
                crop?.emoji ?? '?',
                style: TextStyle(
                  fontSize: cell.state == CropState.dead ? 18 : 26,
                  color: cell.state == CropState.dead
                      ? Colors.grey.withValues(alpha: 0.5)
                      : null,
                ),
              ),
              const SizedBox(height: 1),
              if (cell.state == CropState.ready)
                Text('READY',
                    style: MFTextStyles.bodySmall.copyWith(
                      color: const Color(0xFF00BCD4),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ))
              else if (cell.state == CropState.dead)
                Text('CLEAR',
                    style: MFTextStyles.bodySmall.copyWith(
                      color: const Color(0xFFE53935),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ))
              else if (cell.state == CropState.growing ||
                    cell.state == CropState.planted) ...[
                  Text(
                    '${cell.weeksGrown}/${crop?.growthWeeks ?? '?'}w',
                    style: MFTextStyles.bodySmall.copyWith(fontSize: 9),
                  ),
                  // Only show need indicators — not confirmations
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_needsWater)
                        const Text('💧', style: TextStyle(fontSize: 8)),
                      if (_needsFertilizer)
                        const Text('♻️', style: TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Robot Cell (center) ──────────────────────────────────────────────────────

class _RobotCell extends StatefulWidget {
  final Dome dome;
  final GameState game;
  const _RobotCell({required this.dome, required this.game});

  @override
  State<_RobotCell> createState() => _RobotCellState();
}

class _RobotCellState extends State<_RobotCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _animating = false);
        _controller.reset();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerRainbow() {
    setState(() => _animating = true);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final bot = widget.dome.domeBot;
    final robot = widget.dome.robot;

    if (bot != null) {
      final baseColor = mkColor(bot.level);

      return GestureDetector(
        onTap: _triggerRainbow,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Rainbow: cycle hue 0→360 twice over 2 seconds
            final borderColor = _animating
                ? HSLColor.fromAHSL(
              1.0,
              (_controller.value * 720) % 360,
              1.0,
              0.6,
            ).toColor()
                : baseColor.withValues(alpha: 0.6);

            final bgColor = _animating
                ? HSLColor.fromAHSL(
              0.15,
              (_controller.value * 720) % 360,
              1.0,
              0.6,
            ).toColor()
                : baseColor.withValues(alpha: 0.1);

            return Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: borderColor,
                  width: _animating ? 2.5 : 1.5,
                ),
              ),
              child: child,
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🤖', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 2),
              Text('MK${bot.level}',
                  style: MFTextStyles.bodySmall.copyWith(
                    fontSize: 8,
                    color: MFColors.neonCyan,
                    fontWeight: FontWeight.bold,
                  )),
              Text(_botActions(bot),
                  style: MFTextStyles.bodySmall.copyWith(
                      fontSize: 7, color: MFColors.textMuted),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    // Legacy robot or empty
    return Container(
      decoration: BoxDecoration(
        color: MFColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: robot == null
              ? MFColors.borderSubtle
              : MFStatusColor.forPercent(robot.healthPercent).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            robot == null ? '⬜' : (robot.state == RobotState.offline ? '💤' : '🤖'),
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 2),
          Text(
            robot == null ? 'NO BOT' : 'MK${robot.level}',
            style: MFTextStyles.bodySmall.copyWith(
              fontSize: 8,
              color: robot == null ? MFColors.textMuted : MFColors.neonCyan,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (robot != null)
            Text('${robot.health}%',
                style: MFTextStyles.bodySmall.copyWith(
                  fontSize: 8,
                  color: MFStatusColor.forPercent(robot.healthPercent),
                )),
        ],
      ),
    );
  }

  String _botActions(DomeBot bot) {
    final parts = <String>[];
    if (bot.canWater) parts.add('💧');
    if (bot.canHarvest) parts.add('🌾');
    if (bot.canFertilize) parts.add('♻️');
    if (bot.canPlant) parts.add('🌱');
    return parts.join(' ');
  }
}

// ─── All-Domes Summary Footer ─────────────────────────────────────────────────

class _DomeInfoFooter extends StatelessWidget {
  final Dome dome;   // kept for API compat but we use game now
  final GameState game;

  const _DomeInfoFooter({required this.dome, required this.game});

  @override
  Widget build(BuildContext context) {
    int needWater = 0, needFert = 0, readyCount = 0, deadCount = 0, emptyCount = 0;

    for (final d in game.domes) {
      final botWaters = d.domeBot?.canWater == true;
      final botFertilizes = d.domeBot?.canFertilize == true;
      final botPlants = d.domeBot?.canPlant == true;

      for (final cell in d.cells) {
        switch (cell.state) {
          case CropState.empty:
            if (!botPlants) emptyCount++;
          case CropState.planted:
          case CropState.growing:
            if (!botWaters && !cell.wateredThisWeek) needWater++;
            if (!botFertilizes && !cell.fertilizedThisWeek) needFert++;
          case CropState.ready:
            readyCount++;
          case CropState.dead:
            deadCount++;
        }
      }
    }

    final allGood = needWater == 0 && needFert == 0 &&
        readyCount == 0 && deadCount == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MFColors.borderSubtle)),
      ),
      child: allGood
          ? const Center(
        child: Text(
          '👾 Domes are happy',
          style: TextStyle(
            color: Color(0xFF66BB6A),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          if (emptyCount > 0)
            _SummaryChip('🌱', emptyCount, const Color(0xFF66BB6A)),
          if (needWater > 0)
            _SummaryChip('💧', needWater, const Color(0xFFFF8F00)),
          if (needFert > 0)
            _SummaryChip('♻️', needFert, const Color(0xFF78909C)),
          if (readyCount > 0)
            _SummaryChip('🌾', readyCount, const Color(0xFF00BCD4)),
          if (deadCount > 0)
            _SummaryChip('💀', deadCount, const Color(0xFFE53935)),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String emoji;
  final int count;
  final Color color;

  const _SummaryChip(this.emoji, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Crop Picker Sheet ────────────────────────────────────────────────────────

class _CropPickerSheet extends StatelessWidget {
  final List<CropConfig> crops;
  final GameState game;
  final ValueChanged<String> onCropSelected;

  const _CropPickerSheet({
    required this.crops,
    required this.game,
    required this.onCropSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tierColors = {
      1: MFColors.tier1,
      2: MFColors.tier2,
      3: MFColors.tier3,
      4: MFColors.tier4,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: MFColors.borderSubtle)),
          ),
          child: Row(
            children: [
              Text('SELECT CROP', style: MFTextStyles.labelLarge),
              const Spacer(),
              Text(
                '${game.resources.seeds} seeds  ·  ${game.resources.zSoil.toInt()} Z Soil',
                style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonGreen),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: crops.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final crop = crops[i];
              final canAfford = game.resources.seeds >= 1 &&
                  game.resources.zSoil >= 1;
              final tierColor = tierColors[crop.tier] ?? MFColors.textSecondary;

              return ListTile(
                enabled: canAfford,
                leading: Text(crop.emoji, style: const TextStyle(fontSize: 28)),
                title: Text(crop.name, style: MFTextStyles.bodyLarge),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${crop.growthWeeks}w  ·  ${crop.waterPerWeek}💧/wk  ·  ${crop.baseScrip}🎫',
                      style: MFTextStyles.bodySmall,
                    ),
                    Text(
                      '📦 ${crop.volumeM3}m³ cargo  ·  ♻️ ${crop.compostYield} compost',
                      style: MFTextStyles.bodySmall.copyWith(
                        color: MFColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: tierColor.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'T${crop.tier}',
                    style: MFTextStyles.bodySmall.copyWith(
                      color: tierColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: canAfford ? () => onCropSelected(crop.id) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Info Row helper ──────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: MFTextStyles.bodySmall),
          Text(value, style: MFTextStyles.labelLarge),
        ],
      ),
    );
  }
}

// ─── No Domes View ────────────────────────────────────────────────────────────

class _NoDomesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🔵', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('No domes built yet.',
                style: MFTextStyles.headlineMedium),
          ],
        ),
      ),
    );
  }
}