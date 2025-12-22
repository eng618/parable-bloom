import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/providers/game_providers.dart';

void main() {
  test('Validate all levels for vine overlaps and solvability', () async {
    final levelsDir = Directory('assets/levels');
    if (!levelsDir.existsSync()) {
      fail('assets/levels directory not found');
    }

    final files = levelsDir.listSync().where((e) => e.path.endsWith('.json'));

    for (final entity in files) {
      if (entity is File) {
        final content = await entity.readAsString();
        final jsonMap = json.decode(content);
        final level = LevelData.fromJson(jsonMap);

        // 1. Check for overlaps
        final occupiedCells = <String>{};
        for (final vine in level.vines) {
          for (final cell in vine.path) {
            final row = cell['row'];
            final col = cell['col'];
            final key = '$row,$col';

            if (occupiedCells.contains(key)) {
              fail(
                'Vine overlap detected in ${entity.path} at cell ($row, $col). Multiple vines occupy this cell.',
              );
            }
            occupiedCells.add(key);
          }
        }

        // 2. Check for path rules
        for (final vine in level.vines) {
          // Rule: Min length of 2
          expect(
            vine.path.length,
            greaterThanOrEqualTo(2),
            reason: 'Vine ${vine.id} in ${entity.path} has length < 2',
          );

          // Rule: Straight head segment (no diagonals)
          final head = vine.path.last;
          final neck = vine.path[vine.path.length - 2];
          final dRow = (head['row'] as int) - (neck['row'] as int);
          final dCol = (head['col'] as int) - (neck['col'] as int);

          final isStraight =
              (dRow.abs() == 1 && dCol == 0) || (dRow == 0 && dCol.abs() == 1);
          expect(
            isStraight,
            isTrue,
            reason:
                'Vine ${vine.id} in ${entity.path} has a non-straight head segment: delta ($dRow, $dCol)',
          );
        }

        // 3. Check for solvability
        final solution = LevelSolver.solve(level);
        expect(
          solution,
          isNotNull,
          reason: 'Level ${entity.path} is unsolvable!',
        );
        print('Level ${level.levelId} is solvable. Solution: $solution');
      }
    }
  });
}
