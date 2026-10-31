import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/core/app_theme.dart';

void main() {
  group('AppTheme.getContrastRatio Tests', () {
    test('Pure White vs. Pure Black should have maximum contrast (21.0)', () {
      final white = Colors.white; // 0xFFFFFFFF
      final black = Colors.black; // 0xFF000000

      final contrast = AppTheme.getContrastRatio(white, black);
      expect(contrast, closeTo(21.0, 0.01));
    });

    test('Same colors should have minimum contrast (1.0)', () {
      final white = Colors.white;
      final black = Colors.black;
      final customColor = const Color(0xFF344D2F);

      expect(AppTheme.getContrastRatio(white, white), closeTo(1.0, 0.01));
      expect(AppTheme.getContrastRatio(black, black), closeTo(1.0, 0.01));
      expect(AppTheme.getContrastRatio(customColor, customColor),
          closeTo(1.0, 0.01));
    });

    test('getContrastRatio is commutative', () {
      final primary = const Color(0xFF344D2F);
      final background = const Color(0xFFF9F3E5);

      final ratio1 = AppTheme.getContrastRatio(primary, background);
      final ratio2 = AppTheme.getContrastRatio(background, primary);

      expect(ratio1, equals(ratio2));
    });

    test('Colors below/above linearization threshold are calculated correctly',
        () {
      // Linearization condition: c / 255.0 <= 0.03928
      // Threshold in 255 range: 0.03928 * 255.0 = 10.0164
      // So color channel values <= 10 use standard linearization: (c/255.0) / 12.92
      // Values >= 11 use non-linear formula: pow(((c/255.0) + 0.055) / 1.055, 2.4)

      const veryDarkGray = Color(0xFF090909); // Red, Green, Blue are 9 (<= 10)
      const slightlyLighterGray =
          Color(0xFF0B0B0B); // Red, Green, Blue are 11 (>= 11)

      // Both should work and should result in slightly different contrast against white
      final white = Colors.white;

      final ratioDark = AppTheme.getContrastRatio(veryDarkGray, white);
      final ratioLighter =
          AppTheme.getContrastRatio(slightlyLighterGray, white);

      // We expect dark grey to have slightly higher contrast ratio against white than slightly lighter grey
      expect(ratioDark, greaterThan(ratioLighter));
    });

    test(
        'Calculates expected contrast ratios for known WCAG compliancy thresholds',
        () {
      // Verify contrast ratio of specific palette colors
      final primary = const Color(0xFF344D2F); // Forest primary
      final lightBg = const Color(0xFFF9F3E5); // Garden cream background

      final ratio = AppTheme.getContrastRatio(primary, lightBg);

      // Forest on cream should clear WCAG AA for normal text (>= 4.5)
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('Dark moss primary contrasts with night soil background', () {
      final moss = const Color(0xFFA3B18A);
      final nightSoil = const Color(0xFF141914);
      final ratio = AppTheme.getContrastRatio(moss, nightSoil);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });
  });

  group('AppTheme garden palette', () {
    test('light and dark themes expose garden primary seeds', () {
      expect(AppTheme.primarySeed, const Color(0xFF344D2F));
      expect(AppTheme.primarySeedDark, const Color(0xFFA3B18A));
      expect(AppTheme.lightTheme.colorScheme.primary, AppTheme.primarySeed);
      expect(AppTheme.darkTheme.colorScheme.primary, AppTheme.primarySeedDark);
      expect(
        AppTheme.lightTheme.scaffoldBackgroundColor,
        const Color(0xFFF9F3E5),
      );
      expect(
        AppTheme.darkTheme.scaffoldBackgroundColor,
        const Color(0xFF141914),
      );
    });
  });
}
