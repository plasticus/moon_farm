// ═══════════════════════════════════════════════════════════════
//  lib/models/game_models.dart
// ═══════════════════════════════════════════════════════════════

// All core data models for Moon Farm

// ─── Enums ────────────────────────────────────────────────────────────────────

enum Difficulty { easy, normal, hard }

enum GameStatus { active, terminated, won }

enum CropState { empty, planted, growing, ready, dead }

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

enum PowerSourceType { solarArray, windTurbine, geothermalTap, mycovaultReactor }

enum BuildingType { dome, silo, refinery, laserSentry, powerSource }

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

  // "4J" is the player's callsign in radio chatter and Kovacs' dialogue —
  // appending it to the farm name wherever it's displayed makes it obvious
  // those broadcasts are about you. Not stored, just shown.
  String? get displayName => farmName != null ? '$farmName (4J)' : null;
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
  final List<Monument> monuments;
  final List<WeeklyLogEntry> log;
  final List<RadioTransmission> radioFeed;
  final RelayTechnicianState relay;
  final double totalVolumeDeliveredM3;
  final double totalScrapSoldDam3;
  final int lifetimeScripEarned;
  final int pendingContractScrip; // contract bonuses waiting for next shipment
  final int totalCropsHarvested;
  final int totalCompostGenerated;
  final Map<String, int> cropHarvestCounts; // cropId -> times harvested
  final String? terminationReason; // set when game ends
  final int nextRaidWeek;
  final bool raidDefendedThisWeek;
  final bool manualRaidTriggeredThisWeek;
  // Generic discovery flags for things that unlock via gameplay events
  // rather than scrip/resources (e.g. 'mycoculture_vat' on first
  // Hyper-Mycelium harvest, 'mycovault_reactor' on first Mycoculture made).
  final List<String> unlockedFeatures;
  // Ids of one-shot radio_triggers.toml entries that have already
  // fired for this save — see lib/engine/radio_trigger_engine.dart.
  final List<String> firedRadioTriggers;
  // The most recently completed week's summary — lets the dashboard
  // offer a "view summary again" button without re-running the engine.
  // Overwritten every End Week; null until the first week ever ends.
  final WeekSummary? lastWeekSummary;
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
    this.monuments = const [],
    required this.log,
    required this.radioFeed,
    required this.relay,
    required this.totalVolumeDeliveredM3,
    this.totalScrapSoldDam3 = 0.0,
    required this.lifetimeScripEarned,
    this.pendingContractScrip = 0,
    required this.totalCropsHarvested,
    required this.totalCompostGenerated,
    this.cropHarvestCounts = const {},
    this.terminationReason,
    required this.nextRaidWeek,
    required this.raidDefendedThisWeek,
    this.manualRaidTriggeredThisWeek = false,
    this.unlockedFeatures = const [],
    this.firedRadioTriggers = const [],
    this.lastWeekSummary,
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
    List<Monument>? monuments,
    List<WeeklyLogEntry>? log,
    List<RadioTransmission>? radioFeed,
    RelayTechnicianState? relay,
    double? totalVolumeDeliveredM3,
    double? totalScrapSoldDam3,
    int? lifetimeScripEarned,
    int? pendingContractScrip,
    int? totalCropsHarvested,
    int? totalCompostGenerated,
    Map<String, int>? cropHarvestCounts,
    String? terminationReason,
    int? nextRaidWeek,
    bool? raidDefendedThisWeek,
    bool? manualRaidTriggeredThisWeek,
    List<String>? unlockedFeatures,
    List<String>? firedRadioTriggers,
    WeekSummary? lastWeekSummary,
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
      monuments: monuments ?? this.monuments,
      log: log ?? this.log,
      radioFeed: radioFeed ?? this.radioFeed,
      relay: relay ?? this.relay,
      totalVolumeDeliveredM3: totalVolumeDeliveredM3 ?? this.totalVolumeDeliveredM3,
      totalScrapSoldDam3: totalScrapSoldDam3 ?? this.totalScrapSoldDam3,
      lifetimeScripEarned: lifetimeScripEarned ?? this.lifetimeScripEarned,
      pendingContractScrip: pendingContractScrip ?? this.pendingContractScrip,
      totalCropsHarvested: totalCropsHarvested ?? this.totalCropsHarvested,
      totalCompostGenerated:
      totalCompostGenerated ?? this.totalCompostGenerated,
      cropHarvestCounts: cropHarvestCounts ?? this.cropHarvestCounts,
      terminationReason: terminationReason ?? this.terminationReason,
      nextRaidWeek: nextRaidWeek ?? this.nextRaidWeek,
      raidDefendedThisWeek: raidDefendedThisWeek ?? this.raidDefendedThisWeek,
      manualRaidTriggeredThisWeek:
      manualRaidTriggeredThisWeek ?? this.manualRaidTriggeredThisWeek,
      unlockedFeatures: unlockedFeatures ?? this.unlockedFeatures,
      firedRadioTriggers: firedRadioTriggers ?? this.firedRadioTriggers,
      lastWeekSummary: lastWeekSummary ?? this.lastWeekSummary,
      pendingSales: pendingSales ?? this.pendingSales,
      siloInventory: siloInventory ?? this.siloInventory,
      shipmentsThisWindow: shipmentsThisWindow ?? this.shipmentsThisWindow,
      nextShipWindowWeek: nextShipWindowWeek ?? this.nextShipWindowWeek,
      waterPurifierLevel: waterPurifierLevel ?? this.waterPurifierLevel,
      lastSaved: lastSaved ?? this.lastSaved,
    );
  }

  // "4J" is the player's callsign in radio chatter and Kovacs' dialogue —
  // appending it to the farm name wherever it's displayed makes it obvious
  // those broadcasts are about you. Not stored, just shown.
  String get displayName => '$farmName (4J)';

  // Power calculations
  int get totalPowerProduction =>
      powerSources.fold(0, (sum, p) => sum + p.outputKwh);

  int get totalPowerDraw {
    int draw = 0;
    for (final dome in domes) {
      draw += dome.powerDraw;
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
  final double moss;
  final double mycoculture;
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
    this.moss = 0,
    this.mycoculture = 0,
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
    double? moss,
    double? mycoculture,
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
      moss: moss ?? this.moss,
      mycoculture: mycoculture ?? this.mycoculture,
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
      moss: moss + other.moss,
      mycoculture: mycoculture + other.mycoculture,
      starScrip: starScrip + other.starScrip,
      seeds: seeds + other.seeds,
    );
  }
}

// ─── Dome ─────────────────────────────────────────────────────────────────────

class Dome {
  final String id;
  final String name;
  final int tier; // 1-5
  final List<CropCell> cells; // always 8 cells (positions 0-7, center reserved)
  final DomeBot? domeBot;
  final int structuralHealth; // 0-100
  final int powerDraw;

  const Dome({
    required this.id,
    required this.name,
    required this.tier,
    required this.cells,
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
    DomeBot? domeBot,
    int? structuralHealth,
    int? powerDraw,
  }) {
    return Dome(
      id: id ?? this.id,
      name: name ?? this.name,
      tier: tier ?? this.tier,
      cells: cells ?? this.cells,
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

enum MachineType { composter, smelter, zSoilProcessor, glassFurnace, componentFabricator, mycocultureVat }

class RefineryMachine {
  final MachineType type;
  final int level; // 1-10
  final int powerDraw;
  final bool autoRefine; // Mk10 only — auto-crafts max possible each end-week

  const RefineryMachine({
    required this.type,
    required this.level,
    required this.powerDraw,
    this.autoRefine = false,
  });

  String get name => switch (type) {
    MachineType.composter => 'Composter',
    MachineType.smelter => 'Smelter',
    MachineType.zSoilProcessor => 'Z-Soil Processor',
    MachineType.glassFurnace => 'Glass Furnace',
    MachineType.componentFabricator => 'Component Fabricator',
    MachineType.mycocultureVat => 'Mycoculture Vat',
  };

  String get emoji => switch (type) {
    MachineType.composter => '♻️',
    MachineType.smelter => '🔥',
    MachineType.zSoilProcessor => '🌱',
    MachineType.glassFurnace => '🪟',
    MachineType.componentFabricator => '⚙️',
    MachineType.mycocultureVat => '🧫',
  };

  // Key used to look up this machine in upgrades_refinery.yaml
  String get yamlKey => switch (type) {
    MachineType.composter => 'composter',
    MachineType.smelter => 'smelter',
    MachineType.zSoilProcessor => 'z_soil_processor',
    MachineType.glassFurnace => 'glass_furnace',
    MachineType.componentFabricator => 'component_fabricator',
    MachineType.mycocultureVat => 'mycoculture_vat',
  };

  static MachineType typeFromYamlKey(String key) => switch (key) {
    'composter' => MachineType.composter,
    'smelter' => MachineType.smelter,
    'z_soil_processor' => MachineType.zSoilProcessor,
    'glass_furnace' => MachineType.glassFurnace,
    'component_fabricator' => MachineType.componentFabricator,
    'mycoculture_vat' => MachineType.mycocultureVat,
    _ => MachineType.composter,
  };

  RefineryMachine copyWith({int? level, int? powerDraw, bool? autoRefine}) {
    return RefineryMachine(
      type: type,
      level: level ?? this.level,
      powerDraw: powerDraw ?? this.powerDraw,
      autoRefine: autoRefine ?? this.autoRefine,
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
      case PowerSourceType.geothermalTap: return 'Geothermal Tap';
      case PowerSourceType.mycovaultReactor: return 'Mycovault Reactor';
    }
  }

  String get emoji {
    switch (type) {
      case PowerSourceType.solarArray: return '☀️';
      case PowerSourceType.windTurbine: return '🌀';
      case PowerSourceType.geothermalTap: return '🌋';
      case PowerSourceType.mycovaultReactor: return '⚛️';
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
  // 'volume_delivered' | 'power_capacity' | 'contracts_completed' |
  // 'fauna_killed' | 'crop_diversity' | 'scrip_balance' | 'monuments_built' |
  // 'scrap_baron' | 'full_automation' | 'kovacs_topic_unlocked' |
  // 'kovacs_mood_max' | 'kovacs_mood_min' | 'feature_unlocked'. See
  // EndWeekEngine._isMilestoneComplete for what `target` means for each type.
  final String checkType;
  final double target;
  // Deadline week, inclusive. Null = achievement-style milestone with no
  // deadline — it just waits until completed, never warned/failed/terminated.
  final int? byWeek;
  final int rewardScrip;
  final MilestoneStatus status;
  final String failureMessage;
  final String failureDetail;
  // If true, completing this milestone ends the game with GameStatus.won
  // instead of just banking the reward. Exactly one milestone should set
  // this. The game does not stop running afterward — status just flips to
  // won and play continues (see EndWeekEngine Step 7).
  final bool isWinCondition;
  // A generic "id that must be present in a set" key, reused across two
  // check_types: 'kovacs_topic_unlocked' checks relay.unlockedTopicIds
  // (topic ids from kovacs_dialog.json); 'feature_unlocked' checks
  // GameState.unlockedFeatures (e.g. 'discovered_moss').
  final String? topicId;

  const Milestone({
    required this.id,
    required this.name,
    required this.description,
    this.checkType = 'volume_delivered',
    required this.target,
    this.byWeek,
    required this.rewardScrip,
    required this.status,
    this.failureMessage = '',
    this.failureDetail = '',
    this.isWinCondition = false,
    this.topicId,
  });

  Milestone copyWith({MilestoneStatus? status}) {
    return Milestone(
      id: id,
      name: name,
      description: description,
      checkType: checkType,
      target: target,
      byWeek: byWeek,
      rewardScrip: rewardScrip,
      status: status ?? this.status,
      failureMessage: failureMessage,
      failureDetail: failureDetail,
      isWinCondition: isWinCondition,
      topicId: topicId,
    );
  }
}

// ─── Monument ─────────────────────────────────────────────────────────────────
// A single built monument. Repeatable — the same mkLevel can be built more
// than once, each becoming its own entry here. All display data (name,
// lore, cost, score value) lives in assets/config/monuments.yaml, keyed by
// mkLevel — this just records what was actually built and when.

class Monument {
  final String id;
  final int mkLevel; // 1-10
  final int weekBuilt;

  const Monument({
    required this.id,
    required this.mkLevel,
    required this.weekBuilt,
  });
}

// ─── Relay Technician ─────────────────────────────────────────────────────────

class RelayTechnicianState {
  final int mood; // 0-100
  final List<String> availableContracts; // 3 contract options
  final bool contractsRefreshedThisWeek;
  final Set<String> unlockedTopicIds;
  final bool conversationDoneThisWeek;
  // One-shot flags, set the first time mood ever hits either extreme —
  // mood itself fluctuates, so these are what a milestone can check.
  final bool hasReachedMaxMood;
  final bool hasReachedMinMood;

  const RelayTechnicianState({
    required this.mood,
    required this.availableContracts,
    required this.contractsRefreshedThisWeek,
    this.unlockedTopicIds = const {},
    this.conversationDoneThisWeek = false,
    this.hasReachedMaxMood = false,
    this.hasReachedMinMood = false,
  });

  String get moodLabel {
    if (mood >= 85) return 'Elated 😄';
    if (mood >= 65) return 'Happy 🙂';
    if (mood >= 40) return 'Neutral 😐';
    if (mood >= 20) return 'Sour 😒';
    return 'Hostile 😤';
  }

  double get priceDiscount {
    // Continuous scale from -25% (mood 0) to +20% (mood 100).
    // mood 50 (neutral midpoint) lands close to 0%.
    if (mood >= 50) {
      // 50→100 maps to 0%→+20%
      return (mood - 50) / 50.0 * 0.20;
    } else {
      // 0→50 maps to -25%→0%
      return (mood - 50) / 50.0 * 0.25;
    }
  }

  RelayTechnicianState copyWith({
    int? mood,
    List<String>? availableContracts,
    bool? contractsRefreshedThisWeek,
    Set<String>? unlockedTopicIds,
    bool? conversationDoneThisWeek,
    bool? hasReachedMaxMood,
    bool? hasReachedMinMood,
  }) {
    return RelayTechnicianState(
      mood: (mood ?? this.mood).clamp(0, 100),
      availableContracts: availableContracts ?? this.availableContracts,
      contractsRefreshedThisWeek:
      contractsRefreshedThisWeek ?? this.contractsRefreshedThisWeek,
      unlockedTopicIds: unlockedTopicIds ?? this.unlockedTopicIds,
      conversationDoneThisWeek:
      conversationDoneThisWeek ?? this.conversationDoneThisWeek,
      hasReachedMaxMood: hasReachedMaxMood ?? this.hasReachedMaxMood,
      hasReachedMinMood: hasReachedMinMood ?? this.hasReachedMinMood,
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
  final List<String> milestoneUpdates;
  final List<String> contractUpdates;
  final bool raidOccurred;
  final Map<String, double> resourceChanges;
  final List<String> robotActions;
  final List<String> events; // full event log for the week
  final int newWeek;
  // Radio messages that newly fired during THIS week's processing (pool
  // pick + any radio_triggers.toml entries that fired this pass) — what
  // the week summary screen should actually show, instead of a derived
  // "most recent tip so far" lookup that would just repeat forever once
  // there's nothing left to advance past.
  final List<String> newRadioMessages;

  const WeekSummary({
    required this.week,
    required this.scripReceived,
    required this.scripSpent,
    required this.cropsHarvested,
    required this.cropsDied,
    required this.volumeToColonyM3,
    required this.milestoneUpdates,
    required this.contractUpdates,
    required this.raidOccurred,
    required this.resourceChanges,
    required this.robotActions,
    required this.events,
    required this.newWeek,
    this.newRadioMessages = const [],
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
  // If set, this crop must be FED this resource on a schedule (handled
  // through the same fertilize action/cooldown as compost-fertilizing,
  // but mandatory — missing a due feeding window decays yield exactly
  // like missing a watering, rather than just forgoing a bonus).
  final String? feedResource;

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
    this.feedResource,
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
    'luna_lentils': '🫘',
    'matrix_moss': '🟩',
    'fauna_meat': '🥩',
    'gristle_pod': '🥜',
    'tangleberry': '🍇',
    'prism_pepper': '🫑',
    'mycelium_prime': '🧬',
    'lattice_moss': '💠',
    'marrow_bloom': '🌺',
    'chiton_reed': '🦀',
    'glutton_vine': '🍒',
    'halo_fruit': '🍊',
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
      feedResource: json['feed_resource'] as String?,
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

  /// Explicitly clears the planting crop (sets to null) — "None" option.
  DomeBot withNoCrop() => DomeBot(
    level: level,
    plantCropId: null,
    powerDraw: powerDraw,
  );
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
  bool get isAtWall => y >= 0.81;

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
  final double damagePercentPerSecond; // % of target's maxHp, per second

  const ActiveEffect({
    required this.id,
    required this.effectType,
    required this.x,
    required this.y,
    required this.radius,
    required this.timeRemaining,
    this.damagePercentPerSecond = 0,
  });

  ActiveEffect copyWith({double? timeRemaining}) {
    return ActiveEffect(
      id: id, effectType: effectType, x: x, y: y,
      radius: radius, damagePercentPerSecond: damagePercentPerSecond,
      timeRemaining: timeRemaining ?? this.timeRemaining,
    );
  }
}