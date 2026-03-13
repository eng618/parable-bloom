import "dart:io";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth_mocks/firebase_auth_mocks.dart";
import "package:flutter_test/flutter_test.dart";
import "package:hive/hive.dart";

import "package:parable_bloom/features/game/data/repositories/firebase_game_progress_repository.dart";
import "package:parable_bloom/features/game/domain/entities/cloud_sync_state.dart";
import "package:parable_bloom/features/game/domain/entities/game_progress.dart";

class _BackendStore {
  final Map<String, Map<String, dynamic>> docs = {};

  String _key(
      String collection, String userId, String subcollection, String doc) {
    return "$collection/$userId/$subcollection/$doc";
  }

  Map<String, dynamic>? read(
    String collection,
    String userId,
    String subcollection,
    String doc,
  ) {
    return docs[_key(collection, userId, subcollection, doc)];
  }

  void write(
    String collection,
    String userId,
    String subcollection,
    String doc,
    Map<String, dynamic> data,
  ) {
    docs[_key(collection, userId, subcollection, doc)] =
        Map<String, dynamic>.from(data);
  }

  void remove(
      String collection, String userId, String subcollection, String doc) {
    docs.remove(_key(collection, userId, subcollection, doc));
  }
}

class _FakeFirestore implements FirebaseFirestore {
  final _BackendStore backend;

  _FakeFirestore(this.backend);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _FakeRootCollection(backend, path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRootCollection implements CollectionReference<Map<String, dynamic>> {
  final _BackendStore backend;
  final String collectionPath;

  _FakeRootCollection(this.backend, this.collectionPath);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _FakeRootDoc(backend, collectionPath, path ?? "");
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRootDoc implements DocumentReference<Map<String, dynamic>> {
  final _BackendStore backend;
  final String collectionPath;
  final String userId;

  _FakeRootDoc(this.backend, this.collectionPath, this.userId);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _FakeSubCollection(backend, collectionPath, userId, path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSubCollection implements CollectionReference<Map<String, dynamic>> {
  final _BackendStore backend;
  final String collectionPath;
  final String userId;
  final String subcollectionPath;

  _FakeSubCollection(
      this.backend, this.collectionPath, this.userId, this.subcollectionPath);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _FakeLeafDoc(
      backend,
      collectionPath,
      userId,
      subcollectionPath,
      path ?? "",
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLeafDoc implements DocumentReference<Map<String, dynamic>> {
  final _BackendStore backend;
  final String collectionPath;
  final String userId;
  final String subcollectionPath;
  final String docId;

  _FakeLeafDoc(
    this.backend,
    this.collectionPath,
    this.userId,
    this.subcollectionPath,
    this.docId,
  );

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    final data = backend.read(collectionPath, userId, subcollectionPath, docId);
    return _FakeSnapshot(data);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    backend.write(collectionPath, userId, subcollectionPath, docId, data);
  }

  @override
  Future<void> delete() async {
    backend.remove(collectionPath, userId, subcollectionPath, docId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? _data;

  _FakeSnapshot(this._data);

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() =>
      _data == null ? null : Map<String, dynamic>.from(_data!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tempDir;
  late Box deviceABox;
  late Box deviceBBox;
  late FirebaseGameProgressRepository deviceARepo;
  late FirebaseGameProgressRepository deviceBRepo;
  late _BackendStore sharedBackend;

  setUpAll(() async {
    tempDir =
        await Directory.systemTemp.createTemp("firebase_sync_integration_");
    Hive.init(tempDir.path);
  });

  setUp(() async {
    final user = MockUser(
      uid: "shared-user",
      isAnonymous: false,
      email: "player@example.com",
    );

    final authA = MockFirebaseAuth(mockUser: user, signedIn: true);
    final authB = MockFirebaseAuth(mockUser: user, signedIn: true);

    deviceABox =
        await Hive.openBox("device_a_${DateTime.now().millisecondsSinceEpoch}");
    deviceBBox =
        await Hive.openBox("device_b_${DateTime.now().microsecondsSinceEpoch}");

    sharedBackend = _BackendStore();
    final firestore = _FakeFirestore(sharedBackend);

    deviceARepo = FirebaseGameProgressRepository(deviceABox, firestore, authA);
    deviceBRepo = FirebaseGameProgressRepository(deviceBBox, firestore, authB);

    await deviceARepo.setCloudSyncEnabled(true);
    await deviceBRepo.setCloudSyncEnabled(true);
  });

  tearDown(() async {
    await deviceABox.clear();
    await deviceABox.close();
    await Hive.deleteBoxFromDisk(deviceABox.name);

    await deviceBBox.clear();
    await deviceBBox.close();
    await Hive.deleteBoxFromDisk(deviceBBox.name);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test("new device pulls cloud progress when cloud is ahead", () async {
    final cloudProgress = GameProgress.initial().copyWith(
      currentLevel: 12,
      completedLevels: {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11},
      tutorialCompleted: true,
    );

    await deviceARepo.saveProgress(cloudProgress);
    await deviceARepo.syncToCloud();

    final freshLocal =
        GameProgress.initial().copyWith(currentLevel: 2, completedLevels: {1});
    await deviceBRepo.saveProgress(freshLocal);

    final conflict = await deviceBRepo.inspectSyncConflict();
    expect(conflict.type, SyncConflictType.cloudAhead);

    await deviceBRepo.resolveSyncConflict(SyncConflictResolution.keepCloud);

    final resolved = await deviceBRepo.getProgress();
    expect(resolved.currentLevel, 12);
    expect(resolved.completedLevels.length, 11);
  });

  test("divergent progress allows explicit keep-local overwrite and resync",
      () async {
    final cloudProgress = GameProgress.initial().copyWith(
      currentLevel: 7,
      completedLevels: {1, 2, 3, 4, 5, 6},
      tutorialCompleted: true,
    );

    await deviceARepo.saveProgress(cloudProgress);
    await deviceARepo.syncToCloud();

    final localAheadDifferent = GameProgress.initial().copyWith(
      currentLevel: 7,
      completedLevels: {1, 2, 3, 4, 5, 20},
      tutorialCompleted: true,
    );
    await deviceBRepo.saveProgress(localAheadDifferent);

    final conflict = await deviceBRepo.inspectSyncConflict();
    expect(conflict.type, SyncConflictType.divergent);

    await deviceBRepo.resolveSyncConflict(SyncConflictResolution.keepLocal);

    final deviceAConflict = await deviceARepo.inspectSyncConflict();
    expect(deviceAConflict.type, SyncConflictType.divergent);

    await deviceARepo.resolveSyncConflict(SyncConflictResolution.keepCloud);
    final onDeviceA = await deviceARepo.getProgress();
    expect(onDeviceA.completedLevels.contains(20), isTrue);
    expect(onDeviceA.completedLevels.contains(6), isFalse);
  });
}
