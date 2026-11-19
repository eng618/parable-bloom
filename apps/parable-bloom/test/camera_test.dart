import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'package:parable_bloom/core/board_transform.dart';
import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/application/providers/camera_providers.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/presentation/widgets/garden_game.dart';
import 'package:parable_bloom/features/game/presentation/widgets/game_event_sink.dart';

import 'package:flame/game.dart' show Vector2;

class MockGardenGame extends GardenGame {
  final Vector2 mockSize;
  MockGardenGame(this.mockSize) : super(sink: TestGameEventSink());

  @override
  Vector2 get size => mockSize;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ensureVineVisible centers an off-screen vine', () async {
    final game = MockGardenGame(Vector2(800, 600));
    final level = LevelData(
      id: 'test_lvl',
      name: 'Test Level',
      difficulty: 'Seed',
      gridWidth: 20,
      gridHeight: 20,
      vines: [
        VineData(
          id: 'v1',
          headDirection: 'right',
          orderedPath: [
            {'x': 19, 'y': 19},
            {'x': 18, 'y': 19},
          ],
        )
      ],
      maxMoves: 2,
      minMoves: 1,
      complexity: 'low',
      grace: 3,
      mask: MaskData(mode: 'show-all', points: const []),
    );

    final container = ProviderContainer(
      overrides: [
        disableAnimationsProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    // Set states
    container.read(gameInstanceProvider.notifier).setGame(game);
    container.read(currentLevelProvider.notifier).setLevel(level);

    final cameraNotifier = container.read(cameraStateProvider.notifier);

    // Initialize camera zoom bounds for level
    cameraNotifier.updateZoomBounds(
      screenWidth: 800,
      screenHeight: 600,
      gridCols: 20,
      gridRows: 20,
    );

    // The level opens on the whole board, which would include this corner.
    // Zoom in so the vine sits outside the view.
    cameraNotifier.updateZoom(1);
    expect(container.read(cameraStateProvider).panOffset, vm.Vector2.zero());

    // Call ensureVineVisible for v1 which is in the top-right corner, off-screen under this zoom + margin
    await cameraNotifier.ensureVineVisible(level.vines.first);

    // The camera should have panned to center the vine
    final updatedState = container.read(cameraStateProvider);
    expect(updatedState.panOffset.x, isNot(0.0));
    expect(updatedState.panOffset.y, isNot(0.0));
  });

  test('ensureVineVisible does not pan if vine is already visible', () async {
    final game = MockGardenGame(Vector2(800, 600));
    final level = LevelData(
      id: 'test_lvl_2',
      name: 'Test Level 2',
      difficulty: 'Seed',
      gridWidth: 10,
      gridHeight: 10,
      vines: [
        VineData(
          id: 'v1',
          headDirection: 'right',
          orderedPath: [
            {'x': 5, 'y': 5},
            {'x': 4, 'y': 5},
          ],
        )
      ],
      maxMoves: 2,
      minMoves: 1,
      complexity: 'low',
      grace: 3,
      mask: MaskData(mode: 'show-all', points: const []),
    );

    final container = ProviderContainer(
      overrides: [
        disableAnimationsProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    container.read(gameInstanceProvider.notifier).setGame(game);
    container.read(currentLevelProvider.notifier).setLevel(level);

    final cameraNotifier = container.read(cameraStateProvider.notifier);

    // Initialize camera zoom bounds for level
    cameraNotifier.updateZoomBounds(
      screenWidth: 800,
      screenHeight: 600,
      gridCols: 10,
      gridRows: 10,
    );

    // Position at default centered position
    cameraNotifier.resetToCenter();
    expect(container.read(cameraStateProvider).panOffset, vm.Vector2.zero());

    // Call ensureVineVisible for v1 which is in the center and already visible
    await cameraNotifier.ensureVineVisible(level.vines.first);

    // The camera should remain at zero offset since it is already visible
    expect(container.read(cameraStateProvider).panOffset, vm.Vector2.zero());
  });

  test('applyGestureTransform publishes zoom and pan in one write', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final seen = <CameraState>[];
    container.listen<CameraState>(
      cameraStateProvider,
      (_, next) => seen.add(next),
    );

    container.read(cameraStateProvider.notifier).applyGestureTransform(
          zoom: 1.6,
          panOffset: vm.Vector2(18, -9),
          screenWidth: 800,
          screenHeight: 600,
          gridCols: 8,
          gridRows: 8,
        );

    expect(seen, hasLength(1));
    expect(seen.single.zoom, 1.6);
    expect(seen.single.panOffset.x, closeTo(18, 0.001));
    expect(seen.single.panOffset.y, closeTo(-9, 0.001));
  });

  test('applyGestureTransform limits pan at the destination zoom', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(cameraStateProvider.notifier);

    // On a 400px screen the pan cap is 20% of the scaled board while the
    // board still fits. Zoom 2 of a 4×4 board still fits, so a 60px pan is
    // inside the new cap and outside the zoom-1 cap.
    notifier.applyGestureTransform(
      zoom: 2.0,
      panOffset: vm.Vector2(60, 0),
      screenWidth: 400,
      screenHeight: 400,
      gridCols: 4,
      gridRows: 4,
    );
    expect(container.read(cameraStateProvider).zoom, 2.0);
    expect(
      container.read(cameraStateProvider).panOffset.x,
      closeTo(60, 0.001),
    );

    // Zoom 0.5 shrinks the cap. Using the previous zoom would have left
    // the 60px pan in place.
    notifier.applyGestureTransform(
      zoom: 0.5,
      panOffset: vm.Vector2(60, 0),
      screenWidth: 400,
      screenHeight: 400,
      gridCols: 4,
      gridRows: 4,
    );
    final tightened = container.read(cameraStateProvider);
    expect(tightened.zoom, 0.5);
    expect(
      tightened.panOffset.x,
      closeTo(GameBoardLayout.boardWidth(4) * 0.5 * 0.2, 0.001),
    );
  });

  LevelData frameBoard(int cols, int rows) => LevelData(
        id: 'frame_$cols',
        name: 'Frame',
        difficulty: 'Seed',
        gridWidth: cols,
        gridHeight: rows,
        vines: const [],
        maxMoves: 1,
        minMoves: 1,
        complexity: 'low',
        grace: 3,
        mask: MaskData(mode: 'show-all', points: const []),
      );

  test('animateToDefaultZoom opens on the whole board', () {
    final container = ProviderContainer(
      overrides: [
        disableAnimationsProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(cameraStateProvider.notifier);
    notifier.updateZoom(1.8);
    notifier.animateToDefaultZoom(
      screenWidth: 800,
      screenHeight: 600,
      gridCols: 20,
      gridRows: 20,
    );

    final expected = BoardTransform.levelCompleteFrame(
      cols: 20,
      rows: 20,
      screenWidth: 800,
      screenHeight: 600,
    ).zoom;
    final state = container.read(cameraStateProvider);
    expect(state.zoom, closeTo(expected, 0.001));
    expect(state.zoom, lessThan(1));
    expect(state.panOffset, vm.Vector2.zero());
    expect(state.isAnimating, isFalse);
    expect(state.minZoom, lessThanOrEqualTo(state.zoom));
  });

  test('animateToDefaultZoom eases out onto the whole board', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final target = BoardTransform.levelCompleteFrame(
      cols: 20,
      rows: 20,
      screenWidth: 800,
      screenHeight: 600,
    ).zoom;
    final notifier = container.read(cameraStateProvider.notifier);
    // A return visit can still be holding a close zoom from the last play.
    notifier.updateZoom(1.8);
    notifier.animateToDefaultZoom(
      screenWidth: 800,
      screenHeight: 600,
      gridCols: 20,
      gridRows: 20,
    );

    final opening = container.read(cameraStateProvider);
    expect(opening.isAnimating, isTrue);
    expect(opening.zoom, greaterThan(target));
    expect(opening.zoom, lessThan(1.8));
    expect(opening.panOffset, vm.Vector2.zero());

    await Future<void>.delayed(const Duration(milliseconds: 1200));

    final settled = container.read(cameraStateProvider);
    expect(settled.isAnimating, isFalse);
    expect(settled.zoom, closeTo(target, 0.001));
    expect(settled.panOffset, vm.Vector2.zero());
  });

  test('animateToDefaultZoom keeps a small board inside the max zoom', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(cameraStateProvider.notifier).animateToDefaultZoom(
          screenWidth: 800,
          screenHeight: 600,
          gridCols: 4,
          gridRows: 4,
        );

    final state = container.read(cameraStateProvider);
    expect(state.zoom, BoardTransform.maxCameraZoom);
    expect(state.panOffset, vm.Vector2.zero());
    expect(state.isAnimating, isFalse);
  });

  test('resetToCenter returns to the whole board', () {
    final game = MockGardenGame(Vector2(800, 600));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(gameInstanceProvider.notifier).setGame(game);
    container.read(currentLevelProvider.notifier).setLevel(frameBoard(20, 20));

    final notifier = container.read(cameraStateProvider.notifier);
    notifier.updateZoom(1.8);
    notifier.updatePanOffset(
      vm.Vector2(30, -20),
      screenWidth: 800,
      screenHeight: 600,
      gridCols: 20,
      gridRows: 20,
    );
    notifier.resetToCenter();

    final expected = BoardTransform.levelCompleteFrame(
      cols: 20,
      rows: 20,
      screenWidth: 800,
      screenHeight: 600,
    ).zoom;
    final state = container.read(cameraStateProvider);
    expect(state.zoom, closeTo(expected, 0.001));
    expect(state.panOffset, vm.Vector2.zero());
    expect(state.isAnimating, isFalse);
  });

  test('frameEntireBoard does nothing without a game', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(cameraStateProvider.notifier).frameEntireBoard();

    final state = container.read(cameraStateProvider);
    expect(state.zoom, 1);
    expect(state.isAnimating, isFalse);
    expect(state.panOffset, vm.Vector2.zero());
  });

  test('frameEntireBoard fits a board below the play zoom floor', () async {
    final game = MockGardenGame(Vector2(800, 600));
    final container = ProviderContainer(
      overrides: [
        disableAnimationsProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    container.read(gameInstanceProvider.notifier).setGame(game);
    container.read(currentLevelProvider.notifier).setLevel(frameBoard(40, 40));

    final frame = BoardTransform.levelCompleteFrame(
      cols: 40,
      rows: 40,
      screenWidth: 800,
      screenHeight: 600,
    );
    expect(frame.zoom, lessThan(0.3));

    final notifier = container.read(cameraStateProvider.notifier);
    notifier.updateZoomBounds(
      screenWidth: 800,
      screenHeight: 600,
      gridCols: 40,
      gridRows: 40,
    );
    expect(
      container.read(cameraStateProvider).minZoom,
      closeTo(frame.zoom, 1e-9),
    );
    notifier.updatePanOffset(
      vm.Vector2(80, -40),
      screenWidth: 800,
      screenHeight: 600,
      gridCols: 40,
      gridRows: 40,
    );

    await notifier.frameEntireBoard();

    final state = container.read(cameraStateProvider);
    expect(state.zoom, closeTo(frame.zoom, 1e-9));
    expect(state.minZoom, closeTo(frame.zoom, 1e-9));
    expect(state.panOffset.x, closeTo(0, 1e-9));
    expect(state.panOffset.y, closeTo(0, 1e-9));
    expect(state.isAnimating, isFalse);

    var writes = 0;
    container.listen<CameraState>(
      cameraStateProvider,
      (_, __) => writes++,
    );
    await notifier.frameEntireBoard();
    expect(writes, 0);
  });

  test('a gesture takes over the level-complete frame', () async {
    final game = MockGardenGame(Vector2(800, 600));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(gameInstanceProvider.notifier).setGame(game);
    container.read(currentLevelProvider.notifier).setLevel(frameBoard(40, 40));

    final notifier = container.read(cameraStateProvider.notifier);
    notifier.updateZoomBounds(
      screenWidth: 800,
      screenHeight: 600,
      gridCols: 40,
      gridRows: 40,
    );

    final framed = notifier.frameEntireBoard();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(cameraStateProvider).isAnimating, isTrue);

    notifier.updateZoom(1.1);
    await framed.timeout(const Duration(seconds: 2));

    final state = container.read(cameraStateProvider);
    expect(state.isAnimating, isFalse);
    expect(state.zoom, 1.1);
  });

  LevelData vineLevel(int cols, int rows, List<VineData> vines) => LevelData(
        id: 'vines_${cols}_$rows',
        name: 'Vines',
        difficulty: 'Seed',
        gridWidth: cols,
        gridHeight: rows,
        vines: vines,
        maxMoves: vines.length,
        minMoves: 1,
        complexity: 'low',
        grace: 3,
        mask: MaskData(mode: 'show-all', points: const []),
      );

  VineData singleCell(String id, int x, int y) => VineData(
        id: id,
        headDirection: 'right',
        orderedPath: [
          {'x': x, 'y': y},
        ],
      );

  test('frameRemainingVines pans to vines outside the view', () async {
    final game = MockGardenGame(Vector2(800, 600));
    final container = ProviderContainer(
      overrides: [
        disableAnimationsProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    container.read(gameInstanceProvider.notifier).setGame(game);
    container.read(currentLevelProvider.notifier).setLevel(
          vineLevel(20, 20, [singleCell('far', 19, 19)]),
        );
    container.read(vineStatesProvider);

    final notifier = container.read(cameraStateProvider.notifier);
    notifier.updateZoomBounds(
      screenWidth: 800,
      screenHeight: 600,
      gridCols: 20,
      gridRows: 20,
    );
    notifier.updateZoom(1);

    await notifier.frameRemainingVines();

    final state = container.read(cameraStateProvider);
    expect(state.zoom, 1);
    expect(state.panOffset.x.abs() + state.panOffset.y.abs(), greaterThan(1));
    expect(state.isAnimating, isFalse);
  });

  test('frameRemainingVines stays put when a vine is already in view',
      () async {
    final game = MockGardenGame(Vector2(800, 600));
    final container = ProviderContainer(
      overrides: [
        disableAnimationsProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    container.read(gameInstanceProvider.notifier).setGame(game);
    container.read(currentLevelProvider.notifier).setLevel(
          vineLevel(10, 10, [singleCell('mid', 5, 5)]),
        );
    container.read(vineStatesProvider);

    final notifier = container.read(cameraStateProvider.notifier);
    notifier.updateZoomBounds(
      screenWidth: 800,
      screenHeight: 600,
      gridCols: 10,
      gridRows: 10,
    );
    notifier.updateZoom(1);
    notifier.updatePanOffset(
      vm.Vector2(40, 0),
      screenWidth: 800,
      screenHeight: 600,
      gridCols: 10,
      gridRows: 10,
    );

    await notifier.frameRemainingVines();

    final state = container.read(cameraStateProvider);
    expect(state.zoom, 1);
    expect(state.panOffset.x, closeTo(40, 0.001));
    expect(state.panOffset.y, closeTo(0, 0.001));
  });

  test('frameRemainingVines zooms out to fit a spread group', () async {
    final game = MockGardenGame(Vector2(800, 600));
    final container = ProviderContainer(
      overrides: [
        disableAnimationsProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    container.read(gameInstanceProvider.notifier).setGame(game);
    container.read(currentLevelProvider.notifier).setLevel(
          vineLevel(20, 20, [
            singleCell('a', 0, 0),
            singleCell('b', 19, 19),
          ]),
        );
    container.read(vineStatesProvider);

    final notifier = container.read(cameraStateProvider.notifier);
    notifier.updateZoomBounds(
      screenWidth: 800,
      screenHeight: 600,
      gridCols: 20,
      gridRows: 20,
    );
    notifier.updateZoom(1.5);

    await notifier.frameRemainingVines();

    final state = container.read(cameraStateProvider);
    expect(state.zoom, lessThan(1.5));
    expect(state.zoom, greaterThan(0.3));
    expect(state.panOffset.x.abs(), lessThan(1));
    expect(state.panOffset.y.abs(), lessThan(1));
  });

  test('frameRemainingVines does nothing after the level is complete',
      () async {
    final game = MockGardenGame(Vector2(800, 600));
    final container = ProviderContainer(
      overrides: [
        disableAnimationsProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    container.read(gameInstanceProvider.notifier).setGame(game);
    container.read(currentLevelProvider.notifier).setLevel(
          vineLevel(20, 20, [singleCell('far', 19, 19)]),
        );
    container.read(vineStatesProvider);
    container.read(levelCompleteProvider.notifier).setComplete(true);

    final notifier = container.read(cameraStateProvider.notifier);
    notifier.updateZoom(1);
    await notifier.frameRemainingVines();

    final state = container.read(cameraStateProvider);
    expect(state.zoom, 1);
    expect(state.panOffset, vm.Vector2.zero());
  });

  test('frameRemainingVines leaves an in-flight camera move alone', () async {
    final game = MockGardenGame(Vector2(800, 600));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(gameInstanceProvider.notifier).setGame(game);
    container.read(currentLevelProvider.notifier).setLevel(
          vineLevel(20, 20, [singleCell('far', 19, 19)]),
        );
    container.read(vineStatesProvider);

    final notifier = container.read(cameraStateProvider.notifier);
    final first = notifier.animateToPosition(
      targetZoom: 1.4,
      targetPanOffset: vm.Vector2(12, 0),
    );
    var firstDone = false;
    first.whenComplete(() => firstDone = true);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    await notifier.frameRemainingVines().timeout(const Duration(seconds: 1));

    expect(firstDone, isFalse);
    expect(container.read(cameraStateProvider).isAnimating, isTrue);

    notifier.updateZoom(1.2);
    await first.timeout(const Duration(seconds: 2));
    expect(container.read(cameraStateProvider).zoom, 1.2);
    expect(container.read(cameraStateProvider).isAnimating, isFalse);
  });

  test('frameEntireBoard takes over an in-flight camera move', () async {
    final game = MockGardenGame(Vector2(800, 600));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(gameInstanceProvider.notifier).setGame(game);
    container.read(currentLevelProvider.notifier).setLevel(frameBoard(40, 40));
    final notifier = container.read(cameraStateProvider.notifier);

    final first = notifier.animateToPosition(
      targetZoom: 1.8,
      targetPanOffset: vm.Vector2(40, 10),
    );
    final framed = notifier.frameEntireBoard();
    await first.timeout(const Duration(milliseconds: 500));

    notifier.updateZoom(1.25);
    await framed.timeout(const Duration(seconds: 2));
    expect(container.read(cameraStateProvider).zoom, 1.25);
    expect(container.read(cameraStateProvider).isAnimating, isFalse);
  });
}
