// ═══════════════════════════════════════════════════════════════
//  lib/theme/app_theme.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ─── Moon Farm Color Tokens ───────────────────────────────────────────────────
// Think of these like CSS variables. Change them here, they update everywhere.

class MFColors {
  MFColors._();

  // Base backgrounds
  static const Color background = Color(0xFF0D0D0D);       // near-black base
  static const Color surface = Color(0xFF1A1A1A);          // card / panel bg
  static const Color surfaceElevated = Color(0xFF222222);  // slightly raised

  // Status gradient (5-tier system from GDD)
  static const Color statusFlawless = Color(0xFF00CFFF);   // Neon Blue  95-100%
  static const Color statusOptimal = Color(0xFF39FF14);    // Neon Green  75-94%
  static const Color statusWarning = Color(0xFFFFE600);    // Neon Yellow 50-74%
  static const Color statusDegraded = Color(0xFFFF8C00);   // Neon Orange 25-49%
  static const Color statusCritical = Color(0xFFFF1F5B);   // Neon Pink/Red <25%

  // UI accent colors
  static const Color neonCyan = Color(0xFF00FFFF);         // selected tools
  static const Color neonGreen = Color(0xFF39FF14);        // healthy / positive
  static const Color neonYellow = Color(0xFFFFE600);       // warnings
  static const Color neonOrange = Color(0xFFFF8C00);       // energy / alerts
  static const Color neonPink = Color(0xFFFF1F5B);         // critical / danger
  static const Color neonPurple = Color(0xFFBF5FFF);       // exotic / tier 3
  static const Color neonGold = Color(0xFFFFD700);         // Solars / currency

  // Text
  static const Color textPrimary   = Color(0xFFEEEEEE);
  static const Color textSecondary = Color(0xFFBBBBBB);
  static const Color textMuted     = Color(0xFF888888);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Borders
  static const Color borderSubtle = Color(0xFF2A2A2A);
  static const Color borderDefault = Color(0xFF3A3A3A);
  static const Color borderActive = Color(0xFF00CFFF);

  // Tier colors for crops
  static const Color tier1 = Color(0xFF00CFFF);    // blue - basic
  static const Color tier2 = Color(0xFF39FF14);    // green - compost giants
  static const Color tier3 = Color(0xFFBF5FFF);    // purple - exotic
  static const Color tier4 = Color(0xFFFF8C00);    // orange - cyber-organic

  // Solars currency
  static const Color starScrip = Color(0xFFFFD700);
}

// ─── Text Styles ─────────────────────────────────────────────────────────────

class MFTextStyles {
  MFTextStyles._();

  static const String _fontFamily = 'monospace'; // retro terminal vibe

  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: MFColors.textPrimary,
    letterSpacing: 2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: MFColors.textPrimary,
    letterSpacing: 1.5,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: MFColors.textPrimary,
    letterSpacing: 1,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: MFColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    color: MFColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    color: MFColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    color: MFColors.textMuted,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: MFColors.textPrimary,
  );

  static const TextStyle currency = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: MFColors.starScrip,
    letterSpacing: 1,
  );

  static TextStyle statusText(double percent) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: MFStatusColor.forPercent(percent),
    );
  }
}

// ─── Status Color Helper ──────────────────────────────────────────────────────

class MFStatusColor {
  MFStatusColor._();

  static Color forPercent(double percent) {
    if (percent >= 0.95) return MFColors.statusFlawless;
    if (percent >= 0.75) return MFColors.statusOptimal;
    if (percent >= 0.50) return MFColors.statusWarning;
    if (percent >= 0.25) return MFColors.statusDegraded;
    return MFColors.statusCritical;
  }
}


// ─── App Theme ────────────────────────────────────────────────────────────────

class MFTheme {
  MFTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: MFColors.background,
      colorScheme: const ColorScheme.dark(
        primary: MFColors.neonCyan,
        secondary: MFColors.neonGreen,
        tertiary: MFColors.neonPurple,
        error: MFColors.neonPink,
        surface: MFColors.surface,
        onPrimary: MFColors.background,
        onSecondary: MFColors.background,
        onSurface: MFColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: MFColors.surface,
        foregroundColor: MFColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: MFTextStyles.headlineLarge,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: MFColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: MFColors.borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MFColors.neonCyan,
          foregroundColor: MFColors.background,
          textStyle: MFTextStyles.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MFColors.neonCyan,
          side: const BorderSide(color: MFColors.neonCyan, width: 1),
          textStyle: MFTextStyles.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MFColors.neonCyan,
          textStyle: MFTextStyles.bodyLarge,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: MFColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: MFColors.surfaceElevated,
        contentTextStyle: MFTextStyles.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          side: BorderSide(color: MFColors.borderDefault),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: MFColors.surface,
        selectedItemColor: MFColors.neonCyan,
        unselectedItemColor: MFColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        displayLarge: MFTextStyles.displayLarge,
        displayMedium: MFTextStyles.displayMedium,
        headlineLarge: MFTextStyles.headlineLarge,
        headlineMedium: MFTextStyles.headlineMedium,
        bodyLarge: MFTextStyles.bodyLarge,
        bodyMedium: MFTextStyles.bodyMedium,
        bodySmall: MFTextStyles.bodySmall,
        labelLarge: MFTextStyles.labelLarge,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: MFColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: MFColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: MFColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: MFColors.neonCyan, width: 1.5),
        ),
        labelStyle: MFTextStyles.bodyMedium,
        hintStyle: MFTextStyles.bodyMedium,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}