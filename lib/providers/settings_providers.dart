// ═══════════════════════════════════════════════════════════════
//  lib/providers/settings_providers.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/settings_service.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => SettingsService.instance.load();

  void _update(AppSettings Function(AppSettings) fn) {
    state = fn(state);
    SettingsService.instance.save(state);
  }

  void setThemeMode(AppThemeMode v) => _update((s) => s.copyWith(themeMode: v));
  void setTextScale(double v) => _update((s) => s.copyWith(textScale: v));
  void setConfirmDialogs(bool v) => _update((s) => s.copyWith(confirmDialogs: v));
  void setRaidSpeed(RaidSpeed v) => _update((s) => s.copyWith(raidSpeed: v));
  void setAutoSaveFrequency(AutoSaveFrequency v) =>
      _update((s) => s.copyWith(autoSaveFrequency: v));
  void setLanguage(AppLanguage v) => _update((s) => s.copyWith(language: v));
}
