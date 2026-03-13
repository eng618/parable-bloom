import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/constants/animation_timing.dart';
import '../core/game_board_layout.dart';
import '../features/game/data/repositories/firebase_game_progress_repository.dart';
import '../features/game/domain/entities/game_progress.dart';
import '../features/game/domain/entities/level_data.dart';
import '../features/game/domain/services/level_solver_service.dart';
import '../features/game/presentation/widgets/garden_game.dart';
import 'counter_providers.dart';
import 'infrastructure_providers.dart';
import 'settings_providers.dart';
import '../services/analytics_service.dart';
import '../services/logger_service.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

export '../features/game/domain/entities/level_data.dart';
export 'counter_providers.dart';
export 'infrastructure_providers.dart';
export 'settings_providers.dart';

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
  } catch (e, stack) {
    LoggerService.error('Error loading modules.json',
        error: e, stackTrace: stack, tag: 'modulesProvider');
    return [];
  }
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
    } catch (e, stack) {
      // If loading fails, keep initial state
      LoggerService.error('Error initializing GameProgress',
          error: e, stackTrace: stack, tag: 'GameProgressNotifier');
      state = GameProgress.initial();
    }
  }

  Future<void> completeLevel(int levelNumber) async {
    LoggerService.debug(
      'Completing level $levelNumber, current state: $state',
      tag: 'GameProgressNotifier',
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

    LoggerService.debug(
      'New progress: $newProgress',
      tag: 'GameProgressNotifier',
    );

    await _saveProgress(newProgress);

    LoggerService.debug(
      'After save, state is: $state',
      tag: 'GameProgressNotifier',
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
  final bool isWithered;
  final VineAnimationState animationState;

  VineState({
    required this.id,
    required this.isBlocked,
    required this.isCleared,
    this.hasBeenAttempted = false,
    this.isWithered = false,
    this.animationState = VineAnimationState.normal,
  });

  VineState copyWith({
    bool? isBlocked,
    bool? isCleared,
    bool? hasBeenAttempted,
    bool? isWithered,
    VineAnimationState? animationState,
  }) {
    return VineState(
      id: id,
      isBlocked: isBlocked ?? this.isBlocked,
      isCleared: isCleared ?? this.isCleared,
      hasBeenAttempted: hasBeenAttempted ?? this.hasBeenAttempted,
      isWithered: isWithered ?? this.isWithered,
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
      final isWithered = currentState?.isWithered ?? false;

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
        isWithered: isWithered,
        animationState: animationState,
      );
    }

    return newStates;
  }

  void clearVine(String vineId) {
    LoggerService.debug('Clearing vine $vineId', tag: 'VineStatesNotifier');
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
      LoggerService.info(
        'Marking $vineId as attempted and decrementing life',
        tag: 'VineStatesNotifier',
      );

      state = {
        ...state,
        vineId: s.copyWith(
          hasBeenAttempted: true,
          isWithered: true,
        ),
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
      LoggerService.debug(
        '$vineId already attempted, skipping life decrement',
        tag: 'VineStatesNotifier',
      );
    }
  }

  void _checkLevelComplete() {
    // Level is complete when all vines have either finished clearing
    // or are currently animating their clear animation
    final allFinished = state.values.every((vineState) =>
        vineState.isCleared ||
        vineState.animationState == VineAnimationState.animatingClear);
    LoggerService.debug(
      'Checking completion - allFinished: $allFinished, total vines: ${state.length}',
      tag: 'VineStatesNotifier',
    );
    if (allFinished && state.isNotEmpty) {
      LoggerService.info(
        'LEVEL COMPLETE detected! Setting levelCompleteProvider to true',
        tag: 'VineStatesNotifier',
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
  static const double _animationDurationSeconds =
      AnimationTiming.cameraTransitionSeconds;

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
  }) {
    // Calculate how much we need to zoom out to fit the entire board
    final gridWidth = GameBoardLayout.boardWidth(gridCols);
    final gridHeight = GameBoardLayout.boardHeight(gridRows);

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

    LoggerService.debug(
      'Updated zoom bounds - min: $minZoom, max: $maxZoom (fit: $zoomToFit)',
      tag: 'CameraStateNotifier',
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
  }) {
    // Calculate initial "fit full board" zoom
    final gridWidth = GameBoardLayout.boardWidth(gridCols);
    final gridHeight = GameBoardLayout.boardHeight(gridRows);

    const padding = 0.9;
    final zoomToFitWidth = (screenWidth * padding) / gridWidth;
    final zoomToFitHeight = (screenHeight * padding) / gridHeight;
    final initialZoom =
        zoomToFitWidth < zoomToFitHeight ? zoomToFitWidth : zoomToFitHeight;

    final boardZoomScale = ref.read(boardZoomScaleProvider).value ?? 1.0;

    // Start from fit-to-screen, animate to target scale
    _animationStartZoom = initialZoom;
    _animationTargetZoom = 1.0 * boardZoomScale;
    _animationStartOffset = vm.Vector2.zero();
    _animationTargetOffset = vm.Vector2.zero();
    _animationProgress = 0.0;

    // Set initial state
    state = state.copyWith(
      zoom: initialZoom,
      panOffset: vm.Vector2.zero(),
      isAnimating: true,
    );

    LoggerService.debug(
      'Starting animation from zoom $initialZoom to $_animationTargetZoom',
      tag: 'CameraStateNotifier',
    );

    // If animations are disabled (e.g., during tests), skip creating timers
    if (ref.read(disableAnimationsProvider)) {
      state = state.copyWith(isAnimating: false, zoom: _animationTargetZoom);
      LoggerService.debug(
        'Animations disabled - skipping animation',
        tag: 'CameraStateNotifier',
      );
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
          LoggerService.debug(
            'Animations disabled during run - cancelling',
            tag: 'CameraStateNotifier',
          );
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
          LoggerService.debug('Animation complete', tag: 'CameraStateNotifier');
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
    );

    state = state.copyWith(panOffset: constrainedOffset);
  }

  vm.Vector2 _constrainPanOffset(
    vm.Vector2 offset, {
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
  }) {
    final gridWidth = GameBoardLayout.boardWidth(gridCols) * state.zoom;
    final gridHeight = GameBoardLayout.boardHeight(gridRows) * state.zoom;

    // Allow panning but keep at least 20% of grid visible
    const visibleThreshold = 0.2;
    // For smaller grids that fit on screen, constrain pan tightly
    // For larger grids, constrain to keep at least visibleThreshold of the grid on screen
    final maxOffsetX = screenWidth > gridWidth
        ? gridWidth * 0.2 // Max 20% drift if it fits fully
        : gridWidth * (1 - visibleThreshold);

    final maxOffsetY = screenHeight > gridHeight
        ? gridHeight * 0.2
        : gridHeight * (1 - visibleThreshold);

    // Constrain offset (panOffset is relative to the center, so clamp symmetrically)
    final constrainedX = offset.x.clamp(
      -maxOffsetX,
      maxOffsetX,
    );
    final constrainedY = offset.y.clamp(
      -maxOffsetY,
      maxOffsetY,
    );

    return vm.Vector2(constrainedX, constrainedY);
  }

  // Reset to default zoom and centered position
  void reset() {
    _animationTimer?.cancel();
    state = CameraState.defaultState();
  }

  // Reset to default scaled zoom and centered position (for manual reset)
  void resetToCenter() {
    if (state.isAnimating) return;

    final boardZoomScale = ref.read(boardZoomScaleProvider).value ?? 1.0;

    // Set zoom to board scale and pan offset to zero (which centers the grid)
    state = state.copyWith(
      zoom: 1.0 * boardZoomScale,
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
