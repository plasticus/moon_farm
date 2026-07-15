// ═══════════════════════════════════════════════════════════════
//  lib/main.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'theme/app_theme.dart';
import 'config/game_config_service.dart';
import 'config/upgrade_config_service.dart';
import 'config/raid_config_service.dart';
import 'config/kovacs_config_service.dart';
import 'config/milestone_config_service.dart';
import 'config/radio_config_service.dart';
import 'config/monument_config_service.dart';
import 'config/settings_service.dart';
import 'providers/settings_providers.dart';
import 'screens/main_menu/main_menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style (dark icons for status bar)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Load game config from JSON asset before app launches
  await GameConfigService.instance.initialize();
  await UpgradeConfigService.instance.load();
  await RaidConfigService.instance.load();
  await KovacsConfigService.instance.load();
  await MilestoneConfigService.instance.load();
  await RadioConfigService.instance.load();
  await MonumentConfigService.instance.load();
  await SettingsService.instance.initialize();

  // Manifest currently ships Google's public test App ID, so this always
  // serves test ads — safe to leave running through dev/QA builds.
  await MobileAds.instance.initialize();

  runApp(
    const ProviderScope(
      child: MoonFarmApp(),
    ),
  );
}

class MoonFarmApp extends ConsumerWidget {
  const MoonFarmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = ref.watch(settingsProvider.select((s) => s.textScale));
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final isLight = themeMode == AppThemeMode.light;
    MFColors.setMode(isLight: isLight);

    // Status bar icons need to flip alongside the theme — light icons read
    // fine on the dark background, dark icons are needed once it's light.
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      ),
    );

    return MaterialApp(
      // Changing theme mode remounts the whole app (fresh Navigator, back to
      // Main Menu) rather than reskinning in place — acceptable for now
      // since this is a rarely-touched Settings action, not a live toggle.
      key: ValueKey(themeMode),
      title: 'Moon Farm',
      debugShowCheckedModeBanner: false,
      theme: MFTheme.current,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: const MainMenuScreen(),
    );
  }
}