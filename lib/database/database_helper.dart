// ═══════════════════════════════════════════════════════════════
//  lib/database/database_helper.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/game_models.dart';

// Safe numeric helpers — SQLite can return int or double for any number.
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
      version: 16,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        // During development, just wipe and recreate on any version change.
        // Replace this with proper migrations before publishing.
        await db.execute('DROP TABLE IF EXISTS game_states');
        await db.execute('DROP TABLE IF EXISTS save_slots');
        await db.execute('DROP TABLE IF EXISTS trophies');
        await db.execute('DROP TABLE IF EXISTS weekly_log');
        await _createDB(db, newVersion);
      },
    );
  }

  Future _createDB(Database db, int version) async {
    // ── Save Slots (lightweight metadata for main menu) ──────────────────────
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

    // Pre-populate 4 slots (0=autosave, 1-3=manual)
    for (int i = 0; i <= 3; i++) {
      await db.insert('save_slots', {
        'slot_number': i,
        'is_empty': 1,
      });
    }

    // ── Full Game State (JSON blob for now, fast to iterate on) ─────────────
    // We store the full game state as a JSON blob keyed by slot.
    // This lets us iterate on the model without schema migrations during dev.
    // Phase 2 can split this into normalized tables for query performance.
    await db.execute('''
      CREATE TABLE game_states (
        slot_number INTEGER PRIMARY KEY,
        game_id INTEGER,
        state_json TEXT NOT NULL,
        last_saved TEXT NOT NULL
      )
    ''');

    // ── Trophies (denormalized for quick lookup across saves) ────────────────
    await db.execute('''
      CREATE TABLE trophies (
        id TEXT NOT NULL,
        slot_number INTEGER NOT NULL,
        unlocked INTEGER DEFAULT 0,
        week_earned INTEGER,
        PRIMARY KEY (id, slot_number)
      )
    ''');

    // ── Weekly Log ───────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE weekly_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        slot_number INTEGER NOT NULL,
        week INTEGER NOT NULL,
        events_json TEXT NOT NULL,
        solars_gained INTEGER DEFAULT 0,
        solars_spent INTEGER DEFAULT 0,
        crops_harvested INTEGER DEFAULT 0,
        volume_delivered_m3 REAL DEFAULT 0,
        raid_occurred INTEGER DEFAULT 0,
        raid_succeeded INTEGER DEFAULT 0,
        timestamp TEXT NOT NULL
      )
    ''');

    // ── Indexes ──────────────────────────────────────────────────────────────
    await db.execute(
      'CREATE INDEX idx_log_slot ON weekly_log (slot_number, week DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_trophies_slot ON trophies (slot_number)',
    );
  }

  // ─── Save Slot Operations ─────────────────────────────────────────────────

  Future<List<SaveSlot>> getAllSaveSlots() async {
    final db = await database;
    final results = await db.query('save_slots', orderBy: 'slot_number');

    return results.map((row) {
      final isEmpty = ((row['is_empty'] as num).toInt()) == 1;
      return SaveSlot(
        slotNumber: (row['slot_number'] as num).toInt(),
        farmName: row['farm_name'] as String?,
        difficulty: isEmpty
            ? null
            : _difficultyFromString(row['difficulty'] as String?),
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

  // Creates a save_slots metadata row for a slot number beyond the normal
  // 0-3 range if it doesn't already exist (e.g. slot 4 for dev presets).
  // No-op if the slot already exists. updateSaveSlotMeta/saveGameState
  // both use UPDATE, not upsert, so a slot has to exist as a row before
  // either of those will actually write anything to it.
  Future<void> ensureSlotExists(int slotNumber) async {
    final db = await database;
    final existing = await db.query(
      'save_slots',
      where: 'slot_number = ?',
      whereArgs: [slotNumber],
    );
    if (existing.isEmpty) {
      await db.insert('save_slots', {'slot_number': slotNumber, 'is_empty': 1});
    }
  }

  Future<void> clearSaveSlot(int slotNumber) async {
    final db = await database;
    await db.update(
      'save_slots',
      {
        'farm_name': null,
        'difficulty': null,
        'current_week': null,
        'total_scrip': null,
        'last_saved': null,
        'is_empty': 1,
      },
      where: 'slot_number = ?',
      whereArgs: [slotNumber],
    );
    await db.delete(
      'game_states',
      where: 'slot_number = ?',
      whereArgs: [slotNumber],
    );
    await db.delete(
      'trophies',
      where: 'slot_number = ?',
      whereArgs: [slotNumber],
    );
    await db.delete(
      'weekly_log',
      where: 'slot_number = ?',
      whereArgs: [slotNumber],
    );
  }

  // ─── Game State Operations ────────────────────────────────────────────────

  Future<void> saveGameState(GameState state) async {
    final db = await database;
    final json = _gameStateToJson(state);

    await db.insert(
      'game_states',
      {
        'slot_number': state.slotNumber,
        'game_id': state.gameId,
        'state_json': jsonEncode(json),
        'last_saved': state.lastSaved.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await updateSaveSlotMeta(state);
    await _syncTrophies(db, state);
  }

  Future<GameState?> loadGameState(int slotNumber) async {
    final db = await database;
    final results = await db.query(
      'game_states',
      where: 'slot_number = ?',
      whereArgs: [slotNumber],
    );

    if (results.isEmpty) return null;

    final json = jsonDecode(results.first['state_json'] as String)
    as Map<String, dynamic>;
    return _gameStateFromJson(json);
  }

  Future<void> _syncTrophies(Database db, GameState state) async {
    for (final trophy in state.trophies) {
      if (trophy.status == TrophyStatus.unlocked) {
        await db.insert(
          'trophies',
          {
            'id': trophy.id,
            'slot_number': state.slotNumber,
            'unlocked': 1,
            'week_earned': trophy.weekEarned,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  // ─── Weekly Log ───────────────────────────────────────────────────────────

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

  Future<List<WeeklyLogEntry>> getLogEntries(
      int slotNumber, {
        int limit = 50,
      }) async {
    final db = await database;
    final results = await db.query(
      'weekly_log',
      where: 'slot_number = ?',
      whereArgs: [slotNumber],
      orderBy: 'week DESC',
      limit: limit,
    );

    return results.map((row) {
      return WeeklyLogEntry(
        week: (row['week'] as num).toInt(),
        events: List<String>.from(
          jsonDecode(row['events_json'] as String) as List,
        ),
        scripGained: (row['scrip_gained'] as num).toInt(),
        scripSpent: (row['scrip_spent'] as num).toInt(),
        cropsHarvested: (row['crops_harvested'] as num).toInt(),
        volumeDeliveredM3: (row['volume_delivered_m3'] as num).toDouble(),
        raidOccurred: ((row['raid_occurred'] as num).toInt()) == 1,
        raidSucceeded: ((row['raid_succeeded'] as num).toInt()) == 1,
        timestamp: DateTime.parse(row['timestamp'] as String),
      );
    }).toList();
  }

  // ─── JSON Serialization ───────────────────────────────────────────────────
  // Full game state to/from JSON for storage

  Map<String, dynamic> _gameStateToJson(GameState state) {
    return {
      'game_id': state.gameId,
      'slot_number': state.slotNumber,
      'farm_name': state.farmName,
      'difficulty': state.difficulty.name,
      'current_week': state.currentWeek,
      'status': state.status.name,
      'strike_count': state.strikeCount,
      'resources': _resourcesToJson(state.resources),
      'domes': state.domes.map(_domeToJson).toList(),
      'silos': state.silos.map(_siloToJson).toList(),
      'refineries': state.refineries.map((r) => _refineryToJson(r)).toList(),
      'power_sources': state.powerSources.map(_powerSourceToJson).toList(),
      'laser_sentries': state.laserSentries.map((s) => _sentryToJson(s)).toList(),
      'mining_drones': state.miningDrones.map((d) => _droneToJson(d)).toList(),
      'active_contracts': state.activeContracts.map(_contractToJson).toList(),
      'completed_contracts':
      state.completedContracts.map(_contractToJson).toList(),
      'pending_deliveries':
      state.pendingDeliveries.map((d) => d.toJson()).toList(),
      'milestones': state.milestones.map(_milestoneToJson).toList(),
      'trophies': state.trophies.map(_trophyToJson).toList(),
      'log': state.log.map(_logEntryToJson).toList(),
      'radio_feed': state.radioFeed.map(_radioToJson).toList(),
      'relay': _relayToJson(state.relay),
      'total_volume_delivered_m3': state.totalVolumeDeliveredM3,
      'lifetime_solars_earned': state.lifetimeScripEarned,
      'pending_contract_scrip': state.pendingContractScrip,
      'total_crops_harvested': state.totalCropsHarvested,
      'total_compost_generated': state.totalCompostGenerated,
      'crop_harvest_counts': state.cropHarvestCounts,
      'termination_reason': state.terminationReason,
      'next_raid_week': state.nextRaidWeek,
      'raid_defended_this_week': state.raidDefendedThisWeek,
      'manual_raid_triggered_this_week': state.manualRaidTriggeredThisWeek,
      'unlocked_features': state.unlockedFeatures,
      'fired_radio_triggers': state.firedRadioTriggers,
      'last_week_summary': state.lastWeekSummary != null
          ? _weekSummaryToJson(state.lastWeekSummary!)
          : null,
      'water_purifier_level': state.waterPurifierLevel,
      'silo_inventory': state.siloInventory,
      'shipments_this_window': state.shipmentsThisWindow,
      'next_ship_window_week': state.nextShipWindowWeek,
      'total_raids_defended': state.totalRaidsDefended,
      'total_fauna_killed': state.totalFaunaKilled,
      'total_chitin_collected': state.totalChitinCollected,
      'defense_wall': _wallToJson(state.defenseWall),
      'grenades': _grenadesToJson(state.grenades),
      'pending_sales': state.pendingSales.map(_pendingSaleToJson).toList(),
      'last_saved': state.lastSaved.toIso8601String(),
    };
  }

  GameState _gameStateFromJson(Map<String, dynamic> json) {
    return GameState(
      gameId: (json['game_id'] as num).toInt(),
      slotNumber: (json['slot_number'] as num).toInt(),
      farmName: json['farm_name'] as String,
      difficulty: _difficultyFromString(json['difficulty'] as String)!,
      currentWeek: (json['current_week'] as num).toInt(),
      status: GameStatus.values.firstWhere((e) => e.name == json['status']),
      strikeCount: (json['strike_count'] as num).toInt(),
      resources: _resourcesFromJson(json['resources'] as Map<String, dynamic>),
      domes: (json['domes'] as List).map((d) => _domeFromJson(d as Map<String, dynamic>)).toList(),
      silos: (json['silos'] as List).map((s) => _siloFromJson(s as Map<String, dynamic>)).toList(),
      refineries: (json['refineries'] as List).map((r) => _refineryFromJson(r as Map<String, dynamic>)).toList(),
      powerSources: (json['power_sources'] as List).map((p) => _powerSourceFromJson(p as Map<String, dynamic>)).toList(),
      laserSentries: (json['laser_sentries'] as List).map((s) => _sentryFromJson(s as Map<String, dynamic>)).toList(),
      activeContracts: (json['active_contracts'] as List).map((c) => _contractFromJson(c as Map<String, dynamic>)).toList(),
      completedContracts: (json['completed_contracts'] as List).map((c) => _contractFromJson(c as Map<String, dynamic>)).toList(),
      pendingDeliveries: (json['pending_deliveries'] as List?)
          ?.map((d) => PendingDelivery.fromJson(d as Map<String, dynamic>))
          .toList() ?? const [],
      milestones: (json['milestones'] as List).map((m) => _milestoneFromJson(m as Map<String, dynamic>)).toList(),
      trophies: (json['trophies'] as List).map((t) => _trophyFromJson(t as Map<String, dynamic>)).toList(),
      log: (json['log'] as List).map((l) => _logEntryFromJson(l as Map<String, dynamic>)).toList(),
      radioFeed: (json['radio_feed'] as List).map((r) => _radioFromJson(r as Map<String, dynamic>)).toList(),
      relay: _relayFromJson(json['relay'] as Map<String, dynamic>),
      totalVolumeDeliveredM3: (json['total_volume_delivered_m3'] as num).toDouble(),
      lifetimeScripEarned: (json['lifetime_solars_earned'] as num).toInt(),
      pendingContractScrip: (json['pending_contract_scrip'] as num?)?.toInt() ?? 0,
      totalCropsHarvested: (json['total_crops_harvested'] as num).toInt(),
      totalCompostGenerated: (json['total_compost_generated'] as num).toInt(),
      cropHarvestCounts: (json['crop_harvest_counts'] as Map?)
          ?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {},
      terminationReason: json['termination_reason'] as String?,
      nextRaidWeek: (json['next_raid_week'] as num).toInt(),
      raidDefendedThisWeek: json['raid_defended_this_week'] as bool,
      manualRaidTriggeredThisWeek:
      json['manual_raid_triggered_this_week'] as bool? ?? false,
      unlockedFeatures: (json['unlocked_features'] as List?)
          ?.map((e) => e.toString()).toList() ?? const [],
      firedRadioTriggers: (json['fired_radio_triggers'] as List?)
          ?.map((e) => e.toString()).toList() ?? const [],
      lastWeekSummary: json['last_week_summary'] != null
          ? _weekSummaryFromJson(json['last_week_summary'] as Map<String, dynamic>)
          : null,
      totalRaidsDefended: _i(json['total_raids_defended'] ?? 0),
      totalFaunaKilled: _i(json['total_fauna_killed'] ?? 0),
      totalChitinCollected: _i(json['total_chitin_collected'] ?? 0),
      defenseWall: json['defense_wall'] != null
          ? _wallFromJson(json['defense_wall'] as Map<String, dynamic>)
          : const DefenseWall(level: 1, currentHp: 100, maxHp: 100),
      grenades: json['grenades'] != null
          ? _grenadesFromJson(json['grenades'] as Map<String, dynamic>)
          : const GrenadeInventory(counts: {}, benchLevel: 1),
      pendingSales: (json['pending_sales'] as List).map((s) => _pendingSaleFromJson(s as Map<String, dynamic>)).toList(),
      siloInventory: json['silo_inventory'] != null
          ? Map<String, double>.from((json['silo_inventory'] as Map)
          .map((k, v) => MapEntry(k as String, _d(v))))
          : {},
      shipmentsThisWindow: _i(json['shipments_this_window'] ?? 0),
      nextShipWindowWeek: _i(json['next_ship_window_week'] ?? 4),
      waterPurifierLevel: _i(json['water_purifier_level'] ?? 1),
      miningDrones: json['mining_drones'] != null
          ? (json['mining_drones'] as List)
          .map((d) => _droneFromJson(d as Map<String, dynamic>))
          .toList()
          : [],
      lastSaved: DateTime.parse(json['last_saved'] as String),
    );
  }

  // Sub-serializers
  Map<String, dynamic> _resourcesToJson(Resources r) => {
    'moon_dirt': r.moonDirt, 'chemicals': r.chemicals, 'water': r.water,
    'compost': r.compost, 'z_soil': r.zSoil, 'metals': r.metals,
    'sand': r.sand, 'glass': r.glass, 'components': r.components,
    'ore': r.ore, 'meat': r.meat, 'chitin': r.chitin, 'moss': r.moss,
    'mycoculture': r.mycoculture,
    'star_scrip': r.starScrip, 'seeds': r.seeds,
  };

  Resources _resourcesFromJson(Map<String, dynamic> j) => Resources(
    moonDirt: (j['moon_dirt'] as num).toDouble(),
    chemicals: (j['chemicals'] as num).toDouble(),
    water: (j['water'] as num).toDouble(),
    compost: (j['compost'] as num).toDouble(),
    zSoil: (j['z_soil'] as num).toDouble(),
    metals: (j['metals'] as num).toDouble(),
    sand: (j['sand'] as num).toDouble(),
    glass: (j['glass'] as num).toDouble(),
    components: (j['components'] as num).toDouble(),
    ore: (j['ore'] as num).toDouble(),
    meat: (j['meat'] as num?)?.toDouble() ?? 0,
    chitin: (j['chitin'] as num?)?.toDouble() ?? 0,
    moss: (j['moss'] as num?)?.toDouble() ?? 0,
    mycoculture: (j['mycoculture'] as num?)?.toDouble() ?? 0,
    starScrip: (j['star_scrip'] as num).toInt(),
    seeds: (j['seeds'] as num).toInt(),
  );

  Map<String, dynamic> _weekSummaryToJson(WeekSummary s) => {
    'week': s.week,
    'scrip_received': s.scripReceived,
    'scrip_spent': s.scripSpent,
    'crops_harvested': s.cropsHarvested,
    'crops_died': s.cropsDied,
    'volume_to_colony_m3': s.volumeToColonyM3,
    'new_trophies': s.newTrophies,
    'milestone_updates': s.milestoneUpdates,
    'contract_updates': s.contractUpdates,
    'raid_occurred': s.raidOccurred,
    'resource_changes': s.resourceChanges,
    'robot_actions': s.robotActions,
    'events': s.events,
    'new_week': s.newWeek,
    'new_radio_messages': s.newRadioMessages,
  };

  WeekSummary _weekSummaryFromJson(Map<String, dynamic> j) => WeekSummary(
    week: (j['week'] as num).toInt(),
    scripReceived: (j['scrip_received'] as num).toInt(),
    scripSpent: (j['scrip_spent'] as num).toInt(),
    cropsHarvested: (j['crops_harvested'] as num).toInt(),
    cropsDied: (j['crops_died'] as num).toInt(),
    volumeToColonyM3: (j['volume_to_colony_m3'] as num).toDouble(),
    newTrophies: List<String>.from(j['new_trophies'] as List? ?? []),
    milestoneUpdates: List<String>.from(j['milestone_updates'] as List? ?? []),
    contractUpdates: List<String>.from(j['contract_updates'] as List? ?? []),
    raidOccurred: j['raid_occurred'] as bool? ?? false,
    resourceChanges: Map<String, double>.from(
        (j['resource_changes'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))),
    robotActions: List<String>.from(j['robot_actions'] as List? ?? []),
    events: List<String>.from(j['events'] as List? ?? []),
    newWeek: (j['new_week'] as num).toInt(),
    newRadioMessages: List<String>.from(j['new_radio_messages'] as List? ?? []),
  );

  Map<String, dynamic> _domeToJson(Dome d) => {
    'id': d.id, 'name': d.name, 'tier': d.tier,
    'cells': d.cells.map(_cellToJson).toList(),
    'robot': d.robot != null ? _robotToJson(d.robot!) : null,
    'dome_bot': d.domeBot != null ? _domeBotToJson(d.domeBot!) : null,
    'structural_health': d.structuralHealth, 'power_draw': d.powerDraw,
  };

  Dome _domeFromJson(Map<String, dynamic> j) => Dome(
    id: j['id'] as String, name: j['name'] as String, tier: (j['tier'] as num).toInt(),
    cells: (j['cells'] as List).map((c) => _cellFromJson(c as Map<String, dynamic>)).toList(),
    robot: j['robot'] != null ? _robotFromJson(j['robot'] as Map<String, dynamic>) : null,
    domeBot: j['dome_bot'] != null ? _domeBotFromJson(j['dome_bot'] as Map<String, dynamic>) : null,
    structuralHealth: (j['structural_health'] as num).toInt(),
    powerDraw: (j['power_draw'] as num).toInt(),
  );

  Map<String, dynamic> _domeBotToJson(DomeBot b) => {
    'level': b.level, 'plant_crop_id': b.plantCropId, 'power_draw': b.powerDraw,
  };

  DomeBot _domeBotFromJson(Map<String, dynamic> j) => DomeBot(
    level: _i(j['level']),
    plantCropId: j['plant_crop_id'] as String?,
    powerDraw: _i(j['power_draw'] ?? 2),
  );

  Map<String, dynamic> _cellToJson(CropCell c) => {
    'position': c.position, 'crop_id': c.cropId, 'state': c.state.name,
    'weeks_grown': c.weeksGrown, 'watered': c.wateredThisWeek,
    'fertilized': c.fertilizedThisWeek, 'health': c.healthPercent,
    'fertilize_count': c.fertilizeCount, 'last_fertilize_week': c.lastFertilizeWeek,
  };

  CropCell _cellFromJson(Map<String, dynamic> j) => CropCell(
    position: (j['position'] as num).toInt(), cropId: j['crop_id'] as String?,
    state: CropState.values.firstWhere((e) => e.name == j['state']),
    weeksGrown: (j['weeks_grown'] as num).toInt(), wateredThisWeek: j['watered'] as bool,
    fertilizedThisWeek: j['fertilized'] as bool, healthPercent: (j['health'] as num).toInt(),
    fertilizeCount: (j['fertilize_count'] as num?)?.toInt() ?? 0,
    lastFertilizeWeek: (j['last_fertilize_week'] as num?)?.toInt() ?? -99,
  );

  Map<String, dynamic> _robotToJson(DomeRobot r) => {
    'level': r.level, 'health': r.health, 'state': r.state.name,
    'power_draw': r.powerDraw, 'default_crop_id': r.defaultCropId,
  };

  DomeRobot _robotFromJson(Map<String, dynamic> j) => DomeRobot(
    level: (j['level'] as num).toInt(), health: (j['health'] as num).toInt(),
    state: RobotState.values.firstWhere((e) => e.name == j['state']),
    powerDraw: (j['power_draw'] as num).toInt(), defaultCropId: j['default_crop_id'] as String?,
  );

  Map<String, dynamic> _siloToJson(Silo s) => {
    'id': s.id, 'tier': s.tier, 'capacity': s.capacityCubicMeters,
    'used': s.usedCubicMeters, 'contents': s.contents, 'power_draw': s.powerDraw,
  };

  Silo _siloFromJson(Map<String, dynamic> j) => Silo(
    id: j['id'] as String, tier: (j['tier'] as num).toInt(),
    capacityCubicMeters: (j['capacity'] as num).toDouble(),
    usedCubicMeters: (j['used'] as num).toDouble(),
    contents: Map<String, double>.from(
      (j['contents'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
    ),
    powerDraw: (j['power_draw'] as num).toInt(),
  );

  Map<String, dynamic> _refineryToJson(Refinery r) => {
    'id': r.id, 'tier': r.tier, 'power_draw': r.powerDraw,
    'unlocked_recipes': r.unlockedRecipes,
    'machines': r.machines.map((m) => {
      'type': m.type.name,
      'level': m.level,
      'power_draw': m.powerDraw,
      'auto_refine': m.autoRefine,
    }).toList(),
  };

  Refinery _refineryFromJson(Map<String, dynamic> j) => Refinery(
    id: j['id'] as String, tier: (j['tier'] as num).toInt(),
    powerDraw: (j['power_draw'] as num).toInt(),
    unlockedRecipes: List<String>.from(j['unlocked_recipes'] as List),
    machines: (j['machines'] as List?)?.map((m) {
      final mm = m as Map<String, dynamic>;
      return RefineryMachine(
        type: MachineType.values.firstWhere((e) => e.name == mm['type']),
        level: (mm['level'] as num).toInt(),
        powerDraw: (mm['power_draw'] as num).toInt(),
        autoRefine: mm['auto_refine'] as bool? ?? false,
      );
    }).toList() ?? const [],
  );

  Map<String, dynamic> _powerSourceToJson(PowerSource p) => {
    'id': p.id, 'type': p.type.name, 'output_kwh': p.outputKwh,
  };

  PowerSource _powerSourceFromJson(Map<String, dynamic> j) => PowerSource(
    id: j['id'] as String,
    type: PowerSourceType.values.firstWhere((e) => e.name == j['type']),
    outputKwh: (j['output_kwh'] as num).toInt(),
  );

  Map<String, dynamic> _sentryToJson(LaserSentry s) => {
    'id': s.id, 'level': s.level, 'health': s.health,
    'power_draw': s.powerDraw, 'damage': s.damage,
    'fire_rate': s.fireRate, 'range': s.range,
  };

  LaserSentry _sentryFromJson(Map<String, dynamic> j) => LaserSentry(
    id: j['id'] as String, level: (j['level'] as num).toInt(), health: (j['health'] as num).toInt(),
    powerDraw: (j['power_draw'] as num).toInt(), damage: (j['damage'] as num).toInt(),
    fireRate: (j['fire_rate'] as num).toInt(), range: (j['range'] as num).toInt(),
  );

  Map<String, dynamic> _contractToJson(Contract c) => {
    'id': c.id, 'title': c.title, 'description': c.description,
    'crop_id': c.cropId, 'required': c.requiredAmount, 'current': c.currentAmount,
    'reward': c.rewardScrip, 'status': c.status.name, 'week_accepted': c.weekAccepted,
  };

  Contract _contractFromJson(Map<String, dynamic> j) => Contract(
    id: j['id'] as String, title: j['title'] as String,
    description: j['description'] as String, cropId: j['crop_id'] as String,
    requiredAmount: (j['required'] as num).toInt(), currentAmount: (j['current'] as num).toInt(),
    rewardScrip: (j['reward'] as num).toInt(),
    status: ContractStatus.values.firstWhere((e) => e.name == j['status']),
    weekAccepted: (j['week_accepted'] as num).toInt(),
  );

  Map<String, dynamic> _milestoneToJson(Milestone m) => {
    'id': m.id, 'name': m.name, 'description': m.description,
    'target_volume_m3': m.targetVolumeM3, 'by_week': m.byWeek,
    'reward_scrip': m.rewardScrip, 'status': m.status.name,
  };

  Milestone _milestoneFromJson(Map<String, dynamic> j) => Milestone(
    id: j['id'] as String, name: j['name'] as String,
    description: j['description'] as String,
    targetVolumeM3: (j['target_volume_m3'] as num).toDouble(), byWeek: (j['by_week'] as num).toInt(),
    rewardScrip: (j['reward_scrip'] as num).toInt(),
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
    week: (j['week'] as num).toInt(),
    events: List<String>.from(j['events'] as List),
    scripGained: (j['scrip_gained'] as num).toInt(), scripSpent: (j['scrip_spent'] as num).toInt(),
    cropsHarvested: (j['crops_harvested'] as num).toInt(),
    volumeDeliveredM3: (j['volume_delivered_m3'] as num).toDouble(),
    raidOccurred: j['raid_occurred'] as bool,
    raidSucceeded: j['raid_succeeded'] as bool,
    timestamp: DateTime.parse(j['timestamp'] as String),
  );

  Map<String, dynamic> _radioToJson(RadioTransmission r) => {
    'week': r.week, 'message': r.message, 'is_read': r.isRead,
  };

  RadioTransmission _radioFromJson(Map<String, dynamic> j) => RadioTransmission(
    week: (j['week'] as num).toInt(), message: j['message'] as String,
    isRead: j['is_read'] as bool,
  );

  Map<String, dynamic> _relayToJson(RelayTechnicianState r) => {
    'mood': r.mood, 'seen_rant_topics': r.seenRantTopics,
    'available_contracts': r.availableContracts,
    'contracts_refreshed': r.contractsRefreshedThisWeek,
    'conversation_done_this_week': r.conversationDoneThisWeek,
  };

  RelayTechnicianState _relayFromJson(Map<String, dynamic> j) =>
      RelayTechnicianState(
        mood: (j['mood'] as num).toInt(),
        seenRantTopics: List<String>.from(j['seen_rant_topics'] as List),
        availableContracts: List<String>.from(j['available_contracts'] as List),
        contractsRefreshedThisWeek: j['contracts_refreshed'] as bool,
        conversationDoneThisWeek:
        j['conversation_done_this_week'] as bool? ?? false,
      );

  Map<String, dynamic> _pendingSaleToJson(PendingSale p) => {
    'resource_id': p.resourceId, 'amount': p.amount,
    'solars_value': p.scripValue, 'week_queued': p.weekQueued,
  };

  PendingSale _pendingSaleFromJson(Map<String, dynamic> j) => PendingSale(
    resourceId: j['resource_id'] as String,
    amount: (j['amount'] as num).toDouble(),
    scripValue: (j['solars_value'] as num).toInt(),
    weekQueued: (j['week_queued'] as num).toInt(),
  );

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _droneToJson(MiningDrone d) => {
    'id': d.id, 'tier': d.tier, 'assigned': d.assignedResource,
    'output': d.outputPerWeek, 'power_draw': d.powerDraw,
  };

  MiningDrone _droneFromJson(Map<String, dynamic> j) => MiningDrone(
    id: j['id'] as String,
    tier: _i(j['tier'] ?? 1),
    assignedResource: j['assigned'] as String?,
    outputPerWeek: _d(j['output']),
    powerDraw: _i(j['power_draw'] ?? 3),
  );

  Map<String, dynamic> _wallToJson(DefenseWall w) => {
    'level': w.level, 'current_hp': w.currentHp, 'max_hp': w.maxHp,
  };

  DefenseWall _wallFromJson(Map<String, dynamic> j) => DefenseWall(
    level: _i(j['level']), currentHp: _i(j['current_hp']), maxHp: _i(j['max_hp']),
  );

  Map<String, dynamic> _grenadesToJson(GrenadeInventory g) => {
    'counts': g.counts, 'bench_level': g.benchLevel,
  };

  GrenadeInventory _grenadesFromJson(Map<String, dynamic> j) => GrenadeInventory(
    counts: Map<String, int>.from(
      (j['counts'] as Map? ?? {}).map((k, v) => MapEntry(k as String, _i(v))),
    ),
    benchLevel: _i(j['bench_level'] ?? 1),
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