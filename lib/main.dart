// ═══════════════════════════════════════════════════════════════
//  lib/main.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'config/game_config_service.dart';
import 'config/upgrade_config_service.dart';
import 'config/raid_config_service.dart';
import 'config/kovacs_config_service.dart';
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

  runApp(
    const ProviderScope(
      child: MoonFarmApp(),
    ),
  );
}

class MoonFarmApp extends StatelessWidget {
  const MoonFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moon Farm',
      debugShowCheckedModeBanner: false,
      theme: MFTheme.dark,
      home: const MainMenuScreen(),
    );
  }
}