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
import '../features/game/domain/entities/game_progress.dart';
import '../features/game/domain/repositories/game_progress_repository.dart';
import '../features/game/presentation/widgets/garden_game.dart';
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

  // Legacy getters for backward compatibility - these assume 15 levels per module
  // TODO: Remove these once all code is updated to use getCurrentModuleAndLevel
  @Deprecated(
    'Use getCurrentModuleAndLevel() instead for variable module sizes',
  )
  int get currentModule => ((currentGlobalLevel - 1) ~/ 15) + 1;

  @Deprecated(
    'Use getCurrentModuleAndLevel() instead for variable module sizes',
  )
  int get currentLevelInModule => ((currentGlobalLevel - 1) % 15) + 1;

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
    // Load from Hive
    final box = ref.watch(hiveBoxProvider);
    final currentGlobalLevel = box.get('currentGlobalLevel', defaultValue: 1);
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
    final newCompletedLevels = Set<int>.from(state.completedLevels)
      ..add(globalLevelNumber);

    final newState = state.copyWith(
      currentGlobalLevel: globalLevelNumber + 1,
      completedLevels: newCompletedLevels,
    );
    await _saveProgress(newState);
    state = newState;
    debugPrint(
      'GlobalProgressNotifier: Completed level $globalLevelNumber, advanced to ${newState.currentGlobalLevel}',
    );
  }

  Future<void> _saveProgress(GlobalProgress progress) async {
    final box = ref.read(hiveBoxProvider);
    await box.put('currentGlobalLevel', progress.currentGlobalLevel);
    await box.put('completedLevels', progress.completedLevels.toList());
  }

  Future<void> resetProgress() async {
    const defaultProgress = GlobalProgress(
      currentGlobalLevel: 1,
      completedLevels: {},
    );
    await _saveProgress(defaultProgress);
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

// --- Priority Queue for A* Search ---

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

// --- Level Solver Logic ---

class LevelSolver {
  /// Solves the level and returns one optimal sequence of vine IDs to clear.
  /// Returns null if the level is unsolvable.
  static List<String>? solve(LevelData level) {
    debugPrint('LevelSolver: Attempting to solve level ${level.id}');
    final initialVines = level.vines.map((v) => v.id).toList();

    // Pre-compute blocking relationships for optimization
    final blockingCache = <String, Set<String>>{};
    final blockedByCache = <String, Set<String>>{};

    // Build dependency graph
    for (final vine in level.vines) {
      blockingCache[vine.id] = <String>{};
      blockedByCache[vine.id] = <String>{};
    }

    for (final vine in level.vines) {
      for (final otherVine in level.vines) {
        if (vine.id != otherVine.id) {
          if (_doesVineBlock(level, vine.id, otherVine.id)) {
            blockingCache[vine.id]!.add(otherVine.id);
            blockedByCache[otherVine.id]!.add(vine.id);
          }
        }
      }
    }

    // Use priority-based search with heuristics
    final queue = _PriorityQueue<(List<String>, List<String>)>();
    queue.add((
      initialVines,
      [],
    ), _calculatePriority(level, initialVines, blockingCache, blockedByCache));

    final visited = <String>{};
    visited.add(_getStateKey(initialVines));

    int statesExplored = 0;
    const maxStates = 100000; // Prevent infinite loops on unsolvable levels

    while (queue.isNotEmpty && statesExplored < maxStates) {
      final (currentVines, sequence) = queue.removeFirst();
      statesExplored++;

      if (currentVines.isEmpty) {
        debugPrint(
          'LevelSolver: Solvable! Sequence: $sequence (explored $statesExplored states)',
        );
        return sequence;
      }

      // Get movable vines sorted by priority (most blocking first)
      final movableVines = currentVines
          .where((vineId) => !isVineBlockedInState(level, vineId, currentVines))
          .toList();

      // Sort by heuristic: prefer vines that unblock the most others
      movableVines.sort((a, b) {
        final aUnblocks = blockingCache[a]!.where(currentVines.contains).length;
        final bUnblocks = blockingCache[b]!.where(currentVines.contains).length;
        return bUnblocks.compareTo(
          aUnblocks,
        ); // Higher unblocking potential first
      });

      for (final vineId in movableVines) {
        final nextVines = List<String>.from(currentVines)..remove(vineId);
        final key = _getStateKey(nextVines);

        if (!visited.contains(key)) {
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
    }

    if (statesExplored >= maxStates) {
      debugPrint(
        'LevelSolver: Gave up after exploring $maxStates states - level may be too complex',
      );
    } else {
      debugPrint('LevelSolver: UNSOLVABLE level ${level.id}');
    }
    return null;
  }

  /// Checks if vine A blocks vine B (A prevents B from moving).
  /// Properly simulates snake-like movement of B and checks if A occupies any position B would move to.
  static bool _doesVineBlock(
    LevelData level,
    String blockerId,
    String blockedId,
  ) {
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
  static int _calculatePriority(
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

  static String _getStateKey(List<String> vines) {
    final sorted = List<String>.from(vines)..sort();
    return sorted.join(',');
  }

  /// Simulates snake-like movement: calculates where each segment of a vine
  /// would be positioned after the vine moves one step in its direction.
  static List<Map<String, int>> _simulateVineMovement(VineData vine) {
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
  static bool isVineBlockedInState(
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
  static int getDistanceToBlocker(
    LevelData level,
    String vineId,
    List<String> activeVineIds,
  ) {
    final vine = level.vines.firstWhere((v) => v.id == vineId);

    if (vine.orderedPath.isEmpty) return 0;

    // Start with current positions
    var currentPositions = List<Map<String, int>>.from(vine.orderedPath);
    int distance = 0;

    // Check up to a reasonable distance for blocking (no grid bounds in coordinate system)
    const int maxCheckDistance = 50; // Prevent infinite loops

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

      // Move to next positions
      currentPositions = newPositions;
      distance++;
    }

    return maxCheckDistance; // Positive = can move far without being blocked
  }

  /// Simulates snake-like movement from given positions.
  static List<Map<String, int>> _simulateVineMovementFromPositions(
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
        isBlocked = LevelSolver.isVineBlockedInState(
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
