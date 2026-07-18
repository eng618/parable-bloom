import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parable_bloom/features/game/application/providers/progress_providers.dart';
import 'package:parable_bloom/features/game/application/providers/module_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/domain/entities/cloud_sync_state.dart';
import 'package:parable_bloom/features/game/domain/repositories/game_progress_repository.dart';
import 'package:parable_bloom/core/services/analytics_service.dart';
import 'package:parable_bloom/core/providers/infrastructure_providers.dart';
import 'package:parable_bloom/core/providers/service_providers.dart';
import 'package:parable_bloom/core/services/scripture_service.dart';
import 'package:hive/hive.dart';

void main() {
  group('GameProgressNotifier Scripture Backfill Tests', () {
    late _FakeRepo fakeRepo;
    late List<ModuleData> mockModules;

    setUp(() {
      fakeRepo = _FakeRepo();
      mockModules = [
        ModuleData(
          id: 1,
          name: 'Seedling',
          themeSeed: 'forest',
          levels: const [
            'lvl_seed_01',
            'lvl_seed_02',
            'lvl_seed_03',
            'lvl_seed_04',
            'lvl_seed_05'
          ],
          challengeLevel: 'lvl_seed_challenge',
          parable: const {},
          unlockMessage: '',
          scriptures: [
            ModuleScripture(
              id: 'seed_starter',
              triggerLevel: 'lesson_1',
              reference: 'Luke 8:11',
              title: 'Starter',
              type: 'starter',
            ),
            ModuleScripture(
              id: 'seed_micro_1',
              triggerLevel: 'lvl_seed_02',
              reference: 'Ecclesiastes 11:6',
              title: 'Micro 1',
              type: 'supporting',
            ),
            ModuleScripture(
              id: 'seed_micro_2',
              triggerLevel: 'lvl_seed_04',
              reference: 'Psalm 126:6',
              title: 'Micro 2',
              type: 'supporting',
            ),
          ],
        ),
      ];
    });

    test(
        'New user starts with 0 unlocked scriptures and triggers them normally',
        () async {
      final container = ProviderContainer(
        overrides: [
          gameProgressRepositoryProvider.overrideWithValue(fakeRepo),
          hiveBoxProvider.overrideWithValue(_FakeBox() as Box),
          analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
          modulesProvider.overrideWithValue(AsyncValue.data(mockModules)),
          scriptureServiceProvider.overrideWithValue(_FakeScriptureService()),
        ],
      );

      // Initialize GameProgress
      await container.read(gameProgressProvider.notifier).initialize();
      var progress = container.read(gameProgressProvider);

      expect(progress.unlockedScriptureIds, isEmpty);
      expect(progress.unlockedTranslations, isEmpty);

      // Complete lesson 1 to trigger starter verse
      await container.read(gameProgressProvider.notifier).completeLesson(
            lessonId: 'lesson_1',
            nextLesson: 'lesson_2',
            allLessonsCompleted: false,
          );

      progress = container.read(gameProgressProvider);
      expect(progress.unlockedScriptureIds.contains('seed_starter'), isTrue);
      expect(progress.unlockedTranslations['seed_starter'], isNotNull);
    });

    test(
        'Existing user with completed levels gets prior scriptures backfilled on initialization',
        () async {
      // Simulate existing user who completed up to lvl_seed_03 (level 3)
      final existingProgress = GameProgress.initial().copyWith(
        completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03'},
        currentLevel: 'lvl_seed_04',
        tutorialCompleted: true,
      );
      fakeRepo.saveProgress(existingProgress);

      final container = ProviderContainer(
        overrides: [
          gameProgressRepositoryProvider.overrideWithValue(fakeRepo),
          hiveBoxProvider.overrideWithValue(_FakeBox() as Box),
          analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
          modulesProvider.overrideWithValue(AsyncValue.data(mockModules)),
          scriptureServiceProvider.overrideWithValue(_FakeScriptureService()),
        ],
      );

      // Initialize triggers backfill
      await container.read(gameProgressProvider.notifier).initialize();
      final progress = container.read(gameProgressProvider);

      // Should automatically unlock:
      // - seed_micro_1 (because lvl_seed_02 is completed / index 1 <= max index 2)
      // but NOT seed_micro_2 (lvl_seed_04 has index 3 > max index 2)
      expect(progress.unlockedScriptureIds.contains('seed_micro_1'), isTrue);
      expect(progress.unlockedScriptureIds.contains('seed_micro_2'), isFalse);
      expect(progress.unlockedTranslations['seed_micro_1'], isNotNull);
    });

    test(
        'Re-running initialize / backfill is idempotent and does not overwrite existing translations',
        () async {
      // Simulate user already having lvl_seed_02 completed and backfilled
      final existingProgress = GameProgress.initial().copyWith(
        completedLevels: {'lvl_seed_01', 'lvl_seed_02'},
        unlockedScriptureIds: {'seed_micro_1'},
        unlockedTranslations: {
          'seed_micro_1': 'web'
        }, // Pre-selected translation
        currentLevel: 'lvl_seed_03',
        tutorialCompleted: true,
      );
      fakeRepo.saveProgress(existingProgress);

      final container = ProviderContainer(
        overrides: [
          gameProgressRepositoryProvider.overrideWithValue(fakeRepo),
          hiveBoxProvider.overrideWithValue(_FakeBox() as Box),
          analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
          modulesProvider.overrideWithValue(AsyncValue.data(mockModules)),
          scriptureServiceProvider.overrideWithValue(_FakeScriptureService()),
        ],
      );

      await container.read(gameProgressProvider.notifier).initialize();
      var progress = container.read(gameProgressProvider);

      // Pre-selected translation is preserved
      expect(progress.unlockedTranslations['seed_micro_1'], equals('web'));

      // Re-run backfill manually
      await container.read(gameProgressProvider.notifier).initialize();
      progress = container.read(gameProgressProvider);

      expect(progress.unlockedTranslations['seed_micro_1'], equals('web'));
      expect(progress.unlockedScriptureIds.length, equals(1));
    });
  });
}

class _FakeRepo implements GameProgressRepository {
  GameProgress _progress = GameProgress.initial();
  @override
  Future<GameProgress> getProgress() async => _progress;
  @override
  Future<void> saveProgress(GameProgress progress) async =>
      _progress = progress;
  @override
  Future<void> resetProgress() async => _progress = GameProgress.initial();
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
      type: SyncConflictType.none,
      localProgress: _progress,
      cloudProgress: null);
  @override
  Future<void> resolveSyncConflict(SyncConflictResolution resolution) async {}
}

class _FakeAnalytics extends AnalyticsService {
  @override
  Future<void> init({bool enabled = true}) async {}
  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
  @override
  Future<void> logScreenView(String screenName) async {}
  @override
  Future<void> logParableViewed(String parableId) async {}
  @override
  Future<void> logLevelStart(dynamic levelId) async {}
  @override
  Future<void> logLevelComplete(dynamic levelId, int taps, int wrongTaps,
      {int attempts = 1, int elapsedSeconds = -1}) async {}
  @override
  Future<void> logWrongTap(dynamic levelId, int remainingLives) async {}
  @override
  Future<void> logGameOver(dynamic levelId) async {}
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

class _FakeScriptureService implements ScriptureService {
  @override
  Future<String> pickRandomActiveTranslation() async => 'kjv';
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
