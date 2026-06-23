// ═══════════════════════════════════════════════════════════════
//  lib/config/game_config_service.dart
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import '../models/game_models.dart';
import 'raid_config_service.dart';
import 'upgrade_config_service.dart';
import 'radio_config_service.dart';
import 'milestone_config_service.dart';

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
    await _buildCropConfigs();
  }

  Map<String, dynamic> get _c {
    assert(_config != null, 'GameConfigService not initialized');
    return _config!;
  }

  Future<void> _buildCropConfigs() async {
    _cropConfigs = {};
    // Crops now live in their own editable YAML file.
    final raw = await rootBundle.loadString('assets/config/crops.yaml');
    final doc = loadYaml(raw);
    final list = _deepConvert(doc)['crops'] as List? ?? [];
    for (final cropMap in list) {
      final crop = CropConfig.fromJson(Map<String, dynamic>.from(cropMap as Map));
      _cropConfigs![crop.id] = crop;
    }

    // Inject fauna_meat as a sellable product — configured here, not in dome picker.
    // Price and volume are tunable; tier 99 ensures it never appears in crop pickers.
    const meatConfig = {
      'id': 'fauna_meat',
      'name': 'Fauna Meat',
      'tier': 99,
      'dome_tier_required': 99,
      'growth_weeks': 1,
      'water_per_week': 0,
      'base_scrip_per_m3': 50,
      'compost_yield': 0,
      'description': 'Processed fauna protein. The colony kitchen pays well.',
      'note': '',
      'decay_rate': 0.0,
      'fertilizer_bonus': 1.0,
      'volume_m3': 1.0,
    };
    _cropConfigs!['fauna_meat'] = CropConfig.fromJson(meatConfig);
  }

  // Convert YamlMap/YamlList to plain Dart structures recursively.
  dynamic _deepConvert(dynamic node) {
    if (node is YamlMap) {
      return node.map((k, v) => MapEntry(k.toString(), _deepConvert(v)));
    } else if (node is YamlList) {
      return node.map(_deepConvert).toList();
    } else {
      return node;
    }
  }

  // ─── Crops ────────────────────────────────────────────────────────────────

  Map<String, CropConfig> get allCrops => _cropConfigs!;

  CropConfig? getCrop(String id) => _cropConfigs?[id];

  List<CropConfig> getAllCrops() => _cropConfigs?.values.toList() ?? [];

  List<CropConfig> getCropsByTier(int tier) =>
      _cropConfigs!.values.where((c) => c.tier == tier).toList();

  // A dome grows ONLY crops of its exact tier (not backward-compatible).
  // Tier 99 items (fauna products) are excluded from the dome picker.
  List<CropConfig> getCropsForDomeTier(int domeTier) =>
      _cropConfigs!.values
          .where((c) => c.domeTierRequired == domeTier && c.tier < 99)
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

  List<Milestone> getMilestones(Difficulty difficulty) =>
      MilestoneConfigService.instance.getMilestones(difficulty);

  // ─── Trophies ─────────────────────────────────────────────────────────────

  List<Trophy> getAllTrophies() =>
      MilestoneConfigService.instance.getAllTrophies();

  // ─── Relay / Technician ───────────────────────────────────────────────────

  Map<String, dynamic> get relayConfig {
    return _c['relay_technician'] as Map<String, dynamic>;
  }

  Map<String, dynamic> getRelayConfig() => relayConfig;

  List<String> getDialogueLines(String key) {
    final dialogue = relayConfig['dialogue'] as Map<String, dynamic>?;
    if (dialogue == null) return [];
    final lines = dialogue[key];
    if (lines == null) return [];
    return List<String>.from(lines as List);
  }

  Map<String, dynamic> get shipSchedule {
    return _c['ship_schedule'] as Map<String, dynamic>? ?? {
      'first_window_week': 4,
      'interval_weeks': 4,
      'reminder_weeks_before': 1,
      'rush_shipment_mood_penalty': -20,
      'rush_shipment_price_cut': 0.15,
    };
  }

  int get shipWindowInterval => shipSchedule['interval_weeks'] as int;
  int get shipReminderWeeksBefore => shipSchedule['reminder_weeks_before'] as int;
  int get rushMoodPenalty => shipSchedule['rush_shipment_mood_penalty'] as int;
  double get rushPriceCut => (shipSchedule['rush_shipment_price_cut'] as num).toDouble();

  List<Map<String, dynamic>> getWaterPurifierLevels() {
    final wp = _c['water_purifier'] as Map<String, dynamic>?;
    if (wp == null) return [];
    return List<Map<String, dynamic>>.from(wp['levels'] as List);
  }

  int get basePassiveWaterOutput {
    final wp = _c['water_purifier'] as Map<String, dynamic>?;
    return wp?['base_passive_output'] as int? ?? 5;
  }

  int getWaterOutputForLevel(int level) {
    if (level == 0) return basePassiveWaterOutput;
    final levels = getWaterPurifierLevels();
    final match = levels.where((l) => l['level'] == level).firstOrNull;
    return match?['output_water_per_week'] as int? ?? basePassiveWaterOutput;
  }

  List<String> get rantTopics {
    return List<String>.from(
      relayConfig['rant_topics'] as List,
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

  /// Bulk-only scrap dealer prices — separate buyer from Kovacs/the Space
  /// Colony, takes raw metals/chemicals/components off your hands at a
  /// deliberately bad rate, but only by the truckload.
  Map<String, dynamic> get scrapDealer =>
      marketPrices['scrap_dealer'] as Map<String, dynamic>? ?? {};

  int get scrapDealerBulkAmount => scrapDealer['bulk_amount'] as int? ?? 1000;

  int scrapDealerPrice(String resourceKey) =>
      scrapDealer['${resourceKey}_price'] as int? ?? 0;

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

  List<Map<String, dynamic>> getDefenseWallLevels() {
    final dw = _c['defense_wall'] as Map<String, dynamic>?;
    if (dw == null) return [];
    return List<Map<String, dynamic>>.from(dw['levels'] as List);
  }

  Map<String, dynamic> getDefenseWallLevel(int level) {
    return getDefenseWallLevels()
        .firstWhere((l) => l['level'] == level, orElse: () => getDefenseWallLevels().first);
  }

  List<Map<String, dynamic>> getFaunaTypes() =>
      RaidConfigService.instance.allFaunaTypes;

  Map<String, dynamic>? getFaunaType(String id) =>
      RaidConfigService.instance.getFaunaType(id);

  List<Map<String, dynamic>> getGrenadeTypes() {
    final g = _c['grenades'] as List?;
    if (g == null) return [];
    return List<Map<String, dynamic>>.from(g);
  }

  Map<String, dynamic>? getGrenadeType(String id) {
    return getGrenadeTypes().where((g) => g['id'] == id).firstOrNull;
  }

  Map<String, dynamic> getRaidScaling() =>
      RaidConfigService.instance.scaling;

  int getFirstRaidWeek() =>
      RaidConfigService.instance.firstRaidWeek;

  int getRaidInterval(Difficulty difficulty) =>
      RaidConfigService.instance.raidInterval(difficulty);

  Map<String, dynamic> getGrenadeBenchConfig() {
    return _c['grenade_bench'] as Map<String, dynamic>? ?? {};
  }

  Map<String, dynamic> getDomeBuildingConfig() {
    return _c['dome_building'] as Map<String, dynamic>? ?? {};
  }

  /// Computes the scrip cost for the next dome based on how many you already have.
  int getNextDomeScripCost(Difficulty difficulty, int currentDomeCount) {
    // domeNumber = the dome about to be built (you start with 1, so the
    // first one you ever buy is dome #2).
    final domeNumber = currentDomeCount + 1;
    final cfg = (_c['dome_building'] as Map?)?['dome_cost_scaling']
    as Map<String, dynamic>?;
    if (cfg == null) return 500; // safety fallback if config is missing

    final base = (cfg['base_scrip_cost'] as num).toDouble();
    final rate = (cfg['rate'] as num).toDouble();
    final cap = (cfg['cap'] as num).toInt();
    final capAtCount = cfg['cap_at_count'] as int;

    // Soft cap: once you've reached the configured dome number, price
    // stops climbing entirely and just sits flat at `cap` forever after.
    if (domeNumber >= capAtCount) return cap;

    final n = domeNumber < 2 ? 2 : domeNumber;
    final cost = base * pow(rate, n - 2);
    return cost.round().clamp(0, cap);
  }

  List<Map<String, dynamic>> getDomeBotLevels() =>
      UpgradeConfigService.instance.domeBotLevels;

  List<Map<String, dynamic>> getRadioTips() {
    // Now sourced from radio_triggers.toml (kind = "week", show_as_tip =
    // true) via RadioConfigService — see that file for how to add more.
    return RadioConfigService.instance.tipBannerEntries;
  }

  Map<String, dynamic> getDifficultyConfig(Difficulty difficulty) {
    final settings = _c['difficulty_settings'] as Map<String, dynamic>;
    return settings[difficulty.name] as Map<String, dynamic>;
  }

  Map<String, dynamic> getMachineConfigs() {
    return _c['refinery_machines'] as Map<String, dynamic>? ?? {};
  }

  Map<String, dynamic>? getMachineConfig(String key) {
    final machines = getMachineConfigs();
    return machines[key] as Map<String, dynamic>?;
  }

  Map<String, dynamic> getOperationsBuildings() {
    return _c['operations_buildings'] as Map<String, dynamic>? ?? {};
  }

  String get gameVersion => _c['game_version'] as String;
  String get websiteUrl => _c['website_url'] as String;

  List<String> getFarmNameSuggestions() {
    final raw = _c['farm_name_suggestions'];
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }
}