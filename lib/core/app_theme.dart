import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'dart:math';

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
  // SEMANTIC COLORS - For game states and UI feedback
  // ============================================================

  /// Success color (derived from secondary green)
  static const Color successColor = secondarySeed;

  /// Error color (standard red for consistency)
  static const Color errorColor = Color(0xFFD32F2F);

  // ============================================================
  // GAME COLORS - Colors used in the game itself
  // ============================================================

  /// Color for active/unblocked vines (uses secondary for bracelet tie-in)
  static const Color vineGreen = secondarySeed;

  /// Theme-aware color for attempted/failed vines.
  /// On light theme this is black; on dark theme this is white. Use
  /// `AppTheme.getVineAttemptedColor(brightness)` to pick the correct variant.
  static const Color vineAttemptedLight =
      Color(0xFF000000); // black for light theme
  static const Color vineAttemptedDark =
      Color(0xFFFFFFFF); // white for dark theme

  static Color getVineAttemptedColor(Brightness brightness) {
    return brightness == Brightness.dark
        ? vineAttemptedDark
        : vineAttemptedLight;
  }

  /// Grid dot color (light mode) - subtle beige tint
  static const Color gridDotLight = Color(0x26E2D6C4); // 15% beige

  /// Grid dot color (dark mode) - subtle blue tint for harmony
  static const Color gridDotDark = Color(0x263A7DAF); // 15% primary blue

  /// Get grid dot color based on brightness
  static Color getGridDotColor(Brightness brightness) {
    return brightness == Brightness.dark ? gridDotDark : gridDotLight;
  }

  /// Tap effect color (light mode) - darker for contrast on light background
  static const Color tapEffectLight = Color(0xFF1C1B1F); // Dark gray

  /// Tap effect color (dark mode) - lighter for contrast on dark background
  static const Color tapEffectDark = Color(0xFFE6E1E5); // Light gray

  // ============================================================
  // LIGHT THEME COLORS - Beige-dominant for warmth
  // ============================================================

  static const _lightBackground = Color(0xFFF8F5EF); // Lightened beige
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceContainerLow =
      Color(0xFFEFF3ED); // Subtle green tint
  static const _lightSurfaceContainerHigh =
      Color(0xFFE8E4DE); // Darker beige for depth
  static const _lightOnSurface = Color(0xFF1C1B1F);
  static const _lightOnSurfaceVariant = Color(0xFF49454F);

  // ============================================================
  // DARK THEME COLORS - Blue-green mix for depth
  // ============================================================

  static const _darkBackground = Color(0xFF1A2E3F); // Dark blue
  static const _darkSurface = Color(0xFF2C3E50); // Deeper blue
  static const _darkSurfaceContainerLow =
      Color(0xFF3E5366); // Blue with green hint
  static const _darkSurfaceContainerHigh =
      Color(0xFF4A5F72); // Deeper blue-green for depth
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
      surfaceContainerLow: _lightSurfaceContainerLow,
      surfaceContainerHighest: _lightSurfaceContainerHigh,
      outlineVariant: tertiarySeed, // Tertiary for subtle outlines
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surfaceContainer,
        foregroundColor: _lightOnSurface,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: _lightOnSurface),
        bodyLarge: TextStyle(color: _lightOnSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      extensions: [
        AppThemeExtension(
          vineGreen: AppTheme.vineGreen,
          vineAttempted: AppTheme.vineAttemptedLight,
          gridDot: AppTheme.gridDotLight,
          tapEffect: AppTheme.tapEffectLight,
        ),
      ],
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
      surfaceContainerLow: _darkSurfaceContainerLow,
      surfaceContainerHighest: _darkSurfaceContainerHigh,
      outlineVariant: tertiarySeed, // Tertiary for subtle outlines
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surfaceContainer,
        foregroundColor: _darkOnSurface,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: _darkOnSurface),
        bodyLarge: TextStyle(color: _darkOnSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      extensions: [
        AppThemeExtension(
          vineGreen: AppTheme.vineGreen,
          vineAttempted: AppTheme.vineAttemptedDark,
          gridDot: AppTheme.gridDotDark,
          tapEffect: AppTheme.tapEffectDark,
        ),
      ],
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
        ? _darkSurfaceContainerLow
        : _lightSurfaceContainerLow;
  }

  /// Get tap effect color based on brightness
  static Color getTapEffectColor(Brightness brightness) {
    return brightness == Brightness.dark ? tapEffectDark : tapEffectLight;
  }

  /// Calculate contrast ratio between two colors (WCAG AA compliance helper)
  /// Returns ratio >= 4.5 for normal text, >= 3.0 for large text
  static double getContrastRatio(Color foreground, Color background) {
    double luminance(Color color) {
      final r = color.r / 255.0;
      final g = color.g / 255.0;
      final b = color.b / 255.0;
      final rsRGB = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4);
      final gsRGB = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4);
      final bsRGB = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4);
      return 0.2126 * rsRGB + 0.7152 * gsRGB + 0.0722 * bsRGB;
    }

    final lum1 = luminance(foreground) + 0.05;
    final lum2 = luminance(background) + 0.05;
    return lum1 > lum2 ? lum1 / lum2 : lum2 / lum1;
  }

  /// Create dynamic color scheme for Android 12+ based on system wallpaper
  static Future<ColorScheme?> getDynamicColorScheme(
      Brightness brightness) async {
    try {
      final corePalette = await DynamicColorPlugin.getCorePalette();
      if (corePalette != null) {
        return corePalette.toColorScheme(brightness: brightness);
      }
    } catch (e) {
      // Fallback to default if dynamic color fails
    }
    return null; // Return null to use default theme
  }
}

/// Extension for game-specific theme properties
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.vineGreen,
    required this.vineAttempted,
    required this.gridDot,
    required this.tapEffect,
  });

  final Color vineGreen;
  final Color vineAttempted;
  final Color gridDot;
  final Color tapEffect;

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    Color? vineGreen,
    Color? vineAttempted,
    Color? gridDot,
    Color? tapEffect,
  }) {
    return AppThemeExtension(
      vineGreen: vineGreen ?? this.vineGreen,
      vineAttempted: vineAttempted ?? this.vineAttempted,
      gridDot: gridDot ?? this.gridDot,
      tapEffect: tapEffect ?? this.tapEffect,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      vineGreen: Color.lerp(vineGreen, other.vineGreen, t)!,
      vineAttempted: Color.lerp(vineAttempted, other.vineAttempted, t)!,
      gridDot: Color.lerp(gridDot, other.gridDot, t)!,
      tapEffect: Color.lerp(tapEffect, other.tapEffect, t)!,
    );
  }
}
