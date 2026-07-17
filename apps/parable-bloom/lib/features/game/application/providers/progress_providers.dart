import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/infrastructure_providers.dart';
import '../../../../providers/service_providers.dart';
import '../../../../services/logger_service.dart';
import '../../data/repositories/firebase_game_progress_repository.dart';
import '../../domain/entities/cloud_sync_state.dart';
import '../../domain/entities/game_progress.dart';
import '../../../auth/application/providers/auth_providers.dart';
import 'counter_providers.dart';
import 'module_providers.dart';

final gameProgressProvider =
    NotifierProvider<GameProgressNotifier, GameProgress>(
  GameProgressNotifier.new,
);

final cloudSyncAvailabilityProvider =
    FutureProvider<CloudSyncAvailability>((ref) async {
  final userAsync = ref.watch(authUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) {
        return const CloudSyncAvailability(
          isAvailable: false,
          reason: CloudSyncAvailabilityReason.signedOut,
        );
      }
      if (user.isAnonymous) {
        return const CloudSyncAvailability(
          isAvailable: false,
          reason: CloudSyncAvailabilityReason.anonymousAccount,
        );
      }
      return const CloudSyncAvailability(
        isAvailable: true,
        reason: CloudSyncAvailabilityReason.available,
      );
    },
    loading: () => const CloudSyncAvailability(
      isAvailable: false,
      reason: CloudSyncAvailabilityReason.signedOut,
    ),
    error: (_, __) => const CloudSyncAvailability(
      isAvailable: false,
      reason: CloudSyncAvailabilityReason.signedOut,
    ),
  );
});

final cloudSyncAvailableProvider = FutureProvider<bool>((ref) async {
  final availability = await ref.watch(cloudSyncAvailabilityProvider.future);
  return availability.isAvailable;
});

final cloudSyncEnabledProvider = FutureProvider<bool>((ref) async {
  ref.watch(cloudSyncAvailabilityProvider);
  final notifier = ref.watch(gameProgressProvider.notifier);
  return notifier.isCloudSyncEnabled();
});

final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  ref.watch(cloudSyncAvailabilityProvider);
  final notifier = ref.watch(gameProgressProvider.notifier);
  return notifier.getLastSyncTime();
});

class GameProgressNotifier extends Notifier<GameProgress> {
  @override
  GameProgress build() {
    return GameProgress.initial();
  }

  Future<void> initialize() async {
    if (!ref.mounted) return;
    final repository = ref.read(gameProgressRepositoryProvider);
    try {
      final progress = await repository.getProgress();
      if (!ref.mounted) return;
      state = progress;
      await _backfillUnlockedScriptures();
    } catch (e, stack) {
      if (!ref.mounted) return;
      LoggerService.error('Error initializing GameProgress',
          error: e, stackTrace: stack, tag: 'GameProgressNotifier');
      state = GameProgress.initial();
    }
  }

  Future<void> _backfillUnlockedScriptures() async {
    if (!ref.mounted) return;
    try {
      final modulesList = await ref.read(modulesProvider.future);
      if (!ref.mounted) return;
      final playlist = modulesList.expand((m) => m.allLevels).toList();

      int maxCompletedIndex = -1;
      for (final lvl in state.completedLevels) {
        final idx = playlist.indexOf(lvl);
        if (idx > maxCompletedIndex) {
          maxCompletedIndex = idx;
        }
      }

      var updatedProgress = state;
      bool changed = false;

      for (final module in modulesList) {
        for (final scripture in module.scriptures) {
          final triggerLvl = scripture.triggerLevel;

          final isTriggeredByLevel = state.completedLevels.contains(triggerLvl);
          final isTriggeredByLesson =
              state.completedLessons.contains(triggerLvl);

          final triggerIdx = playlist.indexOf(triggerLvl);
          final isTriggeredByPriorLevel = triggerIdx != -1 &&
              maxCompletedIndex != -1 &&
              triggerIdx <= maxCompletedIndex;

          final shouldBeUnlocked = isTriggeredByLevel ||
              isTriggeredByLesson ||
              isTriggeredByPriorLevel;

          if (shouldBeUnlocked) {
            if (!updatedProgress.unlockedScriptureIds.contains(scripture.id)) {
              final newScriptures =
                  Set<String>.from(updatedProgress.unlockedScriptureIds)
                    ..add(scripture.id);

              final scriptureService = ref.read(scriptureServiceProvider);
              final translationId =
                  await scriptureService.pickRandomActiveTranslation();
              if (!ref.mounted) return;

              final updatedTranslations =
                  Map<String, String>.from(updatedProgress.unlockedTranslations)
                    ..[scripture.id] = translationId;

              updatedProgress = updatedProgress.copyWith(
                unlockedScriptureIds: newScriptures,
                unlockedTranslations: updatedTranslations,
              );
              changed = true;
              LoggerService.info(
                'Backfill scripture unlocked: ${scripture.id} (${scripture.reference}) with translation $translationId',
                tag: 'GameProgressNotifier',
              );
            }
          }
        }
      }

      if (changed) {
        await _saveProgress(updatedProgress);
      }
    } catch (e, stack) {
      LoggerService.error('Error during unlocked scriptures backfill',
          error: e, stackTrace: stack, tag: 'GameProgressNotifier');
    }
  }

  Future<void> completeLevel(String levelId) async {
    LoggerService.debug(
      'Completing level $levelId, current state: $state',
      tag: 'GameProgressNotifier',
    );

    final modulesList = await ref.read(modulesProvider.future);
    if (!ref.mounted) return;
    final playlist = modulesList.expand((m) => m.allLevels).toList();
    final newProgress = state.completeLevel(levelId, playlist);

    var updatedProgress = newProgress;
    try {
      for (final module in modulesList) {
        for (final scripture in module.scriptures) {
          if (scripture.triggerLevel == levelId) {
            if (!updatedProgress.unlockedScriptureIds.contains(scripture.id)) {
              final newScriptures =
                  Set<String>.from(updatedProgress.unlockedScriptureIds)
                    ..add(scripture.id);
              final scriptureService = ref.read(scriptureServiceProvider);
              final translationId =
                  await scriptureService.pickRandomActiveTranslation();
              if (!ref.mounted) return;
              final updatedTranslations =
                  Map<String, String>.from(updatedProgress.unlockedTranslations)
                    ..[scripture.id] = translationId;

              updatedProgress = updatedProgress.copyWith(
                unlockedScriptureIds: newScriptures,
                unlockedTranslations: updatedTranslations,
              );
              LoggerService.info(
                'Scripture unlocked: ${scripture.id} (${scripture.reference}) with translation $translationId',
                tag: 'GameProgressNotifier',
              );
            }
          }
        }
      }
    } catch (e, stack) {
      LoggerService.error('Error checking scripture unlocks in completeLevel',
          error: e, stackTrace: stack);
    }

    LoggerService.debug(
      'New progress: $updatedProgress',
      tag: 'GameProgressNotifier',
    );

    if (!ref.mounted) return;
    await _saveProgress(updatedProgress);

    LoggerService.debug(
      'After save, state is: $state',
      tag: 'GameProgressNotifier',
    );

    final totalTaps = ref.read(levelTotalTapsProvider);
    final wrongTaps = ref.read(levelWrongTapsProvider);
    final attempts = ref.read(levelAttemptCountProvider);
    final startMs = ref.read(levelStartTimestampProvider);
    final elapsedSeconds = startMs != null
        ? DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(startMs))
            .inSeconds
        : -1;

    unawaited(
      ref.read(analyticsServiceProvider).logLevelComplete(
            levelId,
            totalTaps,
            wrongTaps,
            attempts: attempts,
            elapsedSeconds: elapsedSeconds,
          ),
    );
  }

  Future<void> resetTutorial() async {
    final newProgress = state.copyWith(
      tutorialCompleted: false,
      currentLevel:
          state.currentLevel.isEmpty ? 'lvl_seed_01' : state.currentLevel,
    );

    await _saveProgress(newProgress);
  }

  Future<void> completeLesson({
    required String lessonId,
    required String? nextLesson,
    required bool allLessonsCompleted,
  }) async {
    final newCompletedLessons = Set<String>.from(state.completedLessons)
      ..add(lessonId);

    var newProgress = state.copyWith(
      completedLessons: newCompletedLessons,
      currentLesson: nextLesson,
      lessonCompleted: allLessonsCompleted,
      tutorialCompleted: allLessonsCompleted,
      currentLevel: (allLessonsCompleted && state.currentLevel.isEmpty)
          ? 'lvl_seed_01'
          : state.currentLevel,
    );

    try {
      final modulesList = await ref.read(modulesProvider.future);
      if (!ref.mounted) return;
      for (final module in modulesList) {
        for (final scripture in module.scriptures) {
          if (scripture.triggerLevel == lessonId) {
            if (!newProgress.unlockedScriptureIds.contains(scripture.id)) {
              final newScriptures =
                  Set<String>.from(newProgress.unlockedScriptureIds)
                    ..add(scripture.id);
              final scriptureService = ref.read(scriptureServiceProvider);
              final translationId =
                  await scriptureService.pickRandomActiveTranslation();
              if (!ref.mounted) return;
              final updatedTranslations =
                  Map<String, String>.from(newProgress.unlockedTranslations)
                    ..[scripture.id] = translationId;

              newProgress = newProgress.copyWith(
                unlockedScriptureIds: newScriptures,
                unlockedTranslations: updatedTranslations,
              );
              LoggerService.info(
                'Lesson Scripture unlocked: ${scripture.id} (${scripture.reference}) with translation $translationId',
                tag: 'GameProgressNotifier',
              );
            }
          }
        }
      }
    } catch (e, stack) {
      LoggerService.error('Error checking scripture unlocks in completeLesson',
          error: e, stackTrace: stack);
    }

    if (!ref.mounted) return;
    await _saveProgress(newProgress);
  }

  Future<void> resetLessons() async {
    final newProgress = state.copyWith(
      currentLesson: 'lesson_1',
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

  Future<void> saveUnlockedTranslation(
      String moduleId, String translationId) async {
    final updatedTranslations =
        Map<String, String>.from(state.unlockedTranslations)
          ..[moduleId] = translationId;
    final newProgress =
        state.copyWith(unlockedTranslations: updatedTranslations);
    await _saveProgress(newProgress);
  }

  Future<void> _saveProgress(GameProgress progress) async {
    if (!ref.mounted) return;
    final repository = ref.read(gameProgressRepositoryProvider);
    await repository.saveProgress(progress);
    if (!ref.mounted) return;
    state = progress;
  }

  Future<void> enableCloudSync() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    if (repository is FirebaseGameProgressRepository) {
      await repository.setCloudSyncEnabled(true);
    }
    await initialize();
  }

  Future<void> disableCloudSync() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    if (repository is FirebaseGameProgressRepository) {
      await repository.setCloudSyncEnabled(false);
    }
    await initialize();
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

  Future<void> syncOnReconnect() async {
    final repository = ref.read(gameProgressRepositoryProvider);
    if (repository is FirebaseGameProgressRepository) {
      await repository.syncToCloud();
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
