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

    // Load milestones and trophies from config
    final milestones = MilestoneConfigService.instance.getMilestones(difficulty);
    final trophies = MilestoneConfigService.instance.getAllTrophies();

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
      trophies: trophies,
      log: [],
      radioFeed: const [],
      relay: RelayTechnicianState(
        mood: 30,  // starts sour — he's not happy about this posting
        seenRantTopics: [],
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
      robot: null,
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

  static DomeRobot createRobot({required int level}) {
    final levelConfig = _config.getRobotLevel(level);
    return DomeRobot(
      level: level,
      health: 100,
      state: RobotState.healthy,
      powerDraw: levelConfig['power_draw_kwh'] as int,
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

  static LaserSentry createSentry({required int level}) {
    final config = _config.getSentryLevel(level);
    return LaserSentry(
      id: _uuid.v4(),
      level: level,
      health: 100,
      powerDraw: config['power_draw_kwh'] as int,
      damage: config['damage'] as int,
      fireRate: config['fire_rate'] as int,
      range: config['range'] as int,
    );
  }

  /// Target cargo volume (m³) for a contract, by crop tier.
  /// Higher-tier crops are worth more per m³, so contracts ask for more
  /// volume rather than a flat unit count — keeps later tiers meaningful.
  static const Map<int, double> _contractTierTargetM3 = {
    1: 10,
    2: 25,
    3: 50,
    4: 100,
  };

  static double _targetM3ForTier(int tier) {
    if (_contractTierTargetM3.containsKey(tier)) return _contractTierTargetM3[tier]!;
    // Future tiers (5+) keep doubling from the tier 4 baseline.
    final highestKnown = _contractTierTargetM3.keys.reduce((a, b) => a > b ? a : b);
    final highestValue = _contractTierTargetM3[highestKnown]!;
    if (tier > highestKnown) return highestValue * (1 << (tier - highestKnown));
    return _contractTierTargetM3[1]!;
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

    final availableCrops = config.getCropsForDomeTier(maxDomeTier);
    if (availableCrops.isEmpty) return [];

    // Shuffle and pick 3 different crops for variety
    final shuffled = List.of(availableCrops)..shuffle();
    final picked = shuffled.take(3).toList();

    return picked.map((crop) {
      // Required cargo volume is fixed by crop tier (10/25/50/100m³...).
      final targetM3 = _targetM3ForTier(crop.tier);
      final baseQty = (targetM3 / crop.volumeM3).round().clamp(1, 999);

      // Market value = base price-per-m³ * the m³ actually being delivered.
      final marketValue = crop.baseScrip * targetM3;

      // Contracts pay 15-25% above market as a bonus for committing early
      final bonusPct = 0.15 + (_rng.nextDouble() * 0.10); // 15-25%
      final rewardScrip = (marketValue * (1 + bonusPct)).round();
      final bonusDisplay = '${(bonusPct * 100).round()}% above market';

      return Contract(
        id: _uuid.v4(),
        title: '${crop.name} Order',
        description:
        'The colony requests $baseQty units of ${crop.name} '
            '(~${targetM3.round()}m³). Pays $bonusDisplay. '
            'Deliver before next ship window.',
        cropId: crop.id,
        requiredAmount: baseQty,
        currentAmount: 0,
        rewardScrip: rewardScrip,
        status: ContractStatus.available,
        weekAccepted: currentWeek,
      );
    }).toList();
  }

  // ─── Dev75 Preset ─────────────────────────────────────────────────────────
  // A hand-built "week 75, about to start mycoculture" scenario for testing
  // Vat/Reactor/T5-dome content without grinding a real playthrough.
  //
  // Built by taking a normal new game and overriding the fields that matter
  // for the scenario, rather than constructing a GameState from scratch —
  // keeps every field GameFactory.createNewGame already gets right (IDs,
  // starting silo, etc.) instead of re-deriving them by hand.
  //
  // Deliberately NOT included: the Mycoculture Vat is at Mk1 (built, not
  // upgraded) and the Mycovault Reactor is NOT unlocked — the whole point
  // is to test the climb into mycoculture content, not start past it.
  // Dome cells are left empty (ready to plant) rather than pre-seeded with
  // growing crops, to keep the scenario simple to reason about.
  static GameState createDev75Preset({required int slotNumber}) {
    final baseline = createNewGame(
      slotNumber: slotNumber,
      farmName: 'Dev75 Mycoculture Test',
      difficulty: Difficulty.normal,
    );

    const currentWeek = 75;

    // 8x Tier 4 domes, each with a Mk4 Dome Bot, cells empty/ready to plant.
    final domeBotMk4 = UpgradeConfigService.instance.domeBotLevels
        .firstWhere((l) => l['level'] == 4);
    final domes = List.generate(8, (i) {
      final dome = _createNewDome(name: 'Dome ${i + 1}', tier: 4);
      return dome.copyWith(
        domeBot: DomeBot(
          level: 4,
          powerDraw: domeBotMk4['power_draw_kwh'] as int,
        ),
      );
    });

    // 10x Mk4 sentries — sourced from the LIVE operations_buildings config,
    // not GameFactory.createSentry (that reads a dead legacy 3-level block
    // and would give wrong/missing stats for Mk4+).
    final sentryMk4 = (_config.getOperationsBuildings()['laser_sentry']['levels'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((l) => l['level'] == 4);
    final sentries = List.generate(10, (i) => LaserSentry(
      id: _uuid.v4(),
      level: 4,
      health: 100,
      powerDraw: sentryMk4['power_draw_kwh'] as int,
      damage: sentryMk4['damage'] as int,
      fireRate: sentryMk4['fire_rate'] as int,
      range: sentryMk4['range'] as int,
    ));

    // Refinery: every machine maxed at its OWN cap (composter caps at 3,
    // not 10), water purifier at Mk7 specifically (not maxed — by design),
    // Vat at Mk1 only.
    int powerFor(String machineKey, int level) {
      final cfg = UpgradeConfigService.instance.getMachineLevel(machineKey, level);
      return cfg?['power_draw_kwh'] as int? ?? 0;
    }
    final refinery = Refinery(
      id: 'refinery_dev75',
      tier: 1,
      powerDraw: 0,
      unlockedRecipes: const ['compost_to_zsoil'],
      machines: [
        RefineryMachine(type: MachineType.composter, level: 3,
            powerDraw: powerFor('composter', 3)),
        RefineryMachine(type: MachineType.smelter, level: 10,
            powerDraw: powerFor('smelter', 10)),
        RefineryMachine(type: MachineType.zSoilProcessor, level: 10,
            powerDraw: powerFor('z_soil_processor', 10)),
        RefineryMachine(type: MachineType.glassFurnace, level: 10,
            powerDraw: powerFor('glass_furnace', 10)),
        RefineryMachine(type: MachineType.componentFabricator, level: 10,
            powerDraw: powerFor('component_fabricator', 10)),
        RefineryMachine(type: MachineType.mycocultureVat, level: 1,
            powerDraw: powerFor('mycoculture_vat', 1)),
      ],
    );

    // Power: domes+bots+sentries+refinery add up to roughly 1.45 MW at
    // these levels. Provisioned generously above that — a mix, not just
    // taps, since a real 75-week game would have kept its early arrays.
    final powerSources = [
      ...List.generate(9, (_) => createPowerSource(PowerSourceType.geothermalTap)),
      ...List.generate(5, (_) => createPowerSource(PowerSourceType.solarArray)),
      ...List.generate(3, (_) => createPowerSource(PowerSourceType.windTurbine)),
    ];

    // A few scavenger drones for ongoing raw-resource income.
    final drones = List.generate(3, (i) {
      final cfg = (_config.getOperationsBuildings()['mining_drone']['tiers'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((t) => t['tier'] == 3);
      return MiningDrone(
        id: _uuid.v4(),
        tier: 3,
        assignedResource: ['moon_dirt', 'ore', 'sand'][i % 3],
        outputPerWeek: (cfg['output_per_week'] as num).toDouble(),
        powerDraw: cfg['power_draw_kwh'] as int,
      );
    });

    // Generous but not infinite resource stockpile — enough to actually
    // start upgrading the Vat (now mycoculture-gated from Mk3 on) without
    // it being a non-decision. mycoculture itself stays at 0 — that's the
    // whole point of the scenario.
    final resources = baseline.resources.copyWith(
      starScrip: 60000,
      metals: 8000,
      components: 4000,
      chemicals: 3000,
      glass: 2500,
      chitin: 1000,
      mycoculture: 0,
      moonDirt: 800,
      sand: 800,
      ore: 800,
      water: 3000,
      compost: 500,
      zSoil: 500,
      seeds: 60,
      meat: 150,
      moss: 300,
    );

    // All Normal-difficulty milestones marked complete.
    final milestones = MilestoneConfigService.instance
        .getMilestones(Difficulty.normal)
        .map((m) => m.copyWith(status: MilestoneStatus.completed))
        .toList();

    // Back-fill radio triggers that would realistically have already fired
    // by week 75, so the player isn't hit with a flood of 75 weeks' worth
    // of catch-up messages the moment they end a week. Reactor discovery
    // deliberately left unfired — matches the Vat being fresh/un-upgraded.
    final radioTriggers = RadioConfigService.instance.triggers;
    final firedTriggers = <String>{
      'opening_transmission',
      'discovery_mycoculture_vat',
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
      totalVolumeDeliveredM3: 4500,
      lifetimeScripEarned: 80000,
      totalCropsHarvested: 600,
      totalRaidsDefended: 15,
      totalFaunaKilled: 800,
      totalChitinCollected: 150,
      totalCompostGenerated: 3000,
      unlockedFeatures: const ['mycoculture_vat', 'scrap_dealer'],
      firedRadioTriggers: firedTriggers,
      relay: baseline.relay.copyWith(mood: 50, conversationDoneThisWeek: true),
      nextShipWindowWeek: 76,
      shipmentsThisWindow: 0,
      waterPurifierLevel: 7,
      // first_raid_week (10) + 7 * normal interval (10) = 80 — matches the
      // natural cadence a real week-75 playthrough would be on. Left unset
      // before, which defaulted to the very first raid (week ~10) and
      // caused a raid almost every single week until it caught back up.
      nextRaidWeek: 80,
    );

    return checkRadioTriggers(preset);
  }
}