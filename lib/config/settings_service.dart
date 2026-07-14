// ═══════════════════════════════════════════════════════════════
//  lib/config/settings_service.dart
// ═══════════════════════════════════════════════════════════════
//
// Player-facing app settings, persisted locally via SharedPreferences.
// Follows the same singleton-initialized-in-main() pattern as the other
// *ConfigService classes, so settings are available synchronously by the
// time the widget tree first builds.

import 'package:shared_preferences/shared_preferences.dart';

enum RaidSpeed {
  normal(1.0, 'Normal'),
  fast(2.0, 'Fast'),
  turbo(3.0, 'Turbo');

  final double multiplier;
  final String label;
  const RaidSpeed(this.multiplier, this.label);
}

/// Weeks between autosaves. 0 means "manual only" — the autosave slot is
/// never written automatically, only via the explicit Save Game action.
enum AutoSaveFrequency {
  everyWeek(1, 'Every week'),
  every5Weeks(5, 'Every 5 weeks'),
  every10Weeks(10, 'Every 10 weeks'),
  manualOnly(0, 'Manual only');

  final int weeks;
  final String label;
  const AutoSaveFrequency(this.weeks, this.label);
}

/// Not yet wired to any translated content — see docs/phase5_plan.md
/// Localization section. Persisted now so the choice carries forward once
/// real translations land.
enum AppLanguage {
  english('English'),
  spanish('Español');

  final String label;
  const AppLanguage(this.label);
}

/// Not yet wired to a real light palette — most screens hardcode MFColors
/// directly rather than reading from Theme, so a real light mode needs a
/// broader pass. Persisted now so the choice carries forward once it's
/// implemented.
enum AppThemeMode {
  dark('Dark'),
  light('Light');

  final String label;
  const AppThemeMode(this.label);
}

class AppSettings {
  final AppThemeMode themeMode;
  final double textScale;
  final bool confirmDialogs;
  final RaidSpeed raidSpeed;
  final AutoSaveFrequency autoSaveFrequency;
  final AppLanguage language;

  const AppSettings({
    required this.themeMode,
    required this.textScale,
    required this.confirmDialogs,
    required this.raidSpeed,
    required this.autoSaveFrequency,
    required this.language,
  });

  static const defaults = AppSettings(
    themeMode: AppThemeMode.dark,
    textScale: 1.0,
    confirmDialogs: true,
    raidSpeed: RaidSpeed.normal,
    autoSaveFrequency: AutoSaveFrequency.everyWeek,
    language: AppLanguage.english,
  );

  AppSettings copyWith({
    AppThemeMode? themeMode,
    double? textScale,
    bool? confirmDialogs,
    RaidSpeed? raidSpeed,
    AutoSaveFrequency? autoSaveFrequency,
    AppLanguage? language,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      textScale: textScale ?? this.textScale,
      confirmDialogs: confirmDialogs ?? this.confirmDialogs,
      raidSpeed: raidSpeed ?? this.raidSpeed,
      autoSaveFrequency: autoSaveFrequency ?? this.autoSaveFrequency,
      language: language ?? this.language,
    );
  }
}

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _kThemeMode = 'settings_theme_mode';
  static const _kTextScale = 'settings_text_scale';
  static const _kConfirmDialogs = 'settings_confirm_dialogs';
  static const _kRaidSpeed = 'settings_raid_speed';
  static const _kAutoSaveFrequency = 'settings_autosave_frequency';
  static const _kLanguage = 'settings_language';

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  AppSettings load() {
    if (!_initialized) return AppSettings.defaults;
    return AppSettings(
      themeMode: _enumFrom(AppThemeMode.values, _prefs.getString(_kThemeMode)) ??
          AppSettings.defaults.themeMode,
      textScale: _prefs.getDouble(_kTextScale) ?? AppSettings.defaults.textScale,
      confirmDialogs: _prefs.getBool(_kConfirmDialogs) ?? AppSettings.defaults.confirmDialogs,
      raidSpeed: _enumFrom(RaidSpeed.values, _prefs.getString(_kRaidSpeed)) ??
          AppSettings.defaults.raidSpeed,
      autoSaveFrequency:
      _enumFrom(AutoSaveFrequency.values, _prefs.getString(_kAutoSaveFrequency)) ??
          AppSettings.defaults.autoSaveFrequency,
      language: _enumFrom(AppLanguage.values, _prefs.getString(_kLanguage)) ??
          AppSettings.defaults.language,
    );
  }

  Future<void> save(AppSettings s) async {
    if (!_initialized) return;
    await _prefs.setString(_kThemeMode, s.themeMode.name);
    await _prefs.setDouble(_kTextScale, s.textScale);
    await _prefs.setBool(_kConfirmDialogs, s.confirmDialogs);
    await _prefs.setString(_kRaidSpeed, s.raidSpeed.name);
    await _prefs.setString(_kAutoSaveFrequency, s.autoSaveFrequency.name);
    await _prefs.setString(_kLanguage, s.language.name);
  }

  T? _enumFrom<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
