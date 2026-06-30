import '../../lib/features/game/domain/services/level_solver_service.dart';
import '../../lib/features/game/domain/entities/level_data.dart';

void main() {
  final service = LevelSolverService();

  // Create a dummy level
  final vines = <VineData>[];
  for (var i = 0; i < 20; i++) {
    vines.add(VineData(
      id: 'vine_$i',
      headDirection: 'up',
      orderedPath: [
        {'x': i, 'y': 0},
        {'x': i, 'y': 1},
        {'x': i, 'y': 2},
      ],
    ));
  }

  final level = LevelData(
    id: 'test_level',
    name: 'Test Level',
    difficulty: 'hard',
    gridWidth: 30,
    gridHeight: 30,
    vines: vines,
    maxMoves: 100,
    minMoves: 10,
    complexity: 'high',
    grace: 0,
    mask: MaskData(mode: 'show-all', points: []),
  );

  final activeVines = vines.map((v) => v.id).toList();

  print('Running baseline benchmark...');
  final stopwatch = Stopwatch()..start();

  int totalDistance = 0;
  for (var i = 0; i < 1000; i++) {
    for (final vine in vines) {
      totalDistance += service.getDistanceToBlocker(level, vine.id, activeVines);
    }
  }

  stopwatch.stop();
  print('Time taken: ${stopwatch.elapsedMilliseconds} ms');
  print('Total distance (checksum): $totalDistance');
}
