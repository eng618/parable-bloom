import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/providers/game_providers.dart';
import 'package:parable_bloom/features/game/domain/services/level_solver_service.dart';

void main() {
  test('Clean: validate levels and helper logic', () async {
    final levelsDir = Directory('assets/levels');
    if (!levelsDir.existsSync()) fail('assets/levels directory not found');

    final levelFiles = levelsDir.listSync().whereType<File>().where(
      (f) => f.path.contains('level_') && f.path.endsWith('.json'),
    );

    for (final levelFile in levelFiles) {
      final jsonMap = json.decode(await levelFile.readAsString());
      final level = LevelData.fromJson(jsonMap);

      // simple structural checks
      final occupied = <String, String>{};
      for (final vine in level.vines) {
        for (final seg in vine.orderedPath) {
          final k = '${seg['x']},${seg['y']}';
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
        for (int i = 1; i < vine.orderedPath.length; i++) {
          final dx =
              (vine.orderedPath[i]['x'] as int) -
              (vine.orderedPath[i - 1]['x'] as int);
          final dy =
              (vine.orderedPath[i]['y'] as int) -
              (vine.orderedPath[i - 1]['y'] as int);
          expect((dx.abs() + dy.abs()), equals(1));
        }
      }

      // circular-block detection using the canonical helpers
      expect(_detectCircularBlocking(level), isFalse);

      // solvability
      final solver = LevelSolverService();
      expect(
        solver.solve(level),
        isNotNull,
        reason: 'Level ${levelFile.path} is unsolvable',
      );
    }
  });
}

bool _detectCircularBlocking(LevelData level) {
  final occupied = <String, String>{};
  for (final vine in level.vines) {
    for (final s in vine.orderedPath) occupied['${s['x']},${s['y']}'] = vine.id;
  }

  final graph = <String, Set<String>>{};
  for (final vine in level.vines) graph[vine.id] = <String>{};

  for (final a in level.vines) {
    for (final b in level.vines) {
      if (a.id == b.id) continue;
      if (_vineBlocksVine(a, b, level, occupied)) graph[a.id]!.add(b.id);
    }
  }

  final visited = <String>{};
  final stack = <String>{};
  for (final id in graph.keys)
    if (_hasCircularDependency(id, graph, visited, stack)) return true;
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
  for (final n in g[cur] ?? {})
    if (_hasCircularDependency(n, g, vis, stack)) return true;
  stack.remove(cur);
  return false;
}
