import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../game/garden_game.dart';

// Models for game state
class VineData {
  final String id;
  final String color;
  final String description;
  final List<Map<String, int>> path;
  final List<String> blockingVines;

  VineData({
    required this.id,
    required this.color,
    required this.description,
    required this.path,
    required this.blockingVines,
  });

  factory VineData.fromJson(Map<String, dynamic> json) {
    return VineData(
      id: json['id'],
      color: json['color'],
      description: json['description'],
      path: List<Map<String, int>>.from(
        json['path'].map((cell) => Map<String, int>.from(cell))
      ),
      blockingVines: List<String>.from(json['blockingVines']),
    );
  }
}

class LevelData {
  final String levelId;
  final int levelNumber;
  final String title;
  final int difficulty;
  final Map<String, int> grid;
  final List<VineData> vines;
  final Map<String, dynamic> parable;
  final List<String> hints;
  final List<String> optimalSequence;
  final int optimalMoves;

  LevelData({
    required this.levelId,
    required this.levelNumber,
    required this.title,
    required this.difficulty,
    required this.grid,
    required this.vines,
    required this.parable,
    required this.hints,
    required this.optimalSequence,
    required this.optimalMoves,
  });

  factory LevelData.fromJson(Map<String, dynamic> json) {
    return LevelData(
      levelId: json['levelId'],
      levelNumber: json['levelNumber'],
      title: json['title'],
      difficulty: json['difficulty'],
      grid: Map<String, int>.from(json['grid']),
      vines: List<VineData>.from(
        json['vines'].map((vine) => VineData.fromJson(vine))
      ),
      parable: Map<String, dynamic>.from(json['parable']),
      hints: List<String>.from(json['hints']),
      optimalSequence: List<String>.from(json['optimalSequence']),
      optimalMoves: json['optimalMoves'],
    );
  }
}

class GameProgress {
  final int currentLevel;
  final Set<int> completedLevels;

  GameProgress({
    required this.currentLevel,
    required this.completedLevels,
  });

  GameProgress copyWith({
    int? currentLevel,
    Set<int>? completedLevels,
  }) {
    return GameProgress(
      currentLevel: currentLevel ?? this.currentLevel,
      completedLevels: completedLevels ?? this.completedLevels,
    );
  }

  factory GameProgress.fromJson(Map<String, dynamic> json) {
    return GameProgress(
      currentLevel: json['currentLevel'] ?? 1,
      completedLevels: Set<int>.from(json['completedLevels'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentLevel': currentLevel,
      'completedLevels': completedLevels.toList(),
    };
  }
}

// Providers
final hiveBoxProvider = Provider<Box>((ref) {
  throw UnimplementedError('Hive box must be initialized in main');
});

final gameProgressProvider = StateNotifierProvider<GameProgressNotifier, GameProgress>((ref) {
  final box = ref.watch(hiveBoxProvider);
  return GameProgressNotifier(box);
});

class GameProgressNotifier extends StateNotifier<GameProgress> {
  final Box _box;

  GameProgressNotifier(this._box) : super(_loadProgress(_box));

  static GameProgress _loadProgress(Box box) {
    final data = box.get('progress');
    if (data != null) {
      return GameProgress.fromJson(Map<String, dynamic>.from(data));
    }
    return GameProgress(currentLevel: 1, completedLevels: {});
  }

  Future<void> completeLevel(int levelNumber) async {
    final newCompletedLevels = Set<int>.from(state.completedLevels)..add(levelNumber);
    // Increment level number - GardenGame will handle detection of end of levels
    final newCurrentLevel = levelNumber + 1;

    state = state.copyWith(
      completedLevels: newCompletedLevels,
      currentLevel: newCurrentLevel,
    );

    await _saveProgress();
  }

  Future<void> resetProgress() async {
    state = GameProgress(currentLevel: 1, completedLevels: {});
    await _saveProgress();
  }

  Future<void> _saveProgress() async {
    await _box.put('progress', state.toJson());
  }
}

// Current level provider
final currentLevelProvider = StateProvider<LevelData?>((ref) => null);

// Level completion state provider
final levelCompleteProvider = StateProvider<bool>((ref) => false);

// Total game completion state provider
final gameCompletedProvider = StateProvider<bool>((ref) => false);

// Lives system
final livesProvider = StateProvider<int>((ref) => 3);

// Game over state provider
final gameOverProvider = StateProvider<bool>((ref) => false);

// Game instance provider
final gameInstanceProvider = StateNotifierProvider<GameInstanceNotifier, GardenGame?>((ref) {
  return GameInstanceNotifier();
});

class GameInstanceNotifier extends StateNotifier<GardenGame?> {
  GameInstanceNotifier() : super(null);

  void setGame(GardenGame game) {
    state = game;
  }

  void resetLives() {
    state?.ref.read(livesProvider.notifier).state = 3;
    state?.ref.read(gameOverProvider.notifier).state = false;
  }

  void decrementLives() {
    final currentLives = state?.ref.read(livesProvider) ?? 0;
    if (currentLives > 0) {
      state?.ref.read(livesProvider.notifier).state = currentLives - 1;
      if (currentLives - 1 == 0) {
        state?.ref.read(gameOverProvider.notifier).state = true;
      }
    }
  }
}

// Vine state for current level
class VineState {
  final String id;
  final bool isBlocked;
  final bool isCleared;

  VineState({
    required this.id,
    required this.isBlocked,
    required this.isCleared,
  });

  VineState copyWith({
    bool? isBlocked,
    bool? isCleared,
  }) {
    return VineState(
      id: id,
      isBlocked: isBlocked ?? this.isBlocked,
      isCleared: isCleared ?? this.isCleared,
    );
  }
}

// --- Level Solver Logic ---

class LevelSolver {
  /// Solves the level and returns one optimal sequence of vine IDs to clear.
  /// Returns null if the level is unsolvable.
  static List<String>? solve(LevelData level) {
    debugPrint('LevelSolver: Attempting to solve level ${level.levelId}');
    final initialVines = level.vines.map((v) => v.id).toList();
    
    // BFS queue: (remaining vine IDs, sequence taken)
    final queue = <(List<String>, List<String>)>[];
    queue.add((initialVines, []));
    
    final visited = <String>{};
    visited.add(_getStateKey(initialVines));

    while (queue.isNotEmpty) {
      final (currentVines, sequence) = queue.removeAt(0);

      if (currentVines.isEmpty) {
        debugPrint('LevelSolver: Solvable! Sequence: $sequence');
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

    debugPrint('LevelSolver: UNSOLVABLE level ${level.levelId}');
    return null;
  }

  static String _getStateKey(List<String> vines) {
    final sorted = List<String>.from(vines)..sort();
    return sorted.join(',');
  }

  /// Checks if a vine is blocked by any other 'active' vines in a specific state.
  static bool isVineBlockedInState(LevelData level, String vineId, List<String> activeVineIds) {
    final vine = level.vines.firstWhere((v) => v.id == vineId);
    final gridRows = level.grid['rows'] as int;
    final gridCols = level.grid['columns'] as int;

    // Determine direction from head (last two cells)
    if (vine.path.length < 2) return false;
    
    final head = vine.path.last;
    final neck = vine.path[vine.path.length - 2];
    final dRow = (head['row'] as int) - (neck['row'] as int);
    final dCol = (head['col'] as int) - (neck['col'] as int);

    // Trace path from head forward
    var currentRow = (head['row'] as int) + dRow;
    var currentCol = (head['col'] as int) + dCol;

    while (currentRow >= 0 && currentRow < gridRows && currentCol >= 0 && currentCol < gridCols) {
      // Check for collisions with ANY other active vine
      for (final otherId in activeVineIds) {
        if (otherId == vineId) continue;
        
        final otherVine = level.vines.firstWhere((v) => v.id == otherId);
        for (final cell in otherVine.path) {
          if (cell['row'] == currentRow && cell['col'] == currentCol) {
            return true; // Blocked
          }
        }
      }
      currentRow += dRow;
      currentCol += dCol;
    }

    return false; // Not blocked
  }
}

final vineStatesProvider = StateNotifierProvider<VineStatesNotifier, Map<String, VineState>>((ref) {
  final levelData = ref.watch(currentLevelProvider);
  return VineStatesNotifier(levelData, ref);
});

class VineStatesNotifier extends StateNotifier<Map<String, VineState>> {
  final Ref _ref;
  LevelData? _levelData;

  VineStatesNotifier(LevelData? levelData, this._ref) : super(_calculateVineStates(levelData, {})) {
    _levelData = levelData;
  }

  static Map<String, VineState> _calculateVineStates(LevelData? levelData, Map<String, VineState> currentStates) {
    if (levelData == null) return {};

    final activeIds = <String>[];
    for (final vine in levelData.vines) {
      final isCleared = currentStates[vine.id]?.isCleared ?? false;
      if (!isCleared) {
        activeIds.add(vine.id);
      }
    }

    final newStates = <String, VineState>{};
    for (final vine in levelData.vines) {
      final isCleared = currentStates[vine.id]?.isCleared ?? false;
      bool isBlocked = false;
      
      if (!isCleared) {
        isBlocked = LevelSolver.isVineBlockedInState(levelData, vine.id, activeIds);
      }

      newStates[vine.id] = VineState(
        id: vine.id,
        isBlocked: isBlocked,
        isCleared: isCleared,
      );
    }

    return newStates;
  }

  void clearVine(String vineId) {
    debugPrint('VineStatesNotifier: Clearing vine $vineId');
    // Mark as cleared
    final mapWithCleared = Map<String, VineState>.from(state);
    if (mapWithCleared.containsKey(vineId)) {
        mapWithCleared[vineId] = mapWithCleared[vineId]!.copyWith(isCleared: true);
    }
    
    // Recalculate blocking for all
    state = _calculateVineStates(_levelData, mapWithCleared);

    // Check if level is complete
    _checkLevelComplete();
  }

  void _checkLevelComplete() {
    final allCleared = state.values.every((vineState) => vineState.isCleared);
    debugPrint('VineStatesNotifier: Checking completion - all cleared: $allCleared, total vines: ${state.length}');
    if (allCleared) {
      debugPrint('VineStatesNotifier: LEVEL COMPLETE detected! Setting levelCompleteProvider to true');
      // Trigger level complete
      _ref.read(levelCompleteProvider.notifier).state = true;
    }
  }

  void resetForLevel(LevelData levelData) {
    _levelData = levelData;
    state = _calculateVineStates(levelData, {});
  }
}
