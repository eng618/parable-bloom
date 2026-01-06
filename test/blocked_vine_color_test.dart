import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/core/vine_color_palette.dart';
import 'package:parable_bloom/core/app_theme.dart';

void main() {
  test('Blocked colors are reserved and not present in vine palette', () {
    final paletteValues = VineColorPalette.colors.values.toSet();

    expect(
      paletteValues.contains(AppTheme.vineAttemptedLight),
      isFalse,
      reason: 'vineAttemptedLight must not be part of the vine palette',
    );

    expect(
      paletteValues.contains(AppTheme.vineAttemptedDark),
      isFalse,
      reason: 'vineAttemptedDark must not be part of the vine palette',
    );
  });

  test('No level defines a vine color that resolves to a blocked color',
      () async {
    final levelsDir = Directory('assets/levels');
    if (!levelsDir.existsSync()) {
      fail('assets/levels directory not found');
    }

    final levelFiles = levelsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('level_') && f.path.endsWith('.json'))
        .toList();

    for (final file in levelFiles) {
      final jsonMap = json.decode(await file.readAsString());
      final vines = (jsonMap['vines'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      for (final vine in vines) {
        final key = (vine['vine_color'] as String?)?.trim();
        final resolved = VineColorPalette.resolve(key);

        expect(
          resolved != AppTheme.vineAttemptedLight,
          isTrue,
          reason:
              'Level ${file.path} contains a vine that resolves to vineAttemptedLight',
        );

        expect(
          resolved != AppTheme.vineAttemptedDark,
          isTrue,
          reason:
              'Level ${file.path} contains a vine that resolves to vineAttemptedDark',
        );
      }
    }
  }, tags: ['colors']);
}
