import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/infrastructure_providers.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/settings_providers.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/repositories/firebase_game_progress_repository.dart';
import '../../domain/entities/cloud_sync_state.dart';
import '../../domain/entities/game_progress.dart';
import '../../../auth/application/providers/auth_providers.dart';
import '../../../journal/application/providers/journal_providers.dart';
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
      // Pull preferred translation from cloud (offline-first Hive wins on failure).
      try {
        await ref.read(preferredTranslationProvider.notifier).syncFromCloud();
      } catch (_) {}
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

      // Also compute effective max index considering currentLevel
      final currentLevelIdx = playlist.indexOf(state.currentLevel);
      final effectiveMaxIndex = maxCompletedIndex > (currentLevelIdx - 1)
          ? maxCompletedIndex
          : (currentLevelIdx - 1);

      var updatedProgress = state;
      bool changed = false;

      // 1. Heal/backfill completedLevels up to effectiveMaxIndex
      if (effectiveMaxIndex >= 0) {
        final updatedCompletedLevels =
            Set<String>.from(updatedProgress.completedLevels);
        for (int i = 0; i <= effectiveMaxIndex && i < playlist.length; i++) {
          final levelId = playlist[i];
          if (!updatedCompletedLevels.contains(levelId)) {
            updatedCompletedLevels.add(levelId);
            changed = true;
          }
        }
        if (changed) {
          updatedProgress = updatedProgress.copyWith(
            completedLevels: updatedCompletedLevels,
          );
        }
      }

      // 2. Backfill micro-verses and starter scriptures from modules
      for (final module in modulesList) {
        for (final scripture in module.scriptures) {
          final triggerLvl = scripture.triggerLevel;

          final isTriggeredByLevel =
              updatedProgress.completedLevels.contains(triggerLvl);
          final isTriggeredByLesson =
              updatedProgress.completedLessons.contains(triggerLvl);

          final triggerIdx = playlist.indexOf(triggerLvl);
          final isTriggeredByPriorLevel = triggerIdx != -1 &&
              effectiveMaxIndex != -1 &&
              triggerIdx <= effectiveMaxIndex;

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

        // 3. Backfill parable translation if module is completed
        if (updatedProgress.isModuleCompleted(module.id, modulesList)) {
          if (!updatedProgress.unlockedTranslations
              .containsKey(module.id.toString())) {
            final scriptureService = ref.read(scriptureServiceProvider);
            final translationId =
                await scriptureService.pickRandomActiveTranslation();
            if (!ref.mounted) return;

            final updatedTranslations =
                Map<String, String>.from(updatedProgress.unlockedTranslations)
                  ..[module.id.toString()] = translationId;

            updatedProgress = updatedProgress.copyWith(
              unlockedTranslations: updatedTranslations,
            );
            changed = true;
            LoggerService.info(
              'Backfill parable translation: Module ${module.id} (${module.name}) with translation $translationId',
              tag: 'GameProgressNotifier',
            );
          }
        }
      }

      // 4. Backfill passages from biblical themes registry
      try {
        final themesList = await ref.read(journalThemesProvider.future);
        for (final theme in themesList) {
          for (final passage in theme.passages) {
            final triggerLvl = passage.triggerLevel;
            if (triggerLvl.isEmpty) continue;

            final isTriggeredByLevel =
                updatedProgress.completedLevels.contains(triggerLvl);
            final isTriggeredByLesson =
                updatedProgress.completedLessons.contains(triggerLvl);

            final triggerIdx = playlist.indexOf(triggerLvl);
            final isTriggeredByPriorLevel = triggerIdx != -1 &&
                effectiveMaxIndex != -1 &&
                triggerIdx <= effectiveMaxIndex;

            final shouldBeUnlocked = isTriggeredByLevel ||
                isTriggeredByLesson ||
                isTriggeredByPriorLevel;

            if (shouldBeUnlocked) {
              if (!updatedProgress.unlockedScriptureIds.contains(passage.id)) {
                final newScriptures =
                    Set<String>.from(updatedProgress.unlockedScriptureIds)
                      ..add(passage.id);

                final scriptureService = ref.read(scriptureServiceProvider);
                final translationId =
                    await scriptureService.pickRandomActiveTranslation();
                if (!ref.mounted) return;

                final updatedTranslations = Map<String, String>.from(
                    updatedProgress.unlockedTranslations)
                  ..[passage.id] = translationId;

                updatedProgress = updatedProgress.copyWith(
                  unlockedScriptureIds: newScriptures,
                  unlockedTranslations: updatedTranslations,
                );
                changed = true;
                LoggerService.info(
                  'Backfill biblical theme scripture unlocked: ${passage.id} (${passage.reference}) with translation $translationId',
                  tag: 'GameProgressNotifier',
                );
              }
            }
          }
        }
      } catch (e) {
        LoggerService.warn('Could not backfill biblical themes: $e',
            tag: 'GameProgressNotifier');
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

      // Check biblical themes passages
      try {
        final themesList = await ref.read(journalThemesProvider.future);
        for (final theme in themesList) {
          for (final passage in theme.passages) {
            if (passage.triggerLevel == levelId) {
              if (!updatedProgress.unlockedScriptureIds.contains(passage.id)) {
                final newScriptures =
                    Set<String>.from(updatedProgress.unlockedScriptureIds)
                      ..add(passage.id);
                final scriptureService = ref.read(scriptureServiceProvider);
                final translationId =
                    await scriptureService.pickRandomActiveTranslation();
                if (!ref.mounted) return;
                final updatedTranslations = Map<String, String>.from(
                    updatedProgress.unlockedTranslations)
                  ..[passage.id] = translationId;

                updatedProgress = updatedProgress.copyWith(
                  unlockedScriptureIds: newScriptures,
                  unlockedTranslations: updatedTranslations,
                );
                LoggerService.info(
                  'Biblical theme scripture unlocked: ${passage.id} (${passage.reference}) with translation $translationId',
                  tag: 'GameProgressNotifier',
                );
              }
            }
          }
        }
      } catch (e) {
        LoggerService.warn('Error checking theme unlocks in completeLevel: $e');
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
          state.currentLevel.isEmpty ? 'lvl_m01_01' : state.currentLevel,
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
          ? 'lvl_m01_01'
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

      // Check biblical themes
      try {
        final themesList = await ref.read(journalThemesProvider.future);
        for (final theme in themesList) {
          for (final passage in theme.passages) {
            if (passage.triggerLevel == lessonId) {
              if (!newProgress.unlockedScriptureIds.contains(passage.id)) {
                final newScriptures =
                    Set<String>.from(newProgress.unlockedScriptureIds)
                      ..add(passage.id);
                final scriptureService = ref.read(scriptureServiceProvider);
                final translationId =
                    await scriptureService.pickRandomActiveTranslation();
                if (!ref.mounted) return;
                final updatedTranslations =
                    Map<String, String>.from(newProgress.unlockedTranslations)
                      ..[passage.id] = translationId;

                newProgress = newProgress.copyWith(
                  unlockedScriptureIds: newScriptures,
                  unlockedTranslations: updatedTranslations,
                );
                LoggerService.info(
                  'Lesson Biblical Theme Scripture unlocked: ${passage.id} (${passage.reference}) with translation $translationId',
                  tag: 'GameProgressNotifier',
                );
              }
            }
          }
        }
      } catch (e) {
        LoggerService.warn(
            'Error checking theme unlocks in completeLesson: $e');
      }
    } catch (e, stack) {
      LoggerService.error('Error checking scripture unlocks in completeLesson',
          error: e, stackTrace: stack);
    }

    if (!ref.mounted) return;
    await _saveProgress(newProgress);
  }

  Future<void> saveJournalNote(String scriptureId, String note) async {
    final updatedNotes = Map<String, String>.from(state.journalNotes);
    if (note.trim().isEmpty) {
      updatedNotes.remove(scriptureId);
    } else {
      updatedNotes[scriptureId] = note.trim();
    }
    final newProgress = state.copyWith(journalNotes: updatedNotes);
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

  /// Heals a stale [GameProgress.currentLevel] pointer and returns the level
  /// ID that should actually load, or null when there is nothing to heal to.
  ///
  /// The pointer goes stale when the level playlist grows (new cloud levels
  /// published after the profile finished everything) or level IDs migrate:
  /// it then names an ID absent from the playlist, and loaders fall back to
  /// "Play Level 1" / false "game finished". Healing points it at the first
  /// uncompleted level and persists, so refreshes stay fixed.
  Future<String?> healCurrentLevel() async {
    if (!ref.mounted) return null;
    List<String> playlist;
    try {
      final modulesList = await ref.read(modulesProvider.future);
      if (!ref.mounted) return null;
      playlist = modulesList.expand((m) => m.allLevels).toList();
    } catch (e) {
      LoggerService.warn('Could not load playlist for level healing: $e',
          tag: 'GameProgressNotifier');
      return null;
    }

    final next = state.nextUncompletedLevel(playlist);
    if (next == null) return null;
    if (state.currentLevel == next || playlist.contains(state.currentLevel)) {
      // Pointer is still valid (points at a real level): leave replay and
      // in-progress semantics untouched, just report what should load.
      return state.currentLevel;
    }
    LoggerService.info(
      'Healing stale currentLevel ${state.currentLevel} -> $next',
      tag: 'GameProgressNotifier',
    );
    await _saveProgress(state.copyWith(currentLevel: next));
    return next;
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
