// ═══════════════════════════════════════════════════════════════
//  lib/utils/game_factory.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/game_models.dart';
import '../config/game_config_service.dart';
import '../config/upgrade_config_service.dart';
import '../config/raid_config_service.dart';
import '../config/milestone_config_service.dart';
import '../engine/radio_trigger_engine.dart';
import '../config/radio_config_service.dart';

/// Creates a brand new GameState for a given save slot, farm name, and difficulty.
class GameFactory {
  static const _uuid = Uuid();
  static final _config = GameConfigService.instance;
  static final _rng = Random();

  static GameState createNewGame({
    required int slotNumber,
    required String farmName,
    required Difficulty difficulty,
  }) {
    final diffSettings = _config.getDifficultySettings(difficulty);
    final startingRes = diffSettings['starting_resources'] as Map<String, dynamic>;
    final startingScrip = diffSettings['starting_scrip'] as int;

    // Starting resources from config
    final resources = Resources(
      water: (startingRes['water'] as num).toDouble(),
      moonDirt: (startingRes['moon_dirt'] as num).toDouble(),
      chemicals: (startingRes['chemicals'] as num).toDouble(),
      zSoil: (startingRes['z_soil'] as num?)?.toDouble() ?? 10,
      seeds: startingRes['seeds'] as int,
      starScrip: startingScrip,
    );

    // Start with one basic dome
    final startingDome = _createNewDome(name: 'Dome 1', tier: 1);

    // One basic silo
    final startingSilo = _createNewSilo(tier: 1);

    // Starting refinery with free Mk1 composter and smelter
    final startingRefinery = Refinery(
      id: 'refinery_start',
      tier: 1,
      powerDraw: 8,
      unlockedRecipes: ['compost_to_zsoil'],
      machines: const [
        RefineryMachine(type: MachineType.composter, level: 1, powerDraw: 1),
        RefineryMachine(type: MachineType.smelter, level: 1, powerDraw: 2),
      ],
    );

    // Start with wind turbine — covers dome + sentry + drone without refined materials
    final startingPower = PowerSource(
      id: _uuid.v4(),
      type: PowerSourceType.windTurbine,
      outputKwh: 45,
    );

    // Load milestones from config
    final milestones = MilestoneConfigService.instance.getMilestones(difficulty);

    // Starting wall and grenades from difficulty config
    final wallLevel = diffSettings['starting_wall_level'] as int? ?? 1;
    final wallLevels = GameConfigService.instance.getDefenseWallLevels();
    final wallConfig = wallLevels.firstWhere(
          (l) => l['level'] == wallLevel,
      orElse: () => wallLevels.first,
    );
    final wallMaxHp = wallConfig['hp'] as int;

    final grenadesConfig = diffSettings['starting_grenades'] as Map<String, dynamic>? ?? {};
    final startingGrenades = grenadesConfig.map(
          (k, v) => MapEntry(k, v as int),
    );

    // Starting sentries
    final startingSentryCount = diffSettings['starting_sentries'] as int? ?? 0;
    final sentryLevels = GameConfigService.instance
        .getOperationsBuildings()['laser_sentry']?['levels'] as List? ?? [];
    final sentryConfig = sentryLevels.isNotEmpty
        ? sentryLevels.first as Map<String, dynamic>
        : null;
    final startingSentries = sentryConfig != null
        ? List.generate(startingSentryCount, (i) => LaserSentry(
      id: 'sentry_start_$i',
      level: 1,
      health: 100,
      powerDraw: sentryConfig['power_draw_kwh'] as int,
      damage: sentryConfig['damage'] as int,
      fireRate: sentryConfig['fire_rate'] as int,
      range: sentryConfig['range'] as int,
    ))
        : <LaserSentry>[];

    final initialState = GameState(
      gameId: DateTime.now().millisecondsSinceEpoch,
      slotNumber: slotNumber,
      farmName: farmName,
      difficulty: difficulty,
      currentWeek: 1,
      status: GameStatus.active,
      strikeCount: 0,
      resources: resources,
      domes: [startingDome],
      silos: [startingSilo],
      refineries: [startingRefinery],
      powerSources: [startingPower],
      laserSentries: startingSentries,
      activeContracts: [],
      completedContracts: [],
      milestones: milestones,
      log: [],
      radioFeed: const [],
      relay: RelayTechnicianState(
        mood: 30,  // starts sour — he's not happy about this posting
        availableContracts: [],
        contractsRefreshedThisWeek: false,
      ),
      totalVolumeDeliveredM3: 0,
      lifetimeScripEarned: startingScrip,
      totalCropsHarvested: 0,
      totalCompostGenerated: 0,
      nextRaidWeek: RaidConfigService.instance.firstRaidWeek,
      miningDrones: [
        MiningDrone(
          id: 'drone_start_0',
          tier: 1,
          assignedResource: null, // balanced
          outputPerWeek: 6.0,
          powerDraw: 3,
        ),
      ],
      defenseWall: DefenseWall(
        level: 1,
        currentHp: wallMaxHp,
        maxHp: wallMaxHp,
      ),
      grenades: GrenadeInventory(
        counts: startingGrenades,
        benchLevel: 1,
      ),
      raidDefendedThisWeek: false,
      totalRaidsDefended: 0,
      totalFaunaKilled: 0,
      totalChitinCollected: 0,
      pendingSales: [],
      siloInventory: {},
      shipmentsThisWindow: 0,
      nextShipWindowWeek: 4,
      waterPurifierLevel: 1,
      lastSaved: DateTime.now(),
    );

    // Fires the game_start trigger (opening transmission) and anything
    // else in radio_triggers.toml that's already true on turn 1.
    return checkRadioTriggers(initialState);
  }

  static Dome createNewDome({required String name, int tier = 1}) {
    return _createNewDome(name: name, tier: tier);
  }

  static Dome _createNewDome({required String name, int tier = 1}) {
    final powerDraw = UpgradeConfigService.instance.domeTierPowerDraw(tier);
    return Dome(
      id: _uuid.v4(),
      name: name,
      tier: tier,
      cells: List.generate(
        8,
            (i) => CropCell(position: i, state: CropState.empty),
      ),
      structuralHealth: 100,
      powerDraw: powerDraw,
    );
  }

  static Silo createNewSilo({int tier = 1}) {
    return _createNewSilo(tier: tier);
  }

  static Silo _createNewSilo({int tier = 1}) {
    final tierConfig = _config.getSiloTier(tier);
    return Silo(
      id: _uuid.v4(),
      tier: tier,
      capacityCubicMeters:
      (tierConfig['capacity_cubic_meters'] as num).toDouble(),
      usedCubicMeters: 0,
      contents: {},
      powerDraw: tierConfig['power_draw_kwh'] as int,
    );
  }

  static Refinery createRefinery({required int tier}) {
    final tierConfig = _config.getRefineryTier(tier);
    return Refinery(
      id: _uuid.v4(),
      tier: tier,
      powerDraw: tierConfig['power_draw_kwh'] as int,
      unlockedRecipes: List<String>.from(
        tierConfig['unlocked_recipes'] as List,
      ),
    );
  }

  static PowerSource createPowerSource(PowerSourceType type) {
    final typeKey = switch (type) {
      PowerSourceType.solarArray => 'solar_array',
      PowerSourceType.windTurbine => 'wind_turbine',
      PowerSourceType.geothermalTap => 'geothermal_tap',
      PowerSourceType.mycovaultReactor => 'mycovault_reactor',
    };
    final config = _config.getPowerSource(typeKey);
    return PowerSource(
      id: _uuid.v4(),
      type: type,
      outputKwh: config['power_output_kwh'] as int,
    );
  }

  /// Target cargo volume (m³) for a contract, by crop tier.
  /// Higher-tier crops are worth more per m³, so contracts ask for more
  /// volume rather than a flat unit count — keeps later tiers meaningful.
  // Contract unit targets by dome tier — "how many seeds worth of crop"
  // the colony wants. One seed = one harvest = one unit, so this maps
  // directly to harvest count. Easier to reason about than m³ since crop
  // volume varies wildly (Crystalline Beans 0.3m³ vs Fiber-Kelp 1.5m³).
  static const Map<int, int> _contractTierTargetQty = {
    1: 10,
    2: 20,
    3: 30,
    4: 40,
    5: 50,
  };

  static int _baseTargetQtyForTier(int tier) {
    if (_contractTierTargetQty.containsKey(tier)) return _contractTierTargetQty[tier]!;
    // Tiers beyond 5: keep adding 10 per tier
    final highest = _contractTierTargetQty.keys.reduce((a, b) => a > b ? a : b);
    return _contractTierTargetQty[highest]! + ((tier - highest) * 10);
  }

  /// Randomized target quantity for a contract, ±20% of the tier's base
  /// amount (e.g. T1 base 10 → 8-12, T2 base 20 → 16-24), rounded to a
  /// whole number so contracts feel less identical week to week.
  static int _targetQtyForTier(int tier) {
    final base = _baseTargetQtyForTier(tier);
    final low = (base * 0.8).round();
    final high = (base * 1.2).round();
    return low + _rng.nextInt(high - low + 1);
  }

  /// Generate 3 contract options based on what crops the player could plausibly have.
  static List<Contract> generateContractOptions({
    required List<Dome> domes,
    required int currentWeek,
    required double moodDiscount,
  }) {
    final config = GameConfigService.instance;

    // Find what dome tiers player has
    final maxDomeTier = domes.isEmpty
        ? 1
        : domes.map((d) => d.tier).reduce((a, b) => a > b ? a : b);

    // Resource crops (moss/chitin/meat) don't produce a sellable silo unit,
    // so they can't fulfill a contract — exclude them from the pool.
    final availableCrops = config
        .getCropsForDomeTier(maxDomeTier)
        .where((c) => c.yieldsResource == null)
        .toList();
    if (availableCrops.isEmpty) return [];

    // Shuffle and pick 3 different crops for variety
    final shuffled = List.of(availableCrops)..shuffle();
    final picked = shuffled.take(3).toList();

    return picked.map((crop) {
      final baseQty = _targetQtyForTier(crop.tier);

      // Market value = what the player would get selling this quantity
      // at Kovacs' regular rate: baseScrip (per m³) × units × m³ per unit.
      final marketValue = crop.baseScrip * baseQty * crop.volumeM3;

      // Contracts pay 15-25% above market as a bonus for committing early.
      final bonusPct = 0.15 + (_rng.nextDouble() * 0.10);
      final rewardScrip = (marketValue * (1 + bonusPct)).round();
      final bonusDisplay = '${(bonusPct * 100).round()}% above market';

      return Contract(
        id: _uuid.v4(),
        title: '${crop.name} Order',
        description:
        'The colony requests $baseQty units of ${crop.name}. '
            'Pays $bonusDisplay.',
        cropId: crop.id,
        requiredAmount: baseQty,
        currentAmount: 0,
        rewardScrip: rewardScrip,
        status: ContractStatus.available,
        weekAccepted: currentWeek,
      );
    }).toList();
  }

  // ─── Dev70 Preset ─────────────────────────────────────────────────────────
  // Modelled from a real Normal-difficulty playthrough save: "Vertex Harvest
  // Pod W70" exported by Corey on 2026-07-22. Values taken directly from
  // that save.
  //
  // Key scenario: 9x T3 domes, all Mk4 bots, defense wall Mk4, water
  // purifier Mk8, refinery fully specced (composter/smelter/component
  // fabricator/z-soil processor/glass furnace all built) but still no
  // Mycoculture Vat this late — same unresolved gap Dev75 was chasing,
  // just from a later, independently-played save. No monuments built yet
  // either, and the win-condition milestone (Free and Clear) is still
  // pending despite 105K+ scrip on hand — useful for testing the
  // Habitat > Contract "Buy the Farm" flow near its actual trigger point.
  static GameState createDev70Preset({required int slotNumber}) {
    final baseline = createNewGame(
      slotNumber: slotNumber,
      farmName: 'Dev70 — Vertex Harvest Pod',
      difficulty: Difficulty.normal,
    );

    const currentWeek = 70;

    int powerFor(String machineKey, int level) {
      final cfg = UpgradeConfigService.instance.getMachineLevel(machineKey, level);
      return cfg?['power_draw_kwh'] as int? ?? 0;
    }

    LaserSentry makeSentry(int level) {
      final cfg = (_config.getOperationsBuildings()['laser_sentry']['levels'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((l) => l['level'] == level);
      return LaserSentry(
        id: _uuid.v4(), level: level, health: 100,
        powerDraw: cfg['power_draw_kwh'] as int,
        damage: cfg['damage'] as int,
        fireRate: cfg['fire_rate'] as int,
        range: cfg['range'] as int,
      );
    }

    final domeBotMk4 = UpgradeConfigService.instance.domeBotLevels
        .firstWhere((l) => l['level'] == 4);
    Dome makeDome(String name, int tier) {
      return _createNewDome(name: name, tier: tier).copyWith(
        domeBot: DomeBot(level: 4, powerDraw: domeBotMk4['power_draw_kwh'] as int),
      );
    }

    // 9x T3, all Mk4 bots, cells empty
    final domes = List.generate(9, (i) => makeDome('Dome ${i + 1}', 3));

    // Sentries from real save: Mk4 x1, Mk3 x2, Mk5 x2
    final sentries = [
      makeSentry(4),
      makeSentry(3),
      makeSentry(5),
      makeSentry(3),
      makeSentry(5),
    ];

    // Refinery from real save — every machine built out except the Vat
    final refinery = Refinery(
      id: 'refinery_dev70', tier: 1, powerDraw: 8,
      unlockedRecipes: const ['compost_to_zsoil'],
      machines: [
        RefineryMachine(type: MachineType.composter, level: 3,
            powerDraw: powerFor('composter', 3)),
        RefineryMachine(type: MachineType.smelter, level: 10,
            powerDraw: powerFor('smelter', 10), autoRefine: true),
        RefineryMachine(type: MachineType.componentFabricator, level: 10,
            powerDraw: powerFor('component_fabricator', 10)),
        RefineryMachine(type: MachineType.zSoilProcessor, level: 10,
            powerDraw: powerFor('z_soil_processor', 10)),
        RefineryMachine(type: MachineType.glassFurnace, level: 10,
            powerDraw: powerFor('glass_furnace', 10), autoRefine: true),
      ],
    );

    // Power from real save: 10 solar, 10 wind, 6 geothermal
    final powerSources = [
      ...List.generate(10, (_) => createPowerSource(PowerSourceType.solarArray)),
      ...List.generate(10, (_) => createPowerSource(PowerSourceType.windTurbine)),
      ...List.generate(6,  (_) => createPowerSource(PowerSourceType.geothermalTap)),
    ];

    // 10x Mk3 drones — real save had 5 balanced, 2 ore, 3 chemicals
    final droneCfg = (_config.getOperationsBuildings()['mining_drone']['tiers'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((t) => t['tier'] == 3);
    MiningDrone makeDrone(String? assigned) => MiningDrone(
      id: _uuid.v4(), tier: 3, assignedResource: assigned,
      outputPerWeek: (droneCfg['output_per_week'] as num).toDouble(),
      powerDraw: droneCfg['power_draw_kwh'] as int,
    );
    final drones = [
      ...List.generate(5, (_) => makeDrone(null)),
      ...List.generate(2, (_) => makeDrone('ore')),
      ...List.generate(3, (_) => makeDrone('chemicals')),
    ];

    // Resources from real save (mycoculture stays at 0 — no Vat yet)
    final resources = baseline.resources.copyWith(
      starScrip: 105469, metals: 2507, components: 843, chemicals: 1443.5,
      glass: 1788, chitin: 262, mycoculture: 0,
      moonDirt: 814.5, sand: 35.5, ore: 91.5, water: 6886,
      compost: 720, zSoil: 562, seeds: 232, meat: 83.32340621948242, moss: 0,
    );

    // Milestones: matched by NAME against the real save's completed list,
    // not id — that save's milestone list predates a later fix for a
    // duplicate-id collision (two unrelated milestone batches both landed
    // on m69-m71 independently), so id-matching would silently mismatch.
    const completedNames = {
      'First Shipment', 'Initial Contract', 'Steady Supply', 'Reliable Route',
      'Colony Cornerstone', 'Operational Hub', 'Regional Supplier',
      'Freight Magnate', 'Bulk Logistics Partner', 'Planetary Breadbasket',
      'Power Grid', 'Grid Expansion', 'Trusted Supplier',
      'Perimeter Defender', 'Wall Veteran', 'Siege Breaker',
      'Bulwark Commander', 'Perimeter Legend',
      'Tier 1 Cultivator', 'Tier 2 Cultivator',
      'Tier 1 Contractor', 'Tier 2 Contractor',
      'Scrap Runner', 'Scrap Trader', 'First Autopilot', 'Automated Cluster',
      'Coffee Confidant', 'Command Track', 'Meet Barnaby', 'Form 77-A',
      'Let Him Vent', 'Macro Data', 'Elated',
    };
    final milestones = MilestoneConfigService.instance
        .getMilestones(Difficulty.normal)
        .map((m) => m.copyWith(
          status: completedNames.contains(m.name)
              ? MilestoneStatus.completed
              : MilestoneStatus.pending,
        ))
        .toList();

    // Radio: back-fill week triggers up to W70, scrap_dealer discovered.
    // Mycoculture triggers NOT fired (Vat not unlocked yet in real save).
    final radioTriggers = RadioConfigService.instance.triggers;
    final firedTriggers = <String>{
      'opening_transmission',
      'discovery_scrap_dealer',
      for (final t in radioTriggers)
        if (t['kind'] == 'week' && (t['value'] as num) <= currentWeek)
          t['id'] as String,
    }.toList();

    final preset = baseline.copyWith(
      currentWeek: currentWeek,
      domes: domes,
      laserSentries: sentries,
      refineries: [refinery],
      powerSources: powerSources,
      miningDrones: drones,
      resources: resources,
      milestones: milestones,
      defenseWall: baseline.defenseWall.copyWith(level: 4, currentHp: 492, maxHp: 500),
      grenades: const GrenadeInventory(counts: {'flashbang': 5}, benchLevel: 1),
      siloInventory: const {},
      totalVolumeDeliveredM3: 2113.3901937805176,
      totalScrapSoldDam3: 27.0,
      totalCropsHarvested: 344,
      totalCropsPlanted: 258,
      // Back-filled lifetime totals, not activity from "this week" — pin
      // the week-start snapshots to match so the first End Week on this
      // preset doesn't report a fake Week 70 spike in the summary.
      weekBaselineVolumeDeliveredM3: 2113.3901937805176,
      weekBaselineCropsHarvested: 344,
      weekBaselineCropsPlanted: 258,
      totalRaidsDefended: 6,
      totalFaunaKilled: 3110,
      totalChitinCollected: 701,
      totalCompostGenerated: 0,
      unlockedFeatures: const ['scrap_dealer'],
      firedRadioTriggers: firedTriggers,
      relay: baseline.relay.copyWith(
        mood: 100,
        hasReachedMaxMood: true,
        conversationDoneThisWeek: false,
        unlockedTopicIds: const {
          'ask_about_complaints', 'ask_about_hobbies', 'threaten_with_complaint',
          'ask_about_coffee', 'ask_about_freighter_crews', 'rant_about_space_cadets',
          'offer_coffee_help', 'mock_coffee', 'ask_about_freighter_envy',
          'ask_about_cat', 'admit_freighter_envy', 'ask_about_captaincy',
          'ask_about_ionuke', 'ask_about_sector_yields',
        },
      ),
      nextShipWindowWeek: 72,
      shipmentsThisWindow: 0,
      waterPurifierLevel: 8,
      nextRaidWeek: 70,
    );

    return checkRadioTriggers(preset);
  }
}
