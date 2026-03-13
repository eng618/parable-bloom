import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/infrastructure_providers.dart';
import '../../../../providers/service_providers.dart';
import '../../../../services/logger_service.dart';
import '../../data/repositories/firebase_game_progress_repository.dart';
import '../../domain/entities/cloud_sync_state.dart';
import '../../domain/entities/game_progress.dart';
import 'counter_providers.dart';

final gameProgressProvider =
    NotifierProvider<GameProgressNotifier, GameProgress>(
  GameProgressNotifier.new,
);

final cloudSyncEnabledProvider = FutureProvider<bool>((ref) async {
  final notifier = ref.watch(gameProgressProvider.notifier);
  return notifier.isCloudSyncEnabled();
});

final cloudSyncAvailableProvider = FutureProvider<bool>((ref) async {
  final notifier = ref.watch(gameProgressProvider.notifier);
  return notifier.isCloudSyncAvailable();
});

final cloudSyncAvailabilityProvider =
    FutureProvider<CloudSyncAvailability>((ref) async {
  final notifier = ref.watch(gameProgressProvider.notifier);
  return notifier.getCloudSyncAvailability();
});

final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  final notifier = ref.watch(gameProgressProvider.notifier);
  return notifier.getLastSyncTime();
});

class GameProgressNotifier extends Notifier<GameProgress> {
  @override
  GameProgress build() {
    return GameProgress.initial();
  }

  Future<void> initialize() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    try {
      final progress = await repository.getProgress();
      state = progress;
    } catch (e, stack) {
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

    var newTutorialCompleted = state.tutorialCompleted;
    late final int newCurrentLevel;

    const int firstMainLevel = 1;
    const int maxTutorialLevel = 5;

    if (levelNumber == maxTutorialLevel && !state.tutorialCompleted) {
      newTutorialCompleted = true;
      newCurrentLevel = firstMainLevel;
    } else {
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

    final totalTaps = ref.read(levelTotalTapsProvider);
    final wrongTaps = ref.read(levelWrongTapsProvider);
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logLevelComplete(levelNumber, totalTaps, wrongTaps),
    );
  }

  Future<void> resetTutorial() async {
    final newProgress = state.copyWith(
      tutorialCompleted: false,
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

  Future<CloudSyncAvailability> getCloudSyncAvailability() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    return await repository.getCloudSyncAvailability();
  }

  Future<DateTime?> getLastSyncTime() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    return await repository.getLastSyncTime();
  }

  Future<void> manualSync() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    if (repository is FirebaseGameProgressRepository) {
      await repository.syncFromCloud();
      await initialize();
    }
  }

  Future<SyncConflictState> inspectSyncConflict() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    return await repository.inspectSyncConflict();
  }

  Future<void> resolveSyncConflict(SyncConflictResolution resolution) async {
    final repository = ref.read(gameProgressRepositoryProvider);
    await repository.resolveSyncConflict(resolution);
    await initialize();
  }
}
