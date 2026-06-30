import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/domain/services/level_solver_service.dart';

void main() {
  group('LevelSolverService Performance', () {
    late LevelSolverService solver;

    setUp(() {
      solver = LevelSolverService();
    });

    test('isVineBlockedInState performance', () {
      final vines = <VineData>[];
      final activeVineIds = <String>[];

      // Create a grid of vines
      for (int i = 0; i < 50; i++) {
        final id = 'vine_$i';
        activeVineIds.add(id);

        // Make long vines to increase M
        final path = <Map<String, int>>[];
        for (int j = 0; j < 20; j++) {
           path.add({'x': i, 'y': j});
        }

        vines.add(VineData(
          id: id,
          headDirection: 'up',
          orderedPath: path,
        ));
      }

      final level = LevelData(
        id: '1',
        name: 'Perf Test Level',
        difficulty: 'hard',
        gridWidth: 100,
        gridHeight: 100,
        vines: vines,
        maxMoves: 100,
        minMoves: 1,
        complexity: 'high',
        grace: 0,
        mask: MaskData(mode: 'none', points: []),
      );

      final stopwatch = Stopwatch()..start();

      // Run it many times to get a measurable duration
      for (int iter = 0; iter < 100; iter++) {
        for (final vineId in activeVineIds) {
          solver.isVineBlockedInState(level, vineId, activeVineIds);
        }
      }

      stopwatch.stop();
      print('isVineBlockedInState Time: ${stopwatch.elapsedMilliseconds} ms');
    });

    test('getDistanceToBlocker performance', () {
      final vines = <VineData>[];
      final activeVineIds = <String>[];

      // Create a grid of vines
      for (int i = 0; i < 50; i++) {
        final id = 'vine_$i';
        activeVineIds.add(id);

        // Make long vines to increase M
        final path = <Map<String, int>>[];
        for (int j = 0; j < 20; j++) {
           path.add({'x': i, 'y': j});
        }

        vines.add(VineData(
          id: id,
          headDirection: 'up',
          orderedPath: path,
        ));
      }

      final level = LevelData(
        id: '1',
        name: 'Perf Test Level',
        difficulty: 'hard',
        gridWidth: 100,
        gridHeight: 100,
        vines: vines,
        maxMoves: 100,
        minMoves: 1,
        complexity: 'high',
        grace: 0,
        mask: MaskData(mode: 'none', points: []),
      );

      final stopwatch = Stopwatch()..start();

      // Run it many times to get a measurable duration
      for (int iter = 0; iter < 10; iter++) {
        for (final vineId in activeVineIds) {
          solver.getDistanceToBlocker(level, vineId, activeVineIds);
        }
      }

      stopwatch.stop();
      print('getDistanceToBlocker Time: ${stopwatch.elapsedMilliseconds} ms');
    });
  });
}
