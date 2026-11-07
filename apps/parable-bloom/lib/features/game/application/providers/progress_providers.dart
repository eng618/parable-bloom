import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/infrastructure_providers.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/settings_providers.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/repositories/firebase_game_progress_repository.dart';
import '../../domain/entities/cloud_sync_state.dart';
import '../../domain/entities/game_progress.dart';
import '../../domain/entities/level_data.dart';
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
      } catch (e) {
        LoggerService.warn(
          "syncFromCloud failed during initialize: $e",
          tag: "GameProgressNotifier",
        );
      }
    } catch (e, stack) {
      if (!ref.mounted) return;
      LoggerService.error('Error initializing GameProgress',
          error: e, stackTrace: stack, tag: 'GameProgressNotifier');
      state = GameProgress.initial();
    }
  }

  Future<void> _backfillUnlockedScriptures() async {
    if (!ref.mounted) return;
    _runTranslationId = null;
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

      // 1. Heal/backfill completedLevels up to effectiveMaxIndex
      if (effectiveMaxIndex >= 0) {
        final updatedCompletedLevels =
            Set<String>.from(updatedProgress.completedLevels);
        var healed = false;
        for (int i = 0; i <= effectiveMaxIndex && i < playlist.length; i++) {
          final levelId = playlist[i];
          if (!updatedCompletedLevels.contains(levelId)) {
            updatedCompletedLevels.add(levelId);
            healed = true;
          }
        }
        if (healed) {
          updatedProgress = updatedProgress.copyWith(
            completedLevels: updatedCompletedLevels,
          );
        }
      }

      // 2. Scriptures earned by healed levels, finished lessons, or the
      // tutorial itself (including the journal passage id, which can differ
      // from the module scripture id).
      final unlocked =
          await _unlockMatchingScriptures(updatedProgress, modulesList);
      if (unlocked == null) return;
      updatedProgress = unlocked;

      // 3. Backfill parable translation if module is completed
      for (final module in modulesList) {
        if (updatedProgress.isModuleCompleted(module.id, modulesList)) {
          if (!updatedProgress.unlockedTranslations
              .containsKey(module.id.toString())) {
            final translationId = await _unlockTranslationId();
            if (!ref.mounted) return;

            final updatedTranslations =
                Map<String, String>.from(updatedProgress.unlockedTranslations)
                  ..[module.id.toString()] = translationId;

            updatedProgress = updatedProgress.copyWith(
              unlockedTranslations: updatedTranslations,
            );
            LoggerService.info(
              'Backfill parable translation: Module ${module.id} (${module.name}) with translation $translationId',
              tag: 'GameProgressNotifier',
            );
          }
        }
      }

      // Merge onto the latest state so a lesson completed while this
      // backfill was awaiting registries is not overwritten.
      final merged = _mergeBackfill(state, updatedProgress);
      if (merged != state) {
        await _saveProgress(merged);
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
    _runTranslationId = null;
    final playlist = modulesList.expand((m) => m.allLevels).toList();
    final newProgress = state.completeLevel(levelId, playlist);

    var updatedProgress = newProgress;
    try {
      final unlocked =
          await _unlockMatchingScriptures(updatedProgress, modulesList);
      if (unlocked == null) return;
      updatedProgress = unlocked;
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
    _runTranslationId = null;

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
      final unlocked =
          await _unlockMatchingScriptures(newProgress, modulesList);
      if (unlocked == null) return;
      newProgress = unlocked;
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

  /// Adds module scriptures and journal passages whose triggers this
  /// progress has earned. A journal passage is also added when it shares a
  /// reference with an already-unlocked module scripture (`seed_starter` vs
  /// `growth_seed_word`). Returns null only when the notifier unmounts
  /// mid-await; callers then skip the save.
  Future<GameProgress?> _unlockMatchingScriptures(
    GameProgress progress,
    List<ModuleData> modules,
  ) async {
    var updated = progress;
    for (final module in modules) {
      for (final scripture in module.scriptures) {
        if (!updated.satisfiesScriptureTrigger(scripture.triggerLevel)) {
          continue;
        }
        final next = await _addScriptureUnlock(
          updated,
          scripture.id,
          'Scripture unlocked: ${scripture.id} (${scripture.reference})',
        );
        if (next == null) return null;
        updated = next;
      }
    }

    final unlockedReferences = <String>{
      for (final module in modules)
        for (final scripture in module.scriptures)
          if (scripture.reference.isNotEmpty &&
              updated.unlockedScriptureIds.contains(scripture.id))
            scripture.reference,
    };

    try {
      final themes = await ref.read(journalThemesProvider.future);
      if (!ref.mounted) return null;
      for (final theme in themes) {
        for (final passage in theme.passages) {
          final byTrigger =
              updated.satisfiesScriptureTrigger(passage.triggerLevel);
          final byReference = passage.reference.isNotEmpty &&
              unlockedReferences.contains(passage.reference);
          if (!byTrigger && !byReference) continue;
          final next = await _addScriptureUnlock(
            updated,
            passage.id,
            'Journal scripture unlocked: ${passage.id} (${passage.reference})',
          );
          if (next == null) return null;
          updated = next;
        }
      }
    } catch (e) {
      LoggerService.warn(
        'Could not match journal themes while unlocking scriptures: $e',
        tag: 'GameProgressNotifier',
      );
    }
    return updated;
  }

  Future<GameProgress?> _addScriptureUnlock(
    GameProgress progress,
    String id,
    String logLabel,
  ) async {
    if (id.isEmpty || progress.unlockedScriptureIds.contains(id)) {
      return progress;
    }
    final translationId =
        progress.unlockedTranslations[id] ?? await _unlockTranslationId();
    if (!ref.mounted) return null;
    LoggerService.info(
      '$logLabel with translation $translationId',
      tag: 'GameProgressNotifier',
    );
    return progress.copyWith(
      unlockedScriptureIds: {...progress.unlockedScriptureIds, id},
      unlockedTranslations: {
        ...progress.unlockedTranslations,
        id: translationId,
      },
    );
  }

  /// Union of a backfill snapshot and whatever was saved while it awaited.
  /// Latest translations win so a picked translation is not replaced.
  GameProgress _mergeBackfill(GameProgress latest, GameProgress backfilled) {
    return latest.copyWith(
      completedLevels: {
        ...latest.completedLevels,
        ...backfilled.completedLevels,
      },
      completedLessons: {
        ...latest.completedLessons,
        ...backfilled.completedLessons,
      },
      unlockedScriptureIds: {
        ...latest.unlockedScriptureIds,
        ...backfilled.unlockedScriptureIds,
      },
      unlockedTranslations: {
        ...backfilled.unlockedTranslations,
        ...latest.unlockedTranslations,
      },
      lessonCompleted: latest.lessonCompleted || backfilled.lessonCompleted,
      tutorialCompleted:
          latest.tutorialCompleted || backfilled.tutorialCompleted,
    );
  }

  Future<void> _saveProgress(GameProgress progress) async {
    if (!ref.mounted) return;
    final repository = ref.read(gameProgressRepositoryProvider);
    await repository.saveProgress(progress);
    if (!ref.mounted) return;
    state = progress;
  }

  /// Unlock translation picked once per run. Previously every missing
  /// scripture triggered its own pick (service init + connectivity
  /// round-trip each), stalling cold starts and offline backfills N+1.
  String? _runTranslationId;

  Future<String> _unlockTranslationId() async {
    return _runTranslationId ??=
        await ref.read(scriptureServiceProvider).pickRandomActiveTranslation();
  }

  /// Full load resolution across the two registry sources of truth
  /// ([modulesProvider] playlist and [levelMappingsProvider]).
  ///
  /// Returns a level ID guaranteed present in [levelMappingsProvider] (so
  /// callers never mistake registry skew for "game finished"), persisting
  /// pointer repairs. Returns null only when nothing is loadable.
  ///
  /// Policy: a mapped [currentLevel] always wins (covers normal resume AND
  /// intentional replay of completed levels); otherwise prefer the first
  /// uncompleted mapped level, then the first mapped level at all.
  Future<String?> resolveLevelToLoad() async {
    if (!ref.mounted) return null;
    List<String> playlist;
    Map<String, String> mappings;
    try {
      final modulesList = await ref.read(modulesProvider.future);
      if (!ref.mounted) return null;
      playlist = modulesList.expand((m) => m.allLevels).toList();
      mappings = await ref.read(levelMappingsProvider.future);
      if (!ref.mounted) return null;
    } catch (e) {
      LoggerService.warn('Could not load registry for level resolution: $e',
          tag: 'GameProgressNotifier');
      return null;
    }

    final current = state.currentLevel;
    if (mappings.containsKey(current)) return current;

    String? firstMapped;
    for (final id in playlist) {
      if (!mappings.containsKey(id)) continue;
      firstMapped ??= id;
      if (!state.completedLevels.contains(id)) {
        LoggerService.info(
          'Resolving level load $current -> $id (stale pointer)',
          tag: 'GameProgressNotifier',
        );
        await _saveProgress(state.copyWith(currentLevel: id));
        return id;
      }
    }
    if (firstMapped != null) {
      LoggerService.info(
        'Resolving level load $current -> $firstMapped (replay; all mapped complete)',
        tag: 'GameProgressNotifier',
      );
      await _saveProgress(state.copyWith(currentLevel: firstMapped));
      return firstMapped;
    }
    return null;
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
