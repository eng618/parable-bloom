import 'dart:convert';
import 'dart:io';
import 'dart:math';

void main(List<String> args) {
  final parsed = _parseArgs(args);

  final outDir = Directory(parsed.outDir);
  if (!outDir.existsSync()) {
    stderr.writeln('Output directory not found: ${outDir.path}');
    exitCode = 2;
    return;
  }

  final startId = parsed.startId;
  final endId = parsed.endId;
  final moduleToRun = parsed.moduleId;

  final modules = _loadModules(outDir);
  final transcendentEndLevels = modules.map((m) => m.end).toSet();

  int actualStart = startId ?? (_detectNextLevelId(outDir) ?? 1);
  int actualEnd = endId ?? (actualStart + parsed.count - 1);

  if (moduleToRun != null) {
    final m = modules.firstWhere(
      (m) => m.id == moduleToRun,
      orElse: () => throw Exception('Module $moduleToRun not found'),
    );
    actualStart = m.start;
    actualEnd = m.end;
    stdout.writeln('Generating Module ${m.id}: Levels $actualStart-$actualEnd');
  }

  for (int levelId = actualStart; levelId <= actualEnd; levelId++) {
    final file = File('${outDir.path}/level_$levelId.json');
    if (file.existsSync() && !parsed.overwrite) {
      stderr.writeln(
        'Refusing to overwrite existing file: ${file.path} (pass --overwrite)',
      );
      exitCode = 2;
      return;
    }

    final levelJson = _generateSolvableLevel(
      levelId,
      modules: modules,
      transcendentEndLevels: transcendentEndLevels,
    );
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(levelJson)}\n',
    );
    stdout.writeln('Wrote ${file.path}');
  }
}

Map<String, dynamic> _generateSolvableLevel(
  int levelId, {
  required List<_ModuleRange> modules,
  required Set<int> transcendentEndLevels,
}) {
  // Deterministic retries: for a given levelId we always try the same sequence
  // of seeds, so generation stays reproducible.
  const maxAttempts = 100;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final seed = (levelId * 1000) + attempt;

    // Relax coverage gradually: start at 0.85 (above 75% min), lower if struggling
    final coverageTarget = attempt > 50 ? 0.78 : (attempt > 20 ? 0.82 : 0.85);

    final json = _generateLevel(
      levelId,
      modules: modules,
      transcendentEndLevels: transcendentEndLevels,
      seed: seed,
      targetCoverage: coverageTarget,
    );

    try {
      final level = _LiteLevel.fromJson(json);

      if (_detectCircularBlockingLite(level)) continue;
      if (_isSolvableLite(level)) {
        return json;
      }
    } catch (_) {
      // If parsing fails for any reason, try another attempt.
      continue;
    }
  }

  // As a last resort, return a trivially solvable level BUT with correct grid size.
  final (gridWidth, gridHeight) = _gridSizeForLevel(levelId, modules);

  final fallback = {
    'id': levelId,
    'name': 'Level $levelId',
    'difficulty':
        transcendentEndLevels.contains(levelId) ? 'Transcendent' : 'Seedling',
    'grid_size': [gridWidth, gridHeight],
    'mask': {'mode': 'show-all', 'points': []},
    'vines': [
      {
        'id': 'vine_1',
        'head_direction': 'left',
        'ordered_path': [
          {'x': 0, 'y': (gridHeight / 2).floor()},
          {'x': 1, 'y': (gridHeight / 2).floor()},
        ],
        'vine_color': 'default',
      },
    ],
    'max_moves': 1,
    'min_moves': 0,
    'complexity': 'low',
    'grace': transcendentEndLevels.contains(levelId) ? 4 : 3,
  };
  return fallback;
}

Map<String, dynamic> _generateLevel(
  int levelId, {
  required List<_ModuleRange> modules,
  required Set<int> transcendentEndLevels,
  int? seed,
  double targetCoverage = 0.95,
}) {
  final rng = Random(seed ?? levelId);
  final isTranscendent = transcendentEndLevels.contains(levelId);

  final tier = _difficultyTierForLevel(levelId, modules);
  final (gridWidth, gridHeight) = _gridSizeForLevel(levelId, modules);
  final totalCells = gridWidth * gridHeight;

  final blockedProbability =
      (0.22 + (tier * 0.06) + (isTranscendent ? 0.08 : 0.0)).clamp(0.18, 0.45);

  final vines = <Map<String, dynamic>>[];
  final occupiedBy = <String, String>{};

  // Start with more clearable vines on harder levels:
  // Seedling: 2, Nurturing: 2, Flourishing: 5, Transcendent: 8
  final initialClearableCount = switch (tier) {
    0 || 1 => 2,
    2 => 5,
    _ => 8, // Transcendent needs more initial vines for large grids
  };

  for (int i = 0; i < initialClearableCount; i++) {
    final lengthHint = _getBellCurveLength(rng, gridWidth, gridHeight, tier);
    final vine = _tryGenerateClearableWindingVine(
      vineIndex: vines.length,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      occupiedBy: occupiedBy,
      rng: rng,
      lengthHint: lengthHint,
      existingVines: vines,
    );
    if (vine != null) {
      vines.add(vine);
      for (final p in vine['ordered_path']) {
        occupiedBy['${p['x']},${p['y']}'] = vine['id'];
      }
    }
  }

  int stalled = 0;
  // Fill until we reach target coverage
  while (occupiedBy.length < totalCells * targetCoverage) {
    final vineIndex = vines.length;
    final lengthHint = _getBellCurveLength(rng, gridWidth, gridHeight, tier);

    // Keep the blocking graph acyclic by only allowing vines to be blocked by
    // already-placed vines.
    final wantBlocked =
        occupiedBy.isNotEmpty && (rng.nextDouble() < blockedProbability);

    final vine = wantBlocked
        ? _tryGenerateBlockedWindingVine(
            vineIndex: vineIndex,
            gridWidth: gridWidth,
            gridHeight: gridHeight,
            occupiedBy: occupiedBy,
            rng: rng,
            lengthHint: lengthHint,
            existingVines: vines,
          )
        : _tryGenerateClearableWindingVine(
            vineIndex: vineIndex,
            gridWidth: gridWidth,
            gridHeight: gridHeight,
            occupiedBy: occupiedBy,
            rng: rng,
            lengthHint: lengthHint,
            existingVines: vines,
          );

    if (vine == null) {
      stalled++;
      // Extremely generous stall threshold for large grids to pack vines.
      // For a 900-cell grid, allow 27,000+ attempts.
      final stallLimit = (totalCells * 30).clamp(500, 30000);
      if (stalled >= stallLimit) break;
      continue;
    }

    stalled = 0;
    vines.add(vine);
    for (final p in vine['ordered_path']) {
      occupiedBy['${p['x']},${p['y']}'] = vine['id'];
    }
  }

  // Ensure there's at least one vine; if winding generation fails entirely,
  // fall back to a single simple vine.
  if (vines.isEmpty) {
    final y = (gridHeight / 2).floor();
    final head = {'x': 0, 'y': y};
    final neck = {'x': 1, 'y': y};
    vines.add({
      'id': 'vine_1',
      'head_direction': 'left',
      'ordered_path': [head, neck],
      'vine_color': 'default',
    });
  }

  final difficulty = switch (tier) {
    0 => 'Seedling',
    1 => 'Nurturing',
    2 => 'Flourishing',
    3 => 'Transcendent',
    _ => 'Transcendent',
  };

  final complexity = switch (tier) {
    0 => 'low',
    1 => 'medium',
    2 => 'high',
    3 => 'extreme',
    _ => 'extreme',
  };

  return {
    'id': levelId,
    'name': 'Level $levelId',
    'difficulty': difficulty,
    'grid_size': [gridWidth, gridHeight],
    'mask': {'mode': 'show-all', 'points': []},
    'vines': vines,
    'max_moves': (vines.length + (isTranscendent ? 2 : 0)).clamp(1, 999),
    'min_moves': 0,
    'complexity': complexity,
    'grace': isTranscendent ? 4 : 3,
  };
}

class _Pt {
  final int x;
  final int y;
  const _Pt(this.x, this.y);
  String get key => '$x,$y';
}

class _LiteVine {
  final String id;
  final String headDirection;
  final List<_Pt> path;
  final Set<String> cells;

  _LiteVine({required this.id, required this.headDirection, required this.path})
      : cells = {for (final p in path) p.key};

  factory _LiteVine.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final headDirection = json['head_direction'] as String;
    final rawPath = json['ordered_path'] as List;
    final path = rawPath
        .map((e) => _Pt((e['x'] as num).toInt(), (e['y'] as num).toInt()))
        .toList(growable: false);
    return _LiteVine(id: id, headDirection: headDirection, path: path);
  }
}

class _LiteLevel {
  final int id;
  final int width;
  final int height;
  final List<_LiteVine> vines;

  _LiteLevel({
    required this.id,
    required this.width,
    required this.height,
    required this.vines,
  });

  factory _LiteLevel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num).toInt();
    final grid = (json['grid_size'] as List).cast<num>();
    final width = grid[0].toInt();
    final height = grid[1].toInt();
    final vines = (json['vines'] as List)
        .cast<Map>()
        .map((v) => _LiteVine.fromJson(v.cast<String, dynamic>()))
        .toList(growable: false);
    return _LiteLevel(id: id, width: width, height: height, vines: vines);
  }
}

bool _detectCircularBlockingLite(_LiteLevel level) {
  final occupied = <String, String>{};
  for (final vine in level.vines) {
    for (final p in vine.path) {
      occupied[p.key] = vine.id;
    }
  }

  final graph = <String, Set<String>>{
    for (final v in level.vines) v.id: <String>{},
  };

  for (final blocked in level.vines) {
    if (blocked.path.isEmpty) continue;
    final head = blocked.path.first;
    final (dx, dy) = _deltaForDirection(blocked.headDirection);
    final tx = head.x + dx;
    final ty = head.y + dy;
    final blockerId = occupied['$tx,$ty'];
    if (blockerId != null && blockerId != blocked.id) {
      graph[blockerId]!.add(blocked.id);
    }
  }

  final visited = <String>{};
  final stack = <String>{};

  bool dfs(String cur) {
    if (stack.contains(cur)) return true;
    if (visited.contains(cur)) return false;
    visited.add(cur);
    stack.add(cur);
    for (final n in graph[cur] ?? const <String>{}) {
      if (dfs(n)) return true;
    }
    stack.remove(cur);
    return false;
  }

  for (final id in graph.keys) {
    if (dfs(id)) return true;
  }
  return false;
}

bool _isSolvableLite(_LiteLevel level) {
  // Use a greedy solver simulation.
  // Since we generate levels by adding vines that are either clearable or
  // blocked by existing vines (reverse removal order), a greedy removal
  // strategy is a strong heuristic for solvability.
  // It is much faster than BFS for high vine counts (N > 25).

  final currentVines = level.vines.toList();
  final occupied = <String>{};

  // Initial occupation
  for (final v in currentVines) {
    occupied.addAll(v.cells);
  }

  bool progress = true;
  while (progress && currentVines.isNotEmpty) {
    progress = false;

    // Find a vine that can clear
    for (int i = 0; i < currentVines.length; i++) {
      final vine = currentVines[i];
      if (_canVineClearLite(level, vine, occupied)) {
        // Remove it
        occupied.removeAll(vine.cells);
        currentVines.removeAt(i);
        progress = true;
        break; // Restart search with new state
      }
    }
  }

  return currentVines.isEmpty;
}

bool _canVineClearLite(
  _LiteLevel level,
  _LiteVine vine,
  Set<String> occupiedAll,
) {
  if (vine.path.length < 2) return false;
  var current = vine.path;
  final (dx, dy) = _deltaForDirection(vine.headDirection);

  final maxCheckDistance =
      (level.width + level.height + vine.path.length + 10).clamp(10, 300);

  for (var step = 0; step < maxCheckDistance; step++) {
    final head = current.first;
    final newHead = _Pt(head.x + dx, head.y + dy);
    final next = <_Pt>[newHead, ...current.take(current.length - 1)];

    for (final p in next) {
      if (occupiedAll.contains(p.key) && !vine.cells.contains(p.key)) {
        return false;
      }
    }

    if (newHead.x < 0 ||
        newHead.x >= level.width ||
        newHead.y < 0 ||
        newHead.y >= level.height) {
      return true;
    }

    current = next;
  }

  return false;
}

int _difficultyTierForLevel(int levelId, List<_ModuleRange> modules) {
  // Find which module this level belongs to
  for (final m in modules) {
    if (levelId >= m.start && levelId <= m.end) {
      final moduleLength = m.end - m.start + 1;
      final positionInModule = levelId - m.start; // 0-indexed

      // Tutorial (Module 1): All Seedling
      if (m.id == 1) return 0;

      // Standard progression within each module:
      // - First ~33%: Seedling
      // - Next ~33%: Nurturing
      // - Next ~27%: Flourishing
      // - Final level: Transcendent

      if (positionInModule == moduleLength - 1) {
        // Last level in module is always Transcendent
        return 3;
      } else if (positionInModule < moduleLength * 0.33) {
        return 0; // Seedling
      } else if (positionInModule < moduleLength * 0.66) {
        return 1; // Nurturing
      } else {
        return 2; // Flourishing
      }
    }
  }

  // Fallback for levels not in any module (shouldn't happen)
  return 0;
}

Map<String, dynamic>? _tryGenerateClearableWindingVine({
  required int vineIndex,
  required int gridWidth,
  required int gridHeight,
  required Map<String, String> occupiedBy,
  required Random rng,
  required int lengthHint,
  required List<Map<String, dynamic>> existingVines,
}) {
  // Clearable means the head's next cell is out-of-bounds.
  const boundarySides = ['left', 'right', 'bottom', 'top'];

  final targetLen = (2 + rng.nextInt(3 + (lengthHint.clamp(0, 8)))).clamp(
    2,
    12,
  );

  for (int attempt = 0; attempt < 120; attempt++) {
    final side = boundarySides[rng.nextInt(boundarySides.length)];

    final (headX, headY, headDir) = switch (side) {
      'left' => (0, rng.nextInt(gridHeight), 'left'),
      'right' => (gridWidth - 1, rng.nextInt(gridHeight), 'right'),
      'bottom' => (rng.nextInt(gridWidth), 0, 'down'),
      _ => (rng.nextInt(gridWidth), gridHeight - 1, 'up'),
    };

    final (dx, dy) = _deltaForDirection(headDir);

    // Neck must be exactly one cell opposite head_direction.
    final neckX = headX - dx;
    final neckY = headY - dy;
    if (neckX < 0 || neckX >= gridWidth || neckY < 0 || neckY >= gridHeight) {
      continue;
    }

    final headKey = '$headX,$headY';
    final neckKey = '$neckX,$neckY';
    if (occupiedBy.containsKey(headKey) || occupiedBy.containsKey(neckKey)) {
      continue;
    }

    final path = <Map<String, int>>[
      {'x': headX, 'y': headY},
      {'x': neckX, 'y': neckY},
    ];

    final used = <String>{headKey, neckKey};

    var curX = neckX;
    var curY = neckY;
    for (int step = 0; step < targetLen - 2; step++) {
      final next = _pickNextTailCell(
        gridWidth: gridWidth,
        gridHeight: gridHeight,
        curX: curX,
        curY: curY,
        occupied: occupiedBy.keys.toSet(),
        used: used,
        rng: rng,
      );
      if (next == null) break;
      curX = next.$1;
      curY = next.$2;
      final k = '$curX,$curY';
      used.add(k);
      path.add({'x': curX, 'y': curY});
    }

    if (path.length < 2) continue;

    final vineId = 'vine_${vineIndex + 1}';

    // Must be truly clearable given current occupied cells.
    if (!_canVineClear(
      vineId: vineId,
      headDirection: headDir,
      orderedPath: path,
      occupiedBy: occupiedBy,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      ignoredVineIds: {vineId},
    )) {
      continue;
    }

    // Commit.
    for (final cell in path) {
      occupiedBy['${cell['x']},${cell['y']}'] = vineId;
    }

    // Adding this vine must not deadlock the level.
    if (!_anyVineClearable(
      vines: [
        ...existingVines,
        {
          'id': vineId,
          'head_direction': headDir,
          'ordered_path': path,
          'vine_color': 'default',
        },
      ],
      occupiedBy: occupiedBy,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
    )) {
      // Roll back.
      for (final cell in path) {
        occupiedBy.remove('${cell['x']},${cell['y']}');
      }
      continue;
    }

    return {
      'id': vineId,
      'head_direction': headDir,
      'ordered_path': path,
      'vine_color': 'default',
    };
  }

  return null;
}

Map<String, dynamic>? _tryGenerateBlockedWindingVine({
  required int vineIndex,
  required int gridWidth,
  required int gridHeight,
  required Map<String, String> occupiedBy,
  required Random rng,
  required int lengthHint,
  required List<Map<String, dynamic>> existingVines,
}) {
  if (occupiedBy.isEmpty) return null;

  final targetLen = (2 + rng.nextInt(3 + (lengthHint.clamp(0, 8)))).clamp(
    2,
    10,
  );
  final occupiedKeys = occupiedBy.keys.toList(growable: false);

  for (int attempt = 0; attempt < 160; attempt++) {
    final targetKey = occupiedKeys[rng.nextInt(occupiedKeys.length)];
    final parts = targetKey.split(',');
    if (parts.length != 2) continue;
    final tx = int.tryParse(parts[0]);
    final ty = int.tryParse(parts[1]);
    if (tx == null || ty == null) continue;

    // Choose a head cell adjacent to the target, pointing into it.
    final candidates = <(int headX, int headY, String dir)>[
      (tx - 1, ty, 'right'),
      (tx + 1, ty, 'left'),
      (tx, ty - 1, 'up'),
      (tx, ty + 1, 'down'),
    ];

    // Shuffle candidates deterministically.
    for (int i = candidates.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = candidates[i];
      candidates[i] = candidates[j];
      candidates[j] = tmp;
    }

    for (final (headX, headY, headDir) in candidates) {
      if (headX < 0 || headX >= gridWidth || headY < 0 || headY >= gridHeight) {
        continue;
      }

      final headKey = '$headX,$headY';
      if (occupiedBy.containsKey(headKey)) continue;

      final (dx, dy) = _deltaForDirection(headDir);

      // Verify that the forward cell is exactly the chosen occupied target.
      final fx = headX + dx;
      final fy = headY + dy;
      if (fx != tx || fy != ty) continue;

      final blockerId = occupiedBy['$fx,$fy'];
      if (blockerId == null) continue;

      // Neck must be exactly one cell opposite head_direction.
      final neckX = headX - dx;
      final neckY = headY - dy;
      if (neckX < 0 || neckX >= gridWidth || neckY < 0 || neckY >= gridHeight) {
        continue;
      }
      final neckKey = '$neckX,$neckY';
      if (occupiedBy.containsKey(neckKey)) continue;

      final path = <Map<String, int>>[
        {'x': headX, 'y': headY},
        {'x': neckX, 'y': neckY},
      ];
      final used = <String>{headKey, neckKey};

      var curX = neckX;
      var curY = neckY;
      for (int step = 0; step < targetLen - 2; step++) {
        final next = _pickNextTailCell(
          gridWidth: gridWidth,
          gridHeight: gridHeight,
          curX: curX,
          curY: curY,
          occupied: occupiedBy.keys.toSet(),
          used: used,
          rng: rng,
        );
        if (next == null) break;
        curX = next.$1;
        curY = next.$2;
        final k = '$curX,$curY';
        used.add(k);
        path.add({'x': curX, 'y': curY});
      }

      if (path.length < 2) continue;

      final vineId = 'vine_${vineIndex + 1}';

      // Must be blocked immediately by the chosen blocker.
      final firstBlocker = _blockingVineOnFirstStep(
        vineId: vineId,
        headDirection: headDir,
        orderedPath: path,
        occupiedBy: occupiedBy,
        gridWidth: gridWidth,
        gridHeight: gridHeight,
        ignoredVineIds: {vineId},
      );
      if (firstBlocker != blockerId) continue;

      // Must become clearable if the blocker is removed.
      if (!_canVineClear(
        vineId: vineId,
        headDirection: headDir,
        orderedPath: path,
        occupiedBy: occupiedBy,
        gridWidth: gridWidth,
        gridHeight: gridHeight,
        ignoredVineIds: {vineId, blockerId},
      )) {
        continue;
      }

      // Commit.
      for (final cell in path) {
        occupiedBy['${cell['x']},${cell['y']}'] = vineId;
      }

      // Adding this vine must not deadlock the level.
      if (!_anyVineClearable(
        vines: [
          ...existingVines,
          {
            'id': vineId,
            'head_direction': headDir,
            'ordered_path': path,
            'vine_color': 'default',
          },
        ],
        occupiedBy: occupiedBy,
        gridWidth: gridWidth,
        gridHeight: gridHeight,
      )) {
        // Roll back.
        for (final cell in path) {
          occupiedBy.remove('${cell['x']},${cell['y']}');
        }
        continue;
      }

      return {
        'id': vineId,
        'head_direction': headDir,
        'ordered_path': path,
        'vine_color': 'default',
      };
    }
  }

  return null;
}

bool _anyVineClearable({
  required List<Map<String, dynamic>> vines,
  required Map<String, String> occupiedBy,
  required int gridWidth,
  required int gridHeight,
}) {
  for (final v in vines) {
    final id = v['id'];
    final dir = v['head_direction'];
    final path = v['ordered_path'];
    if (id is! String || dir is! String || path is! List) continue;

    final orderedPath = <Map<String, int>>[];
    for (final p in path) {
      if (p is! Map) continue;
      final x = p['x'];
      final y = p['y'];
      if (x is int && y is int) {
        orderedPath.add({'x': x, 'y': y});
      }
    }

    if (orderedPath.length < 2) continue;

    if (_canVineClear(
      vineId: id,
      headDirection: dir,
      orderedPath: orderedPath,
      occupiedBy: occupiedBy,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      ignoredVineIds: {id},
    )) {
      return true;
    }
  }
  return false;
}

String? _blockingVineOnFirstStep({
  required String vineId,
  required String headDirection,
  required List<Map<String, int>> orderedPath,
  required Map<String, String> occupiedBy,
  required int gridWidth,
  required int gridHeight,
  required Set<String> ignoredVineIds,
}) {
  if (orderedPath.isEmpty) return null;
  final head = orderedPath.first;
  final (dx, dy) = _deltaForDirection(headDirection);
  final nx = (head['x'] ?? 0) + dx;
  final ny = (head['y'] ?? 0) + dy;

  // Exiting the grid is not "blocked".
  if (nx < 0 || nx >= gridWidth || ny < 0 || ny >= gridHeight) return null;

  final occ = occupiedBy['$nx,$ny'];
  if (occ == null) return null;
  if (ignoredVineIds.contains(occ)) return null;
  return occ;
}

bool _canVineClear({
  required String vineId,
  required String headDirection,
  required List<Map<String, int>> orderedPath,
  required Map<String, String> occupiedBy,
  required int gridWidth,
  required int gridHeight,
  required Set<String> ignoredVineIds,
}) {
  final (dx, dy) = _deltaForDirection(headDirection);
  if (dx == 0 && dy == 0) return false;
  if (orderedPath.isEmpty) return false;

  var positions = orderedPath
      .map((p) => (p['x'] ?? 0, p['y'] ?? 0))
      .toList(growable: false);

  final maxSteps = (gridWidth + gridHeight + orderedPath.length + 10).clamp(
    20,
    300,
  );

  for (int step = 0; step < maxSteps; step++) {
    final head = positions.first;
    final newHead = (head.$1 + dx, head.$2 + dy);

    final newPositions = <(int, int)>[
      newHead,
      ...positions.take(positions.length - 1),
    ];

    // Collision check against other vines.
    for (final (x, y) in newPositions) {
      if (x < 0 || x >= gridWidth || y < 0 || y >= gridHeight) {
        continue; // out-of-bounds is only allowed for the head when clearing
      }
      final occ = occupiedBy['$x,$y'];
      if (occ != null && !ignoredVineIds.contains(occ)) {
        return false;
      }
    }

    // If the head exits the grid (without collision), the vine clears.
    if (newHead.$1 < 0 ||
        newHead.$1 >= gridWidth ||
        newHead.$2 < 0 ||
        newHead.$2 >= gridHeight) {
      return true;
    }

    positions = newPositions;
  }

  return false;
}

(int dx, int dy) _deltaForDirection(String dir) {
  return switch (dir) {
    'left' => (-1, 0),
    'right' => (1, 0),
    'up' => (0, 1),
    'down' => (0, -1),
    _ => (0, 0),
  };
}

(int, int)? _pickNextTailCell({
  required int gridWidth,
  required int gridHeight,
  required int curX,
  required int curY,
  required Set<String> occupied,
  required Set<String> used,
  required Random rng,
}) {
  final candidates = <(int, int)>[
    (curX + 1, curY),
    (curX - 1, curY),
    (curX, curY + 1),
    (curX, curY - 1),
  ];

  // Shuffle candidates deterministically.
  for (int i = candidates.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = candidates[i];
    candidates[i] = candidates[j];
    candidates[j] = tmp;
  }

  for (final (nx, ny) in candidates) {
    if (nx < 0 || nx >= gridWidth || ny < 0 || ny >= gridHeight) continue;
    final key = '$nx,$ny';
    if (occupied.contains(key) || used.contains(key)) continue;
    return (nx, ny);
  }

  return null;
}

(int, int) _gridSizeForLevel(int levelId, List<_ModuleRange> modules) {
  // Get difficulty tier first
  final tier = _difficultyTierForLevel(levelId, modules);

  // Fixed grid size ranges per difficulty tier (same across all modules)
  // Use a slight variation within each tier for variety
  final seed = Random(levelId);

  final (minW, minH, maxW, maxH) = switch (tier) {
    0 => (6, 8, 9, 16), // Seedling: 6×8 to 9×16
    1 => (9, 16, 12, 20), // Nurturing: 9×16 to 12×20
    2 => (12, 20, 16, 28), // Flourishing: 12×20 to 16×28
    3 => (16, 28, 24, 40), // Transcendent: 16×28 to 24×40
    _ => (6, 8, 9, 16), // Fallback
  };

  // For Transcendent (final level), use larger end of range
  if (tier == 3) {
    // Vary between 80-100% of max range for final levels
    final widthRange = maxW - minW;
    final heightRange = maxH - minH;
    final w = minW + (widthRange * (0.8 + seed.nextDouble() * 0.2)).round();
    final h = minH + (heightRange * (0.8 + seed.nextDouble() * 0.2)).round();
    return (w, h);
  }

  // For other tiers, interpolate across the range
  final widthRange = maxW - minW;
  final heightRange = maxH - minH;
  final w = minW + (widthRange * seed.nextDouble()).round();
  final h = minH + (heightRange * seed.nextDouble()).round();

  return (w, h);
}

int _getBellCurveLength(Random rng, int width, int height, int tier) {
  // Shorter vines on harder tiers = more vines fit = higher coverage + complexity
  final (minAvg, maxAvg) = switch (tier) {
    0 => (6, 8), // Seedling: 6-8 avg
    1 => (4, 6), // Nurturing: 4-6 avg
    2 => (3, 5), // Flourishing: 3-5 avg
    3 => (2, 4), // Transcendent: 2-4 avg
    _ => (2, 4),
  };

  // Target average length for this vine
  final targetAvg = minAvg + rng.nextInt(maxAvg - minAvg + 1);

  // We want a distribution centered at targetAvg.
  // Using the previous logic: center = (minLen + maxLen) / 2
  // So maxLen = 2 * targetAvg - minLen
  final minLen = 2;
  var maxLen = (2 * targetAvg) - minLen;

  // Clamp maxLen to grid dimensions (approx)
  final gridMax = ((width + height) / 1.5).floor();
  if (maxLen > gridMax) maxLen = gridMax;
  if (maxLen < minLen + 1) maxLen = minLen + 1;

  // Average of 3 randoms approximates a normal distribution (Central Limit Theorem)
  final r = (rng.nextDouble() + rng.nextDouble() + rng.nextDouble()) / 3.0;

  // Map 0.0-1.0 to minLen-maxLen
  return (minLen + (maxLen - minLen) * r).round();
}

class _ModuleRange {
  final int id;
  final int start;
  final int end;
  const _ModuleRange(this.id, this.start, this.end);
}

List<_ModuleRange> _loadModules(Directory outDir) {
  // Look in assets/data/modules.json first, then fallback to old location
  var file = File('${outDir.parent.path}/data/modules.json');
  if (!file.existsSync()) {
    file = File('${outDir.path}/modules.json');
  }

  if (!file.existsSync()) return [];

  try {
    final decoded = json.decode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) return [];
    final modules = decoded['modules'];
    if (modules is! List) return [];

    final ranges = <_ModuleRange>[];
    for (final m in modules) {
      if (m is! Map) continue;
      final id = m['id'] as int;
      final range = m['level_range'];
      if (range is! List || range.length < 2) continue;
      final start = (range[0] as num).toInt();
      final end = (range[1] as num).toInt();
      ranges.add(_ModuleRange(id, start, end));
    }
    return ranges;
  } catch (_) {
    return [];
  }
}

int? _detectNextLevelId(Directory outDir) {
  final re = RegExp(r'level_(\d+)\.json$');
  int? maxId;
  for (final entity in outDir.listSync()) {
    if (entity is! File) continue;
    final match = re.firstMatch(entity.path);
    if (match == null) continue;
    final id = int.tryParse(match.group(1)!);
    if (id == null) continue;
    maxId = (maxId == null) ? id : (id > maxId ? id : maxId);
  }
  return (maxId == null) ? null : (maxId + 1);
}

class _Args {
  final int count;
  final String outDir;
  final int? startId;
  final int? endId;
  final int? moduleId;
  final bool overwrite;

  _Args({
    required this.count,
    required this.outDir,
    required this.startId,
    required this.endId,
    required this.moduleId,
    required this.overwrite,
  });
}

_Args _parseArgs(List<String> args) {
  int count = 100;
  String outDir = 'assets/levels';
  int? startId;
  int? endId;
  int? moduleId;
  bool overwrite = false;

  String? readValue(int index) {
    final a = args[index];
    final eq = a.indexOf('=');
    if (eq != -1) return a.substring(eq + 1);
    if (index + 1 < args.length) return args[index + 1];
    return null;
  }

  for (int i = 0; i < args.length; i++) {
    final a = args[i];

    if (a == '--help' || a == '-h') {
      stdout.writeln(
        'Usage: flutter pub run tool/generate_levels.dart [options]',
      );
      stdout.writeln('');
      stdout.writeln('Options:');
      stdout.writeln(
        '  --count <n>       Number of levels to generate (default: 100)',
      );
      stdout.writeln(
        '  --out <dir>       Output directory (default: assets/levels)',
      );
      stdout.writeln(
        '  --start <id>      Starting level id (default: next after existing)',
      );
      stdout.writeln('  --end <id>        Ending level id (optional)');
      stdout.writeln(
        '  --module <id>     Generate all levels for a specific module ID',
      );
      stdout.writeln('  --overwrite       Allow overwriting existing files');
      exitCode = 0;
      exit(0);
    }

    if (a == '--overwrite') {
      overwrite = true;
      continue;
    }

    if (a == '--count' || a.startsWith('--count=')) {
      final value = readValue(i);
      final parsed = int.tryParse(value ?? '');
      if (parsed == null || parsed <= 0) {
        stderr.writeln('Invalid --count: $value');
        exitCode = 2;
        exit(2);
      }
      count = parsed;
      if (!a.contains('=') && i + 1 < args.length) i++;
      continue;
    }

    if (a == '--out' || a.startsWith('--out=')) {
      final value = readValue(i);
      if (value == null || value.trim().isEmpty) {
        stderr.writeln('Invalid --out: $value');
        exitCode = 2;
        exit(2);
      }
      outDir = value;
      if (!a.contains('=') && i + 1 < args.length) i++;
      continue;
    }

    if (a == '--start' || a.startsWith('--start=')) {
      final value = readValue(i);
      final parsed = int.tryParse(value ?? '');
      if (parsed == null || parsed <= 0) {
        stderr.writeln('Invalid --start: $value');
        exitCode = 2;
        exit(2);
      }
      startId = parsed;
      if (!a.contains('=') && i + 1 < args.length) i++;
      continue;
    }

    if (a == '--end' || a.startsWith('--end=')) {
      final value = readValue(i);
      final parsed = int.tryParse(value ?? '');
      if (parsed == null || parsed <= 0) {
        stderr.writeln('Invalid --end: $value');
        exitCode = 2;
        exit(2);
      }
      endId = parsed;
      if (!a.contains('=') && i + 1 < args.length) i++;
      continue;
    }

    if (a == '--module' || a.startsWith('--module=')) {
      final value = readValue(i);
      final parsed = int.tryParse(value ?? '');
      if (parsed == null || parsed <= 0) {
        stderr.writeln('Invalid --module: $value');
        exitCode = 2;
        exit(2);
      }
      moduleId = parsed;
      if (!a.contains('=') && i + 1 < args.length) i++;
      continue;
    }

    stderr.writeln('Unknown arg: $a');
    stderr.writeln('Run with --help for usage.');
    exitCode = 2;
    exit(2);
  }

  return _Args(
    count: count,
    outDir: outDir,
    startId: startId,
    endId: endId,
    moduleId: moduleId,
    overwrite: overwrite,
  );
}
