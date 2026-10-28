import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:parable_bloom/core/providers/infrastructure_providers.dart';
import 'package:parable_bloom/core/providers/service_providers.dart';
import 'package:parable_bloom/core/providers/settings_providers.dart';
import 'package:parable_bloom/core/services/analytics_service.dart';
import 'package:parable_bloom/core/services/scripture_service.dart';
import 'package:parable_bloom/features/game/application/providers/counter_providers.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/application/providers/module_providers.dart';
import 'package:parable_bloom/features/game/application/providers/progress_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/cloud_sync_state.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/features/game/domain/repositories/game_progress_repository.dart';
import 'package:parable_bloom/features/tutorial/application/providers/tutorial_providers.dart';

/// Regression test for the "Reset All Data leaves me on the same level"
/// bug. The old flow invalidated only gameProgressProvider *after*
/// navigating away (dead ref: the invalidate threw and was swallowed),
/// deleted the wrong Firestore path (`users/{uid}` instead of the real
/// progress doc), and left tutorial/session/settings providers stale.
///
/// This replays the fixed reset sequence and asserts every piece of
/// in-memory state the home screen depends on returns to initial.
void main() {
  group('Reset All Data', () {
    test('reset sequence returns all progress state to initial', () async {
      final fakeRepo = _FakeRepo();
      final box = _FakeBox();
      final container = ProviderContainer(
        overrides: [
          gameProgressRepositoryProvider.overrideWithValue(fakeRepo),
          hiveBoxProvider.overrideWithValue(box as Box),
          analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
          modulesProvider.overrideWithValue(const AsyncValue.data([])),
          scriptureServiceProvider.overrideWithValue(_FakeScripture()),
        ],
      );
      addTearDown(container.dispose);

      // Seed a mid-game state: tutorial done, sitting on level 6.
      await container.read(gameProgressProvider.notifier).initialize();
      final notifier = container.read(gameProgressProvider.notifier);
      await notifier.completeLesson(
        lessonId: 'lesson_1',
        nextLesson: 'lesson_2',
        allLessonsCompleted: false,
      );
      // Simulate several completed levels + current level pointer.
      var progress = container.read(gameProgressProvider);
      progress = progress.copyWith(
        completedLevels: {
          'lvl_m01_01',
          'lvl_m01_02',
          'lvl_m01_03',
          'lvl_m01_04',
          'lvl_m01_05',
        },
        currentLevel: 'lvl_m01_06',
        tutorialCompleted: true,
        lessonCompleted: true,
      );
      await fakeRepo.saveProgress(progress);
      await notifier.initialize();
      expect(
        container.read(gameProgressProvider).currentLevel,
        equals('lvl_m01_06'),
      );

      // Stale-able in-memory session state.
      container.read(graceProvider.notifier).setGrace(1);

      // --- Fixed reset sequence (mirrors _performResetAsync) ---
      await container.read(gameProgressProvider.notifier).resetProgress();
      await box.clear();
      container.invalidate(gameProgressProvider);
      container.invalidate(tutorialProgressProvider);
      container.invalidate(currentLevelProvider);
      container.invalidate(levelCompleteProvider);
      container.invalidate(gameCompletedProvider);
      container.invalidate(graceProvider);
      container.invalidate(gameOverProvider);
      container.invalidate(gameInstanceProvider);
      container.invalidate(levelTotalTapsProvider);
      container.invalidate(levelWrongTapsProvider);
      container.invalidate(levelAttemptCountProvider);
      container.invalidate(levelStartTimestampProvider);
      container.invalidate(themeModeProvider);
      container.invalidate(backgroundAudioEnabledProvider);
      container.invalidate(hapticsEnabledProvider);
      container.invalidate(vineStyleProvider);
      container.invalidate(preferredTranslationProvider);

      // --- Assertions: everything home depends on is fresh ---
      final fresh = container.read(gameProgressProvider);
      expect(fresh.completedLevels, isEmpty);
      expect(fresh.unlockedScriptureIds, isEmpty);
      expect(fresh.tutorialCompleted, isFalse);
      expect(fresh.completedLessons, isEmpty);

      final tutorial = container.read(tutorialProgressProvider);
      expect(tutorial.currentLesson, equals(1));
      expect(tutorial.completedLessons, isEmpty);
      expect(tutorial.allLessonsCompleted, isFalse);

      expect(container.read(currentLevelProvider), isNull);
      expect(container.read(graceProvider), equals(3));

      // Repository itself was reset through resetProgress, not just the box.
      expect(fakeRepo.resetCalled, isTrue);
      expect(fakeRepo.saved.unlockedScriptureIds, isEmpty);
    });
  });
}

class _FakeRepo implements GameProgressRepository {
  GameProgress saved = GameProgress.initial();
  bool resetCalled = false;

  @override
  Future<GameProgress> getProgress() async => saved;
  @override
  Future<void> saveProgress(GameProgress progress) async => saved = progress;
  @override
  Future<void> resetProgress() async {
    resetCalled = true;
    saved = GameProgress.initial();
  }

  @override
  Future<void> syncToCloud() async {}
  @override
  Future<DateTime?> getLastSyncTime() async => null;
  @override
  Future<bool> isCloudSyncAvailable() async => false;
  @override
  Future<CloudSyncAvailability> getCloudSyncAvailability() async =>
      const CloudSyncAvailability(
          isAvailable: false, reason: CloudSyncAvailabilityReason.signedOut);
  @override
  Future<void> setCloudSyncEnabled(bool enabled) async {}
  @override
  Future<bool> isCloudSyncEnabled() async => false;
  @override
  Future<void> syncFromCloud() async {}
  @override
  Future<SyncConflictState> inspectSyncConflict() async => SyncConflictState(
      type: SyncConflictType.none, localProgress: saved, cloudProgress: null);
  @override
  Future<void> resolveSyncConflict(SyncConflictResolution resolution) async {}
}

class _FakeBox implements Box<dynamic> {
  final Map _store = {};
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _store.containsKey(key) ? _store[key] : defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async => _store[key] = value;
  @override
  Future<int> clear() async {
    _store.clear();
    return 0;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAnalytics extends AnalyticsService {
  @override
  Future<void> logScreenView(String screenName) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScripture extends ScriptureService {
  @override
  Future<String> pickRandomActiveTranslation() async => 'kjv';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
