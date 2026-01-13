import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/providers/game_providers.dart';
import 'package:parable_bloom/features/game/domain/services/level_solver_service.dart';
import 'package:parable_bloom/features/tutorial/domain/entities/lesson_data.dart';
import 'package:parable_bloom/core/vine_color_palette.dart';

void main() {
  final levelsDir = Directory('assets/levels');
  final lessonsDir = Directory('assets/lessons');

  if (!levelsDir.existsSync()) {
    test('Setup', () {
      fail('assets/levels directory not found');
    });
    return;
  }

  if (!lessonsDir.existsSync()) {
    test('Setup', () {
      fail('assets/lessons directory not found');
    });
    return;
  }

  final levelFiles = levelsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.contains('level_') && f.path.endsWith('.json'))
      .toList();

  final lessonFiles = lessonsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.contains('lesson_') && f.path.endsWith('.json'))
      .toList();

  final allFiles = [...levelFiles, ...lessonFiles];

  final env = Platform.environment;
  final startFilter = int.tryParse(env['PB_LEVEL_START'] ?? '');
  final endFilter = int.tryParse(env['PB_LEVEL_END'] ?? '');
  final batchSize = int.tryParse(env['PB_LEVEL_BATCH'] ?? '') ?? 10;

  // Sort files by level ID
  allFiles.sort((a, b) {
    final idA = _extractId(a.path);
    final idB = _extractId(b.path);
    return idA.compareTo(idB);
  });

  final filtered = allFiles.where((file) {
    final id = _extractId(file.path);
    if (startFilter != null && id < startFilter) return false;
    if (endFilter != null && id > endFilter) return false;
    return true;
  }).toList(growable: false);

  // Group by batches of 10
  for (var i = 0; i < filtered.length; i += batchSize) {
    final end =
        (i + batchSize < filtered.length) ? i + batchSize : filtered.length;
    final batch = filtered.sublist(i, end);
    if (batch.isEmpty) continue;

    final startId = _extractId(batch.first.path);
    final endId = _extractId(batch.last.path);

    group(
      'Levels/Lessons $startId-$endId',
      () {
        for (final file in batch) {
          final levelId = _extractId(file.path);
          test(
            'Level/Lesson $levelId validation',
            () async {
              await _validateLevel(file);
            },
            tags: ['level-solver'],
            timeout: Timeout(Duration(minutes: 2)),
          );
        }
      },
      skip: false,
    );
  }
}

int _extractId(String path) {
  if (path.contains('level_')) {
    return int.parse(path.split('level_').last.split('.').first);
  } else if (path.contains('lesson_')) {
    return int.parse(path.split('lesson_').last.split('.').first);
  } else {
    throw ArgumentError('Invalid file path: $path');
  }
}

LevelData _lessonToLevel(LessonData lesson) {
  final vines = lesson.vines
      .map(
        (v) => VineData(
          id: v.id,
          headDirection: v.headDirection,
          orderedPath: v.orderedPath,
        ),
      )
      .toList();

  return LevelData(
    id: lesson.id,
    name: 'Lesson ${lesson.id}',
    difficulty: 'tutorial',
    gridWidth: lesson.gridWidth,
    gridHeight: lesson.gridHeight,
    vines: vines,
    maxMoves: 999,
    minMoves: 0,
    complexity: 'tutorial',
    grace: 0,
    mask: MaskData(mode: 'show-all', points: const []),
  );
}

Future<void> _validateLevel(File levelFile) async {
  final jsonMap = json.decode(await levelFile.readAsString());

  expect(
    jsonMap is Map && jsonMap.containsKey('grid_size'),
    isTrue,
    reason: 'Missing grid_size in ${levelFile.path}',
  );

  final isLesson = levelFile.path.contains('lesson_');
  final level = isLesson
      ? _lessonToLevel(LessonData.fromJson(jsonMap as Map<String, dynamic>))
      : LevelData.fromJson(jsonMap as Map<String, dynamic>);

  expect(level.gridWidth, greaterThan(0));
  expect(level.gridHeight, greaterThan(0));

  // simple structural checks
  final occupied = <String, String>{};
  for (final vine in level.vines) {
    // Optional vine_color is a palette key.
    if (vine.vineColor != null) {
      final v = vine.vineColor!.trim();
      expect(
        VineColorPalette.isKnownKey(v),
        isTrue,
        reason:
            'Unknown vine_color key in ${levelFile.path} ${vine.id}: ${vine.vineColor}',
      );
    }

    for (final seg in vine.orderedPath) {
      final k = '${seg['x']},${seg['y']}';

      final x = seg['x'] as int;
      final y = seg['y'] as int;
      expect(
        x >= 0 && x < level.gridWidth && y >= 0 && y < level.gridHeight,
        isTrue,
        reason:
            'Out of bounds cell ($x,$y) in ${levelFile.path} ${vine.id} grid_size=[${level.gridWidth},${level.gridHeight}]',
      );

      expect(
        level.isCellVisible(x, y),
        isTrue,
        reason:
            'Vine occupies masked-out cell ($x,$y) in ${levelFile.path} ${vine.id}',
      );

      expect(
        occupied.containsKey(k),
        isFalse,
        reason: 'Overlap at $k in ${levelFile.path}',
      );
      occupied[k] = vine.id;
    }
  }

  for (final vine in level.vines) {
    expect(vine.orderedPath.length, greaterThanOrEqualTo(2));

    // Head/neck orientation: neck must be exactly one cell opposite the head_direction.
    // Equivalently, the vector from neck -> head must match head_direction.
    final head = vine.orderedPath[0];
    final neck = vine.orderedPath[1];
    final dx = (head['x'] as int) - (neck['x'] as int);
    final dy = (head['y'] as int) - (neck['y'] as int);
    switch (vine.headDirection) {
      case 'right':
        expect(
          dx,
          equals(1),
          reason: 'Head/neck mismatch in ${levelFile.path} ${vine.id}',
        );
        expect(
          dy,
          equals(0),
          reason: 'Head/neck mismatch in ${levelFile.path} ${vine.id}',
        );
        break;
      case 'left':
        expect(
          dx,
          equals(-1),
          reason: 'Head/neck mismatch in ${levelFile.path} ${vine.id}',
        );
        expect(
          dy,
          equals(0),
          reason: 'Head/neck mismatch in ${levelFile.path} ${vine.id}',
        );
        break;
      case 'up':
        expect(
          dx,
          equals(0),
          reason: 'Head/neck mismatch in ${levelFile.path} ${vine.id}',
        );
        expect(
          dy,
          equals(1),
          reason: 'Head/neck mismatch in ${levelFile.path} ${vine.id}',
        );
        break;
      case 'down':
        expect(
          dx,
          equals(0),
          reason: 'Head/neck mismatch in ${levelFile.path} ${vine.id}',
        );
        expect(
          dy,
          equals(-1),
          reason: 'Head/neck mismatch in ${levelFile.path} ${vine.id}',
        );
        break;
      default:
        fail(
          'Unknown head_direction ${vine.headDirection} in ${levelFile.path} ${vine.id}',
        );
    }

    for (int i = 1; i < vine.orderedPath.length; i++) {
      final dx = (vine.orderedPath[i]['x'] as int) -
          (vine.orderedPath[i - 1]['x'] as int);
      final dy = (vine.orderedPath[i]['y'] as int) -
          (vine.orderedPath[i - 1]['y'] as int);
      expect((dx.abs() + dy.abs()), equals(1));
    }
  }

  // circular-block detection using the canonical helpers
  expect(
    _detectCircularBlocking(level),
    isFalse,
    reason: 'Circular blocking detected in ${levelFile.path}',
  );

  // NOTE: Expensive solvability checks (search-based) are now performed by
  // the Go level-builder validator in CI. Keep Dart tests focused on
  // structural and fast validations to keep the test run reliable.
  // To run quick, targeted solver smoke checks use the separate
  // `test/level_solver_smoke_test.dart` which is gated by the
  // PB_RUN_HEAVY_LEVEL_CHECKS environment variable.
}

bool _detectCircularBlocking(LevelData level) {
  final occupied = <String, String>{};
  for (final vine in level.vines) {
    for (final s in vine.orderedPath) {
      occupied['${s['x']},${s['y']}'] = vine.id;
    }
  }

  final graph = <String, Set<String>>{};
  for (final vine in level.vines) {
    graph[vine.id] = <String>{};
  }

  for (final a in level.vines) {
    for (final b in level.vines) {
      if (a.id == b.id) continue;
      if (_vineBlocksVine(a, b, level, occupied)) graph[a.id]!.add(b.id);
    }
  }

  final visited = <String>{};
  final stack = <String>{};
  for (final id in graph.keys) {
    if (_hasCircularDependency(id, graph, visited, stack)) {
      return true;
    }
  }
  return false;
}

bool _vineBlocksVine(
  VineData blocker,
  VineData blocked,
  LevelData level,
  Map<String, String> occupied,
) {
  if (blocked.orderedPath.isEmpty) return false;
  final head = blocked.orderedPath[0];
  var tx = head['x'] as int;
  var ty = head['y'] as int;
  switch (blocked.headDirection) {
    case 'right':
      tx += 1;
      break;
    case 'left':
      tx -= 1;
      break;
    case 'up':
      ty += 1;
      break;
    case 'down':
      ty -= 1;
      break;
    default:
      return false;
  }
  return occupied['$tx,$ty'] == blocker.id;
}

bool _hasCircularDependency(
  String cur,
  Map<String, Set<String>> g,
  Set<String> vis,
  Set<String> stack,
) {
  if (stack.contains(cur)) return true;
  if (vis.contains(cur)) return false;
  vis.add(cur);
  stack.add(cur);
  for (final n in g[cur] ?? {}) {
    if (_hasCircularDependency(n, g, vis, stack)) {
      return true;
    }
  }
  stack.remove(cur);
  return false;
}
