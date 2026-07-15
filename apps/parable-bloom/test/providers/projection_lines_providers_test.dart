import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';

// Mock notifier for testing
class MockVineStatesNotifier extends VineStatesNotifier {
  final Map<String, VineState> mockState;

  MockVineStatesNotifier(this.mockState);

  @override
  Map<String, VineState> build() {
    return mockState;
  }
}

void main() {
  group('Projection Lines Providers', () {
    test('projectionLinesVisibleProvider should initialize with false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isVisible = container.read(projectionLinesVisibleProvider);
      expect(isVisible, false);
    });

    test('projectionLinesVisibleProvider should toggle visibility', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initially false
      expect(container.read(projectionLinesVisibleProvider), false);

      // Set to true
      container.read(projectionLinesVisibleProvider.notifier).setVisible(true);
      expect(container.read(projectionLinesVisibleProvider), true);

      // Toggle using toggle method
      container.read(projectionLinesVisibleProvider.notifier).toggle();
      expect(container.read(projectionLinesVisibleProvider), false);

      // Toggle back to true
      container.read(projectionLinesVisibleProvider.notifier).toggle();
      expect(container.read(projectionLinesVisibleProvider), true);
    });

    test('anyVineAnimatingProvider should return false when no vines animating',
        () {
      final container = ProviderContainer(
        overrides: [
          vineStatesProvider.overrideWith(() => MockVineStatesNotifier({})),
        ],
      );
      addTearDown(container.dispose);

      final isAnimating = container.read(anyVineAnimatingProvider);
      expect(isAnimating, false);
    });

    test(
        'anyVineAnimatingProvider should return true when a vine is animating clear',
        () {
      final container = ProviderContainer(
        overrides: [
          vineStatesProvider.overrideWith(() => MockVineStatesNotifier({
                'vine1': VineState(
                  id: 'vine1',
                  isBlocked: false,
                  isCleared: false,
                  animationState: VineAnimationState.animatingClear,
                ),
              })),
        ],
      );
      addTearDown(container.dispose);

      final isAnimating = container.read(anyVineAnimatingProvider);
      expect(isAnimating, true);
    });

    test(
        'anyVineAnimatingProvider should return true when a vine is animating blocked',
        () {
      final container = ProviderContainer(
        overrides: [
          vineStatesProvider.overrideWith(() => MockVineStatesNotifier({
                'vine1': VineState(
                  id: 'vine1',
                  isBlocked: true,
                  isCleared: false,
                  animationState: VineAnimationState.animatingBlocked,
                ),
              })),
        ],
      );
      addTearDown(container.dispose);

      final isAnimating = container.read(anyVineAnimatingProvider);
      expect(isAnimating, true);
    });

    test(
        'anyVineAnimatingProvider should return false when vine is in normal state',
        () {
      final container = ProviderContainer(
        overrides: [
          vineStatesProvider.overrideWith(() => MockVineStatesNotifier({
                'vine1': VineState(
                  id: 'vine1',
                  isBlocked: false,
                  isCleared: false,
                  animationState: VineAnimationState.normal,
                ),
              })),
        ],
      );
      addTearDown(container.dispose);

      final isAnimating = container.read(anyVineAnimatingProvider);
      expect(isAnimating, false);
    });

    test(
        'anyVineAnimatingProvider should return true when any vine is animating among multiple',
        () {
      final container = ProviderContainer(
        overrides: [
          vineStatesProvider.overrideWith(() => MockVineStatesNotifier({
                'vine1': VineState(
                  id: 'vine1',
                  isBlocked: false,
                  isCleared: false,
                  animationState: VineAnimationState.normal,
                ),
                'vine2': VineState(
                  id: 'vine2',
                  isBlocked: false,
                  isCleared: false,
                  animationState: VineAnimationState.animatingClear,
                ),
                'vine3': VineState(
                  id: 'vine3',
                  isBlocked: false,
                  isCleared: false,
                  animationState: VineAnimationState.normal,
                ),
              })),
        ],
      );
      addTearDown(container.dispose);

      final isAnimating = container.read(anyVineAnimatingProvider);
      expect(isAnimating, true);
    });

    test('hintedVineIdsProvider should initialize with an empty set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final hintedVines = container.read(hintedVineIdsProvider);
      expect(hintedVines, isEmpty);
    });

    test('hintedVineIdsProvider should add hinted vine IDs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initially empty
      expect(container.read(hintedVineIdsProvider), isEmpty);

      // Add vine_1
      container.read(hintedVineIdsProvider.notifier).add('vine_1');
      expect(container.read(hintedVineIdsProvider), contains('vine_1'));
      expect(container.read(hintedVineIdsProvider).length, 1);

      // Add vine_2
      container.read(hintedVineIdsProvider.notifier).add('vine_2');
      expect(container.read(hintedVineIdsProvider), contains('vine_1'));
      expect(container.read(hintedVineIdsProvider), contains('vine_2'));
      expect(container.read(hintedVineIdsProvider).length, 2);
    });

    test('hintedVineIdsProvider should clear hinted vine IDs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Add vine_1
      container.read(hintedVineIdsProvider.notifier).add('vine_1');
      expect(container.read(hintedVineIdsProvider), contains('vine_1'));

      // Clear
      container.read(hintedVineIdsProvider.notifier).clear();
      expect(container.read(hintedVineIdsProvider), isEmpty);
    });
  });
}
