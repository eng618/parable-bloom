import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/game/data/repositories/firebase_game_progress_repository.dart';
import '../features/game/domain/entities/game_progress.dart';
import 'counter_providers.dart';
import 'infrastructure_providers.dart';
import 'service_providers.dart';
import '../services/logger_service.dart';

export '../features/game/domain/entities/level_data.dart';
export 'camera_providers.dart';
export 'counter_providers.dart';
export 'gameplay_state_providers.dart';
export 'infrastructure_providers.dart';
export 'settings_providers.dart';
export 'service_providers.dart';

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
