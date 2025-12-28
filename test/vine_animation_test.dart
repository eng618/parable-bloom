import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/providers/game_providers.dart';

void main() {
  group('Vine Animation System Tests', () {
    test('Animation state enum values are properly defined', () {
      // Test that all animation states are properly defined
      expect(VineAnimationState.normal, isNotNull);
      expect(VineAnimationState.animatingClear, isNotNull);
      expect(VineAnimationState.animatingBlocked, isNotNull);
      expect(VineAnimationState.cleared, isNotNull);

      // Test that they are different values
      expect(
        VineAnimationState.normal,
        isNot(VineAnimationState.animatingClear),
      );
      expect(
        VineAnimationState.animatingClear,
        isNot(VineAnimationState.animatingBlocked),
      );
      expect(
        VineAnimationState.animatingBlocked,
        isNot(VineAnimationState.cleared),
      );
    });

    test('VineState copyWith preserves animation state', () {
      final original = VineState(
        id: 'test',
        isBlocked: false,
        isCleared: false,
        animationState: VineAnimationState.normal,
      );

      final copied = original.copyWith(
        animationState: VineAnimationState.animatingClear,
      );

      expect(copied.id, 'test');
      expect(copied.isBlocked, false);
      expect(copied.isCleared, false);
      expect(copied.animationState, VineAnimationState.animatingClear);
    });

    test('VineState maintains all properties correctly', () {
      final state = VineState(
        id: 'test_vine',
        isBlocked: true,
        isCleared: false,
        hasBeenAttempted: true,
        animationState: VineAnimationState.animatingBlocked,
      );

      expect(state.id, 'test_vine');
      expect(state.isBlocked, true);
      expect(state.isCleared, false);
      expect(state.hasBeenAttempted, true);
      expect(state.animationState, VineAnimationState.animatingBlocked);
    });

    test('VineData preserves all properties', () {
      final path = [
        {'x': 0, 'y': 1},
        {'x': 1, 'y': 1},
        {'x': 2, 'y': 1},
      ];

      final vine = VineData(
        id: 'test_vine',
        headDirection: 'right',
        orderedPath: path,
        color: 'green',
      );

      expect(vine.id, 'test_vine');
      expect(vine.headDirection, 'right');
      expect(vine.orderedPath, path);
      expect(vine.color, 'green');
    });

    test('LevelData structure is valid', () {
      final level = LevelData(
        id: 1,
        name: 'Test Level',
        difficulty: 'Seedling',
        vines: [],
        maxMoves: 5,
        minMoves: 2,
        complexity: 'low',
        grace: 3,
      );

      expect(level.id, 1);
      expect(level.name, 'Test Level');
      expect(level.difficulty, 'Seedling');
      expect(level.vines, []);
      expect(level.maxMoves, 5);
      expect(level.minMoves, 2);
      expect(level.complexity, 'low');
      expect(level.grace, 3);
    });

    test('Level solving algorithm finds solution for simple level', () {
      final solvableLevel = LevelData(
        id: 3,
        name: 'Solvable Level',
        difficulty: 'Seedling',
        vines: [
          VineData(
            id: 'clearable',
            headDirection: 'right',
            orderedPath: [
              {'x': 0, 'y': 2},
              {'x': 1, 'y': 2},
              {'x': 2, 'y': 2},
            ],
            color: 'green',
          ),
        ],
        maxMoves: 5,
        minMoves: 2,
        complexity: 'low',
        grace: 3,
      );

      final solution = LevelSolver.solve(solvableLevel);
      expect(solution, ['clearable']);
    });

    test('Animation state transitions maintain state integrity', () {
      final state = VineState(
        id: 'test',
        isBlocked: false,
        isCleared: false,
        animationState: VineAnimationState.normal,
      );

      // Test normal -> animatingClear
      var newState = state.copyWith(
        animationState: VineAnimationState.animatingClear,
      );
      expect(newState.animationState, VineAnimationState.animatingClear);
      expect(newState.isCleared, false);
      expect(newState.isBlocked, false);

      // Test animatingClear -> cleared
      newState = newState.copyWith(
        animationState: VineAnimationState.cleared,
        isCleared: true,
      );
      expect(newState.animationState, VineAnimationState.cleared);
      expect(newState.isCleared, true);
      expect(newState.isBlocked, false);
    });
  });
}
