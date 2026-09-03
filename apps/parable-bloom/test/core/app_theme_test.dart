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
      final customColor = const Color(0xFF3A7DAF);

      expect(AppTheme.getContrastRatio(white, white), closeTo(1.0, 0.01));
      expect(AppTheme.getContrastRatio(black, black), closeTo(1.0, 0.01));
      expect(AppTheme.getContrastRatio(customColor, customColor),
          closeTo(1.0, 0.01));
    });

    test('getContrastRatio is commutative', () {
      final primary = const Color(0xFF3A7DAF);
      final background = const Color(0xFFF8F5EF);

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
      final primary = const Color(0xFF3A7DAF); // Brand primary blue
      final lightBg = const Color(0xFFF8F5EF); // Lightened beige background

      final ratio = AppTheme.getContrastRatio(primary, lightBg);

      // Known contrast ratio for #3A7DAF vs #F8F5EF is approx 4.08
      expect(ratio, closeTo(4.08, 0.05));
    });
  });
}
