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

    // ── Step 0: Water purifier passive output ────────────────────────────────
    final waterOutput = _config.getWaterOutputForLevel(s.waterPurifierLevel);
    if (waterOutput > 0) {
      s = s.copyWith(
        resources: s.resources.copyWith(
          water: s.resources.water + waterOutput,
        ),
      );
      events.add('💧 Water purifier output: +${waterOutput}m³');
    }

    // ── Step 0a: Dome Bot processing ─────────────────────────────────────────
    // Order: water → fertilize → (growth happens later) → harvest → plant
        {
      int botWatered = 0, botHarvested = 0, botFertilized = 0, botPlanted = 0;
      final config = GameConfigService.instance;
      final updatedDomes = <Dome>[];

      for (final dome in s.domes) {
        final bot = dome.domeBot;
        if (bot == null) { updatedDomes.add(dome); continue; }

        var cells = List<CropCell>.from(dome.cells);
        var resources = s.resources;

        // WATER — bot waters all growing cells (costs water)
        if (bot.canWater) {
          for (var i = 0; i < cells.length; i++) {
            final cell = cells[i];
            if (cell.cropId == null) continue;
            final crop = config.getCrop(cell.cropId!);
            if (crop == null) continue;
            final waterNeeded = crop.waterPerWeek.toDouble();
            if (resources.water >= waterNeeded) {
              cells[i] = cell.copyWith(wateredThisWeek: true);
              resources = resources.copyWith(water: resources.water - waterNeeded);
              botWatered++;
            }
          }
        }

        // FERTILIZE — bot fertilizes unwatered growing cells using compost
        if (bot.canFertilize) {
          for (var i = 0; i < cells.length; i++) {
            final cell = cells[i];
            if (cell.cropId == null || cell.state == CropState.empty) continue;
            if (!cell.fertilizedThisWeek && resources.compost >= 2) {
              cells[i] = cell.copyWith(fertilizedThisWeek: true);
              resources = resources.copyWith(compost: resources.compost - 2);
              botFertilized++;
            }
          }
        }

        s = s.copyWith(resources: resources);

        // HARVEST — bot harvests ready crops into silo
        if (bot.canHarvest) {
          final updatedInv = Map<String, double>.from(s.siloInventory);
          for (var i = 0; i < cells.length; i++) {
            final cell = cells[i];
            if (cell.state != CropState.ready || cell.cropId == null) continue;
            final crop = config.getCrop(cell.cropId!);
            if (crop == null) continue;
            updatedInv[cell.cropId!] = (updatedInv[cell.cropId!] ?? 0) + 1;
            cells[i] = cell.cleared();
            botHarvested++;
          }
          s = s.copyWith(
            siloInventory: updatedInv,
            totalCropsHarvested: s.totalCropsHarvested + botHarvested,
          );
        }

        // PLANT — bot plants empty cells with configured crop
        if (bot.canPlant && bot.plantCropId != null) {
          final crop = config.getCrop(bot.plantCropId!);
          if (crop != null) {
            for (var i = 0; i < cells.length; i++) {
              final cell = cells[i];
              if (cell.state == CropState.empty) {
                cells[i] = CropCell(
                  position: cell.position,
                  cropId: bot.plantCropId,
                  state: CropState.planted,
                  weeksGrown: 0,
                  wateredThisWeek: false,
                  fertilizedThisWeek: false,
                );
                botPlanted++;
              }
            }
          }
        }

        updatedDomes.add(dome.copyWith(cells: cells));
      }

      s = s.copyWith(domes: updatedDomes);

      if (botWatered > 0 || botHarvested > 0 || botFertilized > 0 || botPlanted > 0) {
        final parts = <String>[];
        if (botWatered > 0) parts.add('watered $botWatered cells');
        if (botFertilized > 0) parts.add('fertilized $botFertilized cells');
        if (botHarvested > 0) parts.add('harvested $botHarvested crops');
        if (botPlanted > 0) parts.add('planted $botPlanted seeds');
        events.add('🤖 Dome Bots: ${parts.join(', ')}');
        robotActions.add('Dome Bots: ${parts.join(', ')}');
      }
    }

    // ── Step 0b: Mining drone output ─────────────────────────────────────────
    if (s.miningDrones.isNotEmpty) {
      var moonDirt = 0.0, ore = 0.0, sand = 0.0, chemicals = 0.0;
      for (final drone in s.miningDrones) {
        if (drone.isBalanced) {
          final share = drone.outputPerWeek / 4;
          moonDirt += share; ore += share; sand += share; chemicals += share;
        } else {
          switch (drone.assignedResource!) {
            case 'moon_dirt': moonDirt += drone.outputPerWeek;
            case 'ore': ore += drone.outputPerWeek;
            case 'sand': sand += drone.outputPerWeek;
            case 'chemicals': chemicals += drone.outputPerWeek;
          }
        }
      }
      if (moonDirt > 0 || ore > 0 || sand > 0 || chemicals > 0) {
        s = s.copyWith(
          resources: s.resources.copyWith(
            moonDirt: s.resources.moonDirt + moonDirt,
            ore: s.resources.ore + ore,
            sand: s.resources.sand + sand,
            chemicals: s.resources.chemicals + chemicals,
          ),
        );
        final parts = [
          if (moonDirt > 0) '+${moonDirt.toStringAsFixed(1)} dirt',
          if (ore > 0) '+${ore.toStringAsFixed(1)} ore',
          if (sand > 0) '+${sand.toStringAsFixed(1)} sand',
          if (chemicals > 0) '+${chemicals.toStringAsFixed(1)} chem',
        ];
        events.add('⛏️ Mining drones: ${parts.join(', ')}');
      }
    }

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
    final siloUpdates = <String, double>{};  // robot harvests → silo

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

        // Harvest ready crops → deposit to silo
        if (robot.canHarvest && cell.state == CropState.ready) {
          final cropId = cell.cropId!;
          final crop = _config.getCrop(cropId);
          if (crop != null) {
            siloUpdates[cropId] = (siloUpdates[cropId] ?? 0) + 1.0;
            resourcesAfterRobots = resourcesAfterRobots.copyWith(
              seeds: resourcesAfterRobots.seeds + 1,
            );
            cropsHarvested++;
            actions.add('harvested ${crop.name}');
          }
          updatedCells[i] = cell.cleared();
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

    // Merge robot harvest into silo inventory
    final siloAfterRobots = Map<String, double>.from(s.siloInventory);
    for (final entry in siloUpdates.entries) {
      siloAfterRobots[entry.key] = (siloAfterRobots[entry.key] ?? 0) + entry.value;
    }

    s = s.copyWith(
      domes: updatedDomesAfterRobots,
      resources: resourcesAfterRobots,
      siloInventory: siloAfterRobots,
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
        conversationDoneThisWeek: false,  // reset so player must talk again
      ),
    );

    // ── Step 10: Radio transmission ───────────────────────────────────────
    final newRadio = _generateRadioTransmission(s);
    if (newRadio != null) {
      s = s.copyWith(
        radioFeed: [...s.radioFeed, newRadio],
      );
    }

    // ── Step 10b: Ship window reset ──────────────────────────────────────────
    if (s.currentWeek >= s.nextShipWindowWeek) {
      s = s.copyWith(
        nextShipWindowWeek: s.nextShipWindowWeek + _config.shipWindowInterval,
        shipmentsThisWindow: 0,
      );
    }

    // ── Step 10c: Raid scheduling ─────────────────────────────────────────────
    if (s.currentWeek >= s.nextRaidWeek && !s.raidDefendedThisWeek) {
      final wallDamage = (s.defenseWall.maxHp * 0.25).round();
      s = s.copyWith(defenseWall: s.defenseWall.takeDamage(wallDamage));
      events.add('⚠️ Raid was skipped — wall took $wallDamage damage!');
    }
    if (s.currentWeek >= s.nextRaidWeek) {
      final interval = switch (s.difficulty) {
        Difficulty.easy   => 12,
        Difficulty.normal => 10,
        Difficulty.hard   => 6,
      };
      s = s.copyWith(
        nextRaidWeek: s.nextRaidWeek + interval,
        raidDefendedThisWeek: false,
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