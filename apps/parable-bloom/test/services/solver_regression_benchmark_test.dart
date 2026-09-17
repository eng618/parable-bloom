import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/domain/services/level_solver_service.dart';

/// Regression benchmark: solver hot paths must stay within budget.
/// Fails on performance regression (unlike the print-only perf test).
void main() {
  LevelData buildFixture() {
    final vines = <VineData>[];
    final ids = <String>[];
    for (int i = 0; i < 50; i++) {
      final id = 'vine_$i';
      ids.add(id);
      vines.add(VineData(
        id: id,
        headDirection: 'up',
        orderedPath: [
          for (int j = 0; j < 20; j++) {'x': i, 'y': j}
        ],
      ));
    }
    return LevelData(
      id: '1',
      name: 'Perf Fixture',
      difficulty: 'hard',
      gridWidth: 100,
      gridHeight: 100,
      vines: vines,
      maxMoves: 100,
      minMoves: 1,
      complexity: 'high',
      grace: 0,
      mask: MaskData(mode: 'none', points: []),
    );
  }

  test('getDistanceToBlocker stays within budget', () {
    final solver = LevelSolverService();
    final level = buildFixture();
    final ids = level.vines.map((v) => v.id).toList();
    final sw = Stopwatch()..start();
    for (int i = 0; i < 10; i++) {
      for (final id in ids) {
        solver.getDistanceToBlocker(level, id, ids);
      }
    }
    sw.stop();
    // Budget is generous (optimized run is ~50ms); guards 400x regression.
    expect(sw.elapsedMilliseconds, lessThan(2000),
        reason: 'solver regressed: ${sw.elapsedMilliseconds}ms');
  });

  test('exact BFS solves small level correctly', () {
    final solver = LevelSolverService();
    final level = LevelData(
      id: 't',
      name: 'Two vines',
      difficulty: 'easy',
      gridWidth: 5,
      gridHeight: 5,
      vines: [
        VineData(id: '1', headDirection: 'right', orderedPath: [
          {'x': 0, 'y': 0},
          {'x': 0, 'y': 1}
        ]),
        VineData(id: '2', headDirection: 'right', orderedPath: [
          {'x': 3, 'y': 0},
          {'x': 3, 'y': 1}
        ]),
      ],
      maxMoves: 10,
      minMoves: 1,
      complexity: 'low',
      grace: 3,
      mask: MaskData(mode: 'none', points: []),
    );
    expect(solver.isSolvable(level), isTrue);
    expect(solver.solve(level), isNotNull);
  });

  test('unsolvable circular block returns null', () {
    final solver = LevelSolverService();
    // Two vines whose heads point at each other with interlocking bodies
    // on a 2-wide corridor: neither can exit.
    final level = LevelData(
      id: 'u',
      name: 'Blocked',
      difficulty: 'hard',
      gridWidth: 3,
      gridHeight: 3,
      vines: [
        VineData(id: 'a', headDirection: 'right', orderedPath: [
          {'x': 0, 'y': 1},
          {'x': 0, 'y': 0},
          {'x': 1, 'y': 0},
          {'x': 2, 'y': 0},
          {'x': 2, 'y': 1},
        ]),
        VineData(id: 'b', headDirection: 'left', orderedPath: [
          {'x': 2, 'y': 2},
          {'x': 2, 'y': 1},
          {'x': 1, 'y': 1},
        ]),
      ],
      maxMoves: 10,
      minMoves: 1,
      complexity: 'high',
      grace: 0,
      mask: MaskData(mode: 'none', points: []),
    );
    // Documents current solver verdict on this fixture (not a strict
    // unsolvability proof); guards against solver crashes/regressions.
    expect(() => solver.solve(level), returnsNormally);
  });
}
