import 'package:flutter/material.dart';

/// Centralized theme configuration for Parable Bloom.
/// All colors, themes, and visual styling can be configured here.
class AppTheme {
  // ============================================================
  // BRAND COLORS - Core identity colors
  // ============================================================

  /// Primary brand color (Vine Green)
  static const Color primarySeed = Color(0xFF4A7C59);

  /// Secondary accent color
  static const Color secondarySeed = Color(0xFF6B8E23);

  // ============================================================
  // GAME COLORS - Colors used in the game itself
  // ============================================================

  /// Color for active/unblocked vines
  static const Color vineGreen = Color(0xFF8FBC8F);

  /// Color for attempted/failed vines
  static const Color vineAttempted = Colors.red;

  /// Grid dot color (light mode)
  static const Color gridDotLight = Color(0x26FFFFFF); // 15% white

  /// Grid dot color (dark mode)
  static const Color gridDotDark = Color(0x26FFFFFF); // 15% white

  // ============================================================
  // LIGHT THEME COLORS
  // ============================================================

  static const _lightBackground = Color(0xFFF5F5F0);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceContainer = Color(0xFFF0F0E8);
  static const _lightOnSurface = Color(0xFF1C1B1F);
  static const _lightOnSurfaceVariant = Color(0xFF49454F);

  // ============================================================
  // DARK THEME COLORS
  // ============================================================

  static const _darkBackground = Color(0xFF1E3528);
  static const _darkSurface = Color(0xFF2D4A3A);
  static const _darkSurfaceContainer = Color(0xFF3D5A4A);
  static const _darkOnSurface = Color(0xFFE6E1E5);
  static const _darkOnSurfaceVariant = Color(0xFFCAC4D0);

  // ============================================================
  // THEME DATA
  // ============================================================

  /// Light theme for the app
  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primarySeed,
          brightness: Brightness.light,
          surface: _lightSurface,
          onSurface: _lightOnSurface,
          onSurfaceVariant: _lightOnSurfaceVariant,
        ).copyWith(
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
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primarySeed,
          brightness: Brightness.dark,
          surface: _darkSurface,
          onSurface: _darkOnSurface,
          onSurfaceVariant: _darkOnSurfaceVariant,
        ).copyWith(
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
}
