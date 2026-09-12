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
}
