import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/presentation/widgets/game_event_sink.dart';
import 'package:parable_bloom/features/game/presentation/widgets/garden_game.dart';
import 'package:parable_bloom/features/game/presentation/widgets/grid_component.dart';

class RecordingSink extends TestGameEventSink {
  final List<String> ensureVisibleCalls = [];
  final List<String> animationStates = [];
  bool animating = false;

  @override
  bool get isAnyAnimating => animating;

  @override
  Future<void> onEnsureVineVisible(VineData vine) async {
    ensureVisibleCalls.add(vine.id);
  }

  @override
  void onVineAnimationStateChanged(String vineId, VineAnimationState state) {
    animationStates.add('$vineId:$state');
  }
}

LevelData _level() => LevelData(
      id: 'pan',
      name: 'Pan',
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

class _TestGame extends GardenGame {
  _TestGame(GameEventSink sink) : super(sink: sink);

  @override
  Vector2 get size => Vector2(800, 600);
}

Future<(GridComponent, RecordingSink)> _grid() async {
  final sink = RecordingSink();
  final game = _TestGame(sink);
  await game.onLoad();
  final grid = game.grid;
  await grid.onLoad();
  return (grid, sink);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('camera-gesture tap suppression', () {
    test('fresh game does not suppress taps', () {
      final game = GardenGame(sink: TestGameEventSink());
      expect(game.shouldSuppressTaps, isFalse);
    });

    test('active gesture suppresses taps; tail expires after end', () async {
      final game = GardenGame(sink: TestGameEventSink());
      game.setCameraGestureActive(true);
      expect(game.shouldSuppressTaps, isTrue);

      game.setCameraGestureActive(false);
      // Finger-lift tail: still suppressed immediately after end.
      expect(game.shouldSuppressTaps, isTrue);

      await Future.delayed(const Duration(milliseconds: 200));
      expect(game.shouldSuppressTaps, isFalse);
    });
  });

  test('auto-clear pans camera to attempted+unblocked vine', () async {
    final (grid, sink) = await _grid();
    grid.setLevelData(_level(), {
      'v1': VineState(id: 'v1', isBlocked: false, isCleared: false),
      'v2': VineState(id: 'v2', isBlocked: true, isCleared: false),
    });

    // v2 clears; v1 was attempted and is now unblocked -> auto-clear v1.
    grid.setLevelData(_level(), {
      'v1': VineState(
        id: 'v1',
        isBlocked: false,
        isCleared: false,
        hasBeenAttempted: true,
      ),
      'v2': VineState(
        id: 'v2',
        isBlocked: false,
        isCleared: true,
        animationState: VineAnimationState.cleared,
      ),
    });

    await Future.delayed(const Duration(milliseconds: 600));

    expect(sink.ensureVisibleCalls, ['v1']);
    expect(
      grid.getCurrentVineState('v1')!.animationState,
      VineAnimationState.animatingClear,
    );
  });

  test('clear animation runs to completion via component pumps', () async {
    final (grid, sink) = await _grid();
    grid.setLevelData(_level(), {
      'v1': VineState(id: 'v1', isBlocked: false, isCleared: false),
      'v2': VineState(id: 'v2', isBlocked: true, isCleared: false),
    });

    // v1 animating-clear removes it as a blocker so v2 can clear.
    grid.setVineAnimationState('v1', VineAnimationState.animatingClear);
    final comp = grid.getVineComponent('v2')!;
    comp.slideOut();

    expect(
      grid.getCurrentVineState('v2')!.animationState,
      VineAnimationState.animatingClear,
    );

    // Pump the component like the engine would (~60fps).
    for (int i = 0; i < 3000; i++) {
      comp.update(0.06);
      if (sink.animationStates.contains('v2:${VineAnimationState.cleared}')) {
        break;
      }
    }

    expect(
      sink.animationStates,
      contains('v2:${VineAnimationState.cleared}'),
    );
  });
}
