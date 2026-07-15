import "dart:io";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:hive/hive.dart";
import "package:mockito/mockito.dart";
import "package:parable_bloom/features/game/application/providers/progress_providers.dart";
import "package:parable_bloom/features/game/data/repositories/firebase_game_progress_repository.dart";
import "package:parable_bloom/features/game/domain/entities/cloud_sync_state.dart";
import "package:parable_bloom/features/game/domain/entities/game_progress.dart";
import "package:parable_bloom/features/game/domain/repositories/game_progress_repository.dart";
import "package:parable_bloom/providers/infrastructure_providers.dart";
import "package:parable_bloom/features/game/application/providers/module_providers.dart";
import "package:parable_bloom/features/game/domain/entities/level_data.dart";

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class TrackingFirebaseGameProgressRepository
    extends FirebaseGameProgressRepository {
  TrackingFirebaseGameProgressRepository(
    super.localBox,
    super.firestore,
    super.auth,
  );

  final List<String> calls = <String>[];

  GameProgress _stored = GameProgress.initial();

  @override
  Future<void> syncToCloud() async {
    calls.add("syncToCloud");
    _stored = _stored.copyWith(
        currentLevel: 'lvl_seed_02', completedLevels: {'lvl_seed_01'});
  }

  @override
  Future<void> syncFromCloud() async {
    calls.add("syncFromCloud");
    _stored = _stored.copyWith(currentLevel: 'lvl_seed_05', completedLevels: {
      'lvl_seed_01',
      'lvl_seed_02',
      'lvl_seed_03',
      'lvl_seed_04'
    });
  }

  @override
  Future<GameProgress> getProgress() async {
    calls.add("getProgress");
    return _stored;
  }
}

class FakeLocalOnlyRepository implements GameProgressRepository {
  @override
  Future<GameProgress> getProgress() async => GameProgress.initial();

  @override
  Future<void> resetProgress() async {}

  @override
  Future<void> saveProgress(GameProgress progress) async {}

  @override
  Future<void> setCloudSyncEnabled(bool enabled) async {}

  @override
  Future<void> syncFromCloud() async {}

  @override
  Future<void> syncToCloud() async {}

  @override
  Future<bool> isCloudSyncAvailable() async => false;

  @override
  Future<bool> isCloudSyncEnabled() async => false;

  @override
  Future<CloudSyncAvailability> getCloudSyncAvailability() async {
    return const CloudSyncAvailability(
      isAvailable: false,
      reason: CloudSyncAvailabilityReason.signedOut,
    );
  }

  @override
  Future<DateTime?> getLastSyncTime() async => null;

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

void main() {
  late Directory tempDir;
  late Box box;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockAuth;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp("progress_notifier_test_");
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    box = await Hive.openBox(
        "progress_notifier_${DateTime.now().microsecondsSinceEpoch}");
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
  });

  tearDown(() async {
    await box.clear();
    final boxName = box.name;
    await box.close();
    await Hive.deleteBoxFromDisk(boxName);
  });

  test("syncOnReconnect syncs to cloud, then from cloud, then refreshes state",
      () async {
    final repository = TrackingFirebaseGameProgressRepository(
      box,
      mockFirestore,
      mockAuth,
    );

    final container = ProviderContainer(
      overrides: [
        gameProgressRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(gameProgressProvider.notifier).syncOnReconnect();

    expect(repository.calls,
        <String>["syncToCloud", "syncFromCloud", "getProgress"]);
    final state = container.read(gameProgressProvider);
    expect(state.currentLevel, 'lvl_seed_05');
    expect(state.completedLevels,
        <String>{'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03', 'lvl_seed_04'});
  });

  test("syncOnReconnect is a no-op for non-firebase repository", () async {
    final container = ProviderContainer(
      overrides: [
        gameProgressRepositoryProvider
            .overrideWithValue(FakeLocalOnlyRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(gameProgressProvider.notifier).syncOnReconnect();

    expect(container.read(gameProgressProvider), GameProgress.initial());
  });

  test(
      "completeLevel successfully updates progress to next level using manifest playlist",
      () async {
    final modules = [
      ModuleData(
        id: 1,
        name: 'Seedling',
        themeSeed: 'forest',
        levels: ['lvl_seed_01', 'lvl_seed_02'],
        challengeLevel: 'lvl_seed_challenge',
        parable: const {},
        unlockMessage: '',
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        gameProgressRepositoryProvider
            .overrideWithValue(FakeLocalOnlyRepository()),
        modulesProvider.overrideWithValue(AsyncValue.data(modules)),
      ],
    );
    addTearDown(container.dispose);

    // Initial level is lvl_seed_01
    final notifier = container.read(gameProgressProvider.notifier);
    expect(container.read(gameProgressProvider).currentLevel, 'lvl_seed_01');

    // Complete level 1
    await notifier.completeLevel('lvl_seed_01');

    // Progress should now be updated to lvl_seed_02
    final updatedState = container.read(gameProgressProvider);
    expect(updatedState.currentLevel, 'lvl_seed_02');
    expect(updatedState.completedLevels, {'lvl_seed_01'});

    // Complete level 2
    await notifier.completeLevel('lvl_seed_02');

    // Progress should now be updated to lvl_seed_challenge
    final challengeState = container.read(gameProgressProvider);
    expect(challengeState.currentLevel, 'lvl_seed_challenge');
    expect(challengeState.completedLevels, {'lvl_seed_01', 'lvl_seed_02'});
  });
}
