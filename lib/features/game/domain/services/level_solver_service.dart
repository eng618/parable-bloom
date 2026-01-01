import 'package:flutter/material.dart';

// Import only the data model we need (will be moved in future commits)
// For now, importing from providers to maintain compatibility
import '../../../../providers/game_providers.dart' show LevelData, VineData;

/// Domain service for solving vine puzzle levels using BFS/A* algorithm.
/// Pure business logic with no UI or state management dependencies.
class LevelSolverService {
  /// Returns a vine-clear order if solvable, else null.
  ///
  /// This is primarily used by unit tests and debugging; for validation runs
  /// prefer [isSolvable] which is cheaper.
  List<String>? solve(LevelData level, {int maxStates = 100000}) {
    final vineCount = level.vines.length;
    if (vineCount == 0) return <String>[];

    if (vineCount <= 24) {
      return _solveExact(level);
    }

    // For unusually large levels, fall back to a best-effort heuristic.
    return _solveHeuristic(level, maxStates: maxStates);
  }

  /// Fast solvability check.
  ///
  /// Returns true iff the level is solvable within the search budget.
  /// This avoids building a full sequence, which makes level test runs faster.
  bool isSolvable(LevelData level, {int maxStates = 100000}) {
    final vineCount = level.vines.length;
    if (vineCount == 0) return true;

    // Exact subset BFS is fast and reliable for typical vine counts.
    if (vineCount <= 24) {
      return _isSolvableExact(level);
    }

    // Fallback for unusually large levels.
    return _isSolvableHeuristic(level, maxStates: maxStates);
  }

  bool _isSolvableExact(LevelData level) {
    final vines = level.vines.toList(growable: false);
    final vineCount = vines.length;

    final vineCells = <String, Set<String>>{
      for (final v in vines)
        v.id: {for (final s in v.orderedPath) '${s['x']},${s['y']}'},
    };

    final fullMask = (1 << vineCount) - 1;
    final visited = List<bool>.filled(1 << vineCount, false);
    final queue = <int>[fullMask];
    visited[fullMask] = true;

    while (queue.isNotEmpty) {
      final mask = queue.removeAt(0);
      if (mask == 0) return true;

      final occupiedAll = <String>{};
      for (var i = 0; i < vineCount; i++) {
        if ((mask & (1 << i)) == 0) continue;
        occupiedAll.addAll(vineCells[vines[i].id]!);
      }

      for (var i = 0; i < vineCount; i++) {
        if ((mask & (1 << i)) == 0) continue;
        final vine = vines[i];
        if (!_canVineClearExact(
          level,
          vine,
          occupiedAll,
          vineCells[vine.id]!,
        )) {
          continue;
        }

        final next = mask & ~(1 << i);
        if (!visited[next]) {
          visited[next] = true;
          queue.add(next);
        }
      }
    }

    return false;
  }

  List<String>? _solveExact(LevelData level) {
    final vines = level.vines.toList(growable: false);
    final vineCount = vines.length;
    if (vineCount == 0) return <String>[];

    final vineCells = <String, Set<String>>{
      for (final v in vines)
        v.id: {for (final s in v.orderedPath) '${s['x']},${s['y']}'},
    };

    final fullMask = (1 << vineCount) - 1;
    final visited = List<bool>.filled(1 << vineCount, false);
    final prevMask = List<int>.filled(1 << vineCount, -1);
    final removedIndex = List<int>.filled(1 << vineCount, -1);

    final queue = <int>[fullMask];
    visited[fullMask] = true;

    while (queue.isNotEmpty) {
      final mask = queue.removeAt(0);
      if (mask == 0) {
        // Reconstruct removal order.
        final reversed = <String>[];
        var cur = 0;
        while (cur != fullMask) {
          final idx = removedIndex[cur];
          if (idx < 0) break;
          reversed.add(vines[idx].id);
          cur = prevMask[cur];
          if (cur < 0) break;
        }
        return reversed.reversed.toList(growable: false);
      }

      final occupiedAll = <String>{};
      for (var i = 0; i < vineCount; i++) {
        if ((mask & (1 << i)) == 0) continue;
        occupiedAll.addAll(vineCells[vines[i].id]!);
      }

      for (var i = 0; i < vineCount; i++) {
        if ((mask & (1 << i)) == 0) continue;
        final vine = vines[i];
        if (!_canVineClearExact(
          level,
          vine,
          occupiedAll,
          vineCells[vine.id]!,
        )) {
          continue;
        }

        final next = mask & ~(1 << i);
        if (!visited[next]) {
          visited[next] = true;
          prevMask[next] = mask;
          removedIndex[next] = i;
          queue.add(next);
        }
      }
    }

    return null;
  }

  bool _canVineClearExact(
    LevelData level,
    VineData vine,
    Set<String> occupiedAll,
    Set<String> selfCells,
  ) {
    if (vine.orderedPath.isEmpty) return false;

    var currentPositions = List<Map<String, int>>.from(vine.orderedPath);
    final maxCheckDistance =
        (level.gridWidth + level.gridHeight + vine.orderedPath.length + 10)
            .clamp(10, 300);

    for (var step = 0; step < maxCheckDistance; step++) {
      final newPositions = _simulateVineMovementFromPositions(
        currentPositions,
        vine.headDirection,
      );

      final seen = <String>{};
      for (final newPos in newPositions) {
        final k = '${newPos['x']},${newPos['y']}';

        // Self-overlap after movement is not allowed.
        if (!seen.add(k)) return false;

        // Collision with any other vine.
        if (occupiedAll.contains(k) && !selfCells.contains(k)) {
          return false;
        }
      }

      final newHead = newPositions.first;
      final headX = newHead['x'] as int;
      final headY = newHead['y'] as int;
      if (headX < 0 ||
          headX >= level.gridWidth ||
          headY < 0 ||
          headY >= level.gridHeight) {
        return true;
      }

      currentPositions = newPositions;
    }

    return false;
  }

  bool _isSolvableHeuristic(LevelData level, {required int maxStates}) {
    debugPrint(
      'LevelSolverService: Checking solvability for level ${level.id}',
    );

    final initialVines = level.vines.map((v) => v.id).toList();

    final blockingCache = <String, Set<String>>{};
    final blockedByCache = <String, Set<String>>{};

    for (final vine in level.vines) {
      blockingCache[vine.id] = <String>{};
      blockedByCache[vine.id] = <String>{};
    }

    for (final vine in level.vines) {
      for (final otherVine in level.vines) {
        if (vine.id == otherVine.id) continue;
        if (_doesVineBlock(level, vine.id, otherVine.id)) {
          blockingCache[vine.id]!.add(otherVine.id);
          blockedByCache[otherVine.id]!.add(vine.id);
        }
      }
    }

    final queue = _PriorityQueue<List<String>>();
    queue.add(
      initialVines,
      _calculatePriority(level, initialVines, blockingCache, blockedByCache),
    );

    final visited = <String>{_getStateKey(initialVines)};
    int statesExplored = 0;

    while (queue.isNotEmpty && statesExplored < maxStates) {
      final currentVines = queue.removeFirst();
      statesExplored++;

      if (currentVines.isEmpty) {
        debugPrint(
          'LevelSolverService: Solvable (explored $statesExplored states)',
        );
        return true;
      }

      final movableVines = currentVines
          .where(
            (vineId) => getDistanceToBlocker(level, vineId, currentVines) > 0,
          )
          .toList();

      movableVines.sort((a, b) {
        final aUnblocks = blockingCache[a]!.where(currentVines.contains).length;
        final bUnblocks = blockingCache[b]!.where(currentVines.contains).length;
        return bUnblocks.compareTo(aUnblocks);
      });

      for (final vineId in movableVines) {
        final nextVines = List<String>.from(currentVines)..remove(vineId);
        final key = _getStateKey(nextVines);
        if (visited.contains(key)) continue;
        visited.add(key);

        final priority = _calculatePriority(
          level,
          nextVines,
          blockingCache,
          blockedByCache,
        );
        queue.add(nextVines, priority);
      }
    }

    if (statesExplored >= maxStates) {
      debugPrint(
        'LevelSolverService: Gave up after exploring $maxStates states - level may be too complex',
      );
    } else {
      debugPrint('LevelSolverService: UNSOLVABLE level ${level.id}');
    }
    return false;
  }

  List<String>? _solveHeuristic(LevelData level, {required int maxStates}) {
    final initialVines = level.vines.map((v) => v.id).toList();

    final blockingCache = <String, Set<String>>{};
    final blockedByCache = <String, Set<String>>{};

    for (final vine in level.vines) {
      blockingCache[vine.id] = <String>{};
      blockedByCache[vine.id] = <String>{};
    }

    for (final vine in level.vines) {
      for (final otherVine in level.vines) {
        if (vine.id == otherVine.id) continue;
        if (_doesVineBlock(level, vine.id, otherVine.id)) {
          blockingCache[vine.id]!.add(otherVine.id);
          blockedByCache[otherVine.id]!.add(vine.id);
        }
      }
    }

    final queue = _PriorityQueue<(List<String> remaining, List<String> seq)>();
    queue.add((
      initialVines,
      <String>[],
    ), _calculatePriority(level, initialVines, blockingCache, blockedByCache));

    final visited = <String>{_getStateKey(initialVines)};
    int statesExplored = 0;

    while (queue.isNotEmpty && statesExplored < maxStates) {
      final state = queue.removeFirst();
      final currentVines = state.$1;
      final sequence = state.$2;
      statesExplored++;

      if (currentVines.isEmpty) return sequence;

      final movableVines = currentVines
          .where(
            (vineId) => getDistanceToBlocker(level, vineId, currentVines) > 0,
          )
          .toList();

      movableVines.sort((a, b) {
        final aUnblocks = blockingCache[a]!.where(currentVines.contains).length;
        final bUnblocks = blockingCache[b]!.where(currentVines.contains).length;
        return bUnblocks.compareTo(aUnblocks);
      });

      for (final vineId in movableVines) {
        final nextVines = List<String>.from(currentVines)..remove(vineId);
        final key = _getStateKey(nextVines);
        if (visited.contains(key)) continue;
        visited.add(key);

        final priority = _calculatePriority(
          level,
          nextVines,
          blockingCache,
          blockedByCache,
        );
        queue.add((nextVines, [...sequence, vineId]), priority);
      }
    }

    return null;
  }

  /// Checks if vine A blocks vine B (A prevents B from moving).
  /// Properly simulates snake-like movement of B and checks if A occupies any position B would move to.
  bool _doesVineBlock(LevelData level, String blockerId, String blockedId) {
    final blocker = level.vines.firstWhere((v) => v.id == blockerId);
    final blocked = level.vines.firstWhere((v) => v.id == blockedId);

    // Simulate where blocked vine would be after one move
    final blockedNewPositions = _simulateVineMovement(blocked);

    // Check if blocker occupies any of the positions blocked vine would move to
    for (final newPos in blockedNewPositions) {
      for (final blockerCell in blocker.orderedPath) {
        if (blockerCell['x'] == newPos['x'] &&
            blockerCell['y'] == newPos['y']) {
          return true; // Blocker occupies a position blocked vine needs
        }
      }
    }

    return false;
  }

  /// Calculate priority for A* search (lower is better)
  int _calculatePriority(
    LevelData level,
    List<String> remainingVines,
    Map<String, Set<String>> blockingCache,
    Map<String, Set<String>> blockedByCache,
  ) {
    if (remainingVines.isEmpty) return 0;

    // Heuristic: prefer states where fewer vines are blocked
    int blockedCount = 0;
    for (final vineId in remainingVines) {
      final blockers = blockedByCache[vineId]!.where(remainingVines.contains);
      if (blockers.isNotEmpty) blockedCount++;
    }

    // Also consider total remaining moves
    return blockedCount * 10 + remainingVines.length;
  }

  String _getStateKey(List<String> vines) {
    final sorted = List<String>.from(vines)..sort();
    return sorted.join(',');
  }

  /// Simulates snake-like movement: calculates where each segment of a vine
  /// would be positioned after the vine moves one step in its direction.
  List<Map<String, int>> _simulateVineMovement(VineData vine) {
    final positions = List<Map<String, int>>.from(vine.orderedPath);

    if (positions.isEmpty) return positions;

    // Calculate new head position
    final head = positions[0];
    final newHeadX = head['x'] as int;
    final newHeadY = head['y'] as int;

    var deltaX = 0;
    var deltaY = 0;

    switch (vine.headDirection) {
      case 'right':
        deltaX = 1;
        break;
      case 'left':
        deltaX = -1;
        break;
      case 'up':
        deltaY = 1;
        break;
      case 'down':
        deltaY = -1;
        break;
    }

    final newHead = {'x': newHeadX + deltaX, 'y': newHeadY + deltaY};

    // Shift all segments: each segment moves to where the previous one was
    final newPositions = <Map<String, int>>[newHead];

    for (int i = 1; i < positions.length; i++) {
      newPositions.add(positions[i - 1]);
    }

    return newPositions;
  }

  /// Checks if a vine is blocked by any other 'active' vines in a specific state.
  /// Properly simulates snake-like movement where all segments follow the head.
  bool isVineBlockedInState(
    LevelData level,
    String vineId,
    List<String> activeVineIds,
  ) {
    final vine = level.vines.firstWhere((v) => v.id == vineId);

    if (vine.orderedPath.isEmpty) return false;

    // Simulate snake-like movement: calculate where each segment would be after one move
    final newPositions = _simulateVineMovement(vine);

    // Check if any of the new positions would be occupied by other active vines
    for (final newPos in newPositions) {
      for (final otherId in activeVineIds) {
        if (otherId == vineId) continue;

        final otherVine = level.vines.firstWhere((v) => v.id == otherId);
        for (final cell in otherVine.orderedPath) {
          if (cell['x'] == newPos['x'] && cell['y'] == newPos['y']) {
            return true; // Blocked by another vine
          }
        }
      }
    }

    return false; // Not blocked
  }

  /// Calculates how many cells a vine can slide before being blocked.
  /// Properly simulates snake-like movement and checks for collisions.
  /// Returns negative distance if blocked by vine, positive if can move far.
  int getDistanceToBlocker(
    LevelData level,
    String vineId,
    List<String> activeVineIds,
  ) {
    final vine = level.vines.firstWhere((v) => v.id == vineId);

    if (vine.orderedPath.isEmpty) return 0;

    // Start with current positions
    var currentPositions = List<Map<String, int>>.from(vine.orderedPath);
    int distance = 0;

    // Upper bound: enough steps for head to exit the grid from anywhere.
    final maxCheckDistance =
        (level.gridWidth + level.gridHeight + vine.orderedPath.length + 10)
            .clamp(50, 300);

    for (int step = 0; step < maxCheckDistance; step++) {
      // Simulate one step of movement
      final newPositions = _simulateVineMovementFromPositions(
        currentPositions,
        vine.headDirection,
      );

      // Check if any of the new positions would be occupied by other active vines
      for (final newPos in newPositions) {
        for (final otherId in activeVineIds) {
          if (otherId == vineId) continue;

          final otherVine = level.vines.firstWhere((v) => v.id == otherId);
          for (final cell in otherVine.orderedPath) {
            if (cell['x'] == newPos['x'] && cell['y'] == newPos['y']) {
              return -(distance +
                  1); // Negative = blocked by vine at this distance
            }
          }
        }
      }

      // If the head exits the grid (without collision), the vine can clear.
      final newHead = newPositions.first;
      final headX = newHead['x'] as int;
      final headY = newHead['y'] as int;
      if (headX < 0 ||
          headX >= level.gridWidth ||
          headY < 0 ||
          headY >= level.gridHeight) {
        return distance + 1;
      }

      // Move to next positions
      currentPositions = newPositions;
      distance++;
    }

    // If we never hit a collision or exited, treat as blocked (conservative).
    return -(distance + 1);
  }

  /// Simulates snake-like movement from given positions.
  List<Map<String, int>> _simulateVineMovementFromPositions(
    List<Map<String, int>> positions,
    String direction,
  ) {
    if (positions.isEmpty) return positions;

    // Calculate new head position
    final head = positions[0];
    final newHeadX = head['x'] as int;
    final newHeadY = head['y'] as int;

    var deltaX = 0;
    var deltaY = 0;

    switch (direction) {
      case 'right':
        deltaX = 1;
        break;
      case 'left':
        deltaX = -1;
        break;
      case 'up':
        deltaY = 1;
        break;
      case 'down':
        deltaY = -1;
        break;
    }

    final newHead = {'x': newHeadX + deltaX, 'y': newHeadY + deltaY};

    // Shift all segments: each segment moves to where the previous one was
    final newPositions = <Map<String, int>>[newHead];

    for (int i = 1; i < positions.length; i++) {
      newPositions.add(positions[i - 1]);
    }

    return newPositions;
  }
}

/// Priority Queue for A* search algorithm.
/// Internal helper class for the LevelSolverService.
class _PriorityQueue<T> {
  final List<(T, int)> _heap = [];

  void add(T item, int priority) {
    _heap.add((item, priority));
    _bubbleUp(_heap.length - 1);
  }

  T removeFirst() {
    if (_heap.isEmpty) throw StateError('Queue is empty');
    final result = _heap.first.$1;
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = last;
      _sinkDown(0);
    }
    return result;
  }

  bool get isNotEmpty => _heap.isNotEmpty;
  bool get isEmpty => _heap.isEmpty;

  void _bubbleUp(int index) {
    while (index > 0) {
      final parentIndex = (index - 1) ~/ 2;
      if (_heap[index].$2 >= _heap[parentIndex].$2) break;
      _swap(index, parentIndex);
      index = parentIndex;
    }
  }

  void _sinkDown(int index) {
    final length = _heap.length;
    while (true) {
      var smallest = index;
      final left = 2 * index + 1;
      final right = 2 * index + 2;

      if (left < length && _heap[left].$2 < _heap[smallest].$2) {
        smallest = left;
      }
      if (right < length && _heap[right].$2 < _heap[smallest].$2) {
        smallest = right;
      }
      if (smallest == index) break;

      _swap(index, smallest);
      index = smallest;
    }
  }

  void _swap(int i, int j) {
    final temp = _heap[i];
    _heap[i] = _heap[j];
    _heap[j] = temp;
  }
}
