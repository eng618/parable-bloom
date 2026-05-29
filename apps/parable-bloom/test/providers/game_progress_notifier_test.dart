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
    _stored = _stored.copyWith(currentLevel: 2, completedLevels: {1});
  }

  @override
  Future<void> syncFromCloud() async {
    calls.add("syncFromCloud");
    _stored = _stored.copyWith(currentLevel: 5, completedLevels: {1, 2, 3, 4});
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
    expect(state.currentLevel, 5);
    expect(state.completedLevels, <int>{1, 2, 3, 4});
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
}
