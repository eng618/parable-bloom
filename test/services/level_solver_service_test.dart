import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/domain/services/level_solver_service.dart';
import 'package:parable_bloom/providers/game_providers.dart';

void main() {
  group('LevelSolverService', () {
    late LevelSolverService solver;

    setUp(() {
      solver = LevelSolverService();
    });

    test('should be instantiable', () {
      expect(solver, isNotNull);
      expect(solver, isA<LevelSolverService>());
    });

    test('should solve a simple solvable level', () {
      final level = LevelData(
        id: 1,
        name: 'Test Level',
        difficulty: 'easy',
        gridWidth: 5,
        gridHeight: 5,
        vines: [
          VineData(
            id: '1',
            headDirection: 'right',
            orderedPath: [
              {'x': 0, 'y': 0},
              {'x': 1, 'y': 0},
            ],
            vineColor: 'default',
          ),
        ],
        maxMoves: 5,
        minMoves: 1,
        complexity: 'low',
        grace: 3,
        mask: MaskData(mode: 'show-all', points: const []),
      );

      final solution = solver.solve(level);
      expect(solution, isNotNull);
      expect(solution, ['1']);
    });

    test('should detect blocking relationships correctly', () {
      final level = LevelData(
        id: 2,
        name: 'Blocking Test',
        difficulty: 'medium',
        gridWidth: 6,
        gridHeight: 3,
        vines: [
          VineData(
            id: '1',
            headDirection: 'right',
            orderedPath: [
              {'x': 0, 'y': 0},
              {'x': 1, 'y': 0},
            ],
            vineColor: 'default',
          ),
          VineData(
            id: '2',
            headDirection: 'right',
            orderedPath: [
              {'x': 2, 'y': 0},
              {'x': 3, 'y': 0},
            ],
            vineColor: 'primary',
          ),
        ],
        maxMoves: 5,
        minMoves: 2,
        complexity: 'low',
        grace: 3,
        mask: MaskData(mode: 'show-all', points: const []),
      );

      final isBlocked = solver.isVineBlockedInState(level, '1', ['1', '2']);
      expect(isBlocked, isFalse); // Vine 1 can move away from vine 2
    });

    test('should calculate distance to blocker', () {
      final level = LevelData(
        id: 3,
        name: 'Distance Test',
        difficulty: 'easy',
        gridWidth: 5,
        gridHeight: 5,
        vines: [
          VineData(
            id: '1',
            headDirection: 'right',
            orderedPath: [
              {'x': 0, 'y': 0},
            ],
            vineColor: 'default',
          ),
        ],
        maxMoves: 5,
        minMoves: 1,
        complexity: 'low',
        grace: 3,
        mask: MaskData(mode: 'show-all', points: const []),
      );

      final distance = solver.getDistanceToBlocker(level, '1', ['1']);
      expect(distance, greaterThan(0));
    });

    test('should handle empty vine list', () {
      final level = LevelData(
        id: 4,
        name: 'Empty Level',
        difficulty: 'easy',
        gridWidth: 5,
        gridHeight: 5,
        vines: [],
        maxMoves: 5,
        minMoves: 0,
        complexity: 'low',
        grace: 3,
        mask: MaskData(mode: 'show-all', points: const []),
      );

      final solution = solver.solve(level);
      expect(solution, []); // No vines to solve
    });
  });
}
