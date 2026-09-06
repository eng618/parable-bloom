import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/application/providers/counter_providers.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';

LevelData _level() => LevelData(
      id: 'memo',
      name: 'Memo',
      gridWidth: 4,
      gridHeight: 4,
      difficulty: 'easy',
      maxMoves: 10,
      minMoves: 1,
      complexity: 'low',
      grace: 3,
      mask: MaskData(mode: 'show-all', points: []),
      vines: [
        VineData(
          id: 'vine_1',
          headDirection: 'right',
          orderedPath: [
            {'x': 0, 'y': 1},
            {'x': 1, 'y': 1},
          ],
        ),
      ],
    );

void main() {
  group('LevelTotalTapsNotifier.add', () {
    test('adds counts in a single notification', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(levelTotalTapsProvider.notifier).add(3);
      expect(container.read(levelTotalTapsProvider), 3);
    });
  });

  group('VineStatesNotifier memoization', () {
    test('repeat calculation with unchanged inputs reuses result', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final level = _level();
      container.read(currentLevelProvider.notifier).setLevel(level);
      final notifier = container.read(vineStatesProvider.notifier);
      notifier.resetForLevel(level);

      final first = container.read(vineStatesProvider);
      notifier.resetForLevel(level);
      final second = container.read(vineStatesProvider);

      expect(identical(first, second), isTrue);
    });

    test('changed animation state recomputes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final level = _level();
      container.read(currentLevelProvider.notifier).setLevel(level);
      final notifier = container.read(vineStatesProvider.notifier);
      notifier.resetForLevel(level);

      final before = container.read(vineStatesProvider)['vine_1']!;
      notifier.setAnimationState(
        'vine_1',
        VineAnimationState.animatingClear,
      );
      final after = container.read(vineStatesProvider)['vine_1']!;

      expect(before.animationState, VineAnimationState.normal);
      expect(after.animationState, VineAnimationState.animatingClear);
    });
  });
}
