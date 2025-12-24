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

    // Find all module directories
    final moduleDirs = levelsDir.listSync().whereType<Directory>().where(
      (dir) => dir.path.contains('module_'),
    );

    for (final moduleDir in moduleDirs) {
      final files = moduleDir.listSync().where((e) => e.path.endsWith('.json'));

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

            // Rule: Head direction matches last segment direction
            final head = vine.path.last;
            final neck = vine.path[vine.path.length - 2];
            final dRow = (head['row'] as int) - (neck['row'] as int);
            final dCol = (head['col'] as int) - (neck['col'] as int);

            String expectedDirection;
            if (dRow == 1 && dCol == 0)
              expectedDirection = 'down';
            else if (dRow == -1 && dCol == 0)
              expectedDirection = 'up';
            else if (dRow == 0 && dCol == 1)
              expectedDirection = 'right';
            else if (dRow == 0 && dCol == -1)
              expectedDirection = 'left';
            else {
              fail(
                'Invalid direction delta ($dRow, $dCol) for vine ${vine.id}',
              );
              continue;
            }

            expect(
              vine.headDirection,
              equals(expectedDirection),
              reason:
                  'Vine ${vine.id} head direction ${vine.headDirection} does not match path direction $expectedDirection',
            );

            // Rule: Consecutive segments have valid turns (90 degrees only)
            for (int i = 0; i < vine.path.length - 2; i++) {
              final current = vine.path[i];
              final next = vine.path[i + 1];
              final after = vine.path[i + 2];

              final dRow1 = (next['row'] as int) - (current['row'] as int);
              final dCol1 = (next['col'] as int) - (current['col'] as int);
              final dRow2 = (after['row'] as int) - (next['row'] as int);
              final dCol2 = (after['col'] as int) - (next['col'] as int);

              final isValidTurn =
                  (dRow1 == 0 && dCol1 != 0 && dRow2 != 0 && dCol2 == 0) ||
                  (dRow1 != 0 && dCol1 == 0 && dRow2 == 0 && dCol2 != 0);
              expect(
                isValidTurn,
                isTrue,
                reason: 'Vine ${vine.id} has invalid turn at segment ${i + 1}',
              );
            }
          }

          // 3. Check for solvability
          final solution = LevelSolver.solve(level);
          expect(
            solution,
            isNotNull,
            reason: 'Level ${entity.path} is unsolvable!',
          );
          print(
            'Level ${level.id} (Module ${level.moduleId}) is solvable. Solution: $solution',
          );
        }
      }
    }
  });
}
