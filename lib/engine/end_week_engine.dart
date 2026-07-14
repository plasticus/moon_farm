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
//   8. Relay mood decay
//   9. Generate radio transmission
//  10. Advance week counter
//  11. Generate week summary
//  12. Persist to DB

import '../models/game_models.dart';
import '../config/game_config_service.dart';
import '../config/raid_config_service.dart';
import '../config/milestone_config_service.dart';
import '../config/upgrade_config_service.dart';
import '../config/radio_config_service.dart';
import 'radio_trigger_engine.dart';

class EndWeekEngine {
  final GameConfigService _config = GameConfigService.instance;

  /// Computes the actual harvested yield (units) for a cell, factoring in:
  ///  - decay: healthPercent acts as a yield multiplier (100 = full)
  ///  - fertilizer: each application stacks fertilizerBonus multiplicatively
  /// Base yield is 1 unit per cell before modifiers.
  double _cellYield(CropCell cell, CropConfig crop) {
    final healthMult = (cell.healthPercent / 100.0).clamp(0.0, 1.0);
    double fertMult = 1.0;
    for (int i = 0; i < cell.fertilizeCount; i++) {
      fertMult *= crop.fertilizerBonus;
    }
    final units = 1.0 * healthMult * fertMult;
    return units < 0 ? 0 : units;
  }

  /// Adds a quantity of a named resource to a bundle (for resource-yielding crops).
  Resources _addResource(Resources r, String key, double amt) {
    return switch (key) {
      'sand' => r.copyWith(sand: r.sand + amt),
      'ore' => r.copyWith(ore: r.ore + amt),
      'moon_dirt' => r.copyWith(moonDirt: r.moonDirt + amt),
      'chemicals' => r.copyWith(chemicals: r.chemicals + amt),
      'metals' => r.copyWith(metals: r.metals + amt),
      'glass' => r.copyWith(glass: r.glass + amt),
      'components' => r.copyWith(components: r.components + amt),
      'water' => r.copyWith(water: r.water + amt),
      'moss' => r.copyWith(moss: r.moss + amt),
      'chitin' => r.copyWith(chitin: r.chitin + amt),
      'meat' => r.copyWith(meat: r.meat + amt),
      _ => r, // power_kwh and unknowns ignored (no battery bulbs anymore)
    };
  }

  /// Reads a named resource's current amount (for feed/fertilize checks).
  double _resourceAmount(Resources r, String key) {
    return switch (key) {
      'sand' => r.sand,
      'ore' => r.ore,
      'moon_dirt' => r.moonDirt,
      'chemicals' => r.chemicals,
      'metals' => r.metals,
      'glass' => r.glass,
      'components' => r.components,
      'water' => r.water,
      'moss' => r.moss,
      'chitin' => r.chitin,
      'meat' => r.meat,
      'compost' => r.compost,
      _ => 0,
    };
  }

  /// Main entry point. Takes current state, returns (newState, summary).
  (GameState, WeekSummary) processEndWeek(GameState state) {
    final events = <String>[];
    final robotActions = <String>[];
    int scripReceived = 0;
    int cropsHarvested = 0;
    int cropsDied = 0;
    double volumeToColony = 0;
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

    // (Bot harvest now runs AFTER growth tick — see below — so it catches
    //  crops that just became ready this week, not just leftovers from before.)

    // ── Step 0b: Dome Bot water / fertilize / plant ──────────────────────────
        {
      int botWatered = 0, botFertilized = 0;
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

        // FERTILIZE / FEED — bot fertilizes with compost, or for crops that
        // require feeding (e.g. Gristle Pod, fed meat), feeds that instead.
        if (bot.canFertilize) {
          for (var i = 0; i < cells.length; i++) {
            final cell = cells[i];
            if (cell.cropId == null || cell.state == CropState.empty) continue;
            final crop = config.getCrop(cell.cropId!);
            if (crop == null) continue;
            final feedKey = crop.feedResource; // null = compost
            final available = feedKey == null ? resources.compost : _resourceAmount(resources, feedKey);
            // Check cooldown and max fertilizations
            final canFert = !cell.fertilizedThisWeek &&
                cell.fertilizeCount < crop.maxFertilizations &&
                (cell.lastFertilizeWeek < 0 ||
                    cell.weeksGrown - cell.lastFertilizeWeek >= 3) &&
                available >= 2;
            if (canFert) {
              cells[i] = cell.copyWith(
                fertilizedThisWeek: true,
                fertilizeCount: cell.fertilizeCount + 1,
                lastFertilizeWeek: cell.weeksGrown,
              );
              resources = feedKey == null
                  ? resources.copyWith(compost: resources.compost - 2)
                  : _addResource(resources, feedKey, -2);
              botFertilized++;
            }
          }
        }

        s = s.copyWith(resources: resources);
        updatedDomes.add(dome.copyWith(cells: cells));
      }

      s = s.copyWith(domes: updatedDomes);

      if (botWatered > 0 || botFertilized > 0) {
        final parts = <String>[];
        if (botWatered > 0) parts.add('watered $botWatered cells');
        if (botFertilized > 0) parts.add('fertilized $botFertilized cells');
        events.add('🤖 Dome Bots: ${parts.join(', ')}');
        robotActions.add('Dome Bots: ${parts.join(', ')}');
      }
    }

    // ── Step 0c: Auto-Refine (Mk10 machines craft max possible automatically) ──
        {
      final upgrades = UpgradeConfigService.instance;
      var resources = s.resources;
      final autoRefineLog = <String>[];

      Resources subtract(Resources r, String key, double amt) {
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

      Resources add(Resources r, String key, double amt) {
        return switch (key) {
          'z_soil' => r.copyWith(zSoil: r.zSoil + amt),
          'metals' => r.copyWith(metals: r.metals + amt),
          'glass' => r.copyWith(glass: r.glass + amt),
          'components' => r.copyWith(components: r.components + amt),
          'compost' => r.copyWith(compost: r.compost + amt),
          _ => r,
        };
      }

      double getHave(Resources r, String key) {
        return switch (key) {
          'compost' => r.compost,
          'ore' => r.ore,
          'moon_dirt' => r.moonDirt,
          'chemicals' => r.chemicals,
          'water' => r.water,
          'sand' => r.sand,
          'metals' => r.metals,
          'glass' => r.glass,
          'components' => r.components,
          _ => 0,
        };
      }

      for (final refinery in s.refineries) {
        for (final machine in refinery.machines) {
          if (machine.level < 10 || !machine.autoRefine) continue;
          final levelCfg = upgrades.getMachineLevel(machine.yamlKey, machine.level);
          if (levelCfg == null) continue;
          final recipeIn = Map<String, dynamic>.from(levelCfg['recipe_in'] as Map? ?? {});
          final recipeOut = Map<String, dynamic>.from(levelCfg['recipe_out'] as Map? ?? {});
          if (recipeIn.isEmpty) continue;

          int maxN = 999;
          for (final e in recipeIn.entries) {
            final needed = (e.value as num).toDouble();
            if (needed <= 0) continue;
            final have = getHave(resources, e.key);
            final n = (have / needed).floor();
            if (n < maxN) maxN = n;
          }
          maxN = maxN.clamp(0, 999);
          if (maxN <= 0) continue;

          for (final e in recipeIn.entries) {
            resources = subtract(resources, e.key, (e.value as num).toDouble() * maxN);
          }
          for (final e in recipeOut.entries) {
            resources = add(resources, e.key, (e.value as num).toDouble() * maxN);
          }
          autoRefineLog.add('${machine.emoji} ${machine.name} ×$maxN');
        }
      }

      if (autoRefineLog.isNotEmpty) {
        s = s.copyWith(resources: resources);
        events.add('🔁 Auto-Refine: ${autoRefineLog.join(', ')}');
      }
    }

    // ── Step 0b: Scavenger drone output ─────────────────────────────────────────
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
        events.add('⛏️ Scavenger drones: ${parts.join(', ')}');
      }
    }

    // ── Step 1: Process pending sales (ship window weeks only) ───────────────
    if (s.pendingSales.isNotEmpty && s.isShipWindowOpen) {
      int earned = 0;
      int scrapSaleCount = 0;
      int scrapTotalScrip = 0;

      for (final sale in s.pendingSales) {
        earned += sale.scripValue;
        final isContract = sale.resourceId.startsWith('contract_');
        final isScrap = sale.resourceId.startsWith('scrap_');
        if (isScrap) {
          scrapSaleCount++;
          scrapTotalScrip += sale.scripValue;
          continue;
        }
        if (sale.amount <= 0) continue;
        if (isContract) {
          events.add(sale.scripValue > 0
              ? '📦 Contract delivered: ${sale.amount.toStringAsFixed(1)}m³ → +${sale.scripValue} 🎫'
              : '📦 Contract cargo staged: ${sale.amount.toStringAsFixed(1)}m³ (bonus pays on completion)');
        } else {
          events.add('📦 Shipment delivered: ${sale.amount.toStringAsFixed(1)}m³ → +${sale.scripValue} 🎫');
        }
      }

      // Combine all scrap pickups into one grouped line using dam³,
      // matching the dashboard Outgoing Shipments display.
      if (scrapSaleCount > 0) {
        final bulk = _config.scrapDealerBulkAmount;
        final totalDam = (scrapSaleCount * bulk / 1000).toStringAsFixed(1);
        events.add('🔧 Scrap pickup: ${totalDam}dam³ → +$scrapTotalScrip 🎫');
      }
      // Migration safety net: older saves may still be carrying a
      // pre-existing pendingContractScrip balance from before contract
      // rewards were attached directly to their completing shipment.
      if (s.pendingContractScrip > 0) {
        earned += s.pendingContractScrip;
        events.add('📋 Contract bonus paid: +${s.pendingContractScrip} 🎫');
      }
      scripReceived = earned;
      s = s.copyWith(
        resources: s.resources.copyWith(
          starScrip: s.resources.starScrip + earned,
        ),
        pendingSales: [],
        pendingContractScrip: 0,
        lifetimeScripEarned: s.lifetimeScripEarned + earned,
      );
      resourceChanges['star_scrip'] = earned.toDouble();
    }

    // ── Step 2: Robot actions (removed) ───────────────────────────────────────
    // DomeRobot (the legacy 5-level robot with health/wear) has been removed.
    // Automation is handled by DomeBot (Steps 4b/4c).

    // ── Step 3 & 4: Crop growth + decay ───────────────────────────────────
    final updatedDomesAfterGrowth = <Dome>[];

    for (final dome in s.domes) {
      var updatedCells = List<CropCell>.from(dome.cells);

      for (int i = 0; i < updatedCells.length; i++) {
        final cell = updatedCells[i];
        if (cell.state != CropState.growing && cell.state != CropState.ready) {
          // Transition planted → growing
          if (cell.state == CropState.planted && cell.cropId != null) {
            updatedCells[i] = cell.copyWith(state: CropState.growing);
          }
          continue;
        }

        final crop = _config.getCrop(cell.cropId ?? '');
        if (crop == null) continue;

        // Step 4: Decay — missing water reduces yield (healthPercent), doesn't kill.
        // healthPercent acts as the yield multiplier at harvest.
        if (cell.state == CropState.growing && !cell.wateredThisWeek) {
          final lossPct = (crop.decayRate * 100).round();
          final newHealth = (cell.healthPercent - lossPct).clamp(0, 100);
          updatedCells[i] = cell.copyWith(healthPercent: newHealth);
          events.add('🥀 ${crop.name} in ${dome.name} lost $lossPct% yield — not watered.');
          // fall through to growth tick using the updated cell
        }

        // Step 4b: Feed decay — crops that must be FED (e.g. Gristle Pod, fed
        // meat instead of fertilized with compost) take the same yield hit as
        // a missed watering if a scheduled feeding window passes unfed. Same
        // 3-week cadence as the optional fertilize cooldown, just mandatory.
        if (cell.state == CropState.growing && crop.feedResource != null) {
          final feedDue = cell.lastFertilizeWeek < 0
              ? cell.weeksGrown >= 3
              : cell.weeksGrown - cell.lastFertilizeWeek >= 3;
          if (feedDue && !cell.fertilizedThisWeek) {
            final lossPct = (crop.decayRate * 100).round();
            final base = updatedCells[i];
            final newHealth = (base.healthPercent - lossPct).clamp(0, 100);
            updatedCells[i] = base.copyWith(
              healthPercent: newHealth,
              lastFertilizeWeek: cell.weeksGrown, // resets the due-clock
            );
            events.add('🍂 ${crop.name} in ${dome.name} lost $lossPct% yield — not fed.');
          }
        }

        final workingCell = updatedCells[i];

        // Step 3: Growth tick. Fertilizer adds growth speed (multiplicative on progress).
        if (workingCell.state == CropState.growing) {
          final newWeeksGrown = workingCell.weeksGrown + 1;
          if (newWeeksGrown >= crop.growthWeeks) {
            updatedCells[i] = workingCell.copyWith(
              state: CropState.ready,
              weeksGrown: crop.growthWeeks,
              wateredThisWeek: false,
              fertilizedThisWeek: false,
            );
            events.add('✅ ${crop.name} in ${dome.name} are ready to harvest!');
          } else {
            updatedCells[i] = workingCell.copyWith(
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

    // ── Step 4b: Bot harvest (runs right after growth tick, so crops that just
    //    became ready THIS week get harvested immediately — player sees empty
    //    cells ready to plant when they open the dome) ─────────────────────────
        {
      int botHarvested = 0;
      final config = GameConfigService.instance;
      final updatedDomes = <Dome>[];
      var cropCounts = Map<String, int>.from(s.cropHarvestCounts);
      var vatJustUnlocked = false;

      for (final dome in s.domes) {
        final bot = dome.domeBot;

        if (bot == null) {
          updatedDomes.add(dome);
          continue;
        }
        if (!bot.canHarvest) {
          updatedDomes.add(dome);
          continue;
        }

        var cells = List<CropCell>.from(dome.cells);
        final updatedInv = Map<String, double>.from(s.siloInventory);
        var harvestRes = s.resources;
        int domeHarvested = 0;

        for (var i = 0; i < cells.length; i++) {
          final cell = cells[i];
          if (cell.state != CropState.ready || cell.cropId == null) continue;
          final crop = config.getCrop(cell.cropId!);
          if (crop == null) continue;
          final yieldAmount = _cellYield(cell, crop);
          if (crop.yieldsResource != null) {
            harvestRes = _addResource(harvestRes, crop.yieldsResource!,
                crop.resourceYieldAmount * yieldAmount);
          } else {
            updatedInv[cell.cropId!] = (updatedInv[cell.cropId!] ?? 0) + yieldAmount;
          }
          harvestRes = harvestRes.copyWith(
            compost: harvestRes.compost + crop.compostYield,
          );
          cropCounts[cell.cropId!] = (cropCounts[cell.cropId!] ?? 0) + 1;
          if (cell.cropId == 'hyper_mycelium' &&
              cropCounts['hyper_mycelium'] == 1 &&
              !s.unlockedFeatures.contains('mycoculture_vat')) {
            vatJustUnlocked = true;
          }
          cells[i] = cell.cleared();
          domeHarvested++;
          botHarvested++;
        }

        s = s.copyWith(
          siloInventory: updatedInv,
          resources: harvestRes,
          totalCropsHarvested: s.totalCropsHarvested + domeHarvested,
        );
        updatedDomes.add(dome.copyWith(cells: cells));
      }

      s = s.copyWith(domes: updatedDomes, cropHarvestCounts: cropCounts);

      if (vatJustUnlocked) {
        s = s.copyWith(
          unlockedFeatures: [...s.unlockedFeatures, 'mycoculture_vat'],
        );
        events.add('🧫 Something new growing in the Hyper-Mycelium — Mycoculture Vat unlocked at the Refinery!');
      }

      if (botHarvested > 0) {
        events.add('🤖 Dome bots harvested $botHarvested crop${botHarvested == 1 ? '' : 's'}');
      }
    }

    // ── Step 4c: Bot plant (runs right after harvest, using THIS week's
    //    freshly emptied cells — not last week's stale state) ─────────────────
        {
      final config = GameConfigService.instance;
      final updatedDomes = <Dome>[];
      int totalPlanted = 0;

      for (final dome in s.domes) {
        final bot = dome.domeBot;
        if (bot == null) { updatedDomes.add(dome); continue; }

        var cells = List<CropCell>.from(dome.cells);

        if (bot.canPlant && bot.plantCropId != null) {
          final crop = config.getCrop(bot.plantCropId!);
          if (crop != null) {
            for (var i = 0; i < cells.length; i++) {
              final cell = cells[i];
              if (cell.state == CropState.empty && s.resources.seeds > 0) {
                cells[i] = CropCell(
                  position: cell.position,
                  cropId: bot.plantCropId,
                  state: CropState.planted,
                  weeksGrown: 0,
                  wateredThisWeek: false,
                  fertilizedThisWeek: false,
                );
                totalPlanted++;
                s = s.copyWith(
                  resources: s.resources.copyWith(seeds: s.resources.seeds - 1),
                );
              }
            }
          }
        }

        updatedDomes.add(dome.copyWith(cells: cells));
      }

      s = s.copyWith(domes: updatedDomes);

      if (totalPlanted > 0) {
        events.add('🤖 Dome bots planted $totalPlanted seed${totalPlanted == 1 ? '' : 's'}');
        robotActions.add('Dome bots planted $totalPlanted seeds');
      }
    }

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
            final hardMsg = '${milestone.failureMessage}\n${MilestoneConfigService.instance.formatFailureDetail(milestone, s.totalVolumeDeliveredM3)}';
            events.add('❌ Milestone missed: ${milestone.name} — contract terminated!');
            milestoneUpdates.add('❌ Contract terminated! Missed: ${milestone.name}');
            s = s.copyWith(
              status: GameStatus.terminated,
              terminationReason: hardMsg,
            );
        }
        continue;
      }

      updatedMilestones.add(milestone);
    }

    var newStrikeCount = s.strikeCount + (pendingStrikeIncrease ? 1 : 0);
    var newStatus = s.status;
    String? newTermReason = s.terminationReason;
    if (s.difficulty == Difficulty.normal && newStrikeCount >= 3) {
      newStatus = GameStatus.terminated;
      newTermReason = 'Three contract violations. The colony has terminated your agreement.';
      events.add('❌ Three strikes — the colony has terminated your contract.');
    }

    s = s.copyWith(
      milestones: updatedMilestones,
      strikeCount: newStrikeCount,
      status: newStatus,
      terminationReason: newTermReason,
    );

    // ── Step 9: Relay reset ───────────────────────────────────────────────────
    // Mood only changes via conversation — no automated decay.
    s = s.copyWith(
      relay: s.relay.copyWith(
        contractsRefreshedThisWeek: false,
        conversationDoneThisWeek: false,
      ),
    );

    // ── Step 10: Radio transmission ───────────────────────────────────────
    final radioFeedLengthBeforeThisWeek = s.radioFeed.length;
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
      final interval = RaidConfigService.instance.raidInterval(s.difficulty);
      s = s.copyWith(
        nextRaidWeek: s.nextRaidWeek + interval,
        raidDefendedThisWeek: false,
      );
    }

    // ── Step 11: Advance week ─────────────────────────────────────────────
    final nextWeek = s.currentWeek + 1;
    s = s.copyWith(currentWeek: nextWeek, manualRaidTriggeredThisWeek: false);

    // ── Step 11b: Pending deliveries that arrive this new week ─────────────
    if (s.pendingDeliveries.isNotEmpty) {
      final arrived = s.pendingDeliveries.where((d) => d.arrivalWeek <= nextWeek).toList();
      final remaining = s.pendingDeliveries.where((d) => d.arrivalWeek > nextWeek).toList();
      if (arrived.isNotEmpty) {
        var r = s.resources;
        for (final d in arrived) {
          r = switch (d.resourceKey) {
            'seeds' => r.copyWith(seeds: r.seeds + d.amount.toInt()),
            'water' => r.copyWith(water: r.water + d.amount),
            'chemicals' => r.copyWith(chemicals: r.chemicals + d.amount),
            'ore' => r.copyWith(ore: r.ore + d.amount),
            'glass' => r.copyWith(glass: r.glass + d.amount),
            'components' => r.copyWith(components: r.components + d.amount),
            _ => r,
          };
          events.add('📦 Delivery arrived: ${d.amount.toInt()} ${d.resourceKey}');
        }
        s = s.copyWith(resources: r, pendingDeliveries: remaining);
      }
    }

    // ── Step 11c: Scrap Dealer eligibility (one-time unlock) ───────────────
    if (!s.unlockedFeatures.contains('scrap_dealer')) {
      final bulk = _config.scrapDealerBulkAmount;
      final eligible = s.resources.metals >= bulk ||
          s.resources.chemicals >= bulk ||
          s.resources.glass >= bulk ||
          s.resources.components >= bulk;
      if (eligible) {
        s = s.copyWith(
          unlockedFeatures: [...s.unlockedFeatures, 'scrap_dealer'],
        );
        events.add('📻 Colony Radio: Kovacs\' scrap contact is now available on the Relay sell screen.');
      }
    }

    // ── Step 11d: Radio triggers (config-driven, radio_triggers.toml) ──────
    // Catches every week/lifetime-counter/dome-count/feature-unlock trigger
    // in one pass, now that all of this week's state changes are settled.
    s = checkRadioTriggers(s);

    // Whatever's new in radioFeed since the start of Step 10 (pool message
    // + any triggers that fired this exact pass) is "this week's broadcast"
    // for the week summary screen — not a TOML lookup of the most recent
    // tip from however long ago, which would just repeat forever once
    // there's nothing left to advance past.
    final newRadioMessages = s.radioFeed
        .skip(radioFeedLengthBeforeThisWeek)
        .map((t) => t.message)
        .toList();

    // ── Step 12: Build summary ────────────────────────────────────────────
    final summary = WeekSummary(
      week: state.currentWeek,
      scripReceived: scripReceived,
      scripSpent: 0,
      cropsHarvested: cropsHarvested,
      cropsDied: cropsDied,
      volumeToColonyM3: volumeToColony,
      milestoneUpdates: milestoneUpdates,
      contractUpdates: contractUpdates,
      raidOccurred: false,
      resourceChanges: resourceChanges,
      robotActions: robotActions,
      newWeek: nextWeek,
      events: events,
      newRadioMessages: newRadioMessages,
    );

    return (s, summary);
  }


  // ─── Radio transmission generator ────────────────────────────────────────

  RadioTransmission? _generateRadioTransmission(GameState state) {
    // Generate a transmission every 3-5 weeks
    if (state.currentWeek % 3 != 0) return null;

    final pool = RadioConfigService.instance.pool;
    if (pool.isEmpty) return null;

    final index = state.currentWeek % pool.length;
    var message = pool[index];

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