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
  final List<Contract> activeContracts;
  final List<Contract> completedContracts;
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
    required this.activeContracts,
    required this.completedContracts,
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
      activeContracts: activeContracts ?? this.activeContracts,
      completedContracts: completedContracts ?? this.completedContracts,
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
    }
    for (final silo in silos) {
      draw += silo.powerDraw;
    }
    for (final refinery in refineries) {
      draw += refinery.powerDraw;
    }
    for (final sentry in laserSentries) {
      draw += sentry.powerDraw;
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
  final int starScrip;
  final int seeds; // seeds are tracked by crop type separately in dome cells

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
  final int structuralHealth; // 0-100
  final int powerDraw;

  const Dome({
    required this.id,
    required this.name,
    required this.tier,
    required this.cells,
    this.robot,
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
    int? structuralHealth,
    int? powerDraw,
  }) {
    return Dome(
      id: id ?? this.id,
      name: name ?? this.name,
      tier: tier ?? this.tier,
      cells: cells ?? this.cells,
      robot: robot,
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
  final int healthPercent; // 0-100

  const CropCell({
    required this.position,
    this.cropId,
    required this.state,
    this.weeksGrown = 0,
    this.wateredThisWeek = false,
    this.fertilizedThisWeek = false,
    this.healthPercent = 100,
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
  }) {
    return CropCell(
      position: position ?? this.position,
      cropId: cropId ?? this.cropId,
      state: state ?? this.state,
      weeksGrown: weeksGrown ?? this.weeksGrown,
      wateredThisWeek: wateredThisWeek ?? this.wateredThisWeek,
      fertilizedThisWeek: fertilizedThisWeek ?? this.fertilizedThisWeek,
      healthPercent: healthPercent ?? this.healthPercent,
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

  const Refinery({
    required this.id,
    required this.tier,
    required this.powerDraw,
    required this.unlockedRecipes,
  });

  Refinery copyWith({
    String? id,
    int? tier,
    int? powerDraw,
    List<String>? unlockedRecipes,
  }) {
    return Refinery(
      id: id ?? this.id,
      tier: tier ?? this.tier,
      powerDraw: powerDraw ?? this.powerDraw,
      unlockedRecipes: unlockedRecipes ?? this.unlockedRecipes,
    );
  }
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

  const RelayTechnicianState({
    required this.mood,
    required this.seenRantTopics,
    required this.availableContracts,
    required this.contractsRefreshedThisWeek,
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
  }) {
    return RelayTechnicianState(
      mood: (mood ?? this.mood).clamp(0, 100),
      seenRantTopics: seenRantTopics ?? this.seenRantTopics,
      availableContracts: availableContracts ?? this.availableContracts,
      contractsRefreshedThisWeek:
      contractsRefreshedThisWeek ?? this.contractsRefreshedThisWeek,
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
  final int scripReceived;   // from pending sales processing
  final int scripSpent;
  final int cropsHarvested;
  final int cropsDied;
  final double volumeToColonyM3;
  final List<String> newTrophies;
  final List<String> milestoneUpdates;
  final List<String> contractUpdates;
  final bool raidOccurred;
  final Map<String, double> resourceChanges;
  final List<String> robotActions; // what the bots did
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
  final int baseSolarValue;
  final int compostYield;
  final String description;
  final bool canDecay;
  final bool decayIfNotWatered;
  final bool decayIfNotHarvestedOnReady;
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
    required this.baseSolarValue,
    required this.compostYield,
    required this.description,
    required this.canDecay,
    required this.decayIfNotWatered,
    required this.decayIfNotHarvestedOnReady,
    required this.fertilizerBonus,
    required this.volumeM3,
    this.yieldsResource,
    required this.resourceYieldAmount,
  });

  factory CropConfig.fromJson(Map<String, dynamic> json) {
    return CropConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      tier: json['tier'] as int,
      domeTierRequired: json['dome_tier_required'] as int,
      growthWeeks: json['growth_weeks'] as int,
      waterPerWeek: json['water_per_week'] as int,
      caloriesPerUnit: json['calories_per_unit'] as int? ?? 0,
      baseSolarValue: json['base_scrip_value'] as int? ?? json['base_solar_value'] as int? ?? 5,
      compostYield: json['compost_yield'] as int,
      description: json['description'] as String,
      canDecay: json['can_decay'] as bool? ?? false,
      decayIfNotWatered: json['decay_if_not_watered'] as bool? ?? false,
      decayIfNotHarvestedOnReady:
      json['decay_if_not_harvested_on_ready'] as bool? ?? false,
      fertilizerBonus: (json['fertilizer_bonus'] as num?)?.toDouble() ?? 1.0,
      volumeM3: (json['volume_m3'] as num?)?.toDouble() ?? 0.5,
      yieldsResource: json['yields_resource'] as String?,
      resourceYieldAmount: json['resource_yield_amount'] as int? ?? 0,
    );
  }
}