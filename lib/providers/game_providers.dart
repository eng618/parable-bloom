import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/game/data/repositories/firebase_game_progress_repository.dart';
import '../features/game/data/repositories/hive_game_progress_repository.dart';
import '../features/game/data/repositories/hive_global_level_repository.dart';
import '../features/game/domain/entities/game_progress.dart';
import '../features/game/domain/repositories/game_progress_repository.dart';
import '../features/game/domain/repositories/global_level_repository.dart';
import '../features/game/domain/services/level_solver_service.dart';
import '../features/game/presentation/widgets/garden_game.dart';
import '../features/settings/data/repositories/hive_settings_repository.dart';
import '../features/settings/domain/repositories/settings_repository.dart';
import '../services/analytics_service.dart';

// Module data model
class ModuleData {
  final int id;
  final String name;
  final int levelCount;
  final Map<String, dynamic> parable;
  final String unlockMessage;

  ModuleData({
    required this.id,
    required this.name,
    required this.levelCount,
    required this.parable,
    required this.unlockMessage,
  });

  factory ModuleData.fromJson(Map<String, dynamic> json) {
    return ModuleData(
      id: json['id'],
      name: json['name'],
      levelCount: json['level_count'],
      parable: json['parable'],
      unlockMessage: json['unlock_message'],
    );
  }
}

class MaskData {
  final String mode; // 'hide' or 'show' or 'show-all'
  final List<Map<String, int>> points;

  MaskData({required this.mode, required this.points});

  factory MaskData.fromJson(dynamic json) {
    if (json == null) return MaskData(mode: 'show-all', points: []);

    final mode = (json['mode'] as String?) ?? 'show-all';
    final pts = <Map<String, int>>[];

    if (json['points'] != null) {
      for (final p in json['points']) {
        if (p is List && p.length >= 2) {
          pts.add({'x': p[0] as int, 'y': p[1] as int});
        } else if (p is Map) {
          pts.add({'x': p['x'] as int, 'y': p['y'] as int});
        }
      }
    }

    return MaskData(mode: mode, points: pts);
  }
}

// Provider for loading all module data
final modulesProvider = FutureProvider<List<ModuleData>>((ref) async {
  try {
    final jsonString = await rootBundle.loadString(
      'assets/levels/modules.json',
    );
    final jsonMap = json.decode(jsonString);
    final modulesList = jsonMap['modules'] as List<dynamic>;

    return modulesList.map((moduleJson) {
      final range = moduleJson['level_range'] as List<dynamic>;
      return ModuleData(
        id: moduleJson['id'],
        name: moduleJson['name'],
        levelCount: range[1] - range[0] + 1, // Calculate level count from range
        parable: moduleJson['parable'],
        unlockMessage: moduleJson['unlock_message'],
      );
    }).toList();
  } catch (e) {
    debugPrint('Error loading modules.json: $e');
    return [];
  }
});

// Models for game state
class VineData {
  final String id;
  final String headDirection;
  final List<Map<String, int>>
  orderedPath; // Ordered from head (index 0) to tail (last)
  final String color;

  VineData({
    required this.id,
    required this.headDirection,
    required this.orderedPath,
    required this.color,
  });

  factory VineData.fromJson(Map<String, dynamic> json) {
    return VineData(
      id: json['id'].toString(),
      headDirection: json['head_direction'],
      orderedPath: List<Map<String, int>>.from(
        json['ordered_path'].map(
          (cell) => {'x': cell['x'] as int, 'y': cell['y'] as int},
        ),
      ),
      color: json['color'],
    );
  }
}

class LevelData {
  final int id; // Global level ID (1, 2, 3...)
  final String name;
  final String difficulty;
  final List<VineData> vines;
  final int maxMoves;
  final int minMoves;
  final String complexity;
  final int grace;
  final MaskData? mask;

  LevelData({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.vines,
    required this.maxMoves,
    required this.minMoves,
    required this.complexity,
    required this.grace,
    this.mask,
  });

  factory LevelData.fromJson(Map<String, dynamic> json) {
    return LevelData(
      id: json['id'],
      name: json['name'],
      difficulty: json['difficulty'],
      vines: List<VineData>.from(
        json['vines'].map((vine) => VineData.fromJson(vine)),
      ),
      maxMoves: json['max_moves'],
      minMoves: json['min_moves'],
      complexity: json['complexity'],
      grace: json['grace'],
      mask: json.containsKey('mask') ? MaskData.fromJson(json['mask']) : null,
    );
  }

  // Calculate bounds dynamically from vine positions
  ({int minX, int maxX, int minY, int maxY}) getBounds() {
    if (vines.isEmpty || vines.first.orderedPath.isEmpty) {
      return (minX: 0, maxX: 8, minY: 0, maxY: 8); // Default fallback
    }

    int minX = vines
        .expand((vine) => vine.orderedPath)
        .map((pos) => pos['x'] as int)
        .reduce((a, b) => a < b ? a : b);

    int maxX = vines
        .expand((vine) => vine.orderedPath)
        .map((pos) => pos['x'] as int)
        .reduce((a, b) => a > b ? a : b);

    int minY = vines
        .expand((vine) => vine.orderedPath)
        .map((pos) => pos['y'] as int)
        .reduce((a, b) => a < b ? a : b);

    int maxY = vines
        .expand((vine) => vine.orderedPath)
        .map((pos) => pos['y'] as int)
        .reduce((a, b) => a > b ? a : b);

    return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  // Get dimensions for backwards compatibility
  int get width => getBounds().maxX - getBounds().minX + 1;
  int get height => getBounds().maxY - getBounds().minY + 1;
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

// Level solver service provider
final levelSolverServiceProvider = Provider<LevelSolverService>((ref) {
  return LevelSolverService();
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

// Settings repository provider
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final box = ref.watch(hiveBoxProvider);
  return HiveSettingsRepository(box);
});

// Global level repository provider
final globalLevelRepositoryProvider = Provider<GlobalLevelRepository>((ref) {
  final box = ref.watch(hiveBoxProvider);
  return HiveGlobalLevelRepository(box);
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
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logLevelComplete(levelNumber, totalTaps, wrongTaps),
    );
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

// Global progression (continuous level numbering)
class GlobalProgress {
  final int currentGlobalLevel;
  final Set<int> completedLevels; // Global level numbers: 1, 2, 3...

  const GlobalProgress({
    this.currentGlobalLevel = 1,
    this.completedLevels = const {},
  });

  // Helper methods to convert between global and module-based numbering
  // These require module data to be passed in since level counts vary per module
  ({int moduleId, int levelInModule}) getCurrentModuleAndLevel(
    List<ModuleData> modules,
  ) {
    int globalLevel = currentGlobalLevel;
    for (final module in modules) {
      if (globalLevel <= module.levelCount) {
        return (moduleId: module.id, levelInModule: globalLevel);
      }
      globalLevel -= module.levelCount;
    }
    // If we've exceeded all modules, return the last module's last level
    final lastModule = modules.last;
    return (moduleId: lastModule.id, levelInModule: lastModule.levelCount);
  }

  // Check if a module is completed (all levels in the module are done)
  bool isModuleCompleted(int moduleId, List<ModuleData> modules) {
    final module = modules.firstWhere((m) => m.id == moduleId);
    final startLevel =
        modules
            .take(moduleId - 1)
            .fold<int>(0, (total, m) => total + m.levelCount) +
        1;
    return completedLevels.containsAll(
      List.generate(module.levelCount, (i) => startLevel + i),
    );
  }

  @override
  String toString() {
    return 'GlobalProgress(currentGlobalLevel: $currentGlobalLevel, completedLevels: $completedLevels)';
  }

  GlobalProgress copyWith({
    int? currentGlobalLevel,
    Set<int>? completedLevels,
  }) {
    return GlobalProgress(
      currentGlobalLevel: currentGlobalLevel ?? this.currentGlobalLevel,
      completedLevels: completedLevels ?? this.completedLevels,
    );
  }
}

final globalProgressProvider =
    NotifierProvider<GlobalProgressNotifier, GlobalProgress>(
      GlobalProgressNotifier.new,
    );

class GlobalProgressNotifier extends Notifier<GlobalProgress> {
  @override
  GlobalProgress build() {
    // Load from repository synchronously at build time
    final box = ref.watch(hiveBoxProvider);

    // Use Hive directly for synchronous read at build time
    // The repository provides abstraction for mutations (completeLevel, resetProgress)
    final currentGlobalLevel =
        box.get('currentGlobalLevel', defaultValue: 1) as int;
    final completedLevels = Set<int>.from(
      box.get('completedLevels', defaultValue: <int>[]),
    );

    final progress = GlobalProgress(
      currentGlobalLevel: currentGlobalLevel,
      completedLevels: completedLevels,
    );

    debugPrint('GlobalProgressNotifier: Built with $progress');

    return progress;
  }

  Future<void> completeLevel(int globalLevelNumber) async {
    final repository = ref.read(globalLevelRepositoryProvider);

    final newCompletedLevels = Set<int>.from(state.completedLevels)
      ..add(globalLevelNumber);

    final newState = state.copyWith(
      currentGlobalLevel: globalLevelNumber + 1,
      completedLevels: newCompletedLevels,
    );

    await repository.setCurrentGlobalLevel(newState.currentGlobalLevel);
    state = newState;

    debugPrint(
      'GlobalProgressNotifier: Completed level $globalLevelNumber, advanced to ${newState.currentGlobalLevel}',
    );
  }

  Future<void> resetProgress() async {
    final repository = ref.read(globalLevelRepositoryProvider);

    const defaultProgress = GlobalProgress(
      currentGlobalLevel: 1,
      completedLevels: {},
    );

    await repository.setCurrentGlobalLevel(defaultProgress.currentGlobalLevel);
    state = defaultProgress;

    debugPrint('GlobalProgressNotifier: Progress reset to $defaultProgress');
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

// Grace system
final graceProvider = NotifierProvider<GraceNotifier, int>(GraceNotifier.new);

class GraceNotifier extends Notifier<int> {
  @override
  int build() => 3;

  void setGrace(int grace) {
    state = grace;
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
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setThemeMode(mode.name);
  }
}

class GameInstanceNotifier extends Notifier<GardenGame?> {
  @override
  GardenGame? build() => null;

  void setGame(GardenGame game) {
    state = game;
  }

  void resetGrace() {
    ref.read(graceProvider.notifier).setGrace(3);
    ref.read(gameOverProvider.notifier).setGameOver(false);
  }

  void decrementGrace() {
    final currentGrace = ref.read(graceProvider);
    if (currentGrace > 0) {
      ref.read(graceProvider.notifier).setGrace(currentGrace - 1);
      if (currentGrace - 1 == 0) {
        ref.read(gameOverProvider.notifier).setGameOver(true);
      }
    }
  }
}

// Vine state for current level
enum VineAnimationState {
  normal, // On board, tappable, blocks others
  animatingClear, // Animating off-screen, doesn't block others, will be cleared
  animatingBlocked, // Doing blocked animation, blocks others during animation
  cleared, // Removed from game
}

class VineState {
  final String id;
  final bool isBlocked;
  final bool isCleared;
  final bool hasBeenAttempted;
  final VineAnimationState animationState;

  VineState({
    required this.id,
    required this.isBlocked,
    required this.isCleared,
    this.hasBeenAttempted = false,
    this.animationState = VineAnimationState.normal,
  });

  VineState copyWith({
    bool? isBlocked,
    bool? isCleared,
    bool? hasBeenAttempted,
    VineAnimationState? animationState,
  }) {
    return VineState(
      id: id,
      isBlocked: isBlocked ?? this.isBlocked,
      isCleared: isCleared ?? this.isCleared,
      hasBeenAttempted: hasBeenAttempted ?? this.hasBeenAttempted,
      animationState: animationState ?? this.animationState,
    );
  }
}

final vineStatesProvider =
    NotifierProvider<VineStatesNotifier, Map<String, VineState>>(
      VineStatesNotifier.new,
    );

class VineStatesNotifier extends Notifier<Map<String, VineState>> {
  LevelData? _levelData;
  LevelSolverService? _solverService;

  @override
  Map<String, VineState> build() {
    final levelData = ref.watch(currentLevelProvider);
    _levelData = levelData;
    _solverService = ref.watch(levelSolverServiceProvider);
    return _calculateVineStates(levelData, {});
  }

  Map<String, VineState> _calculateVineStates(
    LevelData? levelData,
    Map<String, VineState> currentStates,
  ) {
    if (levelData == null || _solverService == null) return {};

    // Active vines are those that can block others (not cleared and not animating clear)
    final blockingVineIds = <String>[];
    for (final vine in levelData.vines) {
      final currentState = currentStates[vine.id];
      final isCleared = currentState?.isCleared ?? false;
      final animationState =
          currentState?.animationState ?? VineAnimationState.normal;

      if (!isCleared && animationState != VineAnimationState.animatingClear) {
        blockingVineIds.add(vine.id);
      }
    }

    final newStates = <String, VineState>{};
    for (final vine in levelData.vines) {
      final currentState = currentStates[vine.id];
      final isCleared = currentState?.isCleared ?? false;
      final animationState =
          currentState?.animationState ?? VineAnimationState.normal;
      final hasBeenAttempted = currentState?.hasBeenAttempted ?? false;

      bool isBlocked = false;

      // Only calculate blocking for vines that are in normal state
      if (!isCleared && animationState == VineAnimationState.normal) {
        isBlocked = _solverService!.isVineBlockedInState(
          levelData,
          vine.id,
          blockingVineIds,
        );
      }

      newStates[vine.id] = VineState(
        id: vine.id,
        isBlocked: isBlocked,
        isCleared: isCleared,
        hasBeenAttempted: hasBeenAttempted,
        animationState: animationState,
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

    if (!s.hasBeenAttempted) {
      debugPrint(
        'VineStatesNotifier: Marking $vineId as attempted and decrementing life',
      );
      state = {...state, vineId: s.copyWith(hasBeenAttempted: true)};

      // Increment wrong taps counter
      ref.read(levelWrongTapsProvider.notifier).increment();

      // Log wrong tap analytics
      final currentLevel = ref.read(currentLevelProvider);
      final remainingGrace = ref.read(graceProvider);
      if (currentLevel != null) {
        ref
            .read(analyticsServiceProvider)
            .logWrongTap(currentLevel.id, remainingGrace);
      }

      // Notify parent/provider to decrement grace
      ref.read(gameInstanceProvider.notifier).decrementGrace();
    } else {
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

  void setAnimationState(String vineId, VineAnimationState animationState) {
    final currentState = state[vineId];
    if (currentState == null) return;

    state = {
      ...state,
      vineId: currentState.copyWith(animationState: animationState),
    };

    // Recalculate blocking states when animation state changes
    state = _calculateVineStates(_levelData, state);
  }

  void resetForLevel(LevelData levelData) {
    _levelData = levelData;
    state = _calculateVineStates(levelData, {});
  }
}
