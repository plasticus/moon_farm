// ═══════════════════════════════════════════════════════════════
//  lib/config/game_config_service.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/game_models.dart';

/// Singleton that loads game_config.json once and provides typed access.
/// Edit assets/config/game_config.json to tweak any game balance value.
class GameConfigService {
  static final GameConfigService instance = GameConfigService._init();
  GameConfigService._init();

  Map<String, dynamic>? _config;
  Map<String, CropConfig>? _cropConfigs;

  Future<void> initialize() async {
    if (_config != null) return;
    final jsonStr =
    await rootBundle.loadString('assets/config/game_config.json');
    _config = jsonDecode(jsonStr) as Map<String, dynamic>;
    _buildCropConfigs();
  }

  Map<String, dynamic> get _c {
    assert(_config != null, 'GameConfigService not initialized');
    return _config!;
  }

  void _buildCropConfigs() {
    _cropConfigs = {};
    for (final cropJson in _c['crops'] as List) {
      final crop = CropConfig.fromJson(cropJson as Map<String, dynamic>);
      _cropConfigs![crop.id] = crop;
    }
  }

  // ─── Crops ────────────────────────────────────────────────────────────────

  Map<String, CropConfig> get allCrops => _cropConfigs!;

  CropConfig? getCrop(String id) => _cropConfigs?[id];

  List<CropConfig> getCropsByTier(int tier) =>
      _cropConfigs!.values.where((c) => c.tier == tier).toList();

  List<CropConfig> getCropsForDomeTier(int domeTier) =>
      _cropConfigs!.values
          .where((c) => c.domeTierRequired <= domeTier)
          .toList();

  // ─── Difficulty ───────────────────────────────────────────────────────────

  Map<String, dynamic> getDifficultySettings(Difficulty difficulty) {
    return _c['difficulty_settings'][difficulty.name] as Map<String, dynamic>;
  }

  int getStartingScrip(Difficulty difficulty) {
    return getDifficultySettings(difficulty)['starting_scrip'] as int;
  }

  Map<String, dynamic> getStartingResources(Difficulty difficulty) {
    return getDifficultySettings(difficulty)['starting_resources']
    as Map<String, dynamic>;
  }

  int getRaidFrequency(Difficulty difficulty) {
    return getDifficultySettings(difficulty)['raid_frequency_weeks'] as int;
  }

  double getCropDecayRate(Difficulty difficulty) {
    return (getDifficultySettings(difficulty)['crop_decay_rate'] as num)
        .toDouble();
  }

  // ─── Buildings ────────────────────────────────────────────────────────────

  Map<String, dynamic> getDomeTier(int tier) {
    final tiers = _c['buildings']['dome']['tiers'] as List;
    return tiers.firstWhere((t) => (t as Map)['tier'] == tier)
    as Map<String, dynamic>;
  }

  Map<String, dynamic> getNewDomeCost() {
    return _c['buildings']['dome']['new_dome_cost'] as Map<String, dynamic>;
  }

  Map<String, dynamic> getRobotLevel(int level) {
    final levels = _c['buildings']['dome_robot']['levels'] as List;
    return levels.firstWhere((l) => (l as Map)['level'] == level)
    as Map<String, dynamic>;
  }

  Map<String, dynamic> getSiloTier(int tier) {
    final tiers = _c['buildings']['silo']['tiers'] as List;
    return tiers.firstWhere((t) => (t as Map)['tier'] == tier)
    as Map<String, dynamic>;
  }

  Map<String, dynamic> getNewSiloCost() {
    return _c['buildings']['silo']['new_silo_cost'] as Map<String, dynamic>;
  }

  Map<String, dynamic> getRefineryTier(int tier) {
    final tiers = _c['buildings']['refinery']['tiers'] as List;
    return tiers.firstWhere((t) => (t as Map)['tier'] == tier)
    as Map<String, dynamic>;
  }

  Map<String, dynamic> getPowerSource(String type) {
    return _c['buildings']['power'][type] as Map<String, dynamic>;
  }

  Map<String, dynamic> getSentryLevel(int level) {
    final levels = _c['buildings']['laser_sentry']['levels'] as List;
    return levels.firstWhere((l) => (l as Map)['level'] == level)
    as Map<String, dynamic>;
  }

  // ─── Refinery Recipes ─────────────────────────────────────────────────────

  List<Map<String, dynamic>> getAllRecipes() {
    return (_c['refinery_recipes'] as List).cast<Map<String, dynamic>>();
  }

  Map<String, dynamic>? getRecipe(String id) {
    final recipes = _c['refinery_recipes'] as List;
    try {
      return recipes.firstWhere((r) => (r as Map)['id'] == id)
      as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ─── Milestones ───────────────────────────────────────────────────────────

  List<Milestone> getMilestones(Difficulty difficulty) {
    final milestoneList =
    _c['milestones'][difficulty.name] as List;
    return milestoneList.map((m) {
      final map = m as Map<String, dynamic>;
      return Milestone(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        targetVolumeM3: (map['target_volume_m3'] as num).toDouble(),
        byWeek: map['by_week'] as int,
        rewardScrip: map['reward_scrip'] as int,
        status: MilestoneStatus.pending,
      );
    }).toList();
  }

  // ─── Trophies ─────────────────────────────────────────────────────────────

  List<Trophy> getAllTrophies() {
    return (_c['trophies'] as List).map((t) {
      final map = t as Map<String, dynamic>;
      return Trophy(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String,
        emoji: map['emoji'] as String,
        category: map['category'] as String,
        status: TrophyStatus.locked,
      );
    }).toList();
  }

  // ─── Relay / Technician ───────────────────────────────────────────────────

  Map<String, dynamic> get relayConfig {
    return _c['relay_technician'] as Map<String, dynamic>;
  }

  List<String> get rantTopics {
    return List<String>.from(
      relayConfig['rant_topics'] as List,
    );
  }

  List<String> get radioTransmissionTemplates {
    return List<String>.from(
      relayConfig['radio_transmissions'] as List,
    );
  }

  Map<String, dynamic> get moodSystemConfig {
    return relayConfig['mood_system'] as Map<String, dynamic>;
  }

  Map<String, dynamic> getMoodAction(String actionId) {
    return (moodSystemConfig['actions'] as Map<String, dynamic>)[actionId]
    as Map<String, dynamic>;
  }

  // ─── Market ───────────────────────────────────────────────────────────────

  Map<String, dynamic> get marketPrices {
    return _c['market_prices'] as Map<String, dynamic>;
  }

  int getBuyPrice(String itemId) {
    final buy = marketPrices['buy'] as Map<String, dynamic>;
    return buy[itemId] as int? ?? 0;
  }

  double get sellModifier {
    return (marketPrices['sell_modifier'] as num).toDouble();
  }

  double getCropVolumeM3(String cropId) {
    final crop = getCrop(cropId);
    return (crop != null ? crop.volumeM3 : 0.5);
  }

  int getSellPrice(String cropId, {double moodDiscount = 0.0}) {
    final crop = getCrop(cropId);
    if (crop == null) return 0;
    final base = crop.baseSolarValue;
    final withMood = (base * (1 + moodDiscount)).round();
    return withMood;
  }

  // ─── Fauna / Raids ────────────────────────────────────────────────────────

  Map<String, dynamic> get faunaConfig {
    return _c['fauna'] as Map<String, dynamic>;
  }

  int get raidWarningWeeksBefore {
    return faunaConfig['raid_warning_weeks_before'] as int;
  }

  int getWaveCount(Difficulty difficulty) {
    return (faunaConfig['wave_count_by_difficulty'] as Map)[difficulty.name]
    as int;
  }

  List<Map<String, dynamic>> get enemyTypes {
    return (faunaConfig['enemy_types'] as List).cast<Map<String, dynamic>>();
  }

  String get gameVersion => _c['game_version'] as String;
  String get websiteUrl => _c['website_url'] as String;
}