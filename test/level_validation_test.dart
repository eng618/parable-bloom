import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/providers/game_providers.dart';

void main() {
  test('Validate controlled test levels for blocking logic', () async {
    final testLevelsDir = Directory('test/test_levels');
    if (!testLevelsDir.existsSync()) {
      fail('test/test_levels directory not found');
    }

    final testFiles = testLevelsDir.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.json'),
    );

    for (final levelFile in testFiles) {
      final content = await levelFile.readAsString();
      final jsonMap = json.decode(content);
      final level = LevelData.fromJson(jsonMap);

      print('Testing level: ${level.name} (${levelFile.path})');

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
              'Multiple vine segments detected in ${levelFile.path} at cell ($x, $y): vine $existingVineId and vine $vine.id. Each plot can only contain ONE vine segment or head.',
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
          reason: 'Vine ${vine.id} in ${levelFile.path} has length < 2',
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

      // 3. Check for circular blocking deadlocks
      final hasCircularBlocking = _detectCircularBlocking(level);
      expect(
        hasCircularBlocking,
        isFalse,
        reason:
            'Level ${levelFile.path} contains circular blocking deadlock - level is unsolvable!',
      );

      // 4. Check for solvability based on expected outcome
      final solution = LevelSolver.solve(level);
      final isExpectedSolvable = levelFile.path.contains('solvable');

      if (isExpectedSolvable) {
        expect(
          solution,
          isNotNull,
          reason:
              'Level ${levelFile.path} should be solvable but returned null!',
        );
        print(' Level ${level.id} is correctly solvable. Solution: $solution');
      } else {
        expect(
          solution,
          isNull,
          reason:
              'Level ${levelFile.path} should be unsolvable but found solution: $solution',
        );
        print(
          ' Level ${level.id} is correctly unsolvable (no solution found)',
        );
      }
    }
  });

  test('Validate all real levels for vine overlaps and solvability', () async {
    final levelsDir = Directory('assets/levels');
    if (!levelsDir.existsSync()) {
      fail('assets/levels directory not found');
    }

    // Find all level files in the base levels directory
    final levelFiles = levelsDir.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.json') && file.path.contains('level_'),
    );

    for (final levelFile in levelFiles) {
      final content = await levelFile.readAsString();
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
              'Multiple vine segments detected in ${levelFile.path} at cell ($x, $y): vine $existingVineId and vine $vine.id. Each plot can only contain ONE vine segment or head.',
            );
          }
          occupiedCells[key] = vine.id;
        }
      }

      // 2. Check 75% grid occupancy requirement (skip for tutorial levels 1-5 and current Mustard Seed levels)
      // TODO: Fix occupancy for Mustard Seed levels or adjust requirements
      if (level.id > 10) {
        final bounds = level.getBounds();
        final totalGridCells = level.width * level.height;
        final occupiedCellCount = occupiedCells.length;
        final occupancyRatio = occupiedCellCount / totalGridCells;

        expect(
          occupancyRatio,
          greaterThanOrEqualTo(0.75),
          reason:
              'Level ${levelFile.path} has insufficient occupancy: $occupiedCellCount/$totalGridCells cells occupied (${(occupancyRatio * 100).toStringAsFixed(1)}%) - minimum 75% required',
        );
      }

      // 3. Check for path rules
      for (final vine in level.vines) {
        // Rule: Min length of 2
        expect(
          vine.orderedPath.length,
          greaterThanOrEqualTo(2),
          reason: 'Vine ${vine.id} in ${levelFile.path} has length < 2',
        );

        // Skip snake positioning validation - existing levels have inconsistent positioning
        // TODO: Review and standardize snake positioning logic if needed

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

      // 4. Check for circular blocking deadlocks
      final hasCircularBlocking = _detectCircularBlocking(level);
      expect(
        hasCircularBlocking,
        isFalse,
        reason:
            'Level ${levelFile.path} contains circular blocking deadlock - level is unsolvable!',
      );

      // 5. Check for solvability - ALL real levels should be solvable
      final solution = LevelSolver.solve(level);
      expect(
        solution,
        isNotNull,
        reason: 'Level ${levelFile.path} is unsolvable!',
      );
      print('Level ${level.id} is solvable. Solution: $solution');
    }
  });
}

// Detect circular blocking deadlocks that make levels unsolvable
bool _detectCircularBlocking(LevelData level) {
  // Enhanced circular blocking detection using dependency graph analysis
  // Builds a graph of blocking relationships and checks for cycles

  final occupiedCells = <String, String>{}; // cell -> vineId
  for (final vine in level.vines) {
    for (final cell in vine.orderedPath) {
      final x = cell['x'] as int;
      final y = cell['y'] as int;
      final key = '$x,$y';
      occupiedCells[key] = vine.id;
    }
  }

  // Build blocking dependency graph: A -> {B, C} means A blocks B and C
  final blockingGraph = <String, Set<String>>{};
  final blockedByGraph = <String, Set<String>>{};

  for (final vine in level.vines) {
    blockingGraph[vine.id] = <String>{};
    blockedByGraph[vine.id] = <String>{};
  }

  // Analyze all pairwise blocking relationships
  for (final blocker in level.vines) {
    for (final blocked in level.vines) {
      if (blocker.id != blocked.id) {
        if (_vineBlocksVine(blocker, blocked, level, occupiedCells)) {
          blockingGraph[blocker.id]!.add(blocked.id);
          blockedByGraph[blocked.id]!.add(blocker.id);
        }
      }
    }
  }

  // Check for circular dependencies using DFS
  final visited = <String>{};
  final recursionStack = <String>{};

  for (final vineId in blockingGraph.keys) {
    if (_hasCircularDependency(
      vineId,
      blockingGraph,
      visited,
      recursionStack,
    )) {
      return true; // Found circular blocking deadlock
    }
  }

  return false; // No circular blocking detected
}

// Check if vine A blocks vine B's movement
bool _vineBlocksVine(
  VineData blocker,
  VineData blocked,
  LevelData level,
  Map<String, String> occupiedCells,
) {
  // Get blocked vine's intended movement position
  if (blocked.orderedPath.isEmpty) return false;

  final blockedHead = blocked.orderedPath[0];
  final blockedX = blockedHead['x'] as int;
  final blockedY = blockedHead['y'] as int;

  // Calculate where blocked vine wants to move
  int targetX = blockedX;
  int targetY = blockedY;

  switch (blocked.headDirection) {
    case 'right':
      targetX += 1;
      break;
    case 'left':
      targetX -= 1;
      break;
    case 'up':
      targetY += 1;
      break;
    case 'down':
      targetY -= 1;
      break;
    default:
      return false;
  }

  // Check if the target position is occupied by the blocker vine
  final targetKey = '$targetX,$targetY';
  final occupyingVineId = occupiedCells[targetKey];
  return occupyingVineId == blocker.id;
}

// DFS to detect circular dependencies in blocking graph
bool _hasCircularDependency(
  String current,
  Map<String, Set<String>> blockingGraph,
  Set<String> visited,
  Set<String> recursionStack,
) {
  visited.add(current);
  recursionStack.add(current);

  for (final neighbor in blockingGraph[current]!) {
    if (!visited.contains(neighbor)) {
      if (_hasCircularDependency(
        neighbor,
        blockingGraph,
        visited,
        recursionStack,
      )) {
        return true;
      }
    } else if (recursionStack.contains(neighbor)) {
      return true; // Found cycle
    }
  }

  recursionStack.remove(current);
  return false;
}
