// ═══════════════════════════════════════════════════════════════
//  lib/engine/end_week_engine.dart
// ═══════════════════════════════════════════════════════════════
//
// The heart of Moon Farm. Called when the player presses End Week.
// Processes in this strict order:
//   1. Process pending sales → award Star-Scrip
//   2. Robot actions (water, fertilize, harvest, plant)
//   3. Crop growth tick (increment weeksGrown)
//   4. Crop decay check (die if not watered when required)
//   5. Neon Berry special decay (die if ready and not harvested)
//   6. Silo overflow → compost
//   7. Milestone checks
//   8. Trophy checks
//   9. Relay mood decay
//  10. Generate radio transmission
//  11. Advance week counter
//  12. Generate week summary
//  13. Persist to DB

import '../models/game_models.dart';
import '../config/game_config_service.dart';
import '../utils/game_factory.dart';

class EndWeekEngine {
  final GameConfigService _config = GameConfigService.instance;

  /// Main entry point. Takes current state, returns (newState, summary).
  (GameState, WeekSummary) processEndWeek(GameState state) {
    final events = <String>[];
    final robotActions = <String>[];
    int scripReceived = 0;
    int cropsHarvested = 0;
    int cropsDied = 0;
    double volumeToColony = 0;
    final newTrophies = <String>[];
    final milestoneUpdates = <String>[];
    final contractUpdates = <String>[];
    final resourceChanges = <String, double>{};

    var s = state;

    // ── Step 1: Process pending sales ─────────────────────────────────────
    if (s.pendingSales.isNotEmpty) {
      int earned = 0;
      for (final sale in s.pendingSales) {
        earned += sale.scripValue;
        volumeToColony += sale.amount;
        events.add('Shipment delivered: ${sale.amount.toStringAsFixed(1)}m³ → +${sale.scripValue} 🎫');
      }
      scripReceived = earned;
      s = s.copyWith(
        resources: s.resources.copyWith(
          starScrip: s.resources.starScrip + earned,
        ),
        pendingSales: [],
        totalVolumeDeliveredM3: s.totalVolumeDeliveredM3 + volumeToColony,
        lifetimeScripEarned: s.lifetimeScripEarned + earned,
      );
      resourceChanges['star_scrip'] = earned.toDouble();
    }

    // ── Step 2: Robot actions ──────────────────────────────────────────────
    final updatedDomesAfterRobots = <Dome>[];
    var resourcesAfterRobots = s.resources;

    for (final dome in s.domes) {
      if (dome.robot == null || dome.robot!.state == RobotState.offline) {
        updatedDomesAfterRobots.add(dome);
        continue;
      }

      final robot = dome.robot!;
      var updatedCells = List<CropCell>.from(dome.cells);
      final actions = <String>[];

      for (int i = 0; i < updatedCells.length; i++) {
        final cell = updatedCells[i];

        // Water
        if (robot.canWater && cell.state == CropState.growing && !cell.wateredThisWeek) {
          final crop = _config.getCrop(cell.cropId ?? '');
          if (crop != null && resourcesAfterRobots.water >= crop.waterPerWeek) {
            updatedCells[i] = cell.copyWith(wateredThisWeek: true);
            resourcesAfterRobots = resourcesAfterRobots.copyWith(
              water: resourcesAfterRobots.water - crop.waterPerWeek,
            );
          }
        }

        // Fertilize
        if (robot.canFertilize && cell.state == CropState.growing && !cell.fertilizedThisWeek) {
          if (resourcesAfterRobots.compost >= 1) {
            updatedCells[i] = cell.copyWith(fertilizedThisWeek: true);
            resourcesAfterRobots = resourcesAfterRobots.copyWith(
              compost: resourcesAfterRobots.compost - 1,
            );
          }
        }

        // Harvest ready crops
        if (robot.canHarvest && cell.state == CropState.ready) {
          final result = _harvestCell(cell, resourcesAfterRobots, s);
          resourcesAfterRobots = result.$1;
          updatedCells[i] = result.$2;
          cropsHarvested++;
          actions.add('harvested');
        }
      }

      // Plant empty cells (level 5 only)
      if (robot.canPlant && robot.defaultCropId != null) {
        final cropId = robot.defaultCropId!;
        final crop = _config.getCrop(cropId);
        if (crop != null && crop.domeTierRequired <= dome.tier) {
          for (int i = 0; i < updatedCells.length; i++) {
            if (updatedCells[i].state == CropState.empty &&
                resourcesAfterRobots.seeds >= 1 &&
                resourcesAfterRobots.zSoil >= 1) {
              updatedCells[i] = CropCell(
                position: i,
                cropId: cropId,
                state: CropState.growing,
                weeksGrown: 0,
                wateredThisWeek: false,
                fertilizedThisWeek: false,
                healthPercent: 100,
              );
              resourcesAfterRobots = resourcesAfterRobots.copyWith(
                seeds: resourcesAfterRobots.seeds - 1,
                zSoil: resourcesAfterRobots.zSoil - 1,
              );
              actions.add('planted ${crop.name}');
            }
          }
        }
      }

      // Robot wear
      final wearConfig = _config.getRobotLevel(robot.level);
      final wearPerWeek = wearConfig['wear_per_week'] as int? ?? 10;
      final newHealth = (robot.health - wearPerWeek).clamp(0, 100);
      RobotState newRobotState = RobotState.healthy;
      if (newHealth <= 0) {
        newRobotState = RobotState.offline;
        events.add('⚠️ ${dome.name} robot went offline — needs maintenance!');
      } else if (newHealth <= 25) {
        newRobotState = RobotState.critical;
      } else if (newHealth <= 50) {
        newRobotState = RobotState.warning;
      }

      final updatedRobot = robot.copyWith(health: newHealth, state: newRobotState);

      if (actions.isNotEmpty) {
        robotActions.add('${dome.name} bot: ${actions.join(', ')}');
      }

      updatedDomesAfterRobots.add(dome.copyWith(
        cells: updatedCells,
        robot: updatedRobot,
      ));
    }

    s = s.copyWith(
      domes: updatedDomesAfterRobots,
      resources: resourcesAfterRobots,
    );

    // ── Step 3 & 4: Crop growth + decay ───────────────────────────────────
    final updatedDomesAfterGrowth = <Dome>[];
    final decayRate = _config.getCropDecayRate(s.difficulty);

    for (final dome in s.domes) {
      var updatedCells = List<CropCell>.from(dome.cells);

      for (int i = 0; i < updatedCells.length; i++) {
        final cell = updatedCells[i];
        if (cell.state != CropState.growing && cell.state != CropState.ready) continue;

        final crop = _config.getCrop(cell.cropId ?? '');
        if (crop == null) continue;

        // Step 4: Decay check — die if not watered and crop requires water
        if (cell.state == CropState.growing &&
            crop.canDecay &&
            crop.decayIfNotWatered &&
            !cell.wateredThisWeek) {
          // Decay rate modifies probability: hard mode = 2x more likely to die
          if (decayRate >= 1.0 || (decayRate * 100) > (50 + (cell.healthPercent * 0.5))) {
            updatedCells[i] = cell.copyWith(state: CropState.dead);
            cropsDied++;
            events.add('💀 ${crop.name} in ${dome.name} died — not watered.');
            continue;
          }
        }

        // Step 5: Neon Berry — die if ready and not harvested this turn
        if (cell.state == CropState.ready &&
            crop.canDecay &&
            crop.decayIfNotHarvestedOnReady) {
          updatedCells[i] = cell.copyWith(state: CropState.dead);
          cropsDied++;
          events.add('💀 ${crop.name} in ${dome.name} rotted — left unharvested!');
          continue;
        }

        // Step 3: Growth tick
        if (cell.state == CropState.growing) {
          final fertilizeBonus = cell.fertilizedThisWeek ? crop.fertilizerBonus : 1.0;
          // Fertilizer can effectively add a fraction of a week's growth
          final newWeeksGrown = cell.weeksGrown + 1;
          final effectiveGrowth = fertilizeBonus > 1.0 ? newWeeksGrown + (fertilizeBonus - 1.0) : newWeeksGrown.toDouble();

          if (effectiveGrowth >= crop.growthWeeks) {
            updatedCells[i] = cell.copyWith(
              state: CropState.ready,
              weeksGrown: crop.growthWeeks,
              wateredThisWeek: false,
              fertilizedThisWeek: false,
            );
            events.add('✅ ${crop.name} in ${dome.name} are ready to harvest!');
          } else {
            updatedCells[i] = cell.copyWith(
              weeksGrown: newWeeksGrown,
              wateredThisWeek: false,
              fertilizedThisWeek: false,
            );
          }
        }
      }

      updatedDomesAfterGrowth.add(dome.copyWith(cells: updatedCells));
    }

    s = s.copyWith(
      domes: updatedDomesAfterGrowth,
      totalCropsHarvested: s.totalCropsHarvested + cropsHarvested,
    );

    // ── Step 6: Silo overflow → compost ───────────────────────────────────
    // (Full silo handling deferred to Phase 3 when selling is implemented)

    // ── Step 7: Milestone checks ──────────────────────────────────────────
    final updatedMilestones = <Milestone>[];
    var pendingStrikeIncrease = false;

    for (final milestone in s.milestones) {
      if (milestone.status != MilestoneStatus.pending) {
        updatedMilestones.add(milestone);
        continue;
      }

      // Check completion
      if (s.totalVolumeDeliveredM3 >= milestone.targetVolumeM3) {
        updatedMilestones.add(milestone.copyWith(status: MilestoneStatus.completed));
        final scripReward = milestone.rewardScrip;
        s = s.copyWith(
          resources: s.resources.copyWith(
            starScrip: s.resources.starScrip + scripReward,
          ),
          lifetimeScripEarned: s.lifetimeScripEarned + scripReward,
        );
        milestoneUpdates.add('🎖️ Milestone complete: ${milestone.name} (+$scripReward 🎫)');
        events.add('🎖️ Milestone complete: ${milestone.name}! Reward: $scripReward Star-Scrip');
        continue;
      }

      // Check overdue
      if (s.currentWeek >= milestone.byWeek) {
        switch (s.difficulty) {
          case Difficulty.easy:
            updatedMilestones.add(milestone.copyWith(status: MilestoneStatus.warned));
            events.add('⚠️ Milestone missed: ${milestone.name} — warning issued by colony.');
            milestoneUpdates.add('⚠️ Missed: ${milestone.name} (warning only on Easy)');
          case Difficulty.normal:
            updatedMilestones.add(milestone.copyWith(status: MilestoneStatus.failed));
            pendingStrikeIncrease = true;
            events.add('❌ Milestone missed: ${milestone.name} — strike issued!');
            milestoneUpdates.add('❌ Strike! Missed: ${milestone.name}');
          case Difficulty.hard:
            updatedMilestones.add(milestone.copyWith(status: MilestoneStatus.failed));
            events.add('❌ Milestone missed: ${milestone.name} — contract terminated!');
            milestoneUpdates.add('❌ Contract terminated! Missed: ${milestone.name}');
            s = s.copyWith(status: GameStatus.terminated);
        }
        continue;
      }

      updatedMilestones.add(milestone);
    }

    var newStrikeCount = s.strikeCount + (pendingStrikeIncrease ? 1 : 0);
    var newStatus = s.status;
    if (s.difficulty == Difficulty.normal && newStrikeCount >= 3) {
      newStatus = GameStatus.terminated;
      events.add('❌ Three strikes — the colony has terminated your contract.');
    }

    s = s.copyWith(
      milestones: updatedMilestones,
      strikeCount: newStrikeCount,
      status: newStatus,
    );

    // ── Step 8: Trophy checks ─────────────────────────────────────────────
    final trophyResult = _checkTrophies(s, newTrophies);
    s = trophyResult.$1;
    newTrophies.addAll(trophyResult.$2);

    // ── Step 9: Relay mood decay ──────────────────────────────────────────
    final moodConfig = _config.moodSystemConfig;
    final moodDecay = moodConfig['mood_decay_per_week'] as int? ?? 3;
    s = s.copyWith(
      relay: s.relay.copyWith(
        mood: (s.relay.mood - moodDecay).clamp(0, 100),
        contractsRefreshedThisWeek: false,
      ),
    );

    // ── Step 10: Radio transmission ───────────────────────────────────────
    final newRadio = _generateRadioTransmission(s);
    if (newRadio != null) {
      s = s.copyWith(
        radioFeed: [...s.radioFeed, newRadio],
      );
    }

    // ── Step 11: Advance week ─────────────────────────────────────────────
    final nextWeek = s.currentWeek + 1;
    s = s.copyWith(currentWeek: nextWeek);

    // ── Step 12: Build summary ────────────────────────────────────────────
    final summary = WeekSummary(
      week: state.currentWeek,
      scripReceived: scripReceived,
      scripSpent: 0,
      cropsHarvested: cropsHarvested,
      cropsDied: cropsDied,
      volumeToColonyM3: volumeToColony,
      newTrophies: newTrophies,
      milestoneUpdates: milestoneUpdates,
      contractUpdates: contractUpdates,
      raidOccurred: false,
      resourceChanges: resourceChanges,
      robotActions: robotActions,
      newWeek: nextWeek,
      events: events,
    );

    return (s, summary);
  }

  // ─── Harvest a single cell ────────────────────────────────────────────────

  (Resources, CropCell) _harvestCell(CropCell cell, Resources resources, GameState state) {
    final crop = _config.getCrop(cell.cropId ?? '');
    if (crop == null) {
      return (resources, cell.cleared());
    }

    var updatedResources = resources;

    // Award resource yields (cyber-organic crops)
    if (crop.yieldsResource != null) {
      switch (crop.yieldsResource!) {
        case 'metals':
          updatedResources = updatedResources.copyWith(
            metals: updatedResources.metals + crop.resourceYieldAmount,
          );
        case 'sand':
          updatedResources = updatedResources.copyWith(
            sand: updatedResources.sand + crop.resourceYieldAmount,
          );
        case 'components':
          updatedResources = updatedResources.copyWith(
            components: updatedResources.components + crop.resourceYieldAmount,
          );
        case 'power_kwh':
        // Battery bulbs give instant power boost — handled as scrip bonus
          updatedResources = updatedResources.copyWith(
            starScrip: updatedResources.starScrip + crop.resourceYieldAmount,
          );
      }
    }

    // Add to seeds (10% chance of seed return per harvest)
    // Simple: every harvest returns 1 seed
    updatedResources = updatedResources.copyWith(
      seeds: updatedResources.seeds + 1,
    );

    return (updatedResources, cell.cleared());
  }

  // ─── Trophy checker ───────────────────────────────────────────────────────

  (GameState, List<String>) _checkTrophies(GameState state, List<String> alreadyEarned) {
    var s = state;
    final earned = <String>[];

    for (final trophy in s.trophies) {
      if (trophy.status == TrophyStatus.unlocked) continue;

      bool shouldUnlock = false;

      switch (trophy.id) {
        case 'first_harvest':
          shouldUnlock = s.totalCropsHarvested >= 1;
        case 'century_farmer':
          shouldUnlock = s.currentWeek >= 100;
        case 'solar_millionaire':
          shouldUnlock = s.lifetimeScripEarned >= 10000;
        case 'five_domes':
          shouldUnlock = s.domes.length >= 5;
        case 'robot_army':
          shouldUnlock = s.domes.where((d) => d.robot != null && d.robot!.state != RobotState.offline).length >= 3;
        case 'compost_king':
          shouldUnlock = s.totalCompostGenerated >= 1000;
        case 'relay_friend':
          shouldUnlock = s.completedContracts.length >= 10;
        case 'no_miss_10':
        // Checked via events — skip for now, Phase 4
          break;
        case 'speed_harvest':
        // 5 crops in one week — tracked in summary
          break;
      }

      if (shouldUnlock) {
        final updated = trophy.unlock(s.currentWeek);
        earned.add('🏆 Trophy unlocked: ${trophy.name}');
        final updatedTrophies = s.trophies.map((t) => t.id == trophy.id ? updated : t).toList();
        s = s.copyWith(trophies: updatedTrophies);
      }
    }

    return (s, earned);
  }

  // ─── Radio transmission generator ────────────────────────────────────────

  RadioTransmission? _generateRadioTransmission(GameState state) {
    // Generate a transmission every 3-5 weeks
    if (state.currentWeek % 3 != 0) return null;

    final templates = _config.radioTransmissionTemplates;
    if (templates.isEmpty) return null;

    final index = state.currentWeek % templates.length;
    var message = templates[index];

    // Replace template variables
    message = message.replaceAll('{week}', '${state.currentWeek}');
    final colonyPercent = ((state.totalVolumeDeliveredM3 / 100) * 100).clamp(0, 100).toInt();
    message = message.replaceAll('{colony_food_percent}', '$colonyPercent');

    return RadioTransmission(
      week: state.currentWeek,
      message: message,
      isRead: false,
    );
  }
}