import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parable_bloom/features/game/application/providers/progress_providers.dart';
import 'package:parable_bloom/features/game/application/providers/module_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/features/game/domain/entities/cloud_sync_state.dart';
import 'package:parable_bloom/features/game/domain/repositories/game_progress_repository.dart';
import 'package:parable_bloom/core/services/analytics_service.dart';
import 'package:parable_bloom/core/providers/infrastructure_providers.dart';
import 'package:parable_bloom/core/providers/service_providers.dart';
import 'package:parable_bloom/core/services/scripture_service.dart';
import 'package:hive/hive.dart';

class _FakeRepo implements GameProgressRepository {
  GameProgress _progress = GameProgress.initial();

  @override
  Future<GameProgress> getProgress() async => _progress;

  @override
  Future<void> saveProgress(GameProgress progress) async {
    _progress = progress;
  }

  @override
  Future<void> resetProgress() async {
    _progress = GameProgress.initial();
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
        isAvailable: false,
        reason: CloudSyncAvailabilityReason.signedOut,
      );

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
        cloudProgress: null,
      );

  @override
  Future<void> resolveSyncConflict(SyncConflictResolution resolution) async {}
}

class _FakeAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeScriptureService implements ScriptureService {
  @override
  Future<String> pickRandomActiveTranslation() async => 'kjv';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeBox implements Box {
  final Map<dynamic, dynamic> _data = {};
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _data[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    _data[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('Journal Notes Tests', () {
    late _FakeRepo fakeRepo;

    setUp(() {
      fakeRepo = _FakeRepo();
    });

    test('Saving and modifying journal note works as expected', () async {
      final container = ProviderContainer(
        overrides: [
          gameProgressRepositoryProvider.overrideWithValue(fakeRepo),
          hiveBoxProvider.overrideWithValue(_FakeBox() as Box),
          analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
          modulesProvider.overrideWithValue(const AsyncValue.data([])),
          scriptureServiceProvider.overrideWithValue(_FakeScriptureService()),
        ],
      );

      await container.read(gameProgressProvider.notifier).initialize();
      var progress = container.read(gameProgressProvider);
      expect(progress.journalNotes, isEmpty);

      // Save a reflection note for growth_seed_word
      await container
          .read(gameProgressProvider.notifier)
          .saveJournalNote('growth_seed_word', 'My heart needs good soil.');

      progress = container.read(gameProgressProvider);
      expect(progress.journalNotes['growth_seed_word'],
          equals('My heart needs good soil.'));

      // Update the note
      await container.read(gameProgressProvider.notifier).saveJournalNote(
          'growth_seed_word', 'Updated reflection: taking deeper root.');

      progress = container.read(gameProgressProvider);
      expect(progress.journalNotes['growth_seed_word'],
          equals('Updated reflection: taking deeper root.'));

      // Clearing note by setting empty string
      await container
          .read(gameProgressProvider.notifier)
          .saveJournalNote('growth_seed_word', '');

      progress = container.read(gameProgressProvider);
      expect(progress.journalNotes.containsKey('growth_seed_word'), isFalse);
    });
  });
}
