import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/application/providers/counter_providers.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/application/providers/solver_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/domain/services/level_solver_service.dart';

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

    test('wiggle reuses the blocking result and a clear recomputes it', () {
      final solver = _CountingSolver();
      final container = ProviderContainer(
        overrides: [
          levelSolverServiceProvider.overrideWithValue(solver),
        ],
      );
      addTearDown(container.dispose);

      final level = _blockedPairLevel();
      container.read(currentLevelProvider.notifier).setLevel(level);
      final notifier = container.read(vineStatesProvider.notifier);
      notifier.resetForLevel(level);

      final solvedOnce = solver.blockedChecks;
      expect(solvedOnce, greaterThan(0));
      expect(container.read(vineStatesProvider)['v2']!.isBlocked, isTrue);

      notifier.setAnimationState('v2', VineAnimationState.animatingBlocked);
      expect(container.read(vineStatesProvider)['v2']!.isBlocked, isFalse);
      expect(solver.blockedChecks, solvedOnce);

      notifier.setAnimationState('v2', VineAnimationState.normal);
      expect(container.read(vineStatesProvider)['v2']!.isBlocked, isTrue);
      expect(solver.blockedChecks, solvedOnce);

      notifier.setAnimationState('v1', VineAnimationState.animatingClear);
      expect(container.read(vineStatesProvider)['v2']!.isBlocked, isFalse);
      expect(solver.blockedChecks, greaterThan(solvedOnce));

      final afterClear = solver.blockedChecks;
      notifier.setAnimationState('v1', VineAnimationState.cleared);
      expect(container.read(vineStatesProvider)['v2']!.isBlocked, isFalse);
      expect(solver.blockedChecks, afterClear);
    });
  });
}

class _CountingSolver extends LevelSolverService {
  int blockedChecks = 0;

  @override
  bool isVineBlockedInState(
    LevelData level,
    String vineId,
    List<String> activeVineIds,
  ) {
    blockedChecks++;
    return super.isVineBlockedInState(level, vineId, activeVineIds);
  }
}

/// v2's next cell is occupied by v1, so v2 starts blocked.
LevelData _blockedPairLevel() => LevelData(
      id: 'memo-pair',
      name: 'Memo Pair',
      gridWidth: 4,
      gridHeight: 3,
      difficulty: 'easy',
      maxMoves: 6,
      minMoves: 2,
      complexity: 'low',
      grace: 2,
      mask: MaskData(mode: 'show-all', points: []),
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
    );
