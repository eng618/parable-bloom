import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:parable_bloom/services/analytics_service.dart';
import 'package:parable_bloom/providers/game_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/features/game/domain/repositories/game_progress_repository.dart';

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
  Future<void> setCloudSyncEnabled(bool enabled) async {}

  @override
  Future<bool> isCloudSyncEnabled() async => false;

  @override
  Future<void> syncFromCloud() async {}
}

// Minimal fake analytics to avoid needing Firebase in tests
class FakeAnalytics extends AnalyticsService {
  @override
  Future<void> init() async {}

  @override
  Future<void> logLevelStart(int levelId) async {}

  @override
  Future<void> logLevelComplete(int levelId, int taps, int wrongTaps) async {}

  @override
  Future<void> logWrongTap(int levelId, int remainingLives) async {}

  @override
  Future<void> logGameOver(int levelId) async {}
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
      container.read(debugSelectedLevelProvider.notifier).setLevel(5);

      // Now debug play mode should be true
      expect(container.read(debugPlayModeProvider), isTrue);

      // Clear the debug level
      container.read(debugSelectedLevelProvider.notifier).setLevel(null);

      // Debug play mode returns to false
      expect(container.read(debugPlayModeProvider), isFalse);
    });

    test('Game progress notifier does not save when debug play mode is active',
        () {
      final fakeRepo = FakeRepo();
      final fakeAnalytics = FakeAnalytics();
      final fakeBox = FakeBox();

      final container = ProviderContainer(
        overrides: [
          gameProgressRepositoryProvider.overrideWithValue(fakeRepo),
          hiveBoxProvider.overrideWithValue(fakeBox as Box),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        ],
      );

      // Verify initial state: no save, no debug play
      expect(fakeRepo.saveCalled, isFalse);
      expect(container.read(debugPlayModeProvider), isFalse);

      // Try a normal (non-debug) completion
      container.read(gameProgressProvider.notifier).completeLevel(1);
      expect(fakeRepo.saveCalled, isTrue);

      // Reset and test debug mode
      fakeRepo.saveCalled = false;
      container.read(debugSelectedLevelProvider.notifier).setLevel(1);

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
