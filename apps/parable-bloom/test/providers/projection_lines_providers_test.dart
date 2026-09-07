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
  group('ProjectionMode state', () {
    test('initializes hidden', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mode = container.read(projectionModeProvider);
      expect(mode.showAll, isFalse);
      expect(mode.hintedVineIds, isEmpty);
      expect(mode.isHidden, isTrue);
    });

    test('toggleAll flips show-all without touching hints', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(projectionModeProvider.notifier);

      notifier.hint('vine_1');
      notifier.toggleAll();

      var mode = container.read(projectionModeProvider);
      expect(mode.showAll, isTrue);
      expect(mode.hintedVineIds, contains('vine_1'));

      notifier.toggleAll();
      mode = container.read(projectionModeProvider);
      expect(mode.showAll, isFalse);
      expect(mode.hintedVineIds, contains('vine_1'));
    });

    test('hint accumulates vine IDs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(projectionModeProvider.notifier);

      notifier.hint('vine_1');
      notifier.hint('vine_2');

      final mode = container.read(projectionModeProvider);
      expect(mode.hintedVineIds, containsAll(['vine_1', 'vine_2']));
      expect(mode.showAll, isFalse);
    });

    test('clearHints keeps show-all', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(projectionModeProvider.notifier);

      notifier.toggleAll();
      notifier.hint('vine_1');
      notifier.clearHints();

      final mode = container.read(projectionModeProvider);
      expect(mode.hintedVineIds, isEmpty);
      expect(mode.showAll, isTrue);
    });

    test('setShowAll is idempotent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(projectionModeProvider.notifier);

      var notifications = 0;
      container.listen<ProjectionMode>(
        projectionModeProvider,
        (_, __) => notifications++,
      );

      notifier.setShowAll(false);
      expect(notifications, 0);

      notifier.setShowAll(true);
      expect(notifications, 1);
      expect(container.read(projectionModeProvider).showAll, isTrue);
    });

    test('mode equality distinguishes states', () {
      expect(
        const ProjectionMode(),
        const ProjectionMode(showAll: false, hintedVineIds: {}),
      );
      expect(
        const ProjectionMode(showAll: true),
        isNot(const ProjectionMode()),
      );
      expect(
        const ProjectionMode(hintedVineIds: {'a'}),
        const ProjectionMode(hintedVineIds: {'a'}),
      );
    });
  });

  group('anyVineAnimatingProvider', () {
    test('should return false when no vines animating', () {
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
  });
}
