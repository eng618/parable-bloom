import 'package:flutter/material.dart';

/// Centralized theme configuration for Parable Bloom.
/// All colors, themes, and visual styling can be configured here.
class AppTheme {
  // ============================================================
  // BRAND COLORS - Core identity colors inspired by the braided bracelet
  // ============================================================

  /// Primary brand color (Blue from bracelet)
  static const Color primarySeed = Color(0xFF3A7DAF);

  /// Secondary accent color (Green from bracelet)
  static const Color secondarySeed = Color(0xFF4F8A5B);

  /// Tertiary neutral color (Beige from bracelet)
  static const Color tertiarySeed = Color(0xFFE2D6C4);

  // ============================================================
  // GAME COLORS - Colors used in the game itself
  // ============================================================

  /// Color for active/unblocked vines (uses secondary for bracelet tie-in)
  static const Color vineGreen = secondarySeed;

  /// Color for attempted/failed vines
  static const Color vineAttempted = Colors.red;

  /// Grid dot color (light mode) - subtle beige tint
  static const Color gridDotLight = Color(0x26E2D6C4); // 15% beige

  /// Grid dot color (dark mode) - subtle beige tint
  static const Color gridDotDark = Color(0x26E2D6C4); // 15% beige

  /// Tap effect color (light mode) - darker for contrast on light background
  static const Color tapEffectLight = Color(0xFF1C1B1F); // Dark gray

  /// Tap effect color (dark mode) - lighter for contrast on dark background
  static const Color tapEffectDark = Color(0xFFE6E1E5); // Light gray

  // ============================================================
  // LIGHT THEME COLORS - Beige-dominant for warmth
  // ============================================================

  static const _lightBackground = Color(0xFFF8F5EF); // Lightened beige
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceContainer = Color(0xFFEFF3ED); // Subtle green tint
  static const _lightOnSurface = Color(0xFF1C1B1F);
  static const _lightOnSurfaceVariant = Color(0xFF49454F);

  // ============================================================
  // DARK THEME COLORS - Blue-green mix for depth
  // ============================================================

  static const _darkBackground = Color(0xFF1A2E3F); // Dark blue
  static const _darkSurface = Color(0xFF2C3E50); // Deeper blue
  static const _darkSurfaceContainer = Color(
    0xFF3E5366,
  ); // Blue with green hint
  static const _darkOnSurface = Color(0xFFE6E1E5);
  static const _darkOnSurfaceVariant = Color(0xFFCAC4D0);

  // ============================================================
  // THEME DATA
  // ============================================================

  /// Light theme for the app
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.light,
      surface: _lightSurface,
      onSurface: _lightOnSurface,
      onSurfaceVariant: _lightOnSurfaceVariant,
    ).copyWith(
      secondary: secondarySeed,
      tertiary: tertiarySeed,
      surfaceContainerLow: _lightSurfaceContainer,
      surfaceContainerHighest: _lightSurfaceContainer,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: _lightSurfaceContainer,
        foregroundColor: _lightOnSurface,
      ),
    );
  }

  /// Dark theme for the app
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.dark,
      surface: _darkSurface,
      onSurface: _darkOnSurface,
      onSurfaceVariant: _darkOnSurfaceVariant,
    ).copyWith(
      secondary: secondarySeed,
      tertiary: tertiarySeed,
      surfaceContainerLow: _darkSurfaceContainer,
      surfaceContainerHighest: _darkSurfaceContainer,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: _darkSurfaceContainer,
        foregroundColor: _darkOnSurface,
      ),
    );
  }

  // ============================================================
  // GAME THEME COLORS - For the Flame game engine
  // ============================================================

  /// Get game background color based on brightness
  static Color getGameBackground(Brightness brightness) {
    return brightness == Brightness.dark ? _darkBackground : _lightBackground;
  }

  /// Get game surface color based on brightness
  static Color getGameSurface(Brightness brightness) {
    return brightness == Brightness.dark ? _darkSurface : _lightSurface;
  }

  /// Get grid background color based on brightness
  static Color getGridBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? _darkSurfaceContainer
        : _lightSurfaceContainer;
  }

  /// Get tap effect color based on brightness
  static Color getTapEffectColor(Brightness brightness) {
    return brightness == Brightness.dark ? tapEffectDark : tapEffectLight;
  }
}
