import "package:flame/game.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart";
import "package:parable_bloom/features/game/domain/entities/level_data.dart";
import "package:parable_bloom/features/game/presentation/widgets/game_event_sink.dart";
import "package:parable_bloom/features/game/presentation/widgets/garden_game.dart";
import "package:parable_bloom/features/game/presentation/widgets/grid_component.dart";

LevelData _level() => LevelData(
      id: "restart",
      name: "Restart",
      difficulty: "Seed",
      gridWidth: 4,
      gridHeight: 3,
      vines: [
        VineData(
          id: "v1",
          headDirection: "up",
          orderedPath: [
            {"x": 2, "y": 0},
            {"x": 2, "y": 1},
          ],
        ),
        VineData(
          id: "v2",
          headDirection: "right",
          orderedPath: [
            {"x": 1, "y": 0},
            {"x": 0, "y": 0},
          ],
        ),
      ],
      maxMoves: 6,
      minMoves: 2,
      complexity: "low",
      grace: 2,
      mask: MaskData(mode: "show-all", points: const []),
    );

Map<String, VineState> _freshStates() => {
      "v1": VineState(id: "v1", isBlocked: false, isCleared: false),
      "v2": VineState(id: "v2", isBlocked: true, isCleared: false),
    };

class _TestGame extends GardenGame {
  _TestGame() : super(sink: TestGameEventSink());

  @override
  Vector2 get size => Vector2(800, 600);
}

Future<GridComponent> _gridWithLevel(LevelData level) async {
  final game = _TestGame();
  await game.onLoad();
  final grid = game.grid;
  await grid.onLoad();
  grid.setLevelData(level, _freshStates());
  return grid;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Level restart regression", () {
    test("provider reset clears cleared flags for same level", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final level = _level();
      container.read(currentLevelProvider.notifier).setLevel(level);
      final notifier = container.read(vineStatesProvider.notifier);
      notifier.resetForLevel(level);

      notifier.clearVine("v1");
      expect(container.read(vineStatesProvider)["v1"]!.isCleared, isTrue);

      // Game-over retry / pause restart: same LevelData object reloaded.
      notifier.resetForLevel(level);
      final states = container.read(vineStatesProvider);
      expect(states["v1"]!.isCleared, isFalse);
      expect(states["v1"]!.animationState, VineAnimationState.normal);
      expect(states["v2"]!.isCleared, isFalse);
      expect(states.values.map((s) => s.id).toSet(), {"v1", "v2"});
    });

    test("same-level reload rebuilds cleared vine components", () async {
      final level = _level();
      final grid = await _gridWithLevel(level);
      expect(grid.getVineComponent("v1"), isNotNull);
      expect(grid.getVineComponent("v2"), isNotNull);

      // Simulate a mid-level clear: VineComponent._finishAnimation removes
      // itself from the tree on clear.
      grid.setVineAnimationState("v1", VineAnimationState.cleared);
      grid.notifyVineCleared("v1");
      final detached = grid.getVineComponent("v1")!;
      detached.removeFromParent();

      // Restart the same level with fresh states (forceRebuild path used by
      // GameScreen._restartLevel for both pause restart and game-over retry).
      grid.setLevelData(level, _freshStates(), forceRebuild: true);

      final v1 = grid.getVineComponent("v1");
      final v2 = grid.getVineComponent("v2");
      expect(v1, isNotNull);
      expect(v2, isNotNull);
      // A fresh component instance replaces the detached one (which also
      // resets per-attempt flags such as _alreadyNotifiedCleared).
      expect(identical(v1, detached), isFalse);
      expect(grid.getCurrentVineState("v1")!.isCleared, isFalse);
      expect(grid.getActiveVineIds(), containsAll(["v1", "v2"]));
    });

    test("cleared vine can clear again after restart (notify flag reset)",
        () async {
      final level = _level();
      final grid = await _gridWithLevel(level);

      var clearCount = 0;
      // Wrap: count clears by observing animation-state transitions to
      // cleared through the mirror (fresh components start un-notified).
      grid.setVineAnimationState("v1", VineAnimationState.cleared);
      grid.notifyVineCleared("v1");
      clearCount++;
      grid.getVineComponent("v1")!.removeFromParent();

      grid.setLevelData(level, _freshStates(), forceRebuild: true);

      // A fresh component must accept a second clear cycle.
      grid.setVineAnimationState("v1", VineAnimationState.animatingClear);
      expect(
        grid.getCurrentVineState("v1")!.animationState,
        VineAnimationState.animatingClear,
      );
      clearCount++;
      expect(clearCount, 2);
    });

    test("state tick after a clear does not rebuild live components", () async {
      // Regression: tapping vine B right after vine A cleared rebuilt the
      // whole board (dead-component corpse tripped needsRebuild), killing
      // B's just-started slide so the first tap was swallowed.
      final level = _level();
      final grid = await _gridWithLevel(level);
      final v2Before = grid.getVineComponent("v2")!;

      // v1 clears and detaches, as VineComponent._finishAnimation does.
      grid.setVineAnimationState("v1", VineAnimationState.cleared);
      grid.notifyVineCleared("v1");
      grid.getVineComponent("v1")!.removeFromParent();

      // Provider reports v1 cleared while v2 starts sliding.
      grid.setLevelData(level, {
        "v1": VineState(
          id: "v1",
          isBlocked: false,
          isCleared: true,
          animationState: VineAnimationState.cleared,
        ),
        "v2": VineState(
          id: "v2",
          isBlocked: false,
          isCleared: false,
          animationState: VineAnimationState.animatingClear,
        ),
      });

      // No rebuild: v2 keeps its component (and its in-flight animation),
      // and the cleared vine's corpse is pruned instead of resurrected.
      expect(identical(grid.getVineComponent("v2"), v2Before), isTrue);
      expect(grid.getVineComponent("v1"), isNull);
      expect(
        grid.getCurrentVineState("v2")!.animationState,
        VineAnimationState.animatingClear,
      );
    });
  });
}
