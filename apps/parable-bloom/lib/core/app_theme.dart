import 'package:flutter/material.dart';
import 'dart:math';

/// Centralized theme configuration for Parable Bloom.
///
/// Visual refresh palette (garden parchment + forest / moonlit soil) is
/// documented in the project store at `docs/visual-refresh-palette.md` and
/// mirrored in `documentation/reference/color-usage.md`.
class AppTheme {
  // ============================================================
  // BRAND COLORS - Garden identity (habit-loop visual refresh)
  // ============================================================

  /// Primary brand color (deep forest green — light seed / titles / CTAs)
  static const Color primarySeed = Color(0xFF344D2F);

  /// Secondary accent color (muted sage)
  static const Color secondarySeed = Color(0xFF8DA082);

  /// Tertiary warm neutral (parchment beige)
  static const Color tertiarySeed = Color(0xFFE2D6C4);

  /// Primary brand color on dark surfaces (moonlit moss)
  static const Color primarySeedDark = Color(0xFFA3B18A);

  /// Rare floral highlight for ornaments (not a ColorScheme role)
  static const Color daisyAccent = Color(0xFFE9C46A);

  // ============================================================
  // SEMANTIC COLORS - For game states and UI feedback
  // ============================================================

  /// Success color (sage / garden growth)
  static const Color successColor = secondarySeed;

  /// Error color (Material-aligned red for consistency)
  static const Color errorColor = Color(0xFFB3261E);

  // ============================================================
  // GAME COLORS - Colors used in the game itself
  // ============================================================

  /// Color for active/unblocked vines (sage accent)
  static const Color vineGreen = secondarySeed;

  /// Reserved attempted/blocked vine color (light) — soft slate, not in palette
  static const Color vineAttemptedLight = Color(0xFF4A5560);

  /// Reserved attempted/blocked vine color (dark) — soft cream
  static const Color vineAttemptedDark = Color(0xFFE8EADF);

  static Color getVineAttemptedColor(Brightness brightness) {
    return brightness == Brightness.dark
        ? vineAttemptedDark
        : vineAttemptedLight;
  }

  /// Grid dot color (light mode) - subtle parchment tint
  static const Color gridDotLight = Color(0x26E2D6C4); // 15% beige

  /// Grid dot color (dark mode) - subtle moss tint
  static const Color gridDotDark = Color(0x26A3B18A); // 15% moss

  /// Get grid dot color based on brightness
  static Color getGridDotColor(Brightness brightness) {
    return brightness == Brightness.dark ? gridDotDark : gridDotLight;
  }

  /// Tap effect color (light mode) - muted ink
  static const Color tapEffectLight = Color(0xFF5A6258);

  /// Tap effect color (dark mode) - soft mist
  static const Color tapEffectDark = Color(0xFFE8EADF);

  // ============================================================
  // LIGHT THEME COLORS - Warm parchment garden
  // ============================================================

  static const _lightBackground = Color(0xFFF9F3E5); // gardenCream
  static const _lightSurface = Color(0xFFFFFBF3); // gardenSurface
  static const _lightSurfaceContainerLow =
      Color(0xFFF1EBDD); // gardenSurfaceLow
  static const _lightSurfaceContainerHigh =
      Color(0xFFE8E0CE); // gardenSurfaceHigh
  static const _lightOnSurface = Color(0xFF2A3328); // inkOnSurface
  static const _lightOnSurfaceVariant = Color(0xFF5A6258); // inkMuted

  // ============================================================
  // DARK THEME COLORS - Moonlit garden soil
  // ============================================================

  static const _darkBackground = Color(0xFF141914); // nightSoil
  static const _darkSurface = Color(0xFF1E241E); // nightSurface
  static const _darkSurfaceContainerLow = Color(0xFF2A312A); // nightSurfaceLow
  static const _darkSurfaceContainerHigh =
      Color(0xFF353D35); // nightSurfaceHigh
  static const _darkOnSurface = Color(0xFFE8EADF); // mistOnSurface
  static const _darkOnSurfaceVariant = Color(0xFFA8AFA6); // mistMuted

  // ============================================================
  // THEME DATA
  // ============================================================

  /// Bundled serif for brand / display moments (Liberation Serif).
  static const String displayFontFamily = 'ParableDisplay';
  static const List<String> displayFontFallback = ['Georgia', 'serif', 'Serif'];

  /// Shared display (serif) text theme tones for brand moments.
  static TextTheme _displayAwareTextTheme(
    TextTheme base,
    Color onSurface,
  ) {
    TextStyle serif(TextStyle? style) => (style ?? const TextStyle()).copyWith(
          fontFamily: displayFontFamily,
          fontFamilyFallback: displayFontFallback,
          color: onSurface,
        );

    return base.copyWith(
      displayLarge: serif(base.displayLarge),
      displayMedium: serif(base.displayMedium),
      displaySmall: serif(base.displaySmall),
      headlineLarge: serif(base.headlineLarge),
      headlineMedium: serif(base.headlineMedium),
      headlineSmall: serif(base.headlineSmall),
      titleLarge: serif(base.titleLarge),
      bodyLarge:
          (base.bodyLarge ?? const TextStyle()).copyWith(color: onSurface),
      bodyMedium:
          (base.bodyMedium ?? const TextStyle()).copyWith(color: onSurface),
    );
  }

  /// Light theme for the app
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.light,
      primary: primarySeed,
      onPrimary: _lightSurface,
      secondary: secondarySeed,
      tertiary: tertiarySeed,
      surface: _lightSurface,
      onSurface: _lightOnSurface,
      onSurfaceVariant: _lightOnSurfaceVariant,
      error: errorColor,
    ).copyWith(
      surfaceContainerLow: _lightSurfaceContainerLow,
      surfaceContainerHighest: _lightSurfaceContainerHigh,
      outline: primarySeed.withValues(alpha: 0.55),
      outlineVariant: tertiarySeed,
    );

    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _lightBackground,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surfaceContainerLow,
        foregroundColor: _lightOnSurface,
      ),
      textTheme: _displayAwareTextTheme(base.textTheme, _lightOnSurface),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
      seedColor: primarySeedDark,
      brightness: Brightness.dark,
      primary: primarySeedDark,
      onPrimary: _darkBackground,
      secondary: secondarySeed,
      tertiary: const Color(0xFFC9C2B2),
      surface: _darkSurface,
      onSurface: _darkOnSurface,
      onSurfaceVariant: _darkOnSurfaceVariant,
      error: const Color(0xFFF2B8B5),
    ).copyWith(
      surfaceContainerLow: _darkSurfaceContainerLow,
      surfaceContainerHighest: _darkSurfaceContainerHigh,
      outline: primarySeedDark.withValues(alpha: 0.45),
      outlineVariant: const Color(0xFFC9C2B2),
    );

    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _darkBackground,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surfaceContainerLow,
        foregroundColor: _darkOnSurface,
      ),
      textTheme: _displayAwareTextTheme(base.textTheme, _darkOnSurface),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
      final r = color.r;
      final g = color.g;
      final b = color.b;
      final rsRGB = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4);
      final gsRGB = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4);
      final bsRGB = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4);
      return 0.2126 * rsRGB + 0.7152 * gsRGB + 0.0722 * bsRGB;
    }

    final lum1 = luminance(foreground) + 0.05;
    final lum2 = luminance(background) + 0.05;
    return lum1 > lum2 ? lum1 / lum2 : lum2 / lum1;
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
