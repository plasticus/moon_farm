// ═══════════════════════════════════════════════════════════════
//  lib/screens/raid/raid_screen.dart
// ═══════════════════════════════════════════════════════════════
//
// Top-down raid mini-game.
// Fauna spawn from top, move downward.
// Sentries auto-fire heat-seeking projectiles.
// Player throws grenades by tapping the field.
// Defense wall runs along the bottom.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_models.dart';
import '../../providers/game_providers.dart';
import '../../theme/app_theme.dart';
import '../../config/game_config_service.dart';
import '../../config/raid_config_service.dart';
import '../../config/milestone_config_service.dart';
import '../score/score_screen.dart';

class RaidScreen extends ConsumerStatefulWidget {
  final GameState game;
  final bool isManualTrigger;

  const RaidScreen({
    super.key,
    required this.game,
    this.isManualTrigger = false,
  });

  @override
  ConsumerState<RaidScreen> createState() => _RaidScreenState();
}

class _RaidScreenState extends ConsumerState<RaidScreen> {
  // ── Game state ────────────────────────────────────────────────────────────
  late List<FaunaUnit> _fauna;
  late List<ActiveGrenade> _grenades;
  late List<ActiveEffect> _effects;
  late List<_Projectile> _projectiles;
  late int _wallHp;
  late int _wallMaxHp;
  late int _timeRemaining; // seconds
  late Map<String, int> _grenadeInventory;
  String? _selectedGrenadeId;

  // Drop tracking
  int _meatDropped = 0;
  int _chitinDropped = 0;
  int _faunaKilled = 0;
  int _faunaEscaped = 0;
  // Tracks fauna ids that have already been counted as dead this session,
  // preventing double-counting between the projectile kill path (which
  // marks fauna isDead and calls _handleFaunaDeath immediately) and the
  // movement loop's end-of-tick death sweep (which was calling
  // _handleFaunaDeath again for the same already-dead fauna that hadn't
  // been removed from _fauna yet).
  final Set<String> _handledDeaths = {};

  // Spawn tracking
  late List<SpawnInstruction> _spawnQueue;
  int _totalSpawned = 0;
  int _maxFauna = 0;
  double _spawnAccumulator = 0;
  double _spawnInterval = 1.0;

  // Timer
  Timer? _gameTimer;
  bool _raidOver = false;

  final _rng = Random();
  late Size _fieldSize;

  static const double _wallY = 0.88;
  static const double _sentryY = 0.75;

  @override
  void initState() {
    super.initState();
    _initRaid();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _initRaid() {
    final raidConfig = RaidConfigService.instance;
    final config = GameConfigService.instance;
    final game = widget.game;

    // Wall HP
    final wallLevels = config.getDefenseWallLevels();
    final wallConfig = wallLevels.firstWhere(
          (l) => l['level'] == game.defenseWall.level,
      orElse: () => wallLevels.first,
    );
    _wallMaxHp = wallConfig['hp'] as int;
    _wallHp = game.defenseWall.currentHp.clamp(0, _wallMaxHp);

    // Track dynamic progression using true Wave Number instead of raw calendar Week
    final waveNumber = widget.isManualTrigger
        ? max(1, game.totalRaidsDefended)
        : game.totalRaidsDefended + 1;

    // Pre-calculate the exact sequential ticket queue matching your spreadsheet matrix
    _spawnQueue = raidConfig.generateSpawnQueueForWave(waveNumber);
    _maxFauna = _spawnQueue.length;

    // Distribute the exact amount of spawns smoothly across your 60-second limit
    final baseInterval = raidConfig.spawnIntervalBase;
    final minInterval = raidConfig.spawnIntervalMin;
    _spawnInterval = (raidConfig.raidDurationMax / _maxFauna)
        .clamp(minInterval, baseInterval);

    _timeRemaining = raidConfig.raidDurationMax.toInt();
    _fauna = [];
    _grenades = [];
    _effects = [];
    _projectiles = [];
    _grenadeInventory = Map<String, int>.from(game.grenades.counts);
    _totalSpawned = 0;

    // Start game tick at 30fps
    _gameTimer = Timer.periodic(const Duration(milliseconds: 33), _tick);
  }

  void _tick(Timer timer) {
    if (_raidOver) return;
    const dt = 0.033; // ~30fps

    setState(() {
      _updateFauna(dt);
      _updateProjectiles(dt);
      _updateGrenades(dt);
      _updateEffects(dt);
      _firesentries(dt);

      _spawnAccumulator += dt;
      if (_spawnAccumulator >= _spawnInterval && _totalSpawned < _maxFauna) {
        _spawnFauna();
        _spawnAccumulator = 0;
      }
      _checkWallHits();

      // Countdown / End state check
      if (_fauna.isEmpty && _totalSpawned >= _maxFauna) {
        _endRaid(wallBroken: false);
      }
    });
  }

  // ── Spawn ─────────────────────────────────────────────────────────────────

  void _spawnFauna() {
    if (_spawnQueue.isEmpty) return;

    final raidConfig = RaidConfigService.instance;

    // Pop the next exact creature ticket off the deterministic deck
    final instruction = _spawnQueue.removeAt(0);

    // Pull display essentials (emojis, etc.) from YAML baseline profiles
    final baseConfig = raidConfig.getFaunaType(instruction.baseName);
    if (baseConfig == null) return;

    // Apply your infinite formula math (+100 HP, +14 DMG per level) dynamically
    final scaled = raidConfig.getScaledStats(instruction.baseName, instruction.level);
    final x = 0.05 + _rng.nextDouble() * 0.90;

    _fauna.add(FaunaUnit(
      id: 'f_${DateTime.now().microsecondsSinceEpoch}_$_totalSpawned',
      typeId: instruction.baseName,
      emoji: baseConfig['emoji'] as String? ?? '🐛',
      hp: scaled.hp.toDouble(),
      maxHp: scaled.hp.toDouble(),
      speed: scaled.speed,
      damage: scaled.damage,
      hitInterval: (baseConfig['hit_interval'] as num?)?.toDouble() ?? 1.0,
      isBrute: baseConfig['is_brute'] as bool? ?? false,
      x: x,
      y: 0.0,
    ));

    _totalSpawned++;
  }

  // ── Update fauna ──────────────────────────────────────────────────────────

  void _updateFauna(double dt) {
    final updated = <FaunaUnit>[];
    for (var f in _fauna) {
      if (f.isDead) continue;

      // Update stun/scatter timers
      var stunRemaining = (f.stunTimeRemaining - dt).clamp(0.0, 100.0);
      final isStunned = f.isStunned && stunRemaining > 0;
      final isScattered = f.isScattered && stunRemaining > 0;

      double newX = f.x;
      double newY = f.y;

      if (isStunned) {
        // Frozen in place
      } else if (isScattered) {
        // Erratic movement adjustments
        newX = (f.x + (_rng.nextDouble() - 0.5) * f.speed * dt * 2).clamp(0.05, 0.95);
        newY = (f.y + (_rng.nextDouble() - 0.5) * f.speed * dt).clamp(0.0, _wallY - 0.01);
      } else {
        // Check active pheromone bait zones
        ActiveEffect? bait;
        for (final e in _effects) {
          if (e.effectType == 'bait' && e.timeRemaining > 0) {
            bait = e;
            break;
          }
        }

        if (bait != null) {
          final dx = bait.x - f.x;
          final dy = bait.y - f.y;
          final dist = sqrt(dx * dx + dy * dy);
          if (dist > 0.01) {
            newX = f.x + (dx / dist) * f.speed * dt;
            newY = f.y + (dy / dist) * f.speed * dt;
          }
        } else {
          // Direct advance south toward the defense grid
          newY = f.y + f.speed * dt * 0.15;
        }
        newX = newX.clamp(0.05, 0.95);
        newY = newY.clamp(0.0, _wallY);
      }

      // Apply area-of-effect damage over time configurations
      double newHp = f.hp;
      for (final effect in _effects) {
        if (effect.effectType == 'burn_zone' && effect.timeRemaining > 0) {
          final dx = effect.x - newX;
          final dy = effect.y - newY;
          final dist = sqrt(dx * dx + dy * dy);
          if (dist < effect.radius / (_fieldSize.width)) {
            newHp -= f.maxHp * effect.damagePercentPerSecond * dt;
          }
        }
      }

      final updatedUnit = f.copyWith(
        x: newX, y: newY, hp: newHp,
        isStunned: isStunned, isScattered: isScattered,
        stunTimeRemaining: stunRemaining,
        timeSinceLastHit: f.timeSinceLastHit + dt,
      );
      // Handle deaths from burn zone here so they're counted exactly once.
      // The movement-loop death sweep below catches sentry/grenade kills
      // that weren't yet removed from _fauna.
      if (updatedUnit.isDead) _handleFaunaDeath(f);
      updated.add(updatedUnit);
    }

    // Process deaths and distribute inventory resource rewards
    for (final f in _fauna) {
      if (f.isDead && !updated.any((u) => u.id == f.id)) {
        _handleFaunaDeath(f);
      }
    }

    _fauna = updated.where((f) => !f.isDead).toList();
  }

  void _handleFaunaDeath(FaunaUnit f) {
    if (_handledDeaths.contains(f.id)) return;
    _handledDeaths.add(f.id);
    _faunaKilled++;
    final raidConfig = RaidConfigService.instance;

    // Use safe global drop formulas to completely prevent type errors
    if (_rng.nextDouble() < raidConfig.meatChance) {
      _meatDropped++;
    }
    // Chitin chance = this creature type's own base + a climb based on how
    // many fauna have died so far this raid (the kill that just happened
    // doesn't count toward its own roll, so the very first kill of the
    // raid always rolls at the type's plain base chance).
    final climb = (_faunaKilled - 1) * raidConfig.chitinChanceClimbPerKill;
    final chitinChance =
        (raidConfig.chitinChanceFor(f.typeId) + climb).clamp(0.0, 1.0);
    if (_rng.nextDouble() < chitinChance) {
      _chitinDropped++;
    }
  }

  // ── Wall hits ─────────────────────────────────────────────────────────────

  void _checkWallHits() {
    for (var i = 0; i < _fauna.length; i++) {
      final f = _fauna[i];
      if (f.isAtWall && f.timeSinceLastHit >= f.hitInterval) {
        _wallHp = (_wallHp - f.damage).clamp(0, _wallMaxHp);
        _fauna[i] = f.copyWith(timeSinceLastHit: 0);
        if (_wallHp <= 0) {
          _endRaid(wallBroken: true);
          return;
        }
      }
    }
  }

  // ── Sentries auto-fire ────────────────────────────────────────────────────

  final Map<String, double> _sentryCooldowns = {};

  void _firesentries(double dt) {
    if (_fauna.isEmpty) return;
    final sentries = widget.game.laserSentries;

    for (final sentry in sentries) {
      final cooldown = _sentryCooldowns[sentry.id] ?? 0;
      final newCooldown = (cooldown - dt).clamp(0.0, 10.0);
      _sentryCooldowns[sentry.id] = newCooldown;

      if (newCooldown > 0) continue;

      // Lock tracking systems onto the closest available unit
      final sx = _sentryXForSentry(sentries.indexOf(sentry), sentries.length);
      FaunaUnit? target;
      double closestDist = double.infinity;

      for (final f in _fauna) {
        final dx = f.x - sx;
        final dy = f.y - _sentryY;
        final dist = sqrt(dx * dx + dy * dy);
        final rangeNorm = sentry.range / 1000.0;
        if (dist < rangeNorm && dist < closestDist) {
          closestDist = dist;
          target = f;
        }
      }

      if (target != null) {
        _projectiles.add(_Projectile(
          id: 'p_${DateTime.now().microsecondsSinceEpoch}',
          fromX: sx,
          fromY: _sentryY,
          targetId: target.id,
          damage: sentry.damage.toDouble(),
          speed: 0.8,
          progress: 0.0,
        ));
        _sentryCooldowns[sentry.id] = 1.0 / sentry.fireRate;
      }
    }
  }

  double _sentryXForSentry(int index, int total) {
    if (total <= 1) return 0.5;
    return 0.1 + (index / (total - 1)) * 0.8;
  }

  // ── Projectiles ───────────────────────────────────────────────────────────

  void _updateProjectiles(double dt) {
    final updated = <_Projectile>[];
    for (var p in _projectiles) {
      final newProgress = (p.progress + p.speed * dt * 3).clamp(0.0, 1.0);
      if (newProgress >= 1.0) {
        final targetIdx = _fauna.indexWhere((f) => f.id == p.targetId);
        if (targetIdx >= 0) {
          final f = _fauna[targetIdx];
          final newHp = f.hp - p.damage;
          _fauna[targetIdx] = f.copyWith(hp: newHp);
          if (newHp <= 0) _handleFaunaDeath(_fauna[targetIdx]);
        }
      } else {
        updated.add(p.copyWith(progress: newProgress));
      }
    }
    _projectiles = updated;
    _fauna.removeWhere((f) => f.isDead);
  }

  // ── Grenades ─────────────────────────────────────────────────────────────

  void _updateGrenades(double dt) {
    final updated = <ActiveGrenade>[];
    for (var g in _grenades) {
      if (g.hasExploded) continue;
      final newProgress = (g.progress + dt / 0.8).clamp(0.0, 1.0);
      if (newProgress >= 1.0) {
        _explodeGrenade(g);
      } else {
        updated.add(g.copyWith(progress: newProgress));
      }
    }
    _grenades = updated;
  }

  void _explodeGrenade(ActiveGrenade grenade) {
    final config = GameConfigService.instance;
    final gConfig = config.getGrenadeType(grenade.grenadeId);
    if (gConfig == null) return;

    final effect = gConfig['effect'] as String;
    final radius = (gConfig['effect_radius'] as num).toDouble();
    final radiusNorm = radius / (_fieldSize.width > 0 ? _fieldSize.width : 400);

    switch (effect) {
      case 'scatter':
        final duration = (gConfig['effect_duration'] as num).toDouble();
        for (var i = 0; i < _fauna.length; i++) {
          final f = _fauna[i];
          final dx = f.x - grenade.targetX;
          final dy = f.y - grenade.targetY;
          if (sqrt(dx * dx + dy * dy) < radiusNorm) {
            _fauna[i] = f.copyWith(
              isScattered: true,
              isStunned: false,
              stunTimeRemaining: duration,
            );
          }
        }
        break;

      case 'stun':
        final duration = (gConfig['effect_duration'] as num).toDouble();
        for (var i = 0; i < _fauna.length; i++) {
          final f = _fauna[i];
          final dx = f.x - grenade.targetX;
          final dy = f.y - grenade.targetY;
          if (sqrt(dx * dx + dy * dy) < radiusNorm) {
            _fauna[i] = f.copyWith(
              isStunned: true,
              isScattered: false,
              stunTimeRemaining: duration,
            );
          }
        }
        break;

      case 'damage':
        final damagePercent = (gConfig['damage_percent'] as num).toDouble();
        for (var i = 0; i < _fauna.length; i++) {
          final f = _fauna[i];
          final dx = f.x - grenade.targetX;
          final dy = f.y - grenade.targetY;
          if (sqrt(dx * dx + dy * dy) < radiusNorm) {
            final damage = f.maxHp * damagePercent;
            final newHp = f.hp - damage;
            _fauna[i] = f.copyWith(hp: newHp);
            if (newHp <= 0) _handleFaunaDeath(_fauna[i]);
          }
        }
        _fauna.removeWhere((f) => f.isDead);
        break;

      case 'burn_zone':
        _effects.add(ActiveEffect(
          id: 'e_${DateTime.now().microsecondsSinceEpoch}',
          effectType: 'burn_zone',
          x: grenade.targetX,
          y: grenade.targetY,
          radius: radius,
          timeRemaining: (gConfig['effect_duration'] as num).toDouble(),
          damagePercentPerSecond: (gConfig['damage_percent_per_second'] as num).toDouble(),
        ));
        break;

      case 'bait':
        _effects.add(ActiveEffect(
          id: 'e_${DateTime.now().microsecondsSinceEpoch}',
          effectType: 'bait',
          x: grenade.targetX,
          y: grenade.targetY,
          radius: radius,
          timeRemaining: (gConfig['effect_duration'] as num).toDouble(),
        ));
        break;
    }
  }

  void _updateEffects(double dt) {
    _effects = _effects
        .map((e) => e.copyWith(timeRemaining: e.timeRemaining - dt))
        .where((e) => e.timeRemaining > 0)
        .toList();
  }

  // ── Grenade throw ─────────────────────────────────────────────────────────

  void _throwGrenade(Offset tapPosition) {
    if (_selectedGrenadeId == null) return;
    if ((_grenadeInventory[_selectedGrenadeId!] ?? 0) <= 0) return;

    final tx = tapPosition.dx / _fieldSize.width;
    final ty = tapPosition.dy / _fieldSize.height;

    setState(() {
      _grenades.add(ActiveGrenade(
        id: 'g_${DateTime.now().microsecondsSinceEpoch}',
        grenadeId: _selectedGrenadeId!,
        targetX: tx.clamp(0.0, 1.0),
        targetY: ty.clamp(0.0, _wallY),
        progress: 0.0,
        hasExploded: false,
      ));
      _grenadeInventory[_selectedGrenadeId!] =
      (_grenadeInventory[_selectedGrenadeId!]! - 1);
      if (_grenadeInventory[_selectedGrenadeId!] == 0) {
        _grenadeInventory.remove(_selectedGrenadeId!);
        _selectedGrenadeId = null;
      }
    });
  }

  // ── End raid ──────────────────────────────────────────────────────────────

  void _endRaid({required bool wallBroken}) async {
    if (_raidOver) return;
    _raidOver = true;
    _gameTimer?.cancel();

    _faunaEscaped = _fauna.where((f) => f.isAtWall).length;

    final game = widget.game;
    final difficulty = game.difficulty;
    int cropsLost = 0;
    if (wallBroken) {
      final cropLossFraction =
      MilestoneConfigService.instance.cropLossOnBreach(difficulty);
      if (cropLossFraction > 0) {
        // Count growing/ready crops across all domes
        int totalCrops = game.domes.fold(
          0,
              (sum, d) => sum + d.cells
              .where((c) =>
          c.state == CropState.growing || c.state == CropState.ready)
              .length,
        );
        cropsLost = (totalCrops * cropLossFraction).round();
      }
    }

    final result = RaidResult(
      week: game.currentWeek,
      faunaKilled: _faunaKilled,
      faunaEscaped: _faunaEscaped,
      wallDamageTaken: _wallMaxHp - _wallHp,
      wallBroken: wallBroken,
      cropsLost: cropsLost,
      meatDropped: _meatDropped,
      chitinDropped: _chitinDropped,
      wasDefended: !wallBroken,
    );

    await _applyRaidResults(result);

    if (!mounted) return;

    // Check for game over
    final updatedGame = ref.read(activeGameProvider).value;
    if (updatedGame != null && updatedGame.status == GameStatus.terminated) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => ScoreScreen(game: updatedGame)),
            (route) => route.isFirst,
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RaidResultScreen(result: result, game: widget.game),
      ),
    );
  }

  Future<void> _applyRaidResults(RaidResult result) async {
    final game = widget.game;
    final difficulty = game.difficulty;
    final allowedStrikes = MilestoneConfigService.instance.wallStrikes(difficulty);
    final newWall = game.defenseWall.copyWith(currentHp: _wallHp);

    var resources = game.resources.copyWith(
      meat: game.resources.meat + result.meatDropped,
      chitin: game.resources.chitin + result.chitinDropped,
    );

    final newGrenades = game.grenades.copyWith(counts: _grenadeInventory);

    var domes = game.domes;
    if (result.cropsLost > 0) {
      var lostSoFar = 0;
      domes = domes.map((dome) {
        if (lostSoFar >= result.cropsLost) return dome;
        final updatedCells = dome.cells.map((cell) {
          if (lostSoFar < result.cropsLost &&
              (cell.state == CropState.growing ||
                  cell.state == CropState.ready)) {
            lostSoFar++;
            return cell.cleared();
          }
          return cell;
        }).toList();
        return dome.copyWith(cells: updatedCells);
      }).toList();
    }

    // Determine if this wall breach ends the game
    GameStatus newStatus = game.status;
    int newStrikeCount = game.strikeCount;
    String? terminationReason;

    if (result.wallBroken) {
      if (allowedStrikes == 0) {
        // Normal/Hard: instant game over
        newStatus = GameStatus.terminated;
        terminationReason = MilestoneConfigService.instance
            .formatTerminationMessage(difficulty, week: game.currentWeek);
      } else {
        // Easy: increment strike, check if max reached
        newStrikeCount = game.strikeCount + 1;
        if (newStrikeCount > allowedStrikes) {
          newStatus = GameStatus.terminated;
          terminationReason = MilestoneConfigService.instance
              .formatTerminationMessage(difficulty,
              week: game.currentWeek, strikes: newStrikeCount);
        }
      }
    }

    await ref.read(activeGameProvider.notifier).updateGame(
      game.copyWith(
        defenseWall: newWall,
        grenades: newGrenades,
        resources: resources,
        domes: domes,
        status: newStatus,
        strikeCount: newStrikeCount,
        terminationReason: terminationReason,
        raidDefendedThisWeek:
        widget.isManualTrigger ? game.raidDefendedThisWeek : true,
        totalRaidsDefended: widget.isManualTrigger
            ? game.totalRaidsDefended
            : game.totalRaidsDefended + 1,
        totalFaunaKilled: game.totalFaunaKilled + result.faunaKilled,
        totalChitinCollected:
        game.totalChitinCollected + result.chitinDropped,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── HUD ────────────────────────────────────────────────────────
            _RaidHUD(
              wallHp: _wallHp,
              wallMaxHp: _wallMaxHp,
              timeRemaining: _timeRemaining,
              faunaRemaining: (_maxFauna - _totalSpawned) + _fauna.length,
              totalFauna: _maxFauna,
            ),

            // ── Grenade bar ────────────────────────────────────────────────
            _GrenadeBar(
              inventory: _grenadeInventory,
              benchLevel: widget.game.grenades.benchLevel,
              selectedId: _selectedGrenadeId,
              onSelected: (id) => setState(() {
                _selectedGrenadeId = _selectedGrenadeId == id ? null : id;
              }),
            ),

            // ── Field ──────────────────────────────────────────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _fieldSize = Size(constraints.maxWidth, constraints.maxHeight);
                  return GestureDetector(
                    onTapDown: (details) => _throwGrenade(details.localPosition),
                    child: Container(
                      color: const Color(0xFF0A0A14),
                      child: Stack(
                        children: [
                          CustomPaint(
                            painter: _GridPainter(),
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                          ),

                          for (final effect in _effects)
                            _EffectZoneWidget(
                              effect: effect,
                              fieldSize: _fieldSize,
                            ),

                          for (final f in _fauna)
                            _FaunaWidget(fauna: f, fieldSize: _fieldSize),

                          for (final g in _grenades)
                            _GrenadeInFlightWidget(grenade: g, fieldSize: _fieldSize),

                          for (final p in _projectiles)
                            _ProjectileWidget(
                              proj: p,
                              fauna: _fauna,
                              sentries: widget.game.laserSentries,
                              fieldSize: _fieldSize,
                              sentryY: _sentryY,
                              getSentryX: (idx) => _sentryXForSentry(
                                  idx, widget.game.laserSentries.length),
                            ),

                          for (var i = 0; i < widget.game.laserSentries.length; i++)
                            _SentryWidget(
                              sentry: widget.game.laserSentries[i],
                              x: _sentryXForSentry(i, widget.game.laserSentries.length),
                              y: _sentryY,
                              fieldSize: _fieldSize,
                            ),

                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: constraints.maxHeight * (1 - _wallY),
                            child: _WallWidget(
                              hp: _wallHp,
                              maxHp: _wallMaxHp,
                            ),
                          ),

                          if (_selectedGrenadeId != null)
                            const Positioned(
                              top: 8,
                              left: 0,
                              right: 0,
                              child: Text(
                                'TAP FIELD TO THROW',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Projectile model (UI only) ───────────────────────────────────────────────

class _Projectile {
  final String id;
  final String targetId;
  final double fromX;
  final double fromY;
  final double damage;
  final double speed;
  final double progress;

  const _Projectile({
    required this.id,
    required this.targetId,
    required this.fromX,
    required this.fromY,
    required this.damage,
    required this.speed,
    required this.progress,
  });

  _Projectile copyWith({double? progress}) => _Projectile(
    id: id, targetId: targetId, fromX: fromX, fromY: fromY,
    damage: damage, speed: speed, progress: progress ?? this.progress,
  );
}

// ─── HUD ──────────────────────────────────────────────────────────────────────

class _RaidHUD extends StatelessWidget {
  final int wallHp, wallMaxHp, timeRemaining, faunaRemaining, totalFauna;

  const _RaidHUD({
    required this.wallHp,
    required this.wallMaxHp,
    required this.timeRemaining,
    required this.faunaRemaining,
    required this.totalFauna,
  });

  @override
  Widget build(BuildContext context) {
    final wallPct = wallMaxHp > 0 ? wallHp / wallMaxHp : 0.0;
    final wallColor = wallPct > 0.5
        ? MFColors.neonGreen
        : wallPct > 0.25
        ? MFColors.neonOrange
        : MFColors.neonPink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.black87,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WALL',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 9, letterSpacing: 2)),
                const SizedBox(height: 3),
                LinearProgressIndicator(
                  value: wallPct.clamp(0.0, 1.0),
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(wallColor),
                  minHeight: 8,
                ),
                Text('$wallHp / $wallMaxHp',
                    style: TextStyle(color: wallColor, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              Text('$timeRemaining',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
              const Text('SEC', style: TextStyle(color: Colors.white38, fontSize: 8)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('FAUNA',
                    style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 2)),
                const SizedBox(height: 3),
                LinearProgressIndicator(
                  value: totalFauna > 0 ? (totalFauna - faunaRemaining) / totalFauna : 1.0,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Colors.white24),
                  minHeight: 8,
                ),
                Text('$faunaRemaining left',
                    style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Grenade Bar ──────────────────────────────────────────────────────────────

class _GrenadeBar extends StatelessWidget {
  final Map<String, int> inventory;
  final int benchLevel;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  const _GrenadeBar({
    required this.inventory,
    required this.benchLevel,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final config = GameConfigService.instance;
    final allGrenades = config.getGrenadeTypes()
        .where((g) => (g['unlock_level'] as int) <= benchLevel)
        .toList();

    return Container(
      height: 68,
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: allGrenades.map((g) {
          final id = g['id'] as String;
          final count = inventory[id] ?? 0;
          final isSelected = selectedId == id;
          final hasStock = count > 0;

          return GestureDetector(
            onTap: hasStock ? () => onSelected(id) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? MFColors.neonCyan.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? MFColors.neonCyan
                      : hasStock
                      ? Colors.white24
                      : Colors.white12,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(g['emoji'] as String,
                      style: TextStyle(
                        fontSize: 20,
                        color: hasStock ? null : Colors.white24,
                      )),
                  Text('×$count',
                      style: TextStyle(
                        color: hasStock ? Colors.white70 : Colors.white24,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      )),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Field Widgets ────────────────────────────────────────────────────────────

class _FaunaWidget extends StatelessWidget {
  final FaunaUnit fauna;
  final Size fieldSize;

  const _FaunaWidget({required this.fauna, required this.fieldSize});

  @override
  Widget build(BuildContext context) {
    final x = fauna.x * fieldSize.width - 12;
    final y = fauna.y * fieldSize.height - 12;
    final hpPct = fauna.hp / fauna.maxHp;

    Color overlayColor = Colors.transparent;
    if (fauna.isStunned) overlayColor = Colors.yellow.withValues(alpha: 0.4);
    if (fauna.isScattered) overlayColor = Colors.white.withValues(alpha: 0.3);

    return Positioned(
      left: x,
      top: y,
      child: Column(
        children: [
          if (fauna.maxHp > 20)
            SizedBox(
              width: 24,
              child: LinearProgressIndicator(
                value: hpPct.clamp(0.0, 1.0),
                backgroundColor: Colors.red.shade900,
                valueColor: AlwaysStoppedAnimation(
                  hpPct > 0.5 ? Colors.green : Colors.orange,
                ),
                minHeight: 3,
              ),
            ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: overlayColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(fauna.emoji,
                  style: TextStyle(
                    fontSize: fauna.isBrute ? 20 : 14,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

Color mkColor(int level) => switch (level) {
  1 => const Color(0xFF9E9E9E),
  2 => const Color(0xFF66BB6A),
  3 => const Color(0xFF42A5F5),
  4 => const Color(0xFFAB47BC),
  _ => const Color(0xFFFF9800),
};

class _SentryWidget extends StatelessWidget {
  final LaserSentry sentry;
  final double x, y;
  final Size fieldSize;

  const _SentryWidget({
    required this.sentry,
    required this.x,
    required this.y,
    required this.fieldSize,
  });

  @override
  Widget build(BuildContext context) {
    final color = mkColor(sentry.level);
    return Positioned(
      left: x * fieldSize.width - 16,
      top: y * fieldSize.height - 16,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text('🔫', style: TextStyle(fontSize: sentry.level > 2 ? 18 : 16)),
        ),
      ),
    );
  }
}

class _WallWidget extends StatelessWidget {
  final int hp, maxHp;
  const _WallWidget({required this.hp, required this.maxHp});

  @override
  Widget build(BuildContext context) {
    final pct = maxHp > 0 ? hp / maxHp : 0.0;
    final color = pct > 0.5
        ? MFColors.neonGreen
        : pct > 0.25
        ? MFColors.neonOrange
        : MFColors.neonPink;

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(top: BorderSide(color: color, width: 2)),
      ),
      child: Center(
        child: Text(
          '⣿⣿⣿⣿⣿⣿⣿⣿',
          style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10),
        ),
      ),
    );
  }
}

class _GrenadeInFlightWidget extends StatelessWidget {
  final ActiveGrenade grenade;
  final Size fieldSize;

  const _GrenadeInFlightWidget({required this.grenade, required this.fieldSize});

  @override
  Widget build(BuildContext context) {
    final startX = fieldSize.width;
    final startY = fieldSize.height * 0.5;
    final endX = grenade.targetX * fieldSize.width;
    final endY = grenade.targetY * fieldSize.height;

    final t = grenade.progress;
    final x = startX + (endX - startX) * t;
    final arcY = startY + (endY - startY) * t - sin(t * pi) * 60;

    final config = GameConfigService.instance;
    final gConfig = config.getGrenadeType(grenade.grenadeId);
    final emoji = gConfig?['emoji'] as String? ?? '💥';

    return Positioned(
      left: x - 10,
      top: arcY - 10,
      child: Text(emoji, style: const TextStyle(fontSize: 16)),
    );
  }
}

class _EffectZoneWidget extends StatelessWidget {
  final ActiveEffect effect;
  final Size fieldSize;

  const _EffectZoneWidget({required this.effect, required this.fieldSize});

  @override
  Widget build(BuildContext context) {
    final x = effect.x * fieldSize.width;
    final y = effect.y * fieldSize.height;
    final r = effect.radius;

    Color color;
    switch (effect.effectType) {
      case 'burn_zone': color = Colors.orange; break;
      case 'bait': color = Colors.brown; break;
      default: color = Colors.yellow;
    }

    return Positioned(
      left: x - r,
      top: y - r,
      child: Container(
        width: r * 2,
        height: r * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        ),
      ),
    );
  }
}

class _ProjectileWidget extends StatelessWidget {
  final _Projectile proj;
  final List<FaunaUnit> fauna;
  final List<LaserSentry> sentries;
  final Size fieldSize;
  final double sentryY;
  final double Function(int) getSentryX;

  const _ProjectileWidget({
    required this.proj,
    required this.fauna,
    required this.sentries,
    required this.fieldSize,
    required this.sentryY,
    required this.getSentryX,
  });

  @override
  Widget build(BuildContext context) {
    final target = fauna.where((f) => f.id == proj.targetId).firstOrNull;
    if (target == null) return const SizedBox();

    final startX = proj.fromX * fieldSize.width;
    final startY = proj.fromY * fieldSize.height;
    final endX = target.x * fieldSize.width;
    final endY = target.y * fieldSize.height;

    final x = startX + (endX - startX) * proj.progress;
    final y = startY + (endY - startY) * proj.progress;

    return Positioned(
      left: x - 3,
      top: y - 3,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: MFColors.neonCyan,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: MFColors.neonCyan.withValues(alpha: 0.8),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════
// RAID RESULT SCREEN
// ═══════════════════════════════════════════════════════════════

class RaidResultScreen extends ConsumerWidget {
  final RaidResult result;
  final GameState game;

  const RaidResultScreen({super.key, required this.result, required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: MFColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Ad banner placeholder (replace with AdMob widget when ready) ─
            Container(
              width: double.infinity,
              height: 50,
              color: MFColors.surface,
              child: Center(
                child: Text(
                  'AD PLACEHOLDER',
                  style: MFTextStyles.bodySmall.copyWith(
                    color: MFColors.textMuted,
                    letterSpacing: 2,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: MFColors.borderSubtle)),
              ),
              child: Column(
                children: [
                  Text(
                    result.wallBroken ? '💀 WALL BREACHED' : '✅ RAID REPELLED',
                    style: MFTextStyles.displayMedium.copyWith(
                      color: result.wallBroken ? MFColors.neonPink : MFColors.neonGreen,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Week ${result.week}', style: MFTextStyles.bodyMedium),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ResultSection(title: 'COMBAT', children: [
                    _ResultRow('Fauna killed', '${result.faunaKilled}', MFColors.neonGreen),
                    _ResultRow('Fauna escaped', '${result.faunaEscaped}',
                        result.faunaEscaped > 0 ? MFColors.neonOrange : MFColors.textMuted),
                    _ResultRow('Wall damage', '${result.wallDamageTaken} HP',
                        result.wallDamageTaken > 0 ? MFColors.neonOrange : MFColors.textMuted),
                  ]),
                  const SizedBox(height: 12),

                  if (result.meatDropped > 0 || result.chitinDropped > 0)
                    _ResultSection(title: 'DROPS', children: [
                      if (result.meatDropped > 0)
                        _ResultRow('🥩 Meat', '+${result.meatDropped}', MFColors.neonOrange),
                      if (result.chitinDropped > 0)
                        _ResultRow('🦴 Chitin', '+${result.chitinDropped}', MFColors.neonYellow),
                    ]),

                  if (result.cropsLost > 0) ...[
                    const SizedBox(height: 12),
                    _ResultSection(title: 'LOSSES', children: [
                      _ResultRow('Crops destroyed', '${result.cropsLost}', MFColors.neonPink),
                    ]),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MFColors.neonPink.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: MFColors.neonPink.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'The wall was breached. Fauna reached your domes. '
                            '${result.cropsLost} crop${result.cropsLost == 1 ? '' : 's'} destroyed. '
                            'Repair the wall before the next raid.',
                        style: MFTextStyles.bodySmall.copyWith(color: MFColors.neonPink),
                      ),
                    ),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: result.wallBroken ? MFColors.neonOrange : MFColors.neonCyan,
                    foregroundColor: MFColors.background,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    result.wallBroken ? 'RETURN — REPAIR WALL' : '▶  CONTINUE',
                    style: MFTextStyles.labelLarge.copyWith(
                      color: MFColors.background, letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ResultSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MFColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MFColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: MFTextStyles.bodySmall.copyWith(
              color: MFColors.textMuted, letterSpacing: 2, fontSize: 10)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label, value;
  final Color color;

  const _ResultRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: MFTextStyles.bodyMedium),
          Text(value, style: MFTextStyles.labelLarge.copyWith(color: color)),
        ],
      ),
    );
  }
}