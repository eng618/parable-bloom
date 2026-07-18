import "dart:async";
import "dart:io";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:connectivity_plus/connectivity_plus.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:hive/hive.dart";
import "package:mockito/mockito.dart";
import "package:parable_bloom/features/game/application/providers/progress_providers.dart";
import "package:parable_bloom/features/game/data/repositories/firebase_game_progress_repository.dart";
import "package:parable_bloom/features/game/domain/entities/game_progress.dart";
import "package:parable_bloom/core/providers/infrastructure_providers.dart";

// ---------- Mocks ----------

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

// ---------- Tracking repository ----------

class _TrackingFirebaseRepo extends FirebaseGameProgressRepository {
  _TrackingFirebaseRepo(super.localBox, super.firestore, super.auth);

  final List<String> calls = [];

  @override
  Future<void> syncToCloud() async => calls.add("syncToCloud");

  @override
  Future<void> syncFromCloud() async => calls.add("syncFromCloud");

  @override
  Future<GameProgress> getProgress() async {
    calls.add("getProgress");
    return GameProgress.initial();
  }
}

// ---------- Minimal harness widget ----------
//
// Replicates only the connectivity-stream wiring from _ParableBloomAppState
// so the test can pump a real widget without Firebase/Hive dependencies.

class _ConnectivityHarness extends ConsumerStatefulWidget {
  const _ConnectivityHarness();

  @override
  ConsumerState<_ConnectivityHarness> createState() =>
      _ConnectivityHarnessState();
}

class _ConnectivityHarnessState extends ConsumerState<_ConnectivityHarness> {
  bool _wasOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    final stream = ref.read(connectivityStreamProvider);
    _sub = stream.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (!_wasOnline && isOnline) {
        unawaited(ref.read(gameProgressProvider.notifier).syncOnReconnect());
      }
      _wasOnline = isOnline;
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ---------- Tests ----------

void main() {
  late Directory tempDir;
  late Box box;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockAuth;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp("app_connectivity_test_");
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
        "conn_test_${DateTime.now().microsecondsSinceEpoch}");
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
  });

  tearDown(() async {
    await box.clear();
    final boxName = box.name;
    await box.close();
    await Hive.deleteBoxFromDisk(boxName);
  });

  testWidgets("syncOnReconnect is called when connectivity is restored",
      (tester) async {
    final repo = _TrackingFirebaseRepo(box, mockFirestore, mockAuth);
    final controller = StreamController<List<ConnectivityResult>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityStreamProvider.overrideWithValue(controller.stream),
          gameProgressRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: _ConnectivityHarness()),
      ),
    );

    // Go offline
    controller.add([ConnectivityResult.none]);
    await tester.pump();

    // Restore connection
    controller.add([ConnectivityResult.wifi]);
    await tester.pumpAndSettle();

    expect(repo.calls, containsAllInOrder(["syncToCloud", "syncFromCloud"]));
  });

  testWidgets("syncOnReconnect is not called when connectivity stays online",
      (tester) async {
    final repo = _TrackingFirebaseRepo(box, mockFirestore, mockAuth);
    final controller = StreamController<List<ConnectivityResult>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityStreamProvider.overrideWithValue(controller.stream),
          gameProgressRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: _ConnectivityHarness()),
      ),
    );

    // Stay online throughout
    controller.add([ConnectivityResult.wifi]);
    await tester.pump();
    controller.add([ConnectivityResult.wifi]);
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
  });

  testWidgets("syncOnReconnect is not called when connectivity stays offline",
      (tester) async {
    final repo = _TrackingFirebaseRepo(box, mockFirestore, mockAuth);
    final controller = StreamController<List<ConnectivityResult>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityStreamProvider.overrideWithValue(controller.stream),
          gameProgressRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: _ConnectivityHarness()),
      ),
    );

    // Start offline and stay offline
    controller.add([ConnectivityResult.none]);
    await tester.pump();
    controller.add([ConnectivityResult.none]);
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
  });
}
