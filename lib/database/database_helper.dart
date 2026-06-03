// ═══════════════════════════════════════════════════════════════
//  lib/database/database_helper.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/game_models.dart';

// Safe numeric helpers — SQLite can return int or double for any number.
// Always cast through num to avoid runtime type errors.
int _i(dynamic v) => (v as num).toInt();
double _d(dynamic v) => (v as num).toDouble();
int? _iN(dynamic v) => v == null ? null : (v as num).toInt();
double? _dN(dynamic v) => v == null ? null : (v as num).toDouble();

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('moon_farm.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS game_states');
        await db.execute('DROP TABLE IF EXISTS save_slots');
        await db.execute('DROP TABLE IF EXISTS trophies');
        await db.execute('DROP TABLE IF EXISTS weekly_log');
        await _createDB(db, newVersion);
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE save_slots (
        slot_number INTEGER PRIMARY KEY,
        farm_name TEXT,
        difficulty TEXT,
        current_week INTEGER,
        total_scrip INTEGER,
        last_saved TEXT,
        is_empty INTEGER DEFAULT 1
      )
    ''');

    for (int i = 0; i <= 3; i++) {
      await db.insert('save_slots', {'slot_number': i, 'is_empty': 1});
    }

    await db.execute('''
      CREATE TABLE game_states (
        slot_number INTEGER PRIMARY KEY,
        game_id INTEGER,
        state_json TEXT NOT NULL,
        last_saved TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE trophies (
        id TEXT NOT NULL,
        slot_number INTEGER NOT NULL,
        unlocked INTEGER DEFAULT 0,
        week_earned INTEGER,
        PRIMARY KEY (id, slot_number)
      )
    ''');

    await db.execute('''
      CREATE TABLE weekly_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        slot_number INTEGER NOT NULL,
        week INTEGER NOT NULL,
        events_json TEXT NOT NULL,
        scrip_gained INTEGER DEFAULT 0,
        scrip_spent INTEGER DEFAULT 0,
        crops_harvested INTEGER DEFAULT 0,
        volume_delivered_m3 REAL DEFAULT 0,
        raid_occurred INTEGER DEFAULT 0,
        raid_succeeded INTEGER DEFAULT 0,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_log_slot ON weekly_log (slot_number, week DESC)');
    await db.execute('CREATE INDEX idx_trophies_slot ON trophies (slot_number)');
  }

  Future<List<SaveSlot>> getAllSaveSlots() async {
    final db = await database;
    final results = await db.query('save_slots', orderBy: 'slot_number');
    return results.map((row) {
      final isEmpty = _i(row['is_empty']) == 1;
      return SaveSlot(
        slotNumber: _i(row['slot_number']),
        farmName: row['farm_name'] as String?,
        difficulty: isEmpty ? null : _difficultyFromString(row['difficulty'] as String?),
        currentWeek: _iN(row['current_week']),
        totalScrip: _dN(row['total_scrip']),
        lastSaved: row['last_saved'] != null
            ? DateTime.parse(row['last_saved'] as String)
            : null,
        isEmpty: isEmpty,
      );
    }).toList();
  }

  Future<void> updateSaveSlotMeta(GameState state) async {
    final db = await database;
    await db.update(
      'save_slots',
      {
        'farm_name': state.farmName,
        'difficulty': state.difficulty.name,
        'current_week': state.currentWeek,
        'total_scrip': state.resources.starScrip,
        'last_saved': state.lastSaved.toIso8601String(),
        'is_empty': 0,
      },
      where: 'slot_number = ?',
      whereArgs: [state.slotNumber],
    );
  }

  Future<void> clearSaveSlot(int slotNumber) async {
    final db = await database;
    await db.update(
      'save_slots',
      {'farm_name': null, 'difficulty': null, 'current_week': null,
        'total_scrip': null, 'last_saved': null, 'is_empty': 1},
      where: 'slot_number = ?',
      whereArgs: [slotNumber],
    );
    await db.delete('game_states', where: 'slot_number = ?', whereArgs: [slotNumber]);
    await db.delete('trophies', where: 'slot_number = ?', whereArgs: [slotNumber]);
    await db.delete('weekly_log', where: 'slot_number = ?', whereArgs: [slotNumber]);
  }

  Future<void> saveGameState(GameState state) async {
    final db = await database;
    await db.insert(
      'game_states',
      {
        'slot_number': state.slotNumber,
        'game_id': state.gameId,
        'state_json': jsonEncode(_gameStateToJson(state)),
        'last_saved': state.lastSaved.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await updateSaveSlotMeta(state);
    await _syncTrophies(db, state);
  }

  Future<GameState?> loadGameState(int slotNumber) async {
    final db = await database;
    final results = await db.query('game_states', where: 'slot_number = ?', whereArgs: [slotNumber]);
    if (results.isEmpty) return null;
    final json = jsonDecode(results.first['state_json'] as String) as Map<String, dynamic>;
    return _gameStateFromJson(json);
  }

  Future<void> _syncTrophies(Database db, GameState state) async {
    for (final trophy in state.trophies) {
      if (trophy.status == TrophyStatus.unlocked) {
        await db.insert('trophies',
          {'id': trophy.id, 'slot_number': state.slotNumber, 'unlocked': 1, 'week_earned': trophy.weekEarned},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  Future<void> insertLogEntry(int slotNumber, WeeklyLogEntry entry) async {
    final db = await database;
    await db.insert('weekly_log', {
      'slot_number': slotNumber,
      'week': entry.week,
      'events_json': jsonEncode(entry.events),
      'scrip_gained': entry.scripGained,
      'scrip_spent': entry.scripSpent,
      'crops_harvested': entry.cropsHarvested,
      'volume_delivered_m3': entry.volumeDeliveredM3,
      'raid_occurred': entry.raidOccurred ? 1 : 0,
      'raid_succeeded': entry.raidSucceeded ? 1 : 0,
      'timestamp': entry.timestamp.toIso8601String(),
    });
  }

  Future<List<WeeklyLogEntry>> getLogEntries(int slotNumber, {int limit = 50}) async {
    final db = await database;
    final results = await db.query('weekly_log',
        where: 'slot_number = ?', whereArgs: [slotNumber],
        orderBy: 'week DESC', limit: limit);
    return results.map((row) => WeeklyLogEntry(
      week: _i(row['week']),
      events: List<String>.from(jsonDecode(row['events_json'] as String) as List),
      scripGained: _i(row['scrip_gained']),
      scripSpent: _i(row['scrip_spent']),
      cropsHarvested: _i(row['crops_harvested']),
      volumeDeliveredM3: _d(row['volume_delivered_m3']),
      raidOccurred: _i(row['raid_occurred']) == 1,
      raidSucceeded: _i(row['raid_succeeded']) == 1,
      timestamp: DateTime.parse(row['timestamp'] as String),
    )).toList();
  }

  Map<String, dynamic> _gameStateToJson(GameState s) => {
    'game_id': s.gameId, 'slot_number': s.slotNumber, 'farm_name': s.farmName,
    'difficulty': s.difficulty.name, 'current_week': s.currentWeek,
    'status': s.status.name, 'strike_count': s.strikeCount,
    'resources': _resourcesToJson(s.resources),
    'domes': s.domes.map(_domeToJson).toList(),
    'silos': s.silos.map(_siloToJson).toList(),
    'refineries': s.refineries.map(_refineryToJson).toList(),
    'power_sources': s.powerSources.map(_powerSourceToJson).toList(),
    'laser_sentries': s.laserSentries.map(_sentryToJson).toList(),
    'active_contracts': s.activeContracts.map(_contractToJson).toList(),
    'completed_contracts': s.completedContracts.map(_contractToJson).toList(),
    'milestones': s.milestones.map(_milestoneToJson).toList(),
    'trophies': s.trophies.map(_trophyToJson).toList(),
    'log': s.log.map(_logEntryToJson).toList(),
    'radio_feed': s.radioFeed.map(_radioToJson).toList(),
    'relay': _relayToJson(s.relay),
    'total_volume_delivered_m3': s.totalVolumeDeliveredM3,
    'lifetime_scrip_earned': s.lifetimeScripEarned,
    'total_crops_harvested': s.totalCropsHarvested,
    'total_compost_generated': s.totalCompostGenerated,
    'next_raid_week': s.nextRaidWeek,
    'raid_defended_this_week': s.raidDefendedThisWeek,
    'pending_sales': s.pendingSales.map(_pendingSaleToJson).toList(),
    'last_saved': s.lastSaved.toIso8601String(),
  };

  GameState _gameStateFromJson(Map<String, dynamic> j) => GameState(
    gameId: _i(j['game_id']), slotNumber: _i(j['slot_number']),
    farmName: j['farm_name'] as String,
    difficulty: _difficultyFromString(j['difficulty'] as String)!,
    currentWeek: _i(j['current_week']),
    status: GameStatus.values.firstWhere((e) => e.name == j['status']),
    strikeCount: _i(j['strike_count']),
    resources: _resourcesFromJson(j['resources'] as Map<String, dynamic>),
    domes: (j['domes'] as List).map((d) => _domeFromJson(d as Map<String, dynamic>)).toList(),
    silos: (j['silos'] as List).map((d) => _siloFromJson(d as Map<String, dynamic>)).toList(),
    refineries: (j['refineries'] as List).map((d) => _refineryFromJson(d as Map<String, dynamic>)).toList(),
    powerSources: (j['power_sources'] as List).map((d) => _powerSourceFromJson(d as Map<String, dynamic>)).toList(),
    laserSentries: (j['laser_sentries'] as List).map((d) => _sentryFromJson(d as Map<String, dynamic>)).toList(),
    activeContracts: (j['active_contracts'] as List).map((d) => _contractFromJson(d as Map<String, dynamic>)).toList(),
    completedContracts: (j['completed_contracts'] as List).map((d) => _contractFromJson(d as Map<String, dynamic>)).toList(),
    milestones: (j['milestones'] as List).map((d) => _milestoneFromJson(d as Map<String, dynamic>)).toList(),
    trophies: (j['trophies'] as List).map((d) => _trophyFromJson(d as Map<String, dynamic>)).toList(),
    log: (j['log'] as List).map((d) => _logEntryFromJson(d as Map<String, dynamic>)).toList(),
    radioFeed: (j['radio_feed'] as List).map((d) => _radioFromJson(d as Map<String, dynamic>)).toList(),
    relay: _relayFromJson(j['relay'] as Map<String, dynamic>),
    totalVolumeDeliveredM3: _d(j['total_volume_delivered_m3']),
    lifetimeScripEarned: _i(j['lifetime_scrip_earned']),
    totalCropsHarvested: _i(j['total_crops_harvested']),
    totalCompostGenerated: _i(j['total_compost_generated']),
    nextRaidWeek: _i(j['next_raid_week']),
    raidDefendedThisWeek: j['raid_defended_this_week'] as bool,
    pendingSales: (j['pending_sales'] as List).map((d) => _pendingSaleFromJson(d as Map<String, dynamic>)).toList(),
    lastSaved: DateTime.parse(j['last_saved'] as String),
  );

  Map<String, dynamic> _resourcesToJson(Resources r) => {
    'moon_dirt': r.moonDirt, 'chemicals': r.chemicals, 'water': r.water,
    'compost': r.compost, 'z_soil': r.zSoil, 'metals': r.metals,
    'sand': r.sand, 'glass': r.glass, 'components': r.components,
    'ore': r.ore, 'star_scrip': r.starScrip, 'seeds': r.seeds,
  };

  Resources _resourcesFromJson(Map<String, dynamic> j) => Resources(
    moonDirt: _d(j['moon_dirt']), chemicals: _d(j['chemicals']),
    water: _d(j['water']), compost: _d(j['compost']), zSoil: _d(j['z_soil']),
    metals: _d(j['metals']), sand: _d(j['sand']), glass: _d(j['glass']),
    components: _d(j['components']), ore: _d(j['ore']),
    starScrip: _i(j['star_scrip']), seeds: _i(j['seeds']),
  );

  Map<String, dynamic> _domeToJson(Dome d) => {
    'id': d.id, 'name': d.name, 'tier': d.tier,
    'cells': d.cells.map(_cellToJson).toList(),
    'robot': d.robot != null ? _robotToJson(d.robot!) : null,
    'structural_health': d.structuralHealth, 'power_draw': d.powerDraw,
  };

  Dome _domeFromJson(Map<String, dynamic> j) => Dome(
    id: j['id'] as String, name: j['name'] as String, tier: _i(j['tier']),
    cells: (j['cells'] as List).map((c) => _cellFromJson(c as Map<String, dynamic>)).toList(),
    robot: j['robot'] != null ? _robotFromJson(j['robot'] as Map<String, dynamic>) : null,
    structuralHealth: _i(j['structural_health']), powerDraw: _i(j['power_draw']),
  );

  Map<String, dynamic> _cellToJson(CropCell c) => {
    'position': c.position, 'crop_id': c.cropId, 'state': c.state.name,
    'weeks_grown': c.weeksGrown, 'watered': c.wateredThisWeek,
    'fertilized': c.fertilizedThisWeek, 'health': c.healthPercent,
  };

  CropCell _cellFromJson(Map<String, dynamic> j) => CropCell(
    position: _i(j['position']), cropId: j['crop_id'] as String?,
    state: CropState.values.firstWhere((e) => e.name == j['state']),
    weeksGrown: _i(j['weeks_grown']), wateredThisWeek: j['watered'] as bool,
    fertilizedThisWeek: j['fertilized'] as bool, healthPercent: _i(j['health']),
  );

  Map<String, dynamic> _robotToJson(DomeRobot r) => {
    'level': r.level, 'health': r.health, 'state': r.state.name,
    'power_draw': r.powerDraw, 'default_crop_id': r.defaultCropId,
  };

  DomeRobot _robotFromJson(Map<String, dynamic> j) => DomeRobot(
    level: _i(j['level']), health: _i(j['health']),
    state: RobotState.values.firstWhere((e) => e.name == j['state']),
    powerDraw: _i(j['power_draw']), defaultCropId: j['default_crop_id'] as String?,
  );

  Map<String, dynamic> _siloToJson(Silo s) => {
    'id': s.id, 'tier': s.tier, 'capacity': s.capacityCubicMeters,
    'used': s.usedCubicMeters, 'contents': s.contents, 'power_draw': s.powerDraw,
  };

  Silo _siloFromJson(Map<String, dynamic> j) => Silo(
    id: j['id'] as String, tier: _i(j['tier']),
    capacityCubicMeters: _d(j['capacity']), usedCubicMeters: _d(j['used']),
    contents: Map<String, double>.from(
      (j['contents'] as Map).map((k, v) => MapEntry(k as String, _d(v))),
    ),
    powerDraw: _i(j['power_draw']),
  );

  Map<String, dynamic> _refineryToJson(Refinery r) => {
    'id': r.id, 'tier': r.tier, 'power_draw': r.powerDraw,
    'unlocked_recipes': r.unlockedRecipes,
  };

  Refinery _refineryFromJson(Map<String, dynamic> j) => Refinery(
    id: j['id'] as String, tier: _i(j['tier']), powerDraw: _i(j['power_draw']),
    unlockedRecipes: List<String>.from(j['unlocked_recipes'] as List),
  );

  Map<String, dynamic> _powerSourceToJson(PowerSource p) => {
    'id': p.id, 'type': p.type.name, 'output_kwh': p.outputKwh,
  };

  PowerSource _powerSourceFromJson(Map<String, dynamic> j) => PowerSource(
    id: j['id'] as String,
    type: PowerSourceType.values.firstWhere((e) => e.name == j['type']),
    outputKwh: _i(j['output_kwh']),
  );

  Map<String, dynamic> _sentryToJson(LaserSentry s) => {
    'id': s.id, 'level': s.level, 'health': s.health,
    'power_draw': s.powerDraw, 'damage': s.damage,
    'fire_rate': s.fireRate, 'range': s.range,
  };

  LaserSentry _sentryFromJson(Map<String, dynamic> j) => LaserSentry(
    id: j['id'] as String, level: _i(j['level']), health: _i(j['health']),
    powerDraw: _i(j['power_draw']), damage: _i(j['damage']),
    fireRate: _i(j['fire_rate']), range: _i(j['range']),
  );

  Map<String, dynamic> _contractToJson(Contract c) => {
    'id': c.id, 'title': c.title, 'description': c.description,
    'crop_id': c.cropId, 'required': c.requiredAmount, 'current': c.currentAmount,
    'reward': c.rewardScrip, 'status': c.status.name, 'week_accepted': c.weekAccepted,
  };

  Contract _contractFromJson(Map<String, dynamic> j) => Contract(
    id: j['id'] as String, title: j['title'] as String,
    description: j['description'] as String, cropId: j['crop_id'] as String,
    requiredAmount: _i(j['required']), currentAmount: _i(j['current']),
    rewardScrip: _i(j['reward']),
    status: ContractStatus.values.firstWhere((e) => e.name == j['status']),
    weekAccepted: _i(j['week_accepted']),
  );

  Map<String, dynamic> _milestoneToJson(Milestone m) => {
    'id': m.id, 'name': m.name, 'description': m.description,
    'target_volume_m3': m.targetVolumeM3, 'by_week': m.byWeek,
    'reward_scrip': m.rewardScrip, 'status': m.status.name,
  };

  Milestone _milestoneFromJson(Map<String, dynamic> j) => Milestone(
    id: j['id'] as String, name: j['name'] as String,
    description: j['description'] as String,
    targetVolumeM3: _d(j['target_volume_m3']),
    byWeek: _i(j['by_week']), rewardScrip: _i(j['reward_scrip']),
    status: MilestoneStatus.values.firstWhere((e) => e.name == j['status']),
  );

  Map<String, dynamic> _trophyToJson(Trophy t) => {
    'id': t.id, 'name': t.name, 'description': t.description,
    'emoji': t.emoji, 'category': t.category, 'status': t.status.name,
    'week_earned': t.weekEarned,
  };

  Trophy _trophyFromJson(Map<String, dynamic> j) => Trophy(
    id: j['id'] as String, name: j['name'] as String,
    description: j['description'] as String, emoji: j['emoji'] as String,
    category: j['category'] as String,
    status: TrophyStatus.values.firstWhere((e) => e.name == j['status']),
    weekEarned: _iN(j['week_earned']),
  );

  Map<String, dynamic> _logEntryToJson(WeeklyLogEntry l) => {
    'week': l.week, 'events': l.events,
    'scrip_gained': l.scripGained, 'scrip_spent': l.scripSpent,
    'crops_harvested': l.cropsHarvested, 'volume_delivered_m3': l.volumeDeliveredM3,
    'raid_occurred': l.raidOccurred, 'raid_succeeded': l.raidSucceeded,
    'timestamp': l.timestamp.toIso8601String(),
  };

  WeeklyLogEntry _logEntryFromJson(Map<String, dynamic> j) => WeeklyLogEntry(
    week: _i(j['week']),
    events: List<String>.from(j['events'] as List),
    scripGained: _i(j['scrip_gained']), scripSpent: _i(j['scrip_spent']),
    cropsHarvested: _i(j['crops_harvested']),
    volumeDeliveredM3: _d(j['volume_delivered_m3']),
    raidOccurred: j['raid_occurred'] as bool,
    raidSucceeded: j['raid_succeeded'] as bool,
    timestamp: DateTime.parse(j['timestamp'] as String),
  );

  Map<String, dynamic> _radioToJson(RadioTransmission r) => {
    'week': r.week, 'message': r.message, 'is_read': r.isRead,
  };

  RadioTransmission _radioFromJson(Map<String, dynamic> j) => RadioTransmission(
    week: _i(j['week']), message: j['message'] as String,
    isRead: j['is_read'] as bool,
  );

  Map<String, dynamic> _relayToJson(RelayTechnicianState r) => {
    'mood': r.mood, 'seen_rant_topics': r.seenRantTopics,
    'available_contracts': r.availableContracts,
    'contracts_refreshed': r.contractsRefreshedThisWeek,
  };

  RelayTechnicianState _relayFromJson(Map<String, dynamic> j) => RelayTechnicianState(
    mood: _i(j['mood']),
    seenRantTopics: List<String>.from(j['seen_rant_topics'] as List),
    availableContracts: List<String>.from(j['available_contracts'] as List),
    contractsRefreshedThisWeek: j['contracts_refreshed'] as bool,
  );

  Map<String, dynamic> _pendingSaleToJson(PendingSale p) => {
    'resource_id': p.resourceId, 'amount': p.amount,
    'scrip_value': p.scripValue, 'week_queued': p.weekQueued,
  };

  PendingSale _pendingSaleFromJson(Map<String, dynamic> j) => PendingSale(
    resourceId: j['resource_id'] as String,
    amount: _d(j['amount']), scripValue: _i(j['scrip_value']),
    weekQueued: _i(j['week_queued']),
  );

  Difficulty? _difficultyFromString(String? s) {
    if (s == null) return null;
    return Difficulty.values.firstWhere((e) => e.name == s);
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}