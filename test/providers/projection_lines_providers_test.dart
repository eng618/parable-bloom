import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parable_bloom/providers/game_providers.dart';

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

      // Toggle to true
      container.read(projectionLinesVisibleProvider.notifier).state = true;
      expect(container.read(projectionLinesVisibleProvider), true);

      // Toggle back to false
      container.read(projectionLinesVisibleProvider.notifier).state = false;
      expect(container.read(projectionLinesVisibleProvider), false);
    });

    test('anyVineAnimatingProvider should return false when no vines animating',
        () {
      final container = ProviderContainer(
        overrides: [
          vineStatesProvider.overrideWith((ref) => {}),
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
          vineStatesProvider.overrideWith((ref) => {
                'vine1': VineState(
                  id: 'vine1',
                  isBlocked: false,
                  isCleared: false,
                  animationState: VineAnimationState.animatingClear,
                ),
              }),
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
          vineStatesProvider.overrideWith((ref) => {
                'vine1': VineState(
                  id: 'vine1',
                  isBlocked: true,
                  isCleared: false,
                  animationState: VineAnimationState.animatingBlocked,
                ),
              }),
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
          vineStatesProvider.overrideWith((ref) => {
                'vine1': VineState(
                  id: 'vine1',
                  isBlocked: false,
                  isCleared: false,
                  animationState: VineAnimationState.normal,
                ),
              }),
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
          vineStatesProvider.overrideWith((ref) => {
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
              }),
        ],
      );
      addTearDown(container.dispose);

      final isAnimating = container.read(anyVineAnimatingProvider);
      expect(isAnimating, true);
    });
  });
}
