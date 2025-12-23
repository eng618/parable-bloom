import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/game/data/repositories/firebase_game_progress_repository.dart';
import '../features/game/data/repositories/hive_game_progress_repository.dart';
import '../features/game/domain/entities/game_progress.dart';
import '../features/game/domain/repositories/game_progress_repository.dart';
import '../features/game/presentation/widgets/garden_game.dart';
import '../services/analytics_service.dart';

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
        json['path'].map((cell) => Map<String, int>.from(cell)),
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
        json['vines'].map((vine) => VineData.fromJson(vine)),
      ),
      parable: Map<String, dynamic>.from(json['parable']),
      hints: List<String>.from(json['hints']),
      optimalSequence: List<String>.from(json['optimalSequence']),
      optimalMoves: json['optimalMoves'],
    );
  }
}

// Providers
final hiveBoxProvider = Provider<Box>((ref) {
  throw UnimplementedError('Hive box must be initialized in main');
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  throw UnimplementedError('AnalyticsService must be initialized in main');
});

// Level tap tracking providers
final levelTotalTapsProvider = NotifierProvider<LevelTotalTapsNotifier, int>(
  LevelTotalTapsNotifier.new,
);

class LevelTotalTapsNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state++;
  }

  void reset() {
    state = 0;
  }
}

final levelWrongTapsProvider = NotifierProvider<LevelWrongTapsNotifier, int>(
  LevelWrongTapsNotifier.new,
);

class LevelWrongTapsNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state++;
  }

  void reset() {
    state = 0;
  }
}

// Repository providers
final localGameProgressRepositoryProvider = Provider<GameProgressRepository>((
  ref,
) {
  final box = ref.watch(hiveBoxProvider);
  return HiveGameProgressRepository(box);
});

final cloudGameProgressRepositoryProvider = Provider<GameProgressRepository>((
  ref,
) {
  final box = ref.watch(hiveBoxProvider);
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return FirebaseGameProgressRepository(box, firestore, auth);
});

// Current repository selector - defaults to local, can be switched to cloud
final gameProgressRepositoryProvider = Provider<GameProgressRepository>((ref) {
  // For now, use local repository. In the future, this could check user preferences
  // and return either local or cloud repository based on sync settings
  return ref.watch(localGameProgressRepositoryProvider);
});

final gameProgressProvider =
    NotifierProvider<GameProgressNotifier, GameProgress>(
      GameProgressNotifier.new,
    );

// Cloud sync state provider
final cloudSyncEnabledProvider = FutureProvider<bool>((ref) async {
  final notifier = ref.watch(gameProgressProvider.notifier);
  return notifier.isCloudSyncEnabled();
});

final cloudSyncAvailableProvider = FutureProvider<bool>((ref) async {
  final notifier = ref.watch(gameProgressProvider.notifier);
  return notifier.isCloudSyncAvailable();
});

final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  final notifier = ref.watch(gameProgressProvider.notifier);
  return notifier.getLastSyncTime();
});

class GameProgressNotifier extends Notifier<GameProgress> {
  @override
  GameProgress build() {
    // For initial build, return initial state
    // Data will be loaded via initialize() method
    return GameProgress.initial();
  }

  Future<void> initialize() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    try {
      final progress = await repository.getProgress();
      state = progress;
    } catch (e) {
      // If loading fails, keep initial state
      state = GameProgress.initial();
    }
  }

  Future<void> completeLevel(int levelNumber) async {
    final newCompletedLevels = Set<int>.from(state.completedLevels)
      ..add(levelNumber);
    // Increment level number - GardenGame will handle detection of end of levels
    final newCurrentLevel = levelNumber + 1;

    final newProgress = state.copyWith(
      completedLevels: newCompletedLevels,
      currentLevel: newCurrentLevel,
    );

    await _saveProgress(newProgress);

    // Log level complete analytics
    final totalTaps = ref.read(levelTotalTapsProvider);
    final wrongTaps = ref.read(levelWrongTapsProvider);
    ref
        .read(analyticsServiceProvider)
        .logLevelComplete(levelNumber, totalTaps, wrongTaps);
  }

  Future<void> resetProgress() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    await repository.resetProgress();
    state = GameProgress.initial();
  }

  Future<void> _saveProgress(GameProgress progress) async {
    final repository = ref.read(gameProgressRepositoryProvider);
    await repository.saveProgress(progress);
    state = progress;
  }

  // Cloud sync methods
  Future<void> enableCloudSync() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    if (repository is FirebaseGameProgressRepository) {
      await repository.setCloudSyncEnabled(true);
    }
  }

  Future<void> disableCloudSync() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    if (repository is FirebaseGameProgressRepository) {
      await repository.setCloudSyncEnabled(false);
    }
  }

  Future<bool> isCloudSyncEnabled() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    return await repository.isCloudSyncEnabled();
  }

  Future<bool> isCloudSyncAvailable() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    return await repository.isCloudSyncAvailable();
  }

  Future<DateTime?> getLastSyncTime() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    return await repository.getLastSyncTime();
  }

  Future<void> manualSync() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    if (repository is FirebaseGameProgressRepository) {
      await repository.syncFromCloud();
      // Reload local data after sync
      await initialize();
    }
  }
}

// Current level provider
final currentLevelProvider = NotifierProvider<CurrentLevelNotifier, LevelData?>(
  CurrentLevelNotifier.new,
);

class CurrentLevelNotifier extends Notifier<LevelData?> {
  @override
  LevelData? build() => null;

  void setLevel(LevelData? level) {
    state = level;
  }
}

// Level completion state provider
final levelCompleteProvider = NotifierProvider<LevelCompleteNotifier, bool>(
  LevelCompleteNotifier.new,
);

class LevelCompleteNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setComplete(bool complete) {
    state = complete;
  }
}

// Total game completion state provider
final gameCompletedProvider = NotifierProvider<GameCompletedNotifier, bool>(
  GameCompletedNotifier.new,
);

class GameCompletedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setCompleted(bool completed) {
    state = completed;
  }
}

// Lives system
final livesProvider = NotifierProvider<LivesNotifier, int>(LivesNotifier.new);

class LivesNotifier extends Notifier<int> {
  @override
  int build() => 3;

  void setLives(int lives) {
    state = lives;
  }
}

// Game over state provider
final gameOverProvider = NotifierProvider<GameOverNotifier, bool>(
  GameOverNotifier.new,
);

class GameOverNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setGameOver(bool gameOver) {
    state = gameOver;
  }
}

// Game instance provider
final gameInstanceProvider =
    NotifierProvider<GameInstanceNotifier, GardenGame?>(
      GameInstanceNotifier.new,
    );

// Theme mode provider with Hive persistence
enum AppThemeMode { light, dark, system }

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    final box = ref.watch(hiveBoxProvider);
    final value = box.get('themeMode', defaultValue: 'system');
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.system;
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    final box = ref.read(hiveBoxProvider);
    await box.put('themeMode', mode.name);
  }
}

class GameInstanceNotifier extends Notifier<GardenGame?> {
  @override
  GardenGame? build() => null;

  void setGame(GardenGame game) {
    state = game;
  }

  void resetLives() {
    ref.read(livesProvider.notifier).setLives(3);
    ref.read(gameOverProvider.notifier).setGameOver(false);
  }

  void decrementLives() {
    final currentLives = ref.read(livesProvider);
    if (currentLives > 0) {
      ref.read(livesProvider.notifier).setLives(currentLives - 1);
      if (currentLives - 1 == 0) {
        ref.read(gameOverProvider.notifier).setGameOver(true);
      }
    }
  }
}

// Vine state for current level
class VineState {
  final String id;
  final bool isBlocked;
  final bool isCleared;
  final bool hasBeenAttempted; // New field for persistent blocked tap feedback

  VineState({
    required this.id,
    required this.isBlocked,
    required this.isCleared,
    this.hasBeenAttempted = false,
  });

  VineState copyWith({
    bool? isBlocked,
    bool? isCleared,
    bool? hasBeenAttempted,
  }) {
    return VineState(
      id: id,
      isBlocked: isBlocked ?? this.isBlocked,
      isCleared: isCleared ?? this.isCleared,
      hasBeenAttempted: hasBeenAttempted ?? this.hasBeenAttempted,
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
  static bool isVineBlockedInState(
    LevelData level,
    String vineId,
    List<String> activeVineIds,
  ) {
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

    while (currentRow >= 0 &&
        currentRow < gridRows &&
        currentCol >= 0 &&
        currentCol < gridCols) {
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

  /// Calculates how many cells a vine can slide before being blocked or exiting.
  static int getDistanceToBlocker(
    LevelData level,
    String vineId,
    List<String> activeVineIds,
  ) {
    final vine = level.vines.firstWhere((v) => v.id == vineId);
    final gridRows = level.grid['rows'] as int;
    final gridCols = level.grid['columns'] as int;

    if (vine.path.length < 2) return 0;

    final head = vine.path.last;
    final neck = vine.path[vine.path.length - 2];
    final dRow = (head['row'] as int) - (neck['row'] as int);
    final dCol = (head['col'] as int) - (neck['col'] as int);

    var currentRow = (head['row'] as int) + dRow;
    var currentCol = (head['col'] as int) + dCol;
    int distance = 0;

    while (currentRow >= 0 &&
        currentRow < gridRows &&
        currentCol >= 0 &&
        currentCol < gridCols) {
      for (final otherId in activeVineIds) {
        if (otherId == vineId) continue;

        final otherVine = level.vines.firstWhere((v) => v.id == otherId);
        for (final cell in otherVine.path) {
          if (cell['row'] == currentRow && cell['col'] == currentCol) {
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

final vineStatesProvider =
    NotifierProvider<VineStatesNotifier, Map<String, VineState>>(
      VineStatesNotifier.new,
    );

class VineStatesNotifier extends Notifier<Map<String, VineState>> {
  LevelData? _levelData;

  @override
  Map<String, VineState> build() {
    final levelData = ref.watch(currentLevelProvider);
    _levelData = levelData;
    return _calculateVineStates(levelData, {});
  }

  static Map<String, VineState> _calculateVineStates(
    LevelData? levelData,
    Map<String, VineState> currentStates,
  ) {
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
        isBlocked = LevelSolver.isVineBlockedInState(
          levelData,
          vine.id,
          activeIds,
        );
      }

      newStates[vine.id] = VineState(
        id: vine.id,
        isBlocked: isBlocked,
        isCleared: isCleared,
        hasBeenAttempted: currentStates[vine.id]?.hasBeenAttempted ?? false,
      );
    }

    return newStates;
  }

  void clearVine(String vineId) {
    debugPrint('VineStatesNotifier: Clearing vine $vineId');
    // Mark as cleared
    final mapWithCleared = Map<String, VineState>.from(state);
    if (mapWithCleared.containsKey(vineId)) {
      mapWithCleared[vineId] = mapWithCleared[vineId]!.copyWith(
        isCleared: true,
      );
    }

    // Recalculate blocking for all
    state = _calculateVineStates(_levelData, mapWithCleared);

    // Check if level is complete
    _checkLevelComplete();
  }

  void markAttempted(String vineId) {
    final s = state[vineId];
    if (s == null) return;

    if (s.isBlocked && !s.hasBeenAttempted) {
      debugPrint(
        'VineStatesNotifier: Marking $vineId as attempted and decrementing life',
      );
      state = {...state, vineId: s.copyWith(hasBeenAttempted: true)};

      // Increment wrong taps counter
      ref.read(levelWrongTapsProvider.notifier).increment();

      // Log wrong tap analytics
      final currentLevel = ref.read(currentLevelProvider);
      final remainingLives = ref.read(livesProvider);
      if (currentLevel != null) {
        ref
            .read(analyticsServiceProvider)
            .logWrongTap(currentLevel.levelNumber, remainingLives);
      }

      // Notify parent/provider to decrement lives
      ref.read(gameInstanceProvider.notifier).decrementLives();
    } else if (s.isBlocked && s.hasBeenAttempted) {
      debugPrint(
        'VineStatesNotifier: $vineId already attempted, skipping life decrement',
      );
    }
  }

  void _checkLevelComplete() {
    final allCleared = state.values.every((vineState) => vineState.isCleared);
    debugPrint(
      'VineStatesNotifier: Checking completion - all cleared: $allCleared, total vines: ${state.length}',
    );
    if (allCleared) {
      debugPrint(
        'VineStatesNotifier: LEVEL COMPLETE detected! Setting levelCompleteProvider to true',
      );
      // Trigger level complete
      ref.read(levelCompleteProvider.notifier).setComplete(true);
    }
  }

  void resetForLevel(LevelData levelData) {
    _levelData = levelData;
    state = _calculateVineStates(levelData, {});
  }
}
