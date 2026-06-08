// ═══════════════════════════════════════════════════════════════
//  lib/utils/game_factory.dart
// ═══════════════════════════════════════════════════════════════

import 'package:uuid/uuid.dart';
import '../models/game_models.dart';
import '../config/game_config_service.dart';
import '../config/upgrade_config_service.dart';

/// Creates a brand new GameState for a given save slot, farm name, and difficulty.
class GameFactory {
  static const _uuid = Uuid();
  static final _config = GameConfigService.instance;

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
    final milestones = _config.getMilestones(difficulty);
    final trophies = _config.getAllTrophies();

    // Opening transmission from Kovacs
    final openingMsg = GameConfigService.instance
        .getRelayConfig()['opening_transmission'] as String? ??
        "New operator confirmed. First pickup is Week 4. Don't be late. — Kovacs";

    final radioFeed = [
      RadioTransmission(
        week: 1,
        message: openingMsg,
        isRead: false,
      ),
    ];

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

    return GameState(
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
      radioFeed: radioFeed,
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
      nextRaidWeek: UpgradeConfigService.instance.firstRaidWeek,
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
      // Scale quantity to crop growth time and value
      final baseQty = (50 / (crop.baseSolarValue * 0.1).clamp(1, 10)).round().clamp(5, 100);
      final rewardBonus = (crop.baseSolarValue * baseQty * 0.4).round();

      return Contract(
        id: _uuid.v4(),
        title: '${crop.name} Order',
        description:
        'The colony requests $baseQty units of ${crop.name}. '
            'Bonus solar payout on delivery.',
        cropId: crop.id,
        requiredAmount: baseQty,
        currentAmount: 0,
        rewardScrip: rewardBonus,
        status: ContractStatus.available,
        weekAccepted: currentWeek,
      );
    }).toList();
  }
}