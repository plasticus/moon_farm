// ═══════════════════════════════════════════════════════════════
//  lib/theme/app_theme.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ─── Moon Farm Color Tokens ───────────────────────────────────────────────────
// Think of these like CSS variables. Change them here, they update everywhere.

class MFColors {
  MFColors._();

  // Flipped by Settings > Theme (see main.dart). Every token below resolves
  // through this flag at call time, so `MFColors.background` etc. keep
  // working unchanged from all ~30 call sites across the app — only this
  // file needed to change. The one cost: any `const` constructor that used
  // to close over these as compile-time constants no longer can, since a
  // runtime-switchable getter isn't a constant expression.
  static bool _isLight = false;
  static bool get isLight => _isLight;
  static void setMode({required bool isLight}) => _isLight = isLight;

  // Base backgrounds
  static Color get background => _isLight ? _lightBackground : _darkBackground;
  static Color get surface => _isLight ? _lightSurface : _darkSurface;
  static Color get surfaceElevated => _isLight ? _lightSurfaceElevated : _darkSurfaceElevated;
  static const _darkBackground = Color(0xFF0D0D0D);              // near-black base
  static const _darkSurface = Color(0xFF1A1A1A);                 // card / panel bg
  static const _darkSurfaceElevated = Color(0xFF222222);         // slightly raised
  static const _lightBackground = Color(0xFFE8E6E1);             // pale lunar regolith
  static const _lightSurface = Color(0xFFF3F1EC);                // card / panel bg
  static const _lightSurfaceElevated = Color(0xFFFCFAF6);        // near-white elevated

  // Status gradient (5-tier system from GDD)
  static Color get statusFlawless => _isLight ? _lightStatusFlawless : _darkStatusFlawless;
  static Color get statusOptimal => _isLight ? _lightStatusOptimal : _darkStatusOptimal;
  static Color get statusWarning => _isLight ? _lightStatusWarning : _darkStatusWarning;
  static Color get statusDegraded => _isLight ? _lightStatusDegraded : _darkStatusDegraded;
  static Color get statusCritical => _isLight ? _lightStatusCritical : _darkStatusCritical;
  static const _darkStatusFlawless = Color(0xFF00CFFF);   // Neon Blue  95-100%
  static const _darkStatusOptimal = Color(0xFF39FF14);    // Neon Green  75-94%
  static const _darkStatusWarning = Color(0xFFFFE600);    // Neon Yellow 50-74%
  static const _darkStatusDegraded = Color(0xFFFF8C00);   // Neon Orange 25-49%
  static const _darkStatusCritical = Color(0xFFFF1F5B);   // Neon Pink/Red <25%
  static const _lightStatusFlawless = Color(0xFF0077A3);
  static const _lightStatusOptimal = Color(0xFF1E8A0F);
  static const _lightStatusWarning = Color(0xFF9C7A00);
  static const _lightStatusDegraded = Color(0xFFB35900);
  static const _lightStatusCritical = Color(0xFFC4104A);

  // UI accent colors — light variants are deepened/desaturated twins of the
  // same hue, not a different palette, so the "neon tech" language survives
  // the trip from dark sky to lunar daylight.
  static Color get neonCyan => _isLight ? _lightNeonCyan : _darkNeonCyan;
  static Color get neonGreen => _isLight ? _lightNeonGreen : _darkNeonGreen;
  static Color get neonYellow => _isLight ? _lightNeonYellow : _darkNeonYellow;
  static Color get neonOrange => _isLight ? _lightNeonOrange : _darkNeonOrange;
  static Color get neonPink => _isLight ? _lightNeonPink : _darkNeonPink;
  static Color get neonPurple => _isLight ? _lightNeonPurple : _darkNeonPurple;
  static Color get neonGold => _isLight ? _lightNeonGold : _darkNeonGold;
  static const _darkNeonCyan = Color(0xFF00FFFF);         // selected tools
  static const _darkNeonGreen = Color(0xFF39FF14);        // healthy / positive
  static const _darkNeonYellow = Color(0xFFFFE600);       // warnings
  static const _darkNeonOrange = Color(0xFFFF8C00);       // energy / alerts
  static const _darkNeonPink = Color(0xFFFF1F5B);         // critical / danger
  static const _darkNeonPurple = Color(0xFFBF5FFF);       // exotic / tier 3
  static const _darkNeonGold = Color(0xFFFFD700);         // Solars / currency
  static const _lightNeonCyan = Color(0xFF0086A3);
  static const _lightNeonGreen = Color(0xFF1E8A0F);
  static const _lightNeonYellow = Color(0xFF9C7A00);
  static const _lightNeonOrange = Color(0xFFB35900);
  static const _lightNeonPink = Color(0xFFC4104A);
  static const _lightNeonPurple = Color(0xFF7A3FBF);
  static const _lightNeonGold = Color(0xFFAD8600);

  // Text
  static Color get textPrimary => _isLight ? _lightTextPrimary : _darkTextPrimary;
  static Color get textSecondary => _isLight ? _lightTextSecondary : _darkTextSecondary;
  static Color get textMuted => _isLight ? _lightTextMuted : _darkTextMuted;
  static Color get textOnDark => _isLight ? _lightTextOnDark : _darkTextOnDark;
  static const _darkTextPrimary   = Color(0xFFEEEEEE);
  static const _darkTextSecondary = Color(0xFFBBBBBB);
  static const _darkTextMuted     = Color(0xFF888888);
  static const _darkTextOnDark = Color(0xFFFFFFFF);
  static const _lightTextPrimary   = Color(0xFF1C1C1A); // deep graphite, not pure black
  static const _lightTextSecondary = Color(0xFF4A4842);
  static const _lightTextMuted     = Color(0xFF8A8880);
  // textOnDark is for text painted on top of solid neon-colored chips/buttons,
  // which stay dark-ish in both modes — same value regardless of theme.
  static const _lightTextOnDark = Color(0xFFFFFFFF);

  // Borders
  static Color get borderSubtle => _isLight ? _lightBorderSubtle : _darkBorderSubtle;
  static Color get borderDefault => _isLight ? _lightBorderDefault : _darkBorderDefault;
  static Color get borderActive => _isLight ? _lightBorderActive : _darkBorderActive;
  static const _darkBorderSubtle = Color(0xFF2A2A2A);
  static const _darkBorderDefault = Color(0xFF3A3A3A);
  static const _darkBorderActive = Color(0xFF00CFFF);
  static const _lightBorderSubtle = Color(0xFFD6D3CC);
  static const _lightBorderDefault = Color(0xFFB8B5AC);
  static const _lightBorderActive = Color(0xFF0077A3);

  // Tier colors for crops
  static Color get tier1 => _isLight ? _lightTier1 : _darkTier1;
  static Color get tier2 => _isLight ? _lightTier2 : _darkTier2;
  static Color get tier3 => _isLight ? _lightTier3 : _darkTier3;
  static Color get tier4 => _isLight ? _lightTier4 : _darkTier4;
  static Color get tier5 => _isLight ? _lightTier5 : _darkTier5;
  static const _darkTier1 = Color(0xFF00CFFF);    // blue - basic
  static const _darkTier2 = Color(0xFF39FF14);    // green - compost giants
  static const _darkTier3 = Color(0xFFBF5FFF);    // purple - exotic
  static const _darkTier4 = Color(0xFFFF8C00);    // orange - cyber-organic
  static const _darkTier5 = Color(0xFF00FFC8);    // teal - biolab / mycoculture
  static const _lightTier1 = Color(0xFF0077A3);
  static const _lightTier2 = Color(0xFF1E8A0F);
  static const _lightTier3 = Color(0xFF7A3FBF);
  static const _lightTier4 = Color(0xFFB35900);
  static const _lightTier5 = Color(0xFF00806B);

  // Solars currency
  static Color get starScrip => _isLight ? _lightStarScrip : _darkStarScrip;
  static const _darkStarScrip = Color(0xFFFFD700);
  static const _lightStarScrip = Color(0xFFAD8600);
}

// ─── Text Styles ─────────────────────────────────────────────────────────────

class MFTextStyles {
  MFTextStyles._();

  static const String _fontFamily = 'monospace'; // retro terminal vibe

  // These used to be `static const TextStyle` — now getters, since they
  // close over MFColors values that are no longer compile-time constants
  // (see MFColors._isLight). Same names, same call sites, just resolved
  // at call time instead of baked in.
  static TextStyle get displayLarge => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: MFColors.textPrimary,
    letterSpacing: 2,
  );

  static TextStyle get displayMedium => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: MFColors.textPrimary,
    letterSpacing: 1.5,
  );

  static TextStyle get headlineLarge => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: MFColors.textPrimary,
    letterSpacing: 1,
  );

  static TextStyle get headlineMedium => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: MFColors.textPrimary,
  );

  static TextStyle get bodyLarge => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    color: MFColors.textPrimary,
  );

  static TextStyle get bodyMedium => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    color: MFColors.textSecondary,
  );

  static TextStyle get bodySmall => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    color: MFColors.textMuted,
  );

  static TextStyle get labelLarge => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: MFColors.textPrimary,
  );

  static TextStyle get currency => TextStyle(
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

  /// Builds ThemeData from the current MFColors tokens — light or dark,
  /// whichever MFColors.setMode() last set. Kept as a single getter (not
  /// separate dark/light copies) since MFColors already resolves per-token;
  /// re-evaluating this after the mode flips gets the right theme for free.
  static ThemeData get current {
    final brightness = MFColors.isLight ? Brightness.light : Brightness.dark;
    final baseScheme = MFColors.isLight ? const ColorScheme.light() : const ColorScheme.dark();
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: MFColors.background,
      colorScheme: baseScheme.copyWith(
        primary: MFColors.neonCyan,
        secondary: MFColors.neonGreen,
        tertiary: MFColors.neonPurple,
        error: MFColors.neonPink,
        surface: MFColors.surface,
        onPrimary: MFColors.background,
        onSecondary: MFColors.background,
        onSurface: MFColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: MFColors.surface,
        foregroundColor: MFColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: MFTextStyles.headlineLarge,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: MFColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
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
          side: BorderSide(color: MFColors.neonCyan, width: 1),
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
      dividerTheme: DividerThemeData(
        color: MFColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MFColors.surfaceElevated,
        contentTextStyle: MFTextStyles.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          side: BorderSide(color: MFColors.borderDefault),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: MFColors.surface,
        selectedItemColor: MFColors.neonCyan,
        unselectedItemColor: MFColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      textTheme: TextTheme(
        displayLarge: MFTextStyles.displayLarge,
        displayMedium: MFTextStyles.displayMedium,
        headlineLarge: MFTextStyles.headlineLarge,
        headlineMedium: MFTextStyles.headlineMedium,
        bodyLarge: MFTextStyles.bodyLarge,
        bodyMedium: MFTextStyles.bodyMedium,
        bodySmall: MFTextStyles.bodySmall,
        labelLarge: MFTextStyles.labelLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MFColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: MFColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: MFColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: MFColors.neonCyan, width: 1.5),
        ),
        labelStyle: MFTextStyles.bodyMedium,
        hintStyle: MFTextStyles.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}