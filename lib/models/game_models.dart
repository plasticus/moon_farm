// ═══════════════════════════════════════════════════════════════
//  lib/models/game_models.dart
// ═══════════════════════════════════════════════════════════════

// All core data models for Moon Farm

// ─── Enums ────────────────────────────────────────────────────────────────────

enum Difficulty { easy, normal, hard }

enum GameStatus { active, terminated, won }

enum CropState { empty, planted, growing, ready, dead }

enum RobotState { none, healthy, warning, critical, offline }

enum ResourceType {
  moonDirt,
  chemicals,
  water,
  compost,
  zSoil,
  metals,
  sand,
  glass,
  components,
  powerKwh,
  solars,
  seeds,
  ore,
}

enum PowerSourceType { solarArray, windTurbine, geothermalTap }

enum BuildingType { dome, silo, refinery, laserSentry, powerSource }

enum TrophyStatus { locked, unlocked }

enum ContractStatus { available, active, completed, failed }

enum MilestoneStatus { pending, completed, failed, warned }

// ─── Save Slot ────────────────────────────────────────────────────────────────

class SaveSlot {
  final int slotNumber; // 1, 2, 3, or 0 = autosave
  final String? farmName;
  final Difficulty? difficulty;
  final int? currentWeek;
  final double? totalScrip;
  final DateTime? lastSaved;
  final bool isEmpty;

  const SaveSlot({
    required this.slotNumber,
    this.farmName,
    this.difficulty,
    this.currentWeek,
    this.totalScrip,
    this.lastSaved,
    required this.isEmpty,
  });
}

// ─── Full Game State ──────────────────────────────────────────────────────────

class GameState {
  final int gameId;
  final int slotNumber;
  final String farmName;
  final Difficulty difficulty;
  final int currentWeek;
  final GameStatus status;
  final int strikeCount; // for normal/hard loss condition
  final Resources resources;
  final List<Dome> domes;
  final List<Silo> silos;
  final List<Refinery> refineries;
  final List<PowerSource> powerSources;
  final List<LaserSentry> laserSentries;
  final List<MiningDrone> miningDrones;
  final DefenseWall defenseWall;
  final GrenadeInventory grenades;
  final int totalRaidsDefended;
  final int totalFaunaKilled;
  final int totalChitinCollected;
  final List<Contract> activeContracts;
  final List<Contract> completedContracts;
  final List<PendingDelivery> pendingDeliveries;
  final List<Milestone> milestones;
  final List<Trophy> trophies;
  final List<WeeklyLogEntry> log;
  final List<RadioTransmission> radioFeed;
  final RelayTechnicianState relay;
  final double totalVolumeDeliveredM3;
  final int lifetimeScripEarned;
  final int totalCropsHarvested;
  final int totalCompostGenerated;
  final int nextRaidWeek;
  final bool raidDefendedThisWeek;
  final List<PendingSale> pendingSales;
  final Map<String, double> siloInventory; // cropId -> units in silo
  final int shipmentsThisWindow;           // resets each ship window
  final int nextShipWindowWeek;            // next week player can ship
  final int waterPurifierLevel;            // 0 = no purifier
  final DateTime lastSaved;

  const GameState({
    required this.gameId,
    required this.slotNumber,
    required this.farmName,
    required this.difficulty,
    required this.currentWeek,
    required this.status,
    required this.strikeCount,
    required this.resources,
    required this.domes,
    required this.silos,
    required this.refineries,
    required this.powerSources,
    required this.laserSentries,
    required this.miningDrones,
    required this.defenseWall,
    required this.grenades,
    required this.totalRaidsDefended,
    required this.totalFaunaKilled,
    required this.totalChitinCollected,
    required this.activeContracts,
    required this.completedContracts,
    this.pendingDeliveries = const [],
    required this.milestones,
    required this.trophies,
    required this.log,
    required this.radioFeed,
    required this.relay,
    required this.totalVolumeDeliveredM3,
    required this.lifetimeScripEarned,
    required this.totalCropsHarvested,
    required this.totalCompostGenerated,
    required this.nextRaidWeek,
    required this.raidDefendedThisWeek,
    required this.pendingSales,
    required this.siloInventory,
    required this.shipmentsThisWindow,
    required this.nextShipWindowWeek,
    required this.waterPurifierLevel,
    required this.lastSaved,
  });

  GameState copyWith({
    int? gameId,
    int? slotNumber,
    String? farmName,
    Difficulty? difficulty,
    int? currentWeek,
    GameStatus? status,
    int? strikeCount,
    Resources? resources,
    List<Dome>? domes,
    List<Silo>? silos,
    List<Refinery>? refineries,
    List<PowerSource>? powerSources,
    List<LaserSentry>? laserSentries,
    List<MiningDrone>? miningDrones,
    DefenseWall? defenseWall,
    GrenadeInventory? grenades,
    int? totalRaidsDefended,
    int? totalFaunaKilled,
    int? totalChitinCollected,
    List<Contract>? activeContracts,
    List<Contract>? completedContracts,
    List<Milestone>? milestones,
    List<Trophy>? trophies,
    List<WeeklyLogEntry>? log,
    List<RadioTransmission>? radioFeed,
    RelayTechnicianState? relay,
    double? totalVolumeDeliveredM3,
    int? lifetimeScripEarned,
    int? totalCropsHarvested,
    int? totalCompostGenerated,
    int? nextRaidWeek,
    bool? raidDefendedThisWeek,
    List<PendingSale>? pendingSales,
    List<PendingDelivery>? pendingDeliveries,
    Map<String, double>? siloInventory,
    int? shipmentsThisWindow,
    int? nextShipWindowWeek,
    int? waterPurifierLevel,
    DateTime? lastSaved,
  }) {
    return GameState(
      gameId: gameId ?? this.gameId,
      slotNumber: slotNumber ?? this.slotNumber,
      farmName: farmName ?? this.farmName,
      difficulty: difficulty ?? this.difficulty,
      currentWeek: currentWeek ?? this.currentWeek,
      status: status ?? this.status,
      strikeCount: strikeCount ?? this.strikeCount,
      resources: resources ?? this.resources,
      domes: domes ?? this.domes,
      silos: silos ?? this.silos,
      refineries: refineries ?? this.refineries,
      powerSources: powerSources ?? this.powerSources,
      laserSentries: laserSentries ?? this.laserSentries,
      miningDrones: miningDrones ?? this.miningDrones,
      defenseWall: defenseWall ?? this.defenseWall,
      grenades: grenades ?? this.grenades,
      totalRaidsDefended: totalRaidsDefended ?? this.totalRaidsDefended,
      totalFaunaKilled: totalFaunaKilled ?? this.totalFaunaKilled,
      totalChitinCollected: totalChitinCollected ?? this.totalChitinCollected,
      activeContracts: activeContracts ?? this.activeContracts,
      completedContracts: completedContracts ?? this.completedContracts,
      pendingDeliveries: pendingDeliveries ?? this.pendingDeliveries,
      milestones: milestones ?? this.milestones,
      trophies: trophies ?? this.trophies,
      log: log ?? this.log,
      radioFeed: radioFeed ?? this.radioFeed,
      relay: relay ?? this.relay,
      totalVolumeDeliveredM3: totalVolumeDeliveredM3 ?? this.totalVolumeDeliveredM3,
      lifetimeScripEarned: lifetimeScripEarned ?? this.lifetimeScripEarned,
      totalCropsHarvested: totalCropsHarvested ?? this.totalCropsHarvested,
      totalCompostGenerated:
      totalCompostGenerated ?? this.totalCompostGenerated,
      nextRaidWeek: nextRaidWeek ?? this.nextRaidWeek,
      raidDefendedThisWeek: raidDefendedThisWeek ?? this.raidDefendedThisWeek,
      pendingSales: pendingSales ?? this.pendingSales,
      siloInventory: siloInventory ?? this.siloInventory,
      shipmentsThisWindow: shipmentsThisWindow ?? this.shipmentsThisWindow,
      nextShipWindowWeek: nextShipWindowWeek ?? this.nextShipWindowWeek,
      waterPurifierLevel: waterPurifierLevel ?? this.waterPurifierLevel,
      lastSaved: lastSaved ?? this.lastSaved,
    );
  }

  // Power calculations
  int get totalPowerProduction =>
      powerSources.fold(0, (sum, p) => sum + p.outputKwh);

  int get totalPowerDraw {
    int draw = 0;
    for (final dome in domes) {
      draw += dome.powerDraw;
      if (dome.robot != null && dome.robot!.state != RobotState.offline) {
        draw += dome.robot!.powerDraw;
      }
      if (dome.domeBot != null) {
        draw += dome.domeBot!.powerDraw;
      }
    }
    for (final silo in silos) {
      draw += silo.powerDraw;
    }
    for (final refinery in refineries) {
      // Each installed machine draws its own power.
      for (final m in refinery.machines) {
        draw += m.powerDraw;
      }
    }
    for (final sentry in laserSentries) {
      draw += sentry.powerDraw;
    }
    for (final drone in miningDrones) {
      draw += drone.powerDraw;
    }
    return draw;
  }

  int get powerSurplus => totalPowerProduction - totalPowerDraw;
  bool get hasSufficientPower => powerSurplus >= 0;

  // Silo capacity
  double get totalSiloCapacity =>
      silos.fold(0, (sum, s) => sum + s.capacityCubicMeters);
  double get usedSiloCapacity =>
      silos.fold(0, (sum, s) => sum + s.usedCubicMeters);
  double get availableSiloCapacity => totalSiloCapacity - usedSiloCapacity;
  bool get silosNearFull => availableSiloCapacity < totalSiloCapacity * 0.1;

  // Total units across all silo inventory
  double get totalSiloUnits =>
      siloInventory.values.fold(0, (sum, v) => sum + v);

  // Is a ship window currently open?
  bool get isShipWindowOpen => currentWeek >= nextShipWindowWeek;

  // Weeks until next ship window
  int get weeksToNextShipWindow =>
      isShipWindowOpen ? 0 : nextShipWindowWeek - currentWeek;
}

// ─── Resources ────────────────────────────────────────────────────────────────

class Resources {
  final double moonDirt;
  final double chemicals;
  final double water;
  final double compost;
  final double zSoil;
  final double metals;
  final double sand;
  final double glass;
  final double components;
  final double ore;
  final double meat;
  final double chitin;
  final int starScrip;
  final int seeds;

  const Resources({
    this.moonDirt = 0,
    this.chemicals = 0,
    this.water = 0,
    this.compost = 0,
    this.zSoil = 0,
    this.metals = 0,
    this.sand = 0,
    this.glass = 0,
    this.components = 0,
    this.ore = 0,
    this.meat = 0,
    this.chitin = 0,
    this.starScrip = 0,
    this.seeds = 0,
  });

  Resources copyWith({
    double? moonDirt,
    double? chemicals,
    double? water,
    double? compost,
    double? zSoil,
    double? metals,
    double? sand,
    double? glass,
    double? components,
    double? ore,
    double? meat,
    double? chitin,
    int? starScrip,
    int? seeds,
  }) {
    return Resources(
      moonDirt: moonDirt ?? this.moonDirt,
      chemicals: chemicals ?? this.chemicals,
      water: water ?? this.water,
      compost: compost ?? this.compost,
      zSoil: zSoil ?? this.zSoil,
      metals: metals ?? this.metals,
      sand: sand ?? this.sand,
      glass: glass ?? this.glass,
      components: components ?? this.components,
      ore: ore ?? this.ore,
      meat: meat ?? this.meat,
      chitin: chitin ?? this.chitin,
      starScrip: starScrip ?? this.starScrip,
      seeds: seeds ?? this.seeds,
    );
  }

  Resources operator +(Resources other) {
    return Resources(
      moonDirt: moonDirt + other.moonDirt,
      chemicals: chemicals + other.chemicals,
      water: water + other.water,
      compost: compost + other.compost,
      zSoil: zSoil + other.zSoil,
      metals: metals + other.metals,
      sand: sand + other.sand,
      glass: glass + other.glass,
      components: components + other.components,
      ore: ore + other.ore,
      meat: meat + other.meat,
      chitin: chitin + other.chitin,
      starScrip: starScrip + other.starScrip,
      seeds: seeds + other.seeds,
    );
  }
}

// ─── Dome ─────────────────────────────────────────────────────────────────────

class Dome {
  final String id;
  final String name;
  final int tier; // 1-4
  final List<CropCell> cells; // always 8 cells (positions 0-7, center reserved)
  final DomeRobot? robot;
  final DomeBot? domeBot;
  final int structuralHealth; // 0-100
  final int powerDraw;

  const Dome({
    required this.id,
    required this.name,
    required this.tier,
    required this.cells,
    this.robot,
    this.domeBot,
    required this.structuralHealth,
    required this.powerDraw,
  });

  // Grid positions 0-7 (top-left to bottom-right, skipping center index 4)
  // Visual layout:
  // [0][1][2]
  // [3][C][4]  <- C is center (robot slot)
  // [5][6][7]

  int get activeCropCount =>
      cells.where((c) => c.state != CropState.empty).length;
  int get readyToHarvestCount =>
      cells.where((c) => c.state == CropState.ready).length;
  int get deadCropCount =>
      cells.where((c) => c.state == CropState.dead).length;

  double get healthPercent => structuralHealth / 100.0;

  Dome copyWith({
    String? id,
    String? name,
    int? tier,
    List<CropCell>? cells,
    DomeRobot? robot,
    DomeBot? domeBot,
    int? structuralHealth,
    int? powerDraw,
  }) {
    return Dome(
      id: id ?? this.id,
      name: name ?? this.name,
      tier: tier ?? this.tier,
      cells: cells ?? this.cells,
      robot: robot,
      domeBot: domeBot ?? this.domeBot,
      structuralHealth: structuralHealth ?? this.structuralHealth,
      powerDraw: powerDraw ?? this.powerDraw,
    );
  }
}

// ─── Crop Cell ────────────────────────────────────────────────────────────────

class CropCell {
  final int position; // 0-7
  final String? cropId;
  final CropState state;
  final int weeksGrown;
  final bool wateredThisWeek;
  final bool fertilizedThisWeek;
  final int healthPercent; // 0-100, doubles as yield multiplier (decay reduces it)
  final int fertilizeCount; // how many times fertilized this growth cycle
  final int lastFertilizeWeek; // weeksGrown value at last fertilize (for 3-week rule)

  const CropCell({
    required this.position,
    this.cropId,
    required this.state,
    this.weeksGrown = 0,
    this.wateredThisWeek = false,
    this.fertilizedThisWeek = false,
    this.healthPercent = 100,
    this.fertilizeCount = 0,
    this.lastFertilizeWeek = -99,
  });

  bool get isEmpty => state == CropState.empty;
  bool get isReady => state == CropState.ready;
  bool get isDead => state == CropState.dead;
  bool get needsWater => !wateredThisWeek && state == CropState.growing;

  CropCell copyWith({
    int? position,
    String? cropId,
    CropState? state,
    int? weeksGrown,
    bool? wateredThisWeek,
    bool? fertilizedThisWeek,
    int? healthPercent,
    int? fertilizeCount,
    int? lastFertilizeWeek,
  }) {
    return CropCell(
      position: position ?? this.position,
      cropId: cropId ?? this.cropId,
      state: state ?? this.state,
      weeksGrown: weeksGrown ?? this.weeksGrown,
      wateredThisWeek: wateredThisWeek ?? this.wateredThisWeek,
      fertilizedThisWeek: fertilizedThisWeek ?? this.fertilizedThisWeek,
      healthPercent: healthPercent ?? this.healthPercent,
      fertilizeCount: fertilizeCount ?? this.fertilizeCount,
      lastFertilizeWeek: lastFertilizeWeek ?? this.lastFertilizeWeek,
    );
  }

  CropCell cleared() {
    return const CropCell(position: 0, state: CropState.empty).copyWith(
      position: position,
    );
  }
}

// ─── Dome Robot ───────────────────────────────────────────────────────────────

class DomeRobot {
  final int level; // 1-5
  final int health; // 0-100
  final RobotState state;
  final int powerDraw;
  final String? defaultCropId; // for level 5 auto-plant

  const DomeRobot({
    required this.level,
    required this.health,
    required this.state,
    required this.powerDraw,
    this.defaultCropId,
  });

  bool get canWater => level >= 1;
  bool get canFertilize => level >= 2;
  bool get canHarvest => level >= 3;
  bool get canTurnSoil => level >= 4;
  bool get canPlant => level >= 5;

  double get healthPercent => health / 100.0;

  String get robotName {
    switch (level) {
      case 1: return 'Domebot Mk1';
      case 2: return 'Domebot Mk2';
      case 3: return 'Domebot Mk3';
      case 4: return 'Domebot Mk4';
      case 5: return 'Domebot Mk5';
      default: return 'Domebot';
    }
  }

  DomeRobot copyWith({
    int? level,
    int? health,
    RobotState? state,
    int? powerDraw,
    String? defaultCropId,
  }) {
    return DomeRobot(
      level: level ?? this.level,
      health: health ?? this.health,
      state: state ?? this.state,
      powerDraw: powerDraw ?? this.powerDraw,
      defaultCropId: defaultCropId ?? this.defaultCropId,
    );
  }
}

// ─── Silo ─────────────────────────────────────────────────────────────────────

class Silo {
  final String id;
  final int tier;
  final double capacityCubicMeters;
  final double usedCubicMeters;
  final Map<String, double> contents; // resourceId -> amount
  final int powerDraw;

  const Silo({
    required this.id,
    required this.tier,
    required this.capacityCubicMeters,
    required this.usedCubicMeters,
    required this.contents,
    required this.powerDraw,
  });

  double get fillPercent => usedCubicMeters / capacityCubicMeters;
  bool get isFull => usedCubicMeters >= capacityCubicMeters;
  double get available => capacityCubicMeters - usedCubicMeters;

  Silo copyWith({
    String? id,
    int? tier,
    double? capacityCubicMeters,
    double? usedCubicMeters,
    Map<String, double>? contents,
    int? powerDraw,
  }) {
    return Silo(
      id: id ?? this.id,
      tier: tier ?? this.tier,
      capacityCubicMeters: capacityCubicMeters ?? this.capacityCubicMeters,
      usedCubicMeters: usedCubicMeters ?? this.usedCubicMeters,
      contents: contents ?? this.contents,
      powerDraw: powerDraw ?? this.powerDraw,
    );
  }
}

// ─── Refinery ─────────────────────────────────────────────────────────────────

class Refinery {
  final String id;
  final int tier;
  final int powerDraw;
  final List<String> unlockedRecipes;
  final List<RefineryMachine> machines;

  const Refinery({
    required this.id,
    required this.tier,
    required this.powerDraw,
    required this.unlockedRecipes,
    this.machines = const [],
  });

  Refinery copyWith({
    String? id,
    int? tier,
    int? powerDraw,
    List<String>? unlockedRecipes,
    List<RefineryMachine>? machines,
  }) {
    return Refinery(
      id: id ?? this.id,
      tier: tier ?? this.tier,
      powerDraw: powerDraw ?? this.powerDraw,
      unlockedRecipes: unlockedRecipes ?? this.unlockedRecipes,
      machines: machines ?? this.machines,
    );
  }
}

// ─── Refinery Machine ─────────────────────────────────────────────────────────

enum MachineType { composter, smelter, zSoilProcessor, glassFurnace, componentFabricator }

class RefineryMachine {
  final MachineType type;
  final int level; // 1-10
  final int powerDraw;

  const RefineryMachine({
    required this.type,
    required this.level,
    required this.powerDraw,
  });

  String get name => switch (type) {
    MachineType.composter => 'Composter',
    MachineType.smelter => 'Smelter',
    MachineType.zSoilProcessor => 'Z-Soil Processor',
    MachineType.glassFurnace => 'Glass Furnace',
    MachineType.componentFabricator => 'Component Fabricator',
  };

  String get emoji => switch (type) {
    MachineType.composter => '♻️',
    MachineType.smelter => '🔥',
    MachineType.zSoilProcessor => '🌱',
    MachineType.glassFurnace => '🪟',
    MachineType.componentFabricator => '⚙️',
  };

  // Key used to look up this machine in upgrades_refinery.yaml
  String get yamlKey => switch (type) {
    MachineType.composter => 'composter',
    MachineType.smelter => 'smelter',
    MachineType.zSoilProcessor => 'z_soil_processor',
    MachineType.glassFurnace => 'glass_furnace',
    MachineType.componentFabricator => 'component_fabricator',
  };

  static MachineType typeFromYamlKey(String key) => switch (key) {
    'composter' => MachineType.composter,
    'smelter' => MachineType.smelter,
    'z_soil_processor' => MachineType.zSoilProcessor,
    'glass_furnace' => MachineType.glassFurnace,
    'component_fabricator' => MachineType.componentFabricator,
    _ => MachineType.composter,
  };

  RefineryMachine copyWith({int? level, int? powerDraw}) {
    return RefineryMachine(
      type: type,
      level: level ?? this.level,
      powerDraw: powerDraw ?? this.powerDraw,
    );
  }
}

// ─── Scavenger Drone ────────────────────────────────────────────────────────────

class MiningDrone {
  final String id;
  final int tier; // 1, 2, or 3
  final String? assignedResource; // 'moon_dirt', 'ore', 'sand', 'chemicals', or null (balanced)
  final double outputPerWeek;
  final int powerDraw;

  const MiningDrone({
    required this.id,
    required this.tier,
    this.assignedResource,
    required this.outputPerWeek,
    required this.powerDraw,
  });

  // null assignedResource means balanced (equal split across all 4 resources)
  bool get isBalanced => assignedResource == null;

  String get assignedLabel => switch (assignedResource) {
    'moon_dirt' => 'Moon Dirt',
    'ore' => 'Ore',
    'sand' => 'Sand',
    'chemicals' => 'Chemicals',
    _ => 'Balanced',
  };

  MiningDrone copyWith({
    String? id, int? tier, String? assignedResource,
    double? outputPerWeek, int? powerDraw,
  }) {
    return MiningDrone(
      id: id ?? this.id,
      tier: tier ?? this.tier,
      assignedResource: assignedResource,
      outputPerWeek: outputPerWeek ?? this.outputPerWeek,
      powerDraw: powerDraw ?? this.powerDraw,
    );
  }

  // Assign to balanced mode
  MiningDrone setBalanced() => copyWith(assignedResource: null);
}

// ─── Power Source ─────────────────────────────────────────────────────────────

class PowerSource {
  final String id;
  final PowerSourceType type;
  final int outputKwh;

  const PowerSource({
    required this.id,
    required this.type,
    required this.outputKwh,
  });

  String get name {
    switch (type) {
      case PowerSourceType.solarArray: return 'Solar Array';
      case PowerSourceType.windTurbine: return 'Wind Turbine';
      case PowerSourceType.geothermalTap: return 'Geothermal Core Tap';
    }
  }

  String get emoji {
    switch (type) {
      case PowerSourceType.solarArray: return '☀️';
      case PowerSourceType.windTurbine: return '🌬️';
      case PowerSourceType.geothermalTap: return '🌋';
    }
  }
}

// ─── Laser Sentry ─────────────────────────────────────────────────────────────

class LaserSentry {
  final String id;
  final int level;
  final int health; // 0-100
  final int powerDraw;
  final int damage;
  final int fireRate;
  final int range;

  const LaserSentry({
    required this.id,
    required this.level,
    required this.health,
    required this.powerDraw,
    required this.damage,
    required this.fireRate,
    required this.range,
  });

  double get healthPercent => health / 100.0;

  LaserSentry copyWith({
    String? id,
    int? level,
    int? health,
    int? powerDraw,
    int? damage,
    int? fireRate,
    int? range,
  }) {
    return LaserSentry(
      id: id ?? this.id,
      level: level ?? this.level,
      health: health ?? this.health,
      powerDraw: powerDraw ?? this.powerDraw,
      damage: damage ?? this.damage,
      fireRate: fireRate ?? this.fireRate,
      range: range ?? this.range,
    );
  }
}

// ─── Contract ─────────────────────────────────────────────────────────────────

class Contract {
  final String id;
  final String title;
  final String description;
  final String cropId;
  final int requiredAmount;
  final int currentAmount;
  final int rewardScrip;
  final ContractStatus status;
  final int weekAccepted;

  const Contract({
    required this.id,
    required this.title,
    required this.description,
    required this.cropId,
    required this.requiredAmount,
    required this.currentAmount,
    required this.rewardScrip,
    required this.status,
    required this.weekAccepted,
  });

  double get progress =>
      requiredAmount > 0 ? currentAmount / requiredAmount : 0;
  bool get isComplete => currentAmount >= requiredAmount;

  Contract copyWith({
    String? id,
    String? title,
    String? description,
    String? cropId,
    int? requiredAmount,
    int? currentAmount,
    int? rewardScrip,
    ContractStatus? status,
    int? weekAccepted,
  }) {
    return Contract(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      cropId: cropId ?? this.cropId,
      requiredAmount: requiredAmount ?? this.requiredAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      rewardScrip: rewardScrip ?? this.rewardScrip,
      status: status ?? this.status,
      weekAccepted: weekAccepted ?? this.weekAccepted,
    );
  }
}

// ─── Contract Submission ─────────────────────────────────────────────────────

class ContractSubmission {
  final String contractId;
  final String cropId;
  final double amount;
  final int weekSubmitted;

  const ContractSubmission({
    required this.contractId,
    required this.cropId,
    required this.amount,
    required this.weekSubmitted,
  });
}

// ─── Milestone ────────────────────────────────────────────────────────────────

class Milestone {
  final String id;
  final String name;
  final String description;
  final double targetVolumeM3; // cubic meters
  final int byWeek;
  final int rewardScrip;
  final MilestoneStatus status;

  const Milestone({
    required this.id,
    required this.name,
    required this.description,
    required this.targetVolumeM3,
    required this.byWeek,
    required this.rewardScrip,
    required this.status,
  });

  Milestone copyWith({MilestoneStatus? status}) {
    return Milestone(
      id: id,
      name: name,
      description: description,
      targetVolumeM3: targetVolumeM3,
      byWeek: byWeek,
      rewardScrip: rewardScrip,
      status: status ?? this.status,
    );
  }
}

// ─── Trophy ───────────────────────────────────────────────────────────────────

class Trophy {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String category;
  final TrophyStatus status;
  final int? weekEarned;

  const Trophy({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.category,
    required this.status,
    this.weekEarned,
  });

  Trophy unlock(int week) {
    return Trophy(
      id: id,
      name: name,
      description: description,
      emoji: emoji,
      category: category,
      status: TrophyStatus.unlocked,
      weekEarned: week,
    );
  }
}

// ─── Relay Technician ─────────────────────────────────────────────────────────

class RelayTechnicianState {
  final int mood; // 0-100
  final List<String> seenRantTopics;
  final List<String> availableContracts; // 3 contract options
  final bool contractsRefreshedThisWeek;
  final Set<String> unlockedTopicIds;
  final bool conversationDoneThisWeek;

  const RelayTechnicianState({
    required this.mood,
    required this.seenRantTopics,
    required this.availableContracts,
    required this.contractsRefreshedThisWeek,
    this.unlockedTopicIds = const {},
    this.conversationDoneThisWeek = false,
  });

  String get moodLabel {
    if (mood >= 85) return 'Elated 😄';
    if (mood >= 65) return 'Happy 🙂';
    if (mood >= 40) return 'Neutral 😐';
    if (mood >= 20) return 'Sour 😒';
    return 'Hostile 😤';
  }

  double get priceDiscount {
    if (mood >= 85) return 0.20;
    if (mood >= 65) return 0.10;
    if (mood >= 40) return 0.00;
    if (mood >= 20) return -0.10;
    return -0.25;
  }

  RelayTechnicianState copyWith({
    int? mood,
    List<String>? seenRantTopics,
    List<String>? availableContracts,
    bool? contractsRefreshedThisWeek,
    Set<String>? unlockedTopicIds,
    bool? conversationDoneThisWeek,
  }) {
    return RelayTechnicianState(
      mood: (mood ?? this.mood).clamp(0, 100),
      seenRantTopics: seenRantTopics ?? this.seenRantTopics,
      availableContracts: availableContracts ?? this.availableContracts,
      contractsRefreshedThisWeek:
      contractsRefreshedThisWeek ?? this.contractsRefreshedThisWeek,
      unlockedTopicIds: unlockedTopicIds ?? this.unlockedTopicIds,
      conversationDoneThisWeek:
      conversationDoneThisWeek ?? this.conversationDoneThisWeek,
    );
  }
}

// ─── Pending Sale ─────────────────────────────────────────────────────────────

class PendingSale {
  final String resourceId; // cropId or resource type
  final double amount;
  final int scripValue;
  final int weekQueued;

  const PendingSale({
    required this.resourceId,
    required this.amount,
    required this.scripValue,
    required this.weekQueued,
  });
}

// ─── Weekly Log Entry ─────────────────────────────────────────────────────────

class WeeklyLogEntry {
  final int week;
  final List<String> events;
  final int scripGained;
  final int scripSpent;
  final int cropsHarvested;
  final double volumeDeliveredM3;
  final bool raidOccurred;
  final bool raidSucceeded;
  final DateTime timestamp;

  const WeeklyLogEntry({
    required this.week,
    required this.events,
    required this.scripGained,
    required this.scripSpent,
    required this.cropsHarvested,
    required this.volumeDeliveredM3,
    required this.raidOccurred,
    required this.raidSucceeded,
    required this.timestamp,
  });
}

// ─── Radio Transmission ───────────────────────────────────────────────────────

class RadioTransmission {
  final int week;
  final String message;
  final bool isRead;

  const RadioTransmission({
    required this.week,
    required this.message,
    required this.isRead,
  });

  RadioTransmission markRead() {
    return RadioTransmission(week: week, message: message, isRead: true);
  }
}

// ─── Week Summary ─────────────────────────────────────────────────────────────

class WeekSummary {
  final int week;
  final int scripReceived;
  final int scripSpent;
  final int cropsHarvested;
  final int cropsDied;
  final double volumeToColonyM3;
  final List<String> newTrophies;
  final List<String> milestoneUpdates;
  final List<String> contractUpdates;
  final bool raidOccurred;
  final Map<String, double> resourceChanges;
  final List<String> robotActions;
  final List<String> events; // full event log for the week
  final int newWeek;

  const WeekSummary({
    required this.week,
    required this.scripReceived,
    required this.scripSpent,
    required this.cropsHarvested,
    required this.cropsDied,
    required this.volumeToColonyM3,
    required this.newTrophies,
    required this.milestoneUpdates,
    required this.contractUpdates,
    required this.raidOccurred,
    required this.resourceChanges,
    required this.robotActions,
    required this.events,
    required this.newWeek,
  });
}

// ─── Crop Config (loaded from JSON) ──────────────────────────────────────────

class CropConfig {
  final String id;
  final String name;
  final String emoji;
  final int tier;
  final int domeTierRequired;
  final int growthWeeks;
  final int waterPerWeek;
  final int caloriesPerUnit;
  final int baseScripPerM3;
  final int compostYield;
  final String description;
  final String note;
  final double decayRate; // fraction of yield lost per missed watering (0.0-1.0)
  final double fertilizerBonus;
  final double volumeM3; // cubic meters per cell per harvest
  final String? yieldsResource;
  final int resourceYieldAmount;

  const CropConfig({
    required this.id,
    required this.name,
    required this.emoji,
    required this.tier,
    required this.domeTierRequired,
    required this.growthWeeks,
    required this.waterPerWeek,
    required this.caloriesPerUnit,
    required this.baseScripPerM3,
    required this.compostYield,
    required this.description,
    required this.note,
    required this.decayRate,
    required this.fertilizerBonus,
    required this.volumeM3,
    this.yieldsResource,
    required this.resourceYieldAmount,
  });

  // Convenience accessors for older call sites
  int get baseScrip => baseScripPerM3;
  int get baseSolarValue => baseScripPerM3;
  bool get canDecay => decayRate > 0;

  // Max fertilizer applications: once per 3 growth-weeks
  int get maxFertilizations => (growthWeeks / 3).floor().clamp(1, 99);

  // Emojis assigned by crop id (crops.yaml has no emoji field)
  static const Map<String, String> _emojiById = {
    'terran_radishes': '🌶️',
    'hydro_lettuce': '🥬',
    'lunar_carrots': '🥕',
    'spacetatoes': '🥔',
    'moon_wheat': '🌾',
    'sludge_fern': '🌿',
    'bio_mash_pods': '🫛',
    'pulp_gourd': '🎃',
    'nitrate_squash': '🥒',
    'fiber_kelp': '🌱',
    'neon_berries': '🫐',
    'glow_stalks': '🎋',
    'glass_fronds': '🍃',
    'nebula_melons': '🍈',
    'crystalline_beans': '💎',
    'hyper_mycelium': '🍄',
    'silicon_shoots': '🔷',
    'copper_root': '🟤',
    'luna_lentils': '🫘',
    'matrix_moss': '🟩',
  };

  factory CropConfig.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return CropConfig(
      id: id,
      name: json['name'] as String,
      emoji: _emojiById[id] ?? '🌱',
      tier: (json['tier'] as num).toInt(),
      domeTierRequired: (json['dome_tier_required'] as num?)?.toInt() ?? 1,
      growthWeeks: (json['growth_weeks'] as num).toInt(),
      waterPerWeek: (json['water_per_week'] as num).toInt(),
      caloriesPerUnit: (json['calories_per_unit'] as num?)?.toInt() ?? 0,
      baseScripPerM3: (json['base_scrip_per_m3'] as num?)?.toInt() ??
          (json['base_scrip_value'] as num?)?.toInt() ?? 0,
      compostYield: (json['compost_yield'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
      note: json['note'] as String? ?? '',
      decayRate: (json['decay_rate'] as num?)?.toDouble() ?? 0.1,
      fertilizerBonus: (json['fertilizer_bonus'] as num?)?.toDouble() ?? 1.0,
      volumeM3: (json['volume_m3'] as num?)?.toDouble() ?? 0.5,
      yieldsResource: json['yields_resource'] as String?,
      resourceYieldAmount: (json['resource_yield_amount'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Pending Delivery ─────────────────────────────────────────────────────────
// Goods ordered from Kovacs arrive the following week, not immediately.

class PendingDelivery {
  final String resourceKey; // 'seeds', 'water', 'chemicals', 'ore', 'components'
  final double amount;
  final int arrivalWeek;

  const PendingDelivery({
    required this.resourceKey,
    required this.amount,
    required this.arrivalWeek,
  });

  Map<String, dynamic> toJson() => {
    'resource_key': resourceKey,
    'amount': amount,
    'arrival_week': arrivalWeek,
  };

  factory PendingDelivery.fromJson(Map<String, dynamic> j) => PendingDelivery(
    resourceKey: j['resource_key'] as String,
    amount: (j['amount'] as num).toDouble(),
    arrivalWeek: (j['arrival_week'] as num).toInt(),
  );
}

// ─── Dome Bot ─────────────────────────────────────────────────────────────────

class DomeBot {
  final int level;          // 1-4
  final String? plantCropId; // Mk4 only — which crop to auto-plant
  final int powerDraw;

  const DomeBot({
    required this.level,
    this.plantCropId,
    required this.powerDraw,
  });

  bool get canWater     => level >= 1;
  bool get canHarvest   => level >= 2;
  bool get canFertilize => level >= 3;
  bool get canPlant     => level >= 4;

  DomeBot copyWith({int? level, String? plantCropId, int? powerDraw}) {
    return DomeBot(
      level: level ?? this.level,
      plantCropId: plantCropId ?? this.plantCropId,
      powerDraw: powerDraw ?? this.powerDraw,
    );
  }

  DomeBot withCrop(String cropId) => copyWith(plantCropId: cropId);
}

// ─── Defense Wall ─────────────────────────────────────────────────────────────

class DefenseWall {
  final int level;
  final int currentHp;
  final int maxHp;

  const DefenseWall({
    required this.level,
    required this.currentHp,
    required this.maxHp,
  });

  double get healthPercent => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
  bool get isDestroyed => currentHp <= 0;
  bool get needsRepair => currentHp < maxHp;

  DefenseWall copyWith({int? level, int? currentHp, int? maxHp}) {
    return DefenseWall(
      level: level ?? this.level,
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
    );
  }

  DefenseWall fullyRepaired() => copyWith(currentHp: maxHp);
  DefenseWall takeDamage(int damage) => copyWith(currentHp: (currentHp - damage).clamp(0, maxHp));
}

// ─── Grenade Inventory ────────────────────────────────────────────────────────

class GrenadeInventory {
  final Map<String, int> counts; // grenadeId -> count
  final int benchLevel;

  const GrenadeInventory({
    required this.counts,
    required this.benchLevel,
  });

  int countOf(String grenadeId) => counts[grenadeId] ?? 0;
  bool has(String grenadeId) => countOf(grenadeId) > 0;

  GrenadeInventory use(String grenadeId) {
    final current = countOf(grenadeId);
    if (current <= 0) return this;
    final updated = Map<String, int>.from(counts);
    updated[grenadeId] = current - 1;
    if (updated[grenadeId] == 0) updated.remove(grenadeId);
    return GrenadeInventory(counts: updated, benchLevel: benchLevel);
  }

  GrenadeInventory add(String grenadeId, int amount) {
    final updated = Map<String, int>.from(counts);
    updated[grenadeId] = (updated[grenadeId] ?? 0) + amount;
    return GrenadeInventory(counts: updated, benchLevel: benchLevel);
  }

  GrenadeInventory copyWith({Map<String, int>? counts, int? benchLevel}) {
    return GrenadeInventory(
      counts: counts ?? this.counts,
      benchLevel: benchLevel ?? this.benchLevel,
    );
  }
}

// ─── Raid Result ──────────────────────────────────────────────────────────────

class RaidResult {
  final int week;
  final int faunaKilled;
  final int faunaEscaped;
  final int wallDamageTaken;
  final bool wallBroken;
  final int cropsLost;
  final int meatDropped;
  final int chitinDropped;
  final bool wasDefended;

  const RaidResult({
    required this.week,
    required this.faunaKilled,
    required this.faunaEscaped,
    required this.wallDamageTaken,
    required this.wallBroken,
    required this.cropsLost,
    required this.meatDropped,
    required this.chitinDropped,
    required this.wasDefended,
  });
}

// ─── Active Fauna Unit (used during raid mini-game only) ─────────────────────

class FaunaUnit {
  final String id;
  final String typeId;
  final String emoji;
  final double hp;
  final double maxHp;
  final double speed;
  final int damage;
  final double hitInterval;
  final bool isBrute;
  // Position on screen (0.0-1.0 normalized)
  final double x;
  final double y;
  // State
  final bool isStunned;
  final bool isScattered;
  final bool isBaited;
  final double stunTimeRemaining;
  final double timeSinceLastHit;

  const FaunaUnit({
    required this.id,
    required this.typeId,
    required this.emoji,
    required this.hp,
    required this.maxHp,
    required this.speed,
    required this.damage,
    required this.hitInterval,
    required this.isBrute,
    required this.x,
    required this.y,
    this.isStunned = false,
    this.isScattered = false,
    this.isBaited = false,
    this.stunTimeRemaining = 0,
    this.timeSinceLastHit = 0,
  });

  bool get isDead => hp <= 0;
  bool get isAtWall => y >= 0.85;

  FaunaUnit copyWith({
    double? hp,
    double? x,
    double? y,
    bool? isStunned,
    bool? isScattered,
    bool? isBaited,
    double? stunTimeRemaining,
    double? timeSinceLastHit,
  }) {
    return FaunaUnit(
      id: id, typeId: typeId, emoji: emoji,
      maxHp: maxHp, speed: speed, damage: damage,
      hitInterval: hitInterval, isBrute: isBrute,
      hp: hp ?? this.hp,
      x: x ?? this.x,
      y: y ?? this.y,
      isStunned: isStunned ?? this.isStunned,
      isScattered: isScattered ?? this.isScattered,
      isBaited: isBaited ?? this.isBaited,
      stunTimeRemaining: stunTimeRemaining ?? this.stunTimeRemaining,
      timeSinceLastHit: timeSinceLastHit ?? this.timeSinceLastHit,
    );
  }
}

// ─── Active Grenade / Effect (used during raid mini-game only) ───────────────

class ActiveGrenade {
  final String id;
  final String grenadeId;
  final double targetX;
  final double targetY;
  final double progress; // 0.0 = just thrown, 1.0 = arrived
  final bool hasExploded;

  const ActiveGrenade({
    required this.id,
    required this.grenadeId,
    required this.targetX,
    required this.targetY,
    required this.progress,
    required this.hasExploded,
  });

  ActiveGrenade copyWith({double? progress, bool? hasExploded}) {
    return ActiveGrenade(
      id: id, grenadeId: grenadeId,
      targetX: targetX, targetY: targetY,
      progress: progress ?? this.progress,
      hasExploded: hasExploded ?? this.hasExploded,
    );
  }
}

// ─── Active Effect Zone (burn zone, bait zone) ───────────────────────────────

class ActiveEffect {
  final String id;
  final String effectType; // 'burn_zone', 'bait', 'stun_zone'
  final double x;
  final double y;
  final double radius;
  final double timeRemaining;
  final double damagePerSecond;

  const ActiveEffect({
    required this.id,
    required this.effectType,
    required this.x,
    required this.y,
    required this.radius,
    required this.timeRemaining,
    this.damagePerSecond = 0,
  });

  ActiveEffect copyWith({double? timeRemaining}) {
    return ActiveEffect(
      id: id, effectType: effectType, x: x, y: y,
      radius: radius, damagePerSecond: damagePerSecond,
      timeRemaining: timeRemaining ?? this.timeRemaining,
    );
  }
}