import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_weave/providers/game_providers.dart';

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
              fail('Vine overlap detected in ${entity.path} at cell ($row, $col). Multiple vines occupy this cell.');
            }
            occupiedCells.add(key);
          }
        }

        // 2. Check for solvability
        final solution = LevelSolver.solve(level);
        expect(solution, isNotNull, reason: 'Level ${entity.path} is unsolvable!');
        print('Level ${level.levelId} is solvable. Solution: $solution');
      }
    }
  });
}
