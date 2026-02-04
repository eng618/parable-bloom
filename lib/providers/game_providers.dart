import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../features/game/data/repositories/firebase_game_progress_repository.dart';
import '../features/game/data/repositories/hive_game_progress_repository.dart';
import '../features/game/domain/entities/game_progress.dart';
import '../features/game/domain/repositories/game_progress_repository.dart';
import '../features/game/domain/services/level_solver_service.dart';
import '../features/game/presentation/widgets/garden_game.dart';
import '../features/settings/data/repositories/hive_settings_repository.dart';
import '../features/settings/domain/repositories/settings_repository.dart';
import '../core/vine_color_palette.dart';
import '../services/background_audio_controller.dart';
import '../services/analytics_service.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

// Camera state for zoom and pan
class CameraState {
  final double
      zoom; // Scale factor (1.0 = normal, <1.0 = zoomed out, >1.0 = zoomed in)
  final vm.Vector2 panOffset; // Pan offset in pixels
  final double minZoom; // Minimum allowed zoom (dynamic based on level)
  final double maxZoom; // Maximum allowed zoom
  final bool isAnimating; // Whether camera is currently animating

  const CameraState({
    required this.zoom,
    required this.panOffset,
    required this.minZoom,
    required this.maxZoom,
    this.isAnimating = false,
  });

  CameraState copyWith({
    double? zoom,
    vm.Vector2? panOffset,
    double? minZoom,
    double? maxZoom,
    bool? isAnimating,
  }) {
    return CameraState(
      zoom: zoom ?? this.zoom,
      panOffset: panOffset ?? this.panOffset,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      isAnimating: isAnimating ?? this.isAnimating,
    );
  }

  // Default camera state
  static CameraState defaultState() {
    return CameraState(
      zoom: 1.0,
      panOffset: vm.Vector2.zero(),
      minZoom: 0.5,
      maxZoom: 2.0,
      isAnimating: false,
    );
  }
}

// Module data model
class ModuleData {
  final int id;
  final String name;
  final String themeSeed;
  final List<int> levels;
  final int challengeLevel;
  final Map<String, dynamic> parable;
  final String unlockMessage;

  ModuleData({
    required this.id,
    required this.name,
    required this.themeSeed,
    required this.levels,
    required this.challengeLevel,
    required this.parable,
    required this.unlockMessage,
  });

  // Computed properties for backward compatibility and convenience
  int get startLevel => levels.isNotEmpty
      ? levels.reduce((curr, next) => curr < next ? curr : next)
      : challengeLevel;
  int get endLevel {
    if (levels.isEmpty) return challengeLevel;
    final maxLevel = levels.reduce((curr, next) => curr > next ? curr : next);
    return challengeLevel > 0
        ? (challengeLevel > maxLevel ? challengeLevel : maxLevel)
        : maxLevel;
  }

  int get levelCount => challengeLevel > 0 ? levels.length + 1 : levels.length;
  List<int> get allLevels {
    final result = [...levels];
    if (challengeLevel > 0 && !result.contains(challengeLevel)) {
      result.add(challengeLevel);
    }
    return result..sort();
  }

  bool containsLevel(int levelId) {
    return levels.contains(levelId) ||
        (challengeLevel > 0 && levelId == challengeLevel);
  }

  factory ModuleData.fromJson(Map<String, dynamic> json) {
    return ModuleData(
      id: json['id'] as int,
      name: json['name'] as String,
      themeSeed: (json['theme_seed'] as String?) ?? 'forest',
      levels:
          (json['levels'] as List<dynamic>?)?.map((e) => e as int).toList() ??
              [],
      challengeLevel: (json['challenge_level'] as int?) ?? 0,
      parable: json['parable'] as Map<String, dynamic>,
      unlockMessage: (json['unlock_message'] as String?) ?? '',
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
      'assets/data/modules.json',
    );
    final jsonMap = json.decode(jsonString);
    final modulesList = jsonMap['modules'] as List<dynamic>;

    return modulesList
        .map((moduleJson) =>
            ModuleData.fromJson(moduleJson as Map<String, dynamic>))
        .toList();
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
  final String? vineColor;

  VineData({
    required this.id,
    required this.headDirection,
    required this.orderedPath,
    this.vineColor,
  });

  factory VineData.fromJson(Map<String, dynamic> json) {
    final vineColor = json['vine_color']?.toString().trim();
    if (vineColor != null && vineColor.isNotEmpty) {
      if (!VineColorPalette.isKnownKey(vineColor)) {
        debugPrint(
          'Warning: Unknown vine_color "$vineColor" will use default color',
        );
      }
    }
    return VineData(
      id: json['id'].toString(),
      headDirection: json['head_direction'],
      orderedPath: List<Map<String, int>>.from(
        json['ordered_path'].map(
          (cell) => {'x': cell['x'] as int, 'y': cell['y'] as int},
        ),
      ),
      vineColor: vineColor,
    );
  }
}

class LevelData {
  final int id; // Global level ID (1, 2, 3...)
  final String name;
  final String difficulty;

  /// Canonical grid size for the level.
  ///
  /// Ordering is `[width, height]` where:
  /// - x in `[0, width-1]`
  /// - y in `[0, height-1]`
  final int gridWidth;
  final int gridHeight;
  final List<VineData> vines;
  final int maxMoves;
  final int minMoves;
  final String complexity;
  final int grace;
  final MaskData mask;

  LevelData({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.gridWidth,
    required this.gridHeight,
    required this.vines,
    required this.maxMoves,
    required this.minMoves,
    required this.complexity,
    required this.grace,
    required this.mask,
  });

  factory LevelData.fromJson(Map<String, dynamic> json) {
    final gridSize = json['grid_size'];
    if (gridSize is! List || gridSize.length < 2) {
      throw const FormatException(
        'Level JSON must include grid_size: [width, height]',
      );
    }

    final gridWidth = (gridSize[0] as num).toInt();
    final gridHeight = (gridSize[1] as num).toInt();
    if (gridWidth <= 0 || gridHeight <= 0) {
      throw FormatException(
        'grid_size must be positive; got [$gridWidth, $gridHeight]',
      );
    }

    final vines = List<VineData>.from(
      json['vines'].map((vine) => VineData.fromJson(vine)),
    );

    // Validate vine coordinates are within bounds.
    for (final vine in vines) {
      for (final cell in vine.orderedPath) {
        final x = cell['x'] as int;
        final y = cell['y'] as int;
        if (x < 0 || x >= gridWidth || y < 0 || y >= gridHeight) {
          throw FormatException(
            'Vine ${vine.id} has cell ($x,$y) outside grid_size [$gridWidth,$gridHeight]',
          );
        }
      }
    }

    final mask = MaskData.fromJson(json['mask']);

    // For MVP, mask is visual-only, but we validate that vines never occupy masked-out cells.
    for (final vine in vines) {
      for (final cell in vine.orderedPath) {
        final x = cell['x'] as int;
        final y = cell['y'] as int;
        if (!_isCellVisibleWithMask(mask, x, y)) {
          throw FormatException(
            'Vine ${vine.id} occupies masked-out cell ($x,$y)',
          );
        }
      }
    }

    return LevelData(
      id: json['id'],
      name: json['name'],
      difficulty: json['difficulty'],
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      vines: vines,
      maxMoves: json['max_moves'],
      minMoves: json['min_moves'],
      complexity: json['complexity'],
      grace: json['grace'],
      mask: mask,
    );
  }

  bool isCellVisible(int x, int y) {
    return _isCellVisibleWithMask(mask, x, y);
  }

  // Bounds are now driven by grid_size.
  ({int minX, int maxX, int minY, int maxY}) getBounds() {
    return (minX: 0, maxX: gridWidth - 1, minY: 0, maxY: gridHeight - 1);
  }

  // Get dimensions for backwards compatibility
  int get width => gridWidth;
  int get height => gridHeight;

  static bool _isCellVisibleWithMask(MaskData mask, int x, int y) {
    switch (mask.mode) {
      case 'show-all':
        return true;
      case 'hide':
        return !mask.points.any((p) => p['x'] == x && p['y'] == y);
      case 'show':
        return mask.points.any((p) => p['x'] == x && p['y'] == y);
      default:
        return true;
    }
  }
}

// Providers
final hiveBoxProvider = Provider<Box>((ref) {
  try {
    // If the app initialized Hive and opened the garden_save box in main(), prefer that.
    if (Hive.isBoxOpen('garden_save')) {
      return Hive.box('garden_save');
    }
  } catch (e) {
    // If Hive is not available (for example during widget tests or outside main), fall back to an in-memory box.
  }

  debugPrint(
      'hiveBoxProvider: No Hive box open; using in-memory fallback for tests');
  return _InMemoryBox();
});

// Minimal in-memory box implementation used as a safe fallback in tests or when Hive
// hasn't been initialized. It implements the commonly-used subset of the Hive Box API.
class _InMemoryBox implements Box<dynamic> {
  final Map _store = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _store.containsKey(key) ? _store[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => _store[key] = value;

  @override
  Future<void> delete(dynamic key) async => _store.remove(key);

  @override
  Future<int> clear() async {
    final len = _store.length;
    _store.clear();
    return len;
  }

  @override
  bool containsKey(dynamic key) => _store.containsKey(key);

  @override
  Iterable get keys => _store.keys;

  @override
  Iterable get values => _store.values;

  @override
  Map toMap() => Map.from(_store);

  @override
  int get length => _store.length;

  @override
  String get name => 'in_memory_box';

  @override
  bool get isOpen => true;

  @override
  Future<void> close() async {}

  // Use noSuchMethod to gracefully handle other Box API calls we don't need here.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  throw UnimplementedError('AnalyticsService must be initialized in main');
});

// App version provider - fetches version from platform configuration
// (populated from pubspec.yaml during build)
final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return '${packageInfo.version}+${packageInfo.buildNumber}';
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
  // Use the cloud-aware repository which handles both local and cloud sync
  return ref.watch(cloudGameProgressRepositoryProvider);
});

// Settings repository provider
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final box = ref.watch(hiveBoxProvider);
  return HiveSettingsRepository(box);
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
    debugPrint(
      'GameProgressNotifier: Completing level $levelNumber, current state: $state',
    );

    final newCompletedLevels = Set<int>.from(state.completedLevels)
      ..add(levelNumber);

    bool newTutorialCompleted = state.tutorialCompleted;
    int newCurrentLevel;

    // Main levels start at 1; tutorial ends at level 5
    const int firstMainLevel = 1;
    const int maxTutorialLevel = 5;

    if (levelNumber == maxTutorialLevel && !state.tutorialCompleted) {
      // Tutorial completed, start main levels from 1
      newTutorialCompleted = true;
      newCurrentLevel = firstMainLevel;
    } else {
      // Increment level number - GardenGame will handle detection of end of levels
      newCurrentLevel = levelNumber + 1;
    }

    final newProgress = state.copyWith(
      completedLevels: newCompletedLevels,
      currentLevel: newCurrentLevel,
      tutorialCompleted: newTutorialCompleted,
    );

    debugPrint(
      'GameProgressNotifier: New progress: $newProgress',
    );

    await _saveProgress(newProgress);

    debugPrint(
      'GameProgressNotifier: After save, state is: $state',
    );

    // Log level complete analytics
    final totalTaps = ref.read(levelTotalTapsProvider);
    final wrongTaps = ref.read(levelWrongTapsProvider);
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logLevelComplete(levelNumber, totalTaps, wrongTaps),
    );
  }

  Future<void> resetTutorial() async {
    // Just reset the tutorial completed flag
    // We don't remove levels 1-5 from completedLevels anymore since they are distinct from lessons
    final newProgress = state.copyWith(
      tutorialCompleted: false,
      // Keep current level as is, or ensure it's at least 1
      currentLevel: state.currentLevel < 1 ? 1 : state.currentLevel,
    );

    await _saveProgress(newProgress);
  }

  Future<void> completeLesson({
    required int lessonId,
    required int? nextLesson,
    required bool allLessonsCompleted,
  }) async {
    final newCompletedLessons = Set<int>.from(state.completedLessons)
      ..add(lessonId);

    final newProgress = state.copyWith(
      completedLessons: newCompletedLessons,
      currentLesson: nextLesson,
      lessonCompleted: allLessonsCompleted,
      tutorialCompleted: allLessonsCompleted,
      // When tutorial first completes, ensure we start at level 1 if not already further
      currentLevel: (allLessonsCompleted && state.currentLevel < 1)
          ? 1
          : state.currentLevel,
    );

    await _saveProgress(newProgress);
  }

  Future<void> resetLessons() async {
    final newProgress = state.copyWith(
      currentLesson: 1,
      completedLessons: {},
      lessonCompleted: false,
      tutorialCompleted: false,
    );

    await _saveProgress(newProgress);
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

// Background audio enabled setting
final backgroundAudioEnabledProvider =
    NotifierProvider<BackgroundAudioEnabledNotifier, bool>(
  BackgroundAudioEnabledNotifier.new,
);

class BackgroundAudioEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(hiveBoxProvider);
    return box.get('backgroundAudioEnabled', defaultValue: true) as bool;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setBackgroundAudioEnabled(enabled);
  }
}

// Haptics enabled setting
// TODO: Implement actual haptic feedback logic in the game events
final hapticsEnabledProvider = NotifierProvider<HapticsEnabledNotifier, bool>(
  HapticsEnabledNotifier.new,
);

class HapticsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(hiveBoxProvider);
    return box.get('hapticsEnabled', defaultValue: true) as bool;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setHapticsEnabled(enabled);
  }
}

// Background audio controller (plays/loops based on backgroundAudioEnabledProvider)
final backgroundAudioControllerProvider = Provider<BackgroundAudioController>((
  ref,
) {
  final controller = BackgroundAudioController();

  ref.onDispose(() {
    unawaited(controller.dispose());
  });

  ref.listen<bool>(backgroundAudioEnabledProvider, (previous, next) {
    unawaited(controller.setEnabled(next));
  });

  // Apply initial state.
  unawaited(controller.setEnabled(ref.read(backgroundAudioEnabledProvider)));

  return controller;
});

// Debug setting for showing grid coordinates
final debugShowGridCoordinatesProvider =
    NotifierProvider<DebugShowGridCoordinatesNotifier, bool>(
  DebugShowGridCoordinatesNotifier.new,
);

class DebugShowGridCoordinatesNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(hiveBoxProvider);
    return box.get('debugShowGridCoordinates', defaultValue: false) as bool;
  }

  Future<void> setShowCoordinates(bool show) async {
    state = show;
    final box = ref.read(hiveBoxProvider);
    await box.put('debugShowGridCoordinates', show);
  }
}

// Debug setting for vine animation logging
final debugVineAnimationLoggingProvider =
    NotifierProvider<DebugVineAnimationLoggingNotifier, bool>(
  DebugVineAnimationLoggingNotifier.new,
);

// Test-only override to make debug UI visible during widget tests. Defaults
// to false in normal builds.
final debugUiEnabledForTestsProvider = Provider<bool>((ref) => false);

class DebugVineAnimationLoggingNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = ref.watch(hiveBoxProvider);
    return box.get('debugVineAnimationLogging', defaultValue: false) as bool;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final box = ref.read(hiveBoxProvider);
    await box.put('debugVineAnimationLogging', enabled);
  }
}

// Debug-only selected level for temporary play sessions (debug builds only)
class DebugSelectedLevelNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setLevel(int? level) => state = level;
}

final debugSelectedLevelProvider =
    NotifierProvider<DebugSelectedLevelNotifier, int?>(
  DebugSelectedLevelNotifier.new,
);

// Whether we're in a debug play session (true when debugSelectedLevelProvider is non-null)
final debugPlayModeProvider = Provider<bool>((ref) {
  return ref.watch(debugSelectedLevelProvider) != null;
});

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

// Internal celebration effect selection (not user-facing)
enum CelebrationEffect {
  pondRipples,
  // Future options
  leafPetals,
  confetti,
  rippleFireworks,
}

final celebrationEffectProvider =
    NotifierProvider<CelebrationEffectNotifier, CelebrationEffect>(
  CelebrationEffectNotifier.new,
);

class CelebrationEffectNotifier extends Notifier<CelebrationEffect> {
  @override
  CelebrationEffect build() {
    // Default effect; can be overridden programmatically for seasonal themes
    return CelebrationEffect.rippleFireworks;
  }

  void setEffect(CelebrationEffect effect) {
    state = effect;
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
  }

  void markAttempted(String vineId) {
    final s = state[vineId];
    if (s == null) return;

    if (!s.hasBeenAttempted) {
      debugPrint(
        'VineStatesNotifier: Marking $vineId as attempted and decrementing life',
      );

      state = {
        ...state,
        vineId: s.copyWith(hasBeenAttempted: true),
      };

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
    // Level is complete when all vines have either finished clearing
    // or are currently animating their clear animation
    final allFinished = state.values.every((vineState) =>
        vineState.isCleared ||
        vineState.animationState == VineAnimationState.animatingClear);
    debugPrint(
      'VineStatesNotifier: Checking completion - allFinished: $allFinished, total vines: ${state.length}',
    );
    if (allFinished && state.isNotEmpty) {
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

    // Check if level is complete when a vine starts clearing animation
    if (animationState == VineAnimationState.animatingClear) {
      _checkLevelComplete();
    }
  }

  void resetForLevel(LevelData levelData) {
    _levelData = levelData;
    state = _calculateVineStates(levelData, {});
  }
}

// Provider for projection lines visibility
final projectionLinesVisibleProvider =
    NotifierProvider<ProjectionLinesVisibleNotifier, bool>(
  ProjectionLinesVisibleNotifier.new,
);

class ProjectionLinesVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void setVisible(bool visible) {
    state = visible;
  }
}

// Provider to determine if any vine is currently animating
final anyVineAnimatingProvider = Provider<bool>((ref) {
  final vineStates = ref.watch(vineStatesProvider);
  return vineStates.values.any(
    (state) =>
        state.animationState == VineAnimationState.animatingClear ||
        state.animationState == VineAnimationState.animatingBlocked,
  );
});

// Toggle to disable runtime animations in tests or debug builds
final disableAnimationsProvider = Provider<bool>((ref) => false);

// Camera state provider for zoom and pan
final cameraStateProvider = NotifierProvider<CameraStateNotifier, CameraState>(
  CameraStateNotifier.new,
);

class CameraStateNotifier extends Notifier<CameraState> {
  Timer? _animationTimer;
  double _animationStartZoom = 1.0;
  double _animationTargetZoom = 1.0;
  vm.Vector2 _animationStartOffset = vm.Vector2.zero();
  vm.Vector2 _animationTargetOffset = vm.Vector2.zero();
  double _animationProgress = 0.0;
  static const double _animationDurationSeconds = 0.8;

  @override
  CameraState build() {
    // Ensure any running animation timers are cancelled when this notifier is disposed
    ref.onDispose(() {
      _animationTimer?.cancel();
    });
    return CameraState.defaultState();
  }

  // Calculate dynamic zoom bounds based on screen and grid size
  void updateZoomBounds({
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
    required double cellSize,
  }) {
    // Calculate how much we need to zoom out to fit the entire board
    final gridWidth = gridCols * cellSize;
    final gridHeight = gridRows * cellSize;

    // Add padding around the grid (10% on each side)
    const padding = 0.9; // Use 90% of screen space

    final zoomToFitWidth = (screenWidth * padding) / gridWidth;
    final zoomToFitHeight = (screenHeight * padding) / gridHeight;

    // Use the smaller zoom to ensure entire board fits
    final zoomToFit =
        zoomToFitWidth < zoomToFitHeight ? zoomToFitWidth : zoomToFitHeight;

    // Min zoom is slightly less than fit-to-screen (show a bit more context)
    final minZoom = (zoomToFit * 0.85).clamp(0.3, 1.0);

    // Max zoom allows comfortable zooming in, but not excessively
    final maxZoom = 2.5;

    debugPrint(
      'CameraStateNotifier: Updated zoom bounds - min: $minZoom, max: $maxZoom (fit: $zoomToFit)',
    );

    state = state.copyWith(
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
  }

  // Start animated zoom from full-board view to 1.0x
  void animateToDefaultZoom({
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
    required double cellSize,
  }) {
    // Calculate initial "fit full board" zoom
    final gridWidth = gridCols * cellSize;
    final gridHeight = gridRows * cellSize;

    const padding = 0.9;
    final zoomToFitWidth = (screenWidth * padding) / gridWidth;
    final zoomToFitHeight = (screenHeight * padding) / gridHeight;
    final initialZoom =
        zoomToFitWidth < zoomToFitHeight ? zoomToFitWidth : zoomToFitHeight;

    // Start from fit-to-screen, animate to 1.0x
    _animationStartZoom = initialZoom;
    _animationTargetZoom = 1.0;
    _animationStartOffset = vm.Vector2.zero();
    _animationTargetOffset = vm.Vector2.zero();
    _animationProgress = 0.0;

    // Set initial state
    state = state.copyWith(
      zoom: initialZoom,
      panOffset: vm.Vector2.zero(),
      isAnimating: true,
    );

    debugPrint(
      'CameraStateNotifier: Starting animation from zoom $initialZoom to 1.0',
    );

    // If animations are disabled (e.g., during tests), skip creating timers
    if (ref.read(disableAnimationsProvider)) {
      state = state.copyWith(isAnimating: false, zoom: _animationTargetZoom);
      debugPrint(
          'CameraStateNotifier: Animations disabled - skipping animation');
      return;
    }

    // Start animation timer
    _animationTimer?.cancel();
    final startTime = DateTime.now();
    _animationTimer = Timer.periodic(
      const Duration(milliseconds: 16), // ~60 FPS
      (timer) {
        // If animations get disabled during runtime (e.g., tests), cancel safely.
        if (ref.read(disableAnimationsProvider)) {
          timer.cancel();
          state = state.copyWith(isAnimating: false);
          debugPrint(
              'CameraStateNotifier: Animations disabled during run - cancelling');
          return;
        }

        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        _animationProgress =
            (elapsed / (_animationDurationSeconds * 1000)).clamp(0.0, 1.0);

        // Ease-in-out interpolation
        final t = _easeInOutCubic(_animationProgress);

        final newZoom = _animationStartZoom +
            (_animationTargetZoom - _animationStartZoom) * t;
        final newOffset = vm.Vector2(
          _animationStartOffset.x +
              (_animationTargetOffset.x - _animationStartOffset.x) * t,
          _animationStartOffset.y +
              (_animationTargetOffset.y - _animationStartOffset.y) * t,
        );

        state = state.copyWith(
          zoom: newZoom,
          panOffset: newOffset,
        );

        if (_animationProgress >= 1.0) {
          timer.cancel();
          state = state.copyWith(isAnimating: false);
          debugPrint('CameraStateNotifier: Animation complete');
        }
      },
    );
  }

  // Cubic ease-in-out function
  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;
  }

  // Update zoom (from gesture)
  void updateZoom(double newZoom, {bool clamp = true}) {
    if (state.isAnimating) {
      return; // Don't allow manual control during animation
    }

    final clampedZoom =
        clamp ? newZoom.clamp(state.minZoom, state.maxZoom) : newZoom;

    state = state.copyWith(zoom: clampedZoom);
  }

  // Update pan offset (from gesture)
  void updatePanOffset(
    vm.Vector2 newOffset, {
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
    required double cellSize,
  }) {
    if (state.isAnimating) {
      return; // Don't allow manual control during animation
    }

    // Calculate constrained offset to keep grid visible
    final constrainedOffset = _constrainPanOffset(
      newOffset,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: gridCols,
      gridRows: gridRows,
      cellSize: cellSize,
    );

    state = state.copyWith(panOffset: constrainedOffset);
  }

  // Constrain pan offset to keep grid visible
  vm.Vector2 _constrainPanOffset(
    vm.Vector2 offset, {
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
    required double cellSize,
  }) {
    final scaledCellSize = cellSize * state.zoom;
    final gridWidth = gridCols * scaledCellSize;
    final gridHeight = gridRows * scaledCellSize;

    // Calculate centered position
    final centeredX = (screenWidth - gridWidth) / 2;
    final centeredY = (screenHeight - gridHeight) / 2;

    // Allow panning but keep at least 20% of grid visible
    const visibleThreshold = 0.2;
    final maxOffsetX = gridWidth * (1 - visibleThreshold);
    final maxOffsetY = gridHeight * (1 - visibleThreshold);

    // Constrain offset
    final constrainedX = offset.x.clamp(
      centeredX - maxOffsetX,
      centeredX + maxOffsetX,
    );
    final constrainedY = offset.y.clamp(
      centeredY - maxOffsetY,
      centeredY + maxOffsetY,
    );

    return vm.Vector2(constrainedX, constrainedY);
  }

  // Reset to default zoom and centered position
  void reset() {
    _animationTimer?.cancel();
    state = CameraState.defaultState();
  }

  // Reset to 1.0x zoom and centered position (for manual reset)
  void resetToCenter({
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
    required double cellSize,
  }) {
    if (state.isAnimating) return;

    // Set zoom to 1.0 and pan offset to zero (which centers the grid)
    state = state.copyWith(
      zoom: 1.0,
      panOffset: vm.Vector2.zero(),
    );
  }

  double pow(double x, int exp) {
    if (exp == 0) return 1;
    if (exp == 1) return x;
    double result = 1;
    for (int i = 0; i < exp.abs(); i++) {
      result *= x;
    }
    return exp > 0 ? result : 1 / result;
  }
}
