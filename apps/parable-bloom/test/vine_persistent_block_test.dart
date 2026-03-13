import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/providers/gameplay_state_providers.dart';

void main() {
  test('markAttempted persists showBlocked when attempted while blocked', () {
    final container = ProviderContainer(overrides: []);
    addTearDown(container.dispose);

    // Initialize a mock state where vine1 is currently blocked and not attempted
    final mockState = {
      'vine1': VineState(
        id: 'vine1',
        isBlocked: true,
        isCleared: false,
        hasBeenAttempted: false,
      ),
    };

    // Use a real notifier and inject the mock state directly
    final testContainer = ProviderContainer();
    addTearDown(testContainer.dispose);

    final notifier = testContainer.read(vineStatesProvider.notifier);

    // Inject our mock state
    notifier.state = mockState;

    // Sanity checks
    expect(notifier.state['vine1']!.hasBeenAttempted, isFalse);

    // Call markAttempted - should set hasBeenAttempted
    notifier.markAttempted('vine1');

    final updated = notifier.state['vine1']!;
    expect(updated.hasBeenAttempted, isTrue);

    // Now simulate solver recalculation setting isBlocked -> false
    notifier.state = {
      ...notifier.state,
      'vine1': notifier.state['vine1']!.copyWith(isBlocked: false),
    };

    // hasBeenAttempted should remain true
    expect(notifier.state['vine1']!.hasBeenAttempted, isTrue);

    // Resetting for a new level should clear hasBeenAttempted
    final level = LevelData(
      id: 1,
      name: 'L',
      difficulty: 'Seed',
      gridWidth: 2,
      gridHeight: 2,
      vines: [
        VineData(
          id: 'vine1',
          headDirection: 'right',
          orderedPath: [
            {'x': 0, 'y': 0},
            {'x': 1, 'y': 0},
          ],
        )
      ],
      maxMoves: 2,
      minMoves: 1,
      complexity: 'low',
      grace: 1,
      mask: MaskData(mode: 'show-all', points: const []),
    );

    notifier.resetForLevel(level);

    expect(notifier.state['vine1']!.hasBeenAttempted, isFalse);
  });

  test(
    'animatingClear vine is excluded from blockers during rapid interactions',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(vineStatesProvider.notifier);

      final level = LevelData(
        id: 99,
        name: 'Race Timing Regression',
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

      notifier.resetForLevel(level);

      // Baseline: v2 is blocked by v1 occupying the target cell directly ahead.
      expect(notifier.state['v2']!.isBlocked, isTrue);

      // Simulate first tap starting a clear animation.
      notifier.setAnimationState('v1', VineAnimationState.animatingClear);

      // During clear animation, v1 must stop blocking other vines.
      expect(notifier.state['v1']!.animationState,
          VineAnimationState.animatingClear);
      expect(notifier.state['v2']!.isBlocked, isFalse);

      // Simulate rapid second tap sequence while first vine is still animating.
      notifier.setAnimationState('v2', VineAnimationState.animatingBlocked);
      notifier.setAnimationState('v2', VineAnimationState.normal);

      // First vine should still be able to finish its clear state transition.
      notifier.setAnimationState('v1', VineAnimationState.cleared);
      notifier.clearVine('v1');

      expect(notifier.state['v1']!.isCleared, isTrue);
      expect(notifier.state['v1']!.animationState, VineAnimationState.cleared);
      expect(notifier.state['v2']!.animationState, VineAnimationState.normal);
      expect(notifier.state['v2']!.isBlocked, isFalse);
    },
  );

  test('markAttempted decrements grace only once per vine', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(vineStatesProvider.notifier);
    notifier.state = {
      'vine1': VineState(
        id: 'vine1',
        isBlocked: true,
        isCleared: false,
        hasBeenAttempted: false,
      ),
    };

    expect(container.read(graceProvider), 3);

    notifier.markAttempted('vine1');
    expect(container.read(graceProvider), 2);
    expect(notifier.state['vine1']!.hasBeenAttempted, isTrue);

    // Repeated blocked taps on the same vine should not consume extra hearts.
    notifier.markAttempted('vine1');
    expect(container.read(graceProvider), 2);
  });

  test('anyVineAnimating resets after rapid clear and blocked transitions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(vineStatesProvider.notifier);
    final level = LevelData(
      id: 100,
      name: 'Animation State Reset',
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

    notifier.resetForLevel(level);
    expect(container.read(anyVineAnimatingProvider), isFalse);

    notifier.setAnimationState('v1', VineAnimationState.animatingClear);
    expect(container.read(anyVineAnimatingProvider), isTrue);

    notifier.setAnimationState('v2', VineAnimationState.animatingBlocked);
    expect(container.read(anyVineAnimatingProvider), isTrue);

    notifier.setAnimationState('v2', VineAnimationState.normal);
    notifier.setAnimationState('v1', VineAnimationState.cleared);
    notifier.clearVine('v1');

    expect(container.read(anyVineAnimatingProvider), isFalse);
  });
}

// Minimal mock notifier used only for initialization in the test
class MockVineStatesNotifier extends VineStatesNotifier {
  final Map<String, VineState> mockState;

  MockVineStatesNotifier(this.mockState);

  @override
  Map<String, VineState> build() => mockState;
}
