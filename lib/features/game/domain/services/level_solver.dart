import 'dart:developer' as developer;

import '../entities/level.dart';

class LevelSolver {
  /// Solves the level and returns one optimal sequence of vine IDs to clear.
  /// Returns null if the level is unsolvable.
  static List<String>? solve(Level level) {
    developer.log('LevelSolver: Attempting to solve level ${level.levelId}');
    final initialVines = level.gameBoard.vines.map((v) => v.id).toList();

    // BFS queue: (remaining vine IDs, sequence taken)
    final queue = <(List<String>, List<String>)>[];
    queue.add((initialVines, []));

    final visited = <String>{};
    visited.add(_getStateKey(initialVines));

    while (queue.isNotEmpty) {
      final (currentVines, sequence) = queue.removeAt(0);

      if (currentVines.isEmpty) {
        developer.log('LevelSolver: Solvable! Sequence: $sequence');
        return sequence;
      }

      for (final vineId in currentVines) {
        if (!isVineBlockedInState(level, vineId, currentVines)) {
          final nextVines = List<String>.from(currentVines)..remove(vineId);
          final key = _getStateKey(nextVines);

          if (!visited.contains(key)) {
            visited.add(key);
            queue.add((nextVines, [...sequence, vineId]));
          }
        }
      }
    }

    developer.log('LevelSolver: UNSOLVABLE level ${level.levelId}');
    return null;
  }

  static String _getStateKey(List<String> vines) {
    final sorted = List<String>.from(vines)..sort();
    return sorted.join(',');
  }

  /// Checks if a vine is blocked by any other 'active' vines in a specific state.
  static bool isVineBlockedInState(
    Level level,
    String vineId,
    List<String> activeVineIds,
  ) {
    final vine = level.gameBoard.vines.firstWhere((v) => v.id == vineId);
    final gridRows = level.gameBoard.rows;
    final gridCols = level.gameBoard.cols;

    // Determine direction from head (last two cells)
    if (vine.path.length < 2) return false;

    final head = vine.path.last;
    final neck = vine.path[vine.path.length - 2];
    final dRow = head.row - neck.row;
    final dCol = head.col - neck.col;

    // Trace path from head forward
    var currentRow = head.row + dRow;
    var currentCol = head.col + dCol;

    while (currentRow >= 0 &&
        currentRow < gridRows &&
        currentCol >= 0 &&
        currentCol < gridCols) {
      // Check for collisions with ANY other active vine
      for (final otherId in activeVineIds) {
        if (otherId == vineId) continue;

        final otherVine = level.gameBoard.vines.firstWhere(
          (v) => v.id == otherId,
        );
        for (final cell in otherVine.path) {
          if (cell.row == currentRow && cell.col == currentCol) {
            return true; // Blocked
          }
        }
      }
      currentRow += dRow;
      currentCol += dCol;
    }

    return false; // Not blocked
  }

  /// Calculates how many cells a vine can slide before being blocked or exiting.
  static int getDistanceToBlocker(
    Level level,
    String vineId,
    List<String> activeVineIds,
  ) {
    final vine = level.gameBoard.vines.firstWhere((v) => v.id == vineId);
    final gridRows = level.gameBoard.rows;
    final gridCols = level.gameBoard.cols;

    if (vine.path.length < 2) return 0;

    final head = vine.path.last;
    final neck = vine.path[vine.path.length - 2];
    final dRow = head.row - neck.row;
    final dCol = head.col - neck.col;

    var currentRow = head.row + dRow;
    var currentCol = head.col + dCol;
    int distance = 0;

    while (currentRow >= 0 &&
        currentRow < gridRows &&
        currentCol >= 0 &&
        currentCol < gridCols) {
      for (final otherId in activeVineIds) {
        if (otherId == vineId) continue;

        final otherVine = level.gameBoard.vines.firstWhere(
          (v) => v.id == otherId,
        );
        for (final cell in otherVine.path) {
          if (cell.row == currentRow && cell.col == currentCol) {
            return distance; // Blocked at this distance
          }
        }
      }
      distance++;
      currentRow += dRow;
      currentCol += dCol;
    }

    return distance; // No blocker found before edge
  }
}
