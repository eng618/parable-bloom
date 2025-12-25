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

          // 1. Check for NO overlaps - each plot can only have ONE vine segment or head
          final occupiedCells = <String, String>{}; // cell -> vineId
          for (final vine in level.vines) {
            for (final cell in vine.orderedPath) {
              final x = cell['x'] as int;
              final y = cell['y'] as int;
              final key = '$x,$y';

              if (occupiedCells.containsKey(key)) {
                final existingVineId = occupiedCells[key]!;
                fail(
                  'Multiple vine segments detected in ${entity.path} at cell ($x, $y): vine ${existingVineId} and vine ${vine.id}. Each plot can only contain ONE vine segment or head.',
                );
              }
              occupiedCells[key] = vine.id;
            }
          }

          // 2. Check for path rules
          for (final vine in level.vines) {
            // Rule: Min length of 2
            expect(
              vine.orderedPath.length,
              greaterThanOrEqualTo(2),
              reason: 'Vine ${vine.id} in ${entity.path} has length < 2',
            );

            // Rule: Validate snake positioning - first segment opposite to movement direction
            final head = vine.orderedPath[0];
            final firstBody = vine.orderedPath[1];
            final dx = (firstBody['x'] as int) - (head['x'] as int);
            final dy = (firstBody['y'] as int) - (head['y'] as int);

            // Check that first segment is positioned opposite to movement direction
            bool hasCorrectSnakePositioning;
            String expectedPositionDescription;
            switch (vine.headDirection) {
              case 'right':
                hasCorrectSnakePositioning =
                    dx == -1 && dy == 0; // First segment LEFT of head
                expectedPositionDescription =
                    'first segment should be LEFT of head (x decreases)';
                break;
              case 'left':
                hasCorrectSnakePositioning =
                    dx == 1 && dy == 0; // First segment RIGHT of head
                expectedPositionDescription =
                    'first segment should be RIGHT of head (x increases)';
                break;
              case 'up':
                hasCorrectSnakePositioning =
                    dx == 0 && dy == -1; // First segment DOWN from head
                expectedPositionDescription =
                    'first segment should be DOWN from head (y decreases)';
                break;
              case 'down':
                hasCorrectSnakePositioning =
                    dx == 0 && dy == 1; // First segment UP from head
                expectedPositionDescription =
                    'first segment should be UP from head (y increases)';
                break;
              default:
                hasCorrectSnakePositioning = false;
                expectedPositionDescription = 'unknown direction';
            }

            expect(
              hasCorrectSnakePositioning,
              isTrue,
              reason:
                  'Vine ${vine.id} head at (${head['x']},${head['y']}) moving ${vine.headDirection} - $expectedPositionDescription, but first segment is at (${firstBody['x']},${firstBody['y']})',
            );

            // Rule: Validate all segments are adjacent (orthogonal movement only)
            for (int i = 1; i < vine.orderedPath.length; i++) {
              final prevSegment = vine.orderedPath[i - 1];
              final currentSegment = vine.orderedPath[i];

              final segmentDx =
                  (currentSegment['x'] as int) - (prevSegment['x'] as int);
              final segmentDy =
                  (currentSegment['y'] as int) - (prevSegment['y'] as int);

              final isAdjacent = (segmentDx.abs() + segmentDy.abs()) == 1;
              expect(
                isAdjacent,
                isTrue,
                reason:
                    'Vine ${vine.id} segments at positions ${i - 1} (${prevSegment['x']},${prevSegment['y']}) and $i (${currentSegment['x']},${currentSegment['y']}) are not adjacent (delta: $segmentDx, $segmentDy) - must be orthogonal neighbors',
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
