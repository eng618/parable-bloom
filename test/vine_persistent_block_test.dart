import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/providers/game_providers.dart';

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
}

// Minimal mock notifier used only for initialization in the test
class MockVineStatesNotifier extends VineStatesNotifier {
  final Map<String, VineState> mockState;

  MockVineStatesNotifier(this.mockState);

  @override
  Map<String, VineState> build() => mockState;
}
