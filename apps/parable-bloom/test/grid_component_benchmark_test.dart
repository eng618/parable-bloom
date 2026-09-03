import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';

void main() {
  test('Coordinate lookup benchmark and correctness test', () {
    // Create a realistic LevelData with 10 vines, each of length 8 on a 10x10 grid.
    final List<VineData> vines = [];
    for (int i = 0; i < 10; i++) {
      vines.add(VineData(
        id: 'vine_$i',
        headDirection: 'right',
        orderedPath: List.generate(8, (j) => {'x': i, 'y': j}),
      ));
    }

    final level = LevelData(
      id: 'benchmark_level',
      name: 'Benchmark Level',
      difficulty: 'hard',
      gridWidth: 10,
      gridHeight: 10,
      vines: vines,
      maxMoves: 100,
      minMoves: 10,
      complexity: 'high',
      grace: 0,
      mask: MaskData(mode: 'show-all', points: const []),
    );

    // Old lookup implementation (nested loops)
    VineData? oldLookup(int col, int row) {
      final worldX = col;
      final worldY = row;

      for (final vine in level.vines) {
        for (final cell in vine.orderedPath) {
          if (cell['x'] == worldX && cell['y'] == worldY) {
            return vine;
          }
        }
      }
      return null;
    }

    // New lookup implementation (Map lookup)
    final Map<(int, int), VineData> coordinateToVineMap = {};
    for (final vine in level.vines) {
      for (final cell in vine.orderedPath) {
        final x = cell['x'];
        final y = cell['y'];
        if (x != null && y != null) {
          coordinateToVineMap[(x, y)] = vine;
        }
      }
    }

    VineData? newLookup(int col, int row) {
      final worldX = col;
      final worldY = row;
      return coordinateToVineMap[(worldX, worldY)];
    }

    // Verify correctness: Both must return the exact same vine (or null) for all grid cells.
    for (int col = 0; col < 10; col++) {
      for (int row = 0; row < 10; row++) {
        final vineOld = oldLookup(col, row);
        final vineNew = newLookup(col, row);
        expect(vineNew?.id, equals(vineOld?.id));
      }
    }

    // Benchmark lookup of every cell 100,000 times
    const int iterations = 100000;

    final stopwatchOld = Stopwatch()..start();
    for (int i = 0; i < iterations; i++) {
      oldLookup(9, 7);
      oldLookup(9, 9);
    }
    stopwatchOld.stop();

    final stopwatchNew = Stopwatch()..start();
    for (int i = 0; i < iterations; i++) {
      newLookup(9, 7);
      newLookup(9, 9);
    }
    stopwatchNew.stop();

    print('=== Benchmark Results ($iterations iterations) ===');
    print(
        'Old Lookup (Nested Loop): ${stopwatchOld.elapsedMicroseconds} microseconds');
    print(
        'New Lookup (Map Lookup):  ${stopwatchNew.elapsedMicroseconds} microseconds');
    final speedup =
        stopwatchOld.elapsedMicroseconds / stopwatchNew.elapsedMicroseconds;
    print('Speedup: ${speedup.toStringAsFixed(2)}x faster');
    print('================================================');
  });
}
