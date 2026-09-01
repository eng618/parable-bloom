import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/application/providers/camera_providers.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/presentation/widgets/garden_game.dart';

import 'package:flame/game.dart' show Vector2;

class MockGardenGame extends GardenGame {
  final Vector2 mockSize;
  MockGardenGame(this.mockSize) : super(ref: null);

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

    // Set initial centered camera state
    cameraNotifier.resetToCenter();
    expect(container.read(cameraStateProvider).panOffset, vm.Vector2.zero());

    // Call ensureVineVisible for v1 which is in the top-right corner, off-screen under default view + margin
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
}
