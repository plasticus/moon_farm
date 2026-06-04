// ═══════════════════════════════════════════════════════════════
//  lib/screens/dome/dome_screen.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/game_config_service.dart';

// ─── Dome Action Enum ─────────────────────────────────────────────────────────

enum DomeAction { water, fertilize, harvest, plant, clearDead }

// ─── Main Dome Screen ─────────────────────────────────────────────────────────

class DomeScreen extends ConsumerStatefulWidget {
  const DomeScreen({super.key});

  @override
  ConsumerState<DomeScreen> createState() => _DomeScreenState();
}

class _DomeScreenState extends ConsumerState<DomeScreen> {
  DomeAction? _selectedAction;
  String? _selectedCropId; // for planting

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(activeGameProvider).value;
    if (game == null) return const SizedBox();

    final domeIndex = ref.watch(activeDomeIndexProvider);
    if (game.domes.isEmpty) return _NoDomesView();

    final clampedIndex = domeIndex.clamp(0, game.domes.length - 1);
    final dome = game.domes[clampedIndex];

    return Column(
      children: [
        // ── Dome navigator ───────────────────────────────────────────────
        _DomeNavigator(
          domes: game.domes,
          currentIndex: clampedIndex,
          onPrevious: clampedIndex > 0
              ? () => ref.read(activeDomeIndexProvider.notifier).state--
              : null,
          onNext: clampedIndex < game.domes.length - 1
              ? () => ref.read(activeDomeIndexProvider.notifier).state++
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
                // Tap Plant again to change crop
                _showCropPickerForToolbar(context, ref, game, dome, clampedIndex);
              } else if (_selectedAction == DomeAction.plant) {
                setState(() { _selectedAction = null; _selectedCropId = null; });
              } else {
                // First Plant tap — show picker immediately
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

        // ── 3x3 Grid ────────────────────────────────────────────────────
        Expanded(
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

        // ── Dome info footer ─────────────────────────────────────────────
        _DomeInfoFooter(dome: dome, game: game),
      ],
    );
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
      _snack(ref.context, 'Not enough water! Need ${crop.waterPerWeek}L.');
      return;
    }

    _updateCell(
      ref, game, dome, domeIndex,
      cell.copyWith(wateredThisWeek: true),
      game.resources.copyWith(water: resources.water - crop.waterPerWeek),
    );
  }

  void _doFertilize(WidgetRef ref, GameState game, Dome dome, CropCell cell, int domeIndex) {
    if (cell.state != CropState.growing) {
      _snack(ref.context, 'Nothing to fertilize here.');
      return;
    }
    if (cell.fertilizedThisWeek) {
      _snack(ref.context, 'Already fertilized this week.');
      return;
    }
    if (game.resources.compost < 1) {
      _snack(ref.context, 'No compost available.');
      return;
    }

    _updateCell(
      ref, game, dome, domeIndex,
      cell.copyWith(fertilizedThisWeek: true),
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

    // Add to pending sales automatically
    final saleValue = GameConfigService.instance.getSellPrice(
      cell.cropId!,
      moodDiscount: game.relay.priceDiscount,
    );
    final sale = PendingSale(
      resourceId: cell.cropId!,
      amount: crop.volumeM3,
      scripValue: saleValue,
      weekQueued: game.currentWeek,
    );

    // Return a seed
    final newResources = game.resources.copyWith(
      seeds: game.resources.seeds + 1,
    );

    final updatedGame = game.copyWith(
      resources: newResources,
      pendingSales: [...game.pendingSales, sale],
      totalCropsHarvested: game.totalCropsHarvested + 1,
    );

    _updateCellInGame(ref, updatedGame, dome, domeIndex, cell.cleared());

    // Check first harvest trophy
    if (updatedGame.totalCropsHarvested == 1) {
      final updatedTrophies = updatedGame.trophies.map((t) {
        if (t.id == 'first_harvest') return t.unlock(game.currentWeek);
        return t;
      }).toList();
      ref.read(activeGameProvider.notifier).updateGameLocal(
        updatedGame.copyWith(trophies: updatedTrophies),
      );
      _snack(ref.context, '🏆 Trophy unlocked: First Harvest!');
      return;
    }

    _snack(ref.context, '✅ Harvested ${crop.name}! +${saleValue} 🎫 queued.');
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

    if (crop.domeTierRequired > dome.tier) {
      _snack(ref.context, '${crop.name} needs a Tier ${crop.domeTierRequired} dome.');
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
    if (cell.state != CropState.dead) {
      _snack(ref.context, 'Nothing dead to clear here.');
      return;
    }

    // Dead crops turn to compost
    _updateCell(
      ref, game, dome, domeIndex,
      cell.cleared(),
      game.resources.copyWith(compost: game.resources.compost + 1),
    );
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

  void _showCropPicker(
      BuildContext context,
      WidgetRef ref,
      GameState game,
      Dome dome,
      CropCell cell,
      int domeIndex,
      ) {
    final availableCrops = GameConfigService.instance
        .getCropsForDomeTier(dome.tier);

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
          setState(() => _selectedCropId = cropId);
          _doPlant(ref, game, dome, cell, domeIndex, cropId);
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

  Color get _borderColor {
    if (selectedAction != null) return MFColors.neonCyan.withValues(alpha: 0.6);
    switch (cell.state) {
      case CropState.empty: return MFColors.borderSubtle;
      case CropState.planted:
      case CropState.growing: return MFColors.neonGreen.withValues(alpha: 0.4);
      case CropState.ready: return MFColors.neonGreen;
      case CropState.dead: return MFColors.neonPink.withValues(alpha: 0.5);
    }
  }

  Color get _bgColor {
    switch (cell.state) {
      case CropState.empty: return MFColors.surface;
      case CropState.planted:
      case CropState.growing: return MFColors.neonGreen.withValues(alpha: 0.05);
      case CropState.ready: return MFColors.neonGreen.withValues(alpha: 0.12);
      case CropState.dead: return MFColors.neonPink.withValues(alpha: 0.05);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final crop = cell.cropId != null ? config.getCrop(cell.cropId!) : null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
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
                    : MFColors.textMuted,
                size: 24,
              ),
            ] else ...[
              Text(
                crop?.emoji ?? '?',
                style: TextStyle(
                  fontSize: cell.state == CropState.dead ? 20 : 28,
                  color: cell.state == CropState.dead
                      ? Colors.grey
                      : null,
                ),
              ),
              const SizedBox(height: 2),
              if (cell.state == CropState.ready)
                Text(
                  'READY',
                  style: MFTextStyles.bodySmall.copyWith(
                    color: MFColors.neonGreen,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (cell.state == CropState.dead)
                Text(
                  'DEAD',
                  style: MFTextStyles.bodySmall.copyWith(
                    color: MFColors.neonPink,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (cell.state == CropState.growing) ...[
                  Text(
                    '${cell.weeksGrown}/${crop?.growthWeeks ?? '?'}w',
                    style: MFTextStyles.bodySmall.copyWith(fontSize: 9),
                  ),
                  // Status indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (cell.wateredThisWeek)
                        Text('💧', style: const TextStyle(fontSize: 8)),
                      if (cell.fertilizedThisWeek)
                        Text('♻️', style: const TextStyle(fontSize: 8)),
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

class _RobotCell extends StatelessWidget {
  final Dome dome;
  final GameState game;

  const _RobotCell({required this.dome, required this.game});

  @override
  Widget build(BuildContext context) {
    final robot = dome.robot;

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
            Text(
              '${robot.health}%',
              style: MFTextStyles.bodySmall.copyWith(
                fontSize: 8,
                color: MFStatusColor.forPercent(robot.healthPercent),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Dome Info Footer ─────────────────────────────────────────────────────────

class _DomeInfoFooter extends StatelessWidget {
  final Dome dome;
  final GameState game;

  const _DomeInfoFooter({required this.dome, required this.game});

  @override
  Widget build(BuildContext context) {
    final readyCount = dome.readyToHarvestCount;
    final deadCount = dome.deadCropCount;
    final growingCount = dome.cells
        .where((c) => c.state == CropState.growing)
        .length;
    final unwateredCount = dome.cells
        .where((c) => c.state == CropState.growing && !c.wateredThisWeek)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MFColors.borderSubtle)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _FooterStat('🌱', '$growingCount growing'),
          _FooterStat('✅', '$readyCount ready',
              color: readyCount > 0 ? MFColors.neonGreen : null),
          _FooterStat('💧', '$unwateredCount need water',
              color: unwateredCount > 0 ? MFColors.neonYellow : null),
          _FooterStat('💀', '$deadCount dead',
              color: deadCount > 0 ? MFColors.neonPink : null),
        ],
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  final String emoji;
  final String label;
  final Color? color;

  const _FooterStat(this.emoji, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 3),
        Text(
          label,
          style: MFTextStyles.bodySmall.copyWith(
            color: color ?? MFColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
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