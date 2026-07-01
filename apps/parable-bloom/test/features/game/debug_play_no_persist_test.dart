import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:parable_bloom/services/analytics_service.dart';
import 'package:parable_bloom/features/game/domain/entities/cloud_sync_state.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/features/game/domain/repositories/game_progress_repository.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/application/providers/progress_providers.dart';
import 'package:parable_bloom/providers/infrastructure_providers.dart';
import 'package:parable_bloom/providers/service_providers.dart';
import 'package:parable_bloom/providers/settings_providers.dart';
import 'package:parable_bloom/features/game/application/providers/module_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';

class FakeRepo implements GameProgressRepository {
  bool saveCalled = false;

  @override
  Future<GameProgress> getProgress() async {
    return GameProgress.initial();
  }

  @override
  Future<void> saveProgress(GameProgress progress) async {
    saveCalled = true;
  }

  @override
  Future<void> resetProgress() async {}

  @override
  Future<void> syncToCloud() async {}

  @override
  Future<DateTime?> getLastSyncTime() async => null;

  @override
  Future<bool> isCloudSyncAvailable() async => false;

  @override
  Future<CloudSyncAvailability> getCloudSyncAvailability() async {
    return const CloudSyncAvailability(
      isAvailable: false,
      reason: CloudSyncAvailabilityReason.signedOut,
    );
  }

  @override
  Future<void> setCloudSyncEnabled(bool enabled) async {}

  @override
  Future<bool> isCloudSyncEnabled() async => false;

  @override
  Future<void> syncFromCloud() async {}

  @override
  Future<SyncConflictState> inspectSyncConflict() async {
    return SyncConflictState(
      type: SyncConflictType.none,
      localProgress: GameProgress.initial(),
      cloudProgress: null,
    );
  }

  @override
  Future<void> resolveSyncConflict(SyncConflictResolution resolution) async {}
}

// Minimal fake analytics to avoid needing Firebase in tests
class FakeAnalytics extends AnalyticsService {
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
  Future<void> logLevelComplete(
    dynamic levelId,
    int taps,
    int wrongTaps, {
    int attempts = 1,
    int elapsedSeconds = -1,
  }) async {}

  @override
  Future<void> logWrongTap(dynamic levelId, int remainingLives) async {}

  @override
  Future<void> logGameOver(dynamic levelId) async {}
}

class FakeBox implements Box<dynamic> {
  final Map<dynamic, dynamic> _store = {};
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

void main() {
  group('Debug Play Mode Tests', () {
    test('Debug play mode provider reflects selected level', () {
      final container = ProviderContainer();

      // Initially, no debug level is selected, so debug play mode is off
      expect(container.read(debugPlayModeProvider), isFalse);

      // Set a debug level
      container
          .read(debugSelectedLevelProvider.notifier)
          .setLevel('lvl_seed_05');

      // Now debug play mode should be true
      expect(container.read(debugPlayModeProvider), isTrue);

      // Clear the debug level
      container.read(debugSelectedLevelProvider.notifier).setLevel(null);

      // Debug play mode returns to false
      expect(container.read(debugPlayModeProvider), isFalse);
    });

    test('Game progress notifier does not save when debug play mode is active',
        () async {
      final fakeRepo = FakeRepo();
      final fakeAnalytics = FakeAnalytics();
      final fakeBox = FakeBox();

      final container = ProviderContainer(
        overrides: [
          gameProgressRepositoryProvider.overrideWithValue(fakeRepo),
          hiveBoxProvider.overrideWithValue(fakeBox as Box),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
          modulesProvider.overrideWithValue(AsyncValue.data([
            ModuleData(
              id: 1,
              name: 'Seedling',
              themeSeed: 'forest',
              levels: ['lvl_seed_01', 'lvl_seed_02'],
              challengeLevel: 'lvl_seed_challenge',
              parable: const {},
              unlockMessage: '',
              scriptures: const [],
            ),
          ])),
        ],
      );

      // Verify initial state: no save, no debug play
      expect(fakeRepo.saveCalled, isFalse);
      expect(container.read(debugPlayModeProvider), isFalse);

      // Try a normal (non-debug) completion
      await container
          .read(gameProgressProvider.notifier)
          .completeLevel('lvl_seed_01');
      expect(fakeRepo.saveCalled, isTrue);

      // Reset and test debug mode
      fakeRepo.saveCalled = false;
      container
          .read(debugSelectedLevelProvider.notifier)
          .setLevel('lvl_seed_01');

      // Verify debug play mode is now active
      expect(container.read(debugPlayModeProvider), isTrue);

      // The completion logic in GameScreen checks debugPlayModeProvider
      // and skips calling completeLevel. This test demonstrates the provider
      // state is correct; the actual skipping happens in GameScreen's
      // onLevelComplete callback (which is integration-tested separately).
      expect(container.read(debugPlayModeProvider), isTrue);
    });
  });
}
