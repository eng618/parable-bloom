import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/presentation/widgets/game_event_sink.dart';
import 'package:parable_bloom/features/game/presentation/widgets/garden_game.dart';
import 'package:parable_bloom/features/game/presentation/widgets/grid_component.dart';

/// Regression tests for taps landing mid-clear-animation: the Flame mirror
/// must reflect animation transitions synchronously, otherwise the
/// provider round-trip leaves a ghost blocker and the next vine falsely
/// bounces (and loses grace).
LevelData _blockingLevel() => LevelData(
      id: 'mirror',
      name: 'Mirror',
      difficulty: 'Seed',
      gridWidth: 4,
      gridHeight: 3,
      vines: [
        VineData(
          id: 'v1',
          headDirection: 'up',
          orderedPath: [
            {'x': 2, 'y': 0},
            {'x': 2, 'y': 1},
          ],
        ),
        VineData(
          id: 'v2',
          headDirection: 'right',
          orderedPath: [
            {'x': 1, 'y': 0},
            {'x': 0, 'y': 0},
          ],
        ),
      ],
      maxMoves: 6,
      minMoves: 2,
      complexity: 'low',
      grace: 2,
      mask: MaskData(mode: 'show-all', points: const []),
    );

/// Lesson 1 used to ignore every tap except the head cell.
LevelData _lesson1() => LevelData(
      id: 'lesson_1',
      name: 'Lesson 1',
      difficulty: 'tutorial',
      gridWidth: 4,
      gridHeight: 4,
      vines: [
        VineData(
          id: 'vine_1',
          headDirection: 'left',
          orderedPath: [
            {'x': 0, 'y': 3},
            {'x': 1, 'y': 3},
            {'x': 2, 'y': 3},
          ],
        ),
      ],
      maxMoves: 1,
      minMoves: 1,
      complexity: 'tutorial',
      grace: 3,
      mask: MaskData(mode: 'show-all', points: const []),
    );

Map<String, VineState> _lesson1States() => {
      'vine_1': VineState(id: 'vine_1', isBlocked: false, isCleared: false),
    };

Map<String, VineState> _freshStates() => {
      'v1': VineState(id: 'v1', isBlocked: false, isCleared: false),
      'v2': VineState(id: 'v2', isBlocked: true, isCleared: false),
    };

/// Test game with a fixed size (same pattern as camera_test.dart's mock:
/// avoids the engine layout assertion when reading `size` off-cycle).
class _TestGame extends GardenGame {
  _TestGame() : super(sink: TestGameEventSink());

  @override
  Vector2 get size => Vector2(800, 600);
}

Future<GridComponent> _grid() async {
  final game = _TestGame();
  // Sprite loads fail without a test bundle (caught + logged in onLoad);
  // grid creation proceeds.
  await game.onLoad();
  final grid = game.grid;
  // Component lifecycle never runs off-engine: initialize local fields.
  await grid.onLoad();
  grid.setLevelData(_blockingLevel(), _freshStates());
  return grid;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('GridComponent mirror during clear animations', () {
    test('animation state is mirrored without provider round-trip', () async {
      final grid = await _grid();
      expect(grid.getActiveVineIds(), containsAll(['v1', 'v2']));

      grid.setVineAnimationState('v1', VineAnimationState.animatingClear);

      expect(grid.getActiveVineIds(), ['v2']);
      expect(
        grid.getCurrentVineState('v1')!.animationState,
        VineAnimationState.animatingClear,
      );
    });

    test('tap during another vine clear takes the clear path', () async {
      final grid = await _grid();

      // v1 starts sliding out; v2 taps while v1 is still on screen.
      grid.setVineAnimationState('v1', VineAnimationState.animatingClear);
      grid.handleCellTap(0, 1); // v2 head at (x=1, y=0)

      // Must clear (v1 excluded as a blocker), not bounce as blocked.
      // A blocked verdict would mark v2 attempted and cost grace.
      expect(
        grid.getCurrentVineState('v2')!.animationState,
        VineAnimationState.animatingClear,
      );
      expect(grid.getCurrentVineState('v2')!.hasBeenAttempted, isFalse);
    });
  });

  group('Lesson 1 vine taps', () {
    Future<GridComponent> lessonGrid() async {
      final game = _TestGame();
      await game.onLoad();
      final grid = game.grid;
      await grid.onLoad();
      grid.setLevelData(_lesson1(), _lesson1States());
      return grid;
    }

    test('a body cell slides the vine', () async {
      final grid = await lessonGrid();

      grid.handleCellTap(3, 1); // body at (x=1, y=3), head is (0, 3)

      expect(
        grid.getCurrentVineState('vine_1')!.animationState,
        VineAnimationState.animatingClear,
      );
    });

    test('the head still slides the vine', () async {
      final grid = await lessonGrid();

      grid.handleCellTap(3, 0); // head at (x=0, y=3)

      expect(
        grid.getCurrentVineState('vine_1')!.animationState,
        VineAnimationState.animatingClear,
      );
    });

    test('an empty cell does not slide the vine', () async {
      final grid = await lessonGrid();

      grid.handleCellTap(0, 0);

      expect(
        grid.getCurrentVineState('vine_1')!.animationState,
        VineAnimationState.normal,
      );
    });
  });
}
