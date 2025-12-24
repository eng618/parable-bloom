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

          // 1. Check for overlaps (except at blocking points)
          final occupiedCells = <String, String>{}; // cell -> vineId
          for (final vine in level.vines) {
            for (final cell in vine.path) {
              final row = cell['row'];
              final col = cell['col'];
              final key = '$row,$col';

              if (occupiedCells.containsKey(key) &&
                  occupiedCells[key] != vine.id) {
                // Allow overlaps only if it's a head-body intersection (blocking point)
                // This happens when a vine's head occupies the same cell as another vine's body
                final otherVineId = occupiedCells[key]!;
                final otherVine = level.vines.firstWhere(
                  (v) => v.id == otherVineId,
                );

                // Check if this is a valid blocking intersection
                final isHeadBodyIntersection = _isValidBlockingIntersection(
                  vine,
                  otherVine,
                  row,
                  col,
                );

                if (!isHeadBodyIntersection) {
                  fail(
                    'Invalid vine overlap detected in ${entity.path} at cell ($row, $col) between vines ${vine.id} and $otherVineId.',
                  );
                }
              }
              occupiedCells[key] = vine.id;
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
            if (dRow == 1 && dCol == 0) {
              expectedDirection = 'down';
            } else if (dRow == -1 && dCol == 0) {
              expectedDirection = 'up';
            } else if (dRow == 0 && dCol == 1) {
              expectedDirection = 'right';
            } else if (dRow == 0 && dCol == -1) {
              expectedDirection = 'left';
            } else {
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
            // Check direction changes between consecutive segments
            for (int i = 0; i < vine.path.length - 1; i++) {
              final currentDir = vine.path[i]['direction'] as String;
              final nextDir = vine.path[i + 1]['direction'] as String;

              // Same direction is always valid (straight line)
              if (currentDir == nextDir) continue;

              // Different directions must be perpendicular (90-degree turn)
              final isValidTurn =
                  (currentDir == 'up' || currentDir == 'down') &&
                      (nextDir == 'left' || nextDir == 'right') ||
                  (currentDir == 'left' || currentDir == 'right') &&
                      (nextDir == 'up' || nextDir == 'down');

              expect(
                isValidTurn,
                isTrue,
                reason:
                    'Vine ${vine.id} has invalid direction change from $currentDir to $nextDir at segment ${i + 1}',
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

// Helper function to check if an overlap is a valid blocking intersection
bool _isValidBlockingIntersection(
  VineData vine1,
  VineData vine2,
  int row,
  int col,
) {
  // Find which vine has the head at this position
  final headVine =
      vine1.path.last['row'] == row && vine1.path.last['col'] == col
      ? vine1
      : vine2.path.last['row'] == row && vine2.path.last['col'] == col
      ? vine2
      : null;

  if (headVine == null) return false; // No vine has head here

  // The other vine should have a body segment at this position
  final bodyVine = headVine == vine1 ? vine2 : vine1;

  // Check if the body vine has a segment at this position (not counting its head)
  for (int i = 0; i < bodyVine.path.length - 1; i++) {
    if (bodyVine.path[i]['row'] == row && bodyVine.path[i]['col'] == col) {
      return true; // Valid blocking intersection
    }
  }

  return false; // Invalid overlap
}
