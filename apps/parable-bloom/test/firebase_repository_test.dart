import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/mockito.dart';

import 'package:parable_bloom/features/game/data/repositories/firebase_game_progress_repository.dart';
import 'package:parable_bloom/features/game/domain/entities/cloud_sync_state.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';

// Mock Firestore
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String? collectionPath) {
    return super.noSuchMethod(
      Invocation.method(#collection, [collectionPath]),
      returnValue: MockCollectionReference(),
    ) as CollectionReference<Map<String, dynamic>>;
  }
}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return super.noSuchMethod(
      Invocation.method(#doc, [path]),
      returnValue: MockDocumentReference(),
    ) as DocumentReference<Map<String, dynamic>>;
  }
}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {
  @override
  CollectionReference<Map<String, dynamic>> collection(String? collectionPath) {
    return super.noSuchMethod(
      Invocation.method(#collection, [collectionPath]),
      returnValue: MockCollectionReference(),
    ) as CollectionReference<Map<String, dynamic>>;
  }

  @override
  Future<void> set(Map<String, dynamic>? data, [SetOptions? options]) {
    return super.noSuchMethod(
      Invocation.method(#set, [data, options]),
      returnValue: Future<void>.value(),
    ) as Future<void>;
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    return super.noSuchMethod(
      Invocation.method(#get, [options]),
      returnValue: Future.value(MockDocumentSnapshot()),
    ) as Future<DocumentSnapshot<Map<String, dynamic>>>;
  }

  @override
  Future<void> delete() {
    return super.noSuchMethod(
      Invocation.method(#delete, []),
      returnValue: Future<void>.value(),
    ) as Future<void>;
  }
}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  bool get exists =>
      super.noSuchMethod(Invocation.getter(#exists), returnValue: false)
          as bool;

  @override
  Map<String, dynamic>? data() =>
      super.noSuchMethod(Invocation.method(#data, []), returnValue: null)
          as Map<String, dynamic>?;
}

void main() {
  late Box box;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late FirebaseGameProgressRepository repository;
  late Directory tempDir;
  late MockDocumentSnapshot mockSnapshot;
  late MockDocumentReference mockSubDoc;

  setUpAll(() async {
    // Create a temporary directory for testing
    tempDir = await Directory.systemTemp.createTemp('hive_firebase_test_');
    // Initialize Hive with the temp directory
    Hive.init(tempDir.path);
  });

  setUp(() async {
    // Create a unique test box for each test to avoid conflicts
    final boxName =
        'test_box_firebase_${DateTime.now().millisecondsSinceEpoch}';
    box = await Hive.openBox(boxName);

    // Mock Firebase Auth with a signed-in anonymous user
    final mockUser = MockUser(uid: 'test-user-id');
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

    // Mock Firestore
    mockFirestore = MockFirebaseFirestore();

    repository = FirebaseGameProgressRepository(box, mockFirestore, mockAuth);

    // Setup Firestore Mocks
    final mockCollection = MockCollectionReference();
    final mockDoc = MockDocumentReference();
    final mockSubCollection = MockCollectionReference();
    mockSubDoc = MockDocumentReference();
    mockSnapshot = MockDocumentSnapshot();

    // Stub chain: firestore -> collection -> doc -> collection -> doc
    // Using explicit values to satisfy sound null safety for non-nullable parameters
    when(mockFirestore.collection('game_progress_dev'))
        .thenReturn(mockCollection);
    when(mockCollection.doc('test-user-id')).thenReturn(mockDoc);
    when(mockDoc.collection('data')).thenReturn(mockSubCollection);
    when(mockSubCollection.doc('progress')).thenReturn(mockSubDoc);

    // Stub operations
    // get() takes optional GetOptions, so any is okay if inferred correctly.
    // set() takes non-nullable Map<String, dynamic>, using any as dynamic to satisfy type check.
    when(mockSubDoc.get(any)).thenAnswer((_) async => mockSnapshot);
    when(mockSubDoc.set(any as dynamic)).thenAnswer((_) async => {});
    when(mockSubDoc.delete()).thenAnswer((_) async => {});

    // Default snapshot state (does not exist)
    when(mockSnapshot.exists).thenReturn(false);
    when(mockSnapshot.data()).thenReturn(null);
  });

  tearDown(() async {
    await box.clear();
    await box.close();
    // Delete the box to free resources
    await Hive.deleteBoxFromDisk(box.name);
  });

  tearDownAll(() async {
    // Clean up Hive after all tests
    await Hive.close();
    // Clean up temp directory
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('FirebaseGameProgressRepository', () {
    test('should return initial progress when no data exists', () async {
      final progress = await repository.getProgress();

      expect(progress.currentLevel, equals('lvl_seed_01'));
      expect(progress.completedLevels, isEmpty);
    });

    test('should save and retrieve progress correctly', () async {
      final originalProgress = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_03',
        completedLevels: {'lvl_seed_01', 'lvl_seed_02'},
        tutorialCompleted: false,
      );

      await repository.saveProgress(originalProgress);
      final retrievedProgress = await repository.getProgress();

      expect(retrievedProgress.currentLevel, equals('lvl_seed_03'));
      expect(retrievedProgress.completedLevels, equals({'lvl_seed_01', 'lvl_seed_02'}));
    });

    test('should reset progress correctly', () async {
      final progress = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_05',
        completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03', 'lvl_seed_04'},
        tutorialCompleted: false,
      );

      await repository.saveProgress(progress);
      await repository.resetProgress();

      final resetProgress = await repository.getProgress();
      expect(resetProgress.currentLevel, equals('lvl_seed_01'));
      expect(resetProgress.completedLevels, isEmpty);
    });

    test('should handle cloud sync settings', () async {
      // Initially disabled
      expect(await repository.isCloudSyncEnabled(), isFalse);

      // Enable sync
      await repository.setCloudSyncEnabled(true);
      expect(await repository.isCloudSyncEnabled(), isTrue);

      // Disable sync
      await repository.setCloudSyncEnabled(false);
      expect(await repository.isCloudSyncEnabled(), isFalse);
    });

    test('enabling sync applies cloud data when cloud is ahead', () async {
      final local = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_02',
        completedLevels: {'lvl_seed_01'},
      );
      await repository.saveProgress(local);

      final cloud = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_06',
        completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03', 'lvl_seed_04', 'lvl_seed_05'},
      );
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.data()).thenReturn(cloud.toJson());

      await repository.setCloudSyncEnabled(true);

      final resolved = await repository.getProgress();
      expect(resolved.currentLevel, 'lvl_seed_06');
      expect(resolved.completedLevels, {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03', 'lvl_seed_04', 'lvl_seed_05'});
      expect(await repository.getLastSyncTime(), isNotNull);
    });

    test('enabling sync does not auto-push when local is ahead', () async {
      final local = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_07',
        completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03', 'lvl_seed_04', 'lvl_seed_05', 'lvl_seed_06'},
      );
      await repository.saveProgress(local);

      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.data()).thenReturn(
        GameProgress.initial().copyWith(
          currentLevel: 'lvl_seed_03',
          completedLevels: {'lvl_seed_01', 'lvl_seed_02'},
        ).toJson(),
      );

      int writeAttempts = 0;
      when(mockSubDoc.set(any as dynamic)).thenAnswer((_) async {
        writeAttempts += 1;
      });

      await repository.setCloudSyncEnabled(true);

      expect(writeAttempts, 0);
      expect(await repository.getLastSyncTime(), isNull);
    });

    test('enabling sync does not auto-push when conflict is divergent',
        () async {
      final local = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_06',
        completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03', 'lvl_seed_06'},
      );
      await repository.saveProgress(local);

      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.data()).thenReturn(
        GameProgress.initial().copyWith(
          currentLevel: 'lvl_seed_06',
          completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_04', 'lvl_seed_05'},
        ).toJson(),
      );

      int writeAttempts = 0;
      when(mockSubDoc.set(any as dynamic)).thenAnswer((_) async {
        writeAttempts += 1;
      });

      await repository.setCloudSyncEnabled(true);

      expect(writeAttempts, 0);
      expect(await repository.getLastSyncTime(), isNull);
    });

    test('should detect cloud sync availability', () async {
      // With mocked signed-in user, should be available
      final available = await repository.isCloudSyncAvailable();
      expect(available, isTrue);

      final availability = await repository.getCloudSyncAvailability();
      expect(availability.isAvailable, isTrue);
      expect(availability.reason, CloudSyncAvailabilityReason.available);
    });

    test('should report anonymous account as unavailable', () async {
      final anonymousAuth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'anon-user', isAnonymous: true),
        signedIn: true,
      );
      repository =
          FirebaseGameProgressRepository(box, mockFirestore, anonymousAuth);

      final availability = await repository.getCloudSyncAvailability();
      expect(availability.isAvailable, isFalse);
      expect(availability.reason, CloudSyncAvailabilityReason.anonymousAccount);
    });

    test('should handle last sync time', () async {
      // Initially null
      expect(await repository.getLastSyncTime(), isNull);

      // Set a sync time (simulated)
      final now = DateTime.now();
      await box.put('last_sync_time', now.millisecondsSinceEpoch);

      final lastSync = await repository.getLastSyncTime();
      expect(lastSync, isNotNull);
      expect(
        lastSync!.millisecondsSinceEpoch,
        equals(now.millisecondsSinceEpoch),
      );
    });

    test('should sync to cloud (basic functionality test)', () async {
      // This test verifies the sync method doesn't crash
      // In a real scenario, we'd mock Firestore responses
      final progress = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_02',
        completedLevels: {'lvl_seed_01'},
        tutorialCompleted: false,
      );

      await repository.saveProgress(progress);

      // Sync should not throw (even if Firestore is mocked)
      await expectLater(repository.syncToCloud(), completes);
    });

    test('syncToCloud skips push when local data is already synced', () async {
      final progress = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_04',
        completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03'},
      );
      await repository.saveProgress(progress);

      final now = DateTime.now().millisecondsSinceEpoch;
      await box.put('cloud_sync_enabled', true);
      await box.put('last_local_update', now - 1000);
      await box.put('last_sync_time', now);

      int writeAttempts = 0;
      when(mockSubDoc.set(any as dynamic)).thenAnswer((_) async {
        writeAttempts += 1;
      });

      await repository.syncToCloud();

      expect(writeAttempts, 0);
    });

    test('syncToCloud pushes when local data is newer than last sync',
        () async {
      final progress = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_04',
        completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03'},
      );
      await repository.saveProgress(progress);

      final now = DateTime.now().millisecondsSinceEpoch;
      await box.put('cloud_sync_enabled', true);
      await box.put('last_local_update', now);
      await box.put('last_sync_time', now - 1000);

      when(mockSubDoc.get(any)).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.exists).thenReturn(false);
      when(mockSnapshot.data()).thenReturn(null);

      int writeAttempts = 0;
      when(mockSubDoc.set(any as dynamic)).thenAnswer((_) async {
        writeAttempts += 1;
      });

      await repository.syncToCloud();

      expect(writeAttempts, 1);
      expect(await repository.getLastSyncTime(), isNotNull);
    });

    test('should handle cloud read timeout without throwing', () async {
      repository = FirebaseGameProgressRepository(
        box,
        mockFirestore,
        mockAuth,
        cloudReadTimeout: const Duration(milliseconds: 10),
        cloudRetryDelay: Duration.zero,
      );

      when(mockSubDoc.get(any)).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return mockSnapshot;
      });
      when(mockSnapshot.exists).thenReturn(false);
      when(mockSnapshot.data()).thenReturn(null);

      await repository.setCloudSyncEnabled(true);

      await expectLater(repository.syncToCloud(), completes);
    });

    test('should handle cloud write timeout without updating last sync time',
        () async {
      repository = FirebaseGameProgressRepository(
        box,
        mockFirestore,
        mockAuth,
        cloudWriteTimeout: const Duration(milliseconds: 10),
        cloudRetryDelay: Duration.zero,
      );

      when(mockSubDoc.get(any)).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.exists).thenReturn(false);
      when(mockSnapshot.data()).thenReturn(null);
      when(mockSubDoc.set(any as dynamic)).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });

      await repository.setCloudSyncEnabled(true);

      await expectLater(repository.syncToCloud(), completes);
      expect(await repository.getLastSyncTime(), isNull);
    });

    test('should retry cloud write and succeed after transient failures',
        () async {
      int writeAttempts = 0;

      when(mockSubDoc.get(any)).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.exists).thenReturn(false);
      when(mockSnapshot.data()).thenReturn(null);
      when(mockSubDoc.set(any as dynamic)).thenAnswer((_) async {
        writeAttempts += 1;
        if (writeAttempts < 3) {
          throw TimeoutException('transient timeout');
        }
      });

      await repository.setCloudSyncEnabled(true);

      expect(writeAttempts, 3);
      expect(await repository.getLastSyncTime(), isNotNull);
    });

    test('should retry cloud write for transient Firebase errors', () async {
      int writeAttempts = 0;

      when(mockSubDoc.get(any)).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.exists).thenReturn(false);
      when(mockSnapshot.data()).thenReturn(null);
      when(mockSubDoc.set(any as dynamic)).thenAnswer((_) async {
        writeAttempts += 1;
        if (writeAttempts < 3) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'transient unavailable',
          );
        }
      });

      await repository.setCloudSyncEnabled(true);

      expect(writeAttempts, 3);
      expect(await repository.getLastSyncTime(), isNotNull);
    });

    test('should not retry cloud write for permanent Firebase errors',
        () async {
      int writeAttempts = 0;

      when(mockSubDoc.get(any)).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.exists).thenReturn(false);
      when(mockSnapshot.data()).thenReturn(null);
      when(mockSubDoc.set(any as dynamic)).thenAnswer((_) async {
        writeAttempts += 1;
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'permanent permission error',
        );
      });

      await repository.setCloudSyncEnabled(true);

      expect(writeAttempts, 1);
      expect(await repository.getLastSyncTime(), isNull);
    });

    test('should retry cloud read and succeed after transient failures',
        () async {
      int readAttempts = 0;

      when(mockSubDoc.get(any)).thenAnswer((_) async {
        readAttempts += 1;
        if (readAttempts < 3) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'transient unavailable',
          );
        }
        return mockSnapshot;
      });
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.data()).thenReturn(
        GameProgress.initial()
            .copyWith(currentLevel: 'lvl_seed_05', completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03', 'lvl_seed_04'}).toJson(),
      );

      repository = FirebaseGameProgressRepository(
        box,
        mockFirestore,
        mockAuth,
        cloudRetryDelay: Duration.zero,
      );

      final conflict = await repository.inspectSyncConflict();

      expect(readAttempts, 3);
      expect(conflict.cloudProgress, isNotNull);
      expect(conflict.cloudProgress!.currentLevel, 'lvl_seed_05');
    });

    test('should return null cloud progress after exhausting read retries',
        () async {
      int readAttempts = 0;

      when(mockSubDoc.get(any)).thenAnswer((_) async {
        readAttempts += 1;
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'service unavailable',
        );
      });

      repository = FirebaseGameProgressRepository(
        box,
        mockFirestore,
        mockAuth,
        cloudRetryDelay: Duration.zero,
      );

      final conflict = await repository.inspectSyncConflict();

      expect(readAttempts, 3);
      expect(conflict.cloudProgress, isNull);
      expect(conflict.type, SyncConflictType.none);
    });

    test('should not retry cloud read for permanent Firebase errors', () async {
      int readAttempts = 0;

      when(mockSubDoc.get(any)).thenAnswer((_) async {
        readAttempts += 1;
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'permanent read error',
        );
      });

      repository = FirebaseGameProgressRepository(
        box,
        mockFirestore,
        mockAuth,
        cloudRetryDelay: Duration.zero,
      );

      final conflict = await repository.inspectSyncConflict();

      expect(readAttempts, 1);
      expect(conflict.cloudProgress, isNull);
    });

    test('inspectSyncConflict returns cloudAhead when cloud dominates',
        () async {
      final local = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_02',
        completedLevels: {'lvl_seed_01'},
      );
      await repository.saveProgress(local);

      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.data()).thenReturn(
        GameProgress.initial().copyWith(
            currentLevel: 'lvl_seed_06', completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03', 'lvl_seed_04', 'lvl_seed_05'}).toJson(),
      );

      final conflict = await repository.inspectSyncConflict();
      expect(conflict.type, SyncConflictType.cloudAhead);
      expect(conflict.cloudProgress, isNotNull);
      expect(conflict.cloudProgress!.currentLevel, 'lvl_seed_06');
    });

    test('inspectSyncConflict returns none when local and cloud are equal',
        () async {
      final shared = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_04',
        completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03'},
      );
      await repository.saveProgress(shared);

      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.data()).thenReturn(shared.toJson());

      final conflict = await repository.inspectSyncConflict();

      expect(conflict.type, SyncConflictType.none);
      expect(conflict.cloudProgress, isNotNull);
      expect(conflict.localProgress.currentLevel, 'lvl_seed_04');
    });

    test('inspectSyncConflict returns divergent for partial overlap', () async {
      final local = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_06',
        completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03', 'lvl_seed_06'},
      );
      await repository.saveProgress(local);

      final cloud = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_06',
        completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_04', 'lvl_seed_05'},
      );

      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.data()).thenReturn(cloud.toJson());

      final conflict = await repository.inspectSyncConflict();

      expect(conflict.type, SyncConflictType.divergent);
      expect(conflict.requiresUserDecision, isTrue);
    });

    test('resolveSyncConflict keepCloud replaces local state', () async {
      final local = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_02',
        completedLevels: {'lvl_seed_01'},
      );
      await repository.saveProgress(local);

      final cloud = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_08',
        completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03', 'lvl_seed_04', 'lvl_seed_05', 'lvl_seed_06', 'lvl_seed_07'},
      );
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.data()).thenReturn(cloud.toJson());

      await repository.resolveSyncConflict(SyncConflictResolution.keepCloud);

      final resolved = await repository.getProgress();
      expect(resolved.currentLevel, 'lvl_seed_08');
      expect(resolved.completedLevels, {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03', 'lvl_seed_04', 'lvl_seed_05', 'lvl_seed_06', 'lvl_seed_07'});
    });

    test('resolveSyncConflict keepLocal pushes local state to cloud', () async {
      final local = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_07',
        completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03', 'lvl_seed_04', 'lvl_seed_05', 'lvl_seed_06'},
      );
      await repository.saveProgress(local);

      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.data()).thenReturn(
        GameProgress.initial().copyWith(
          currentLevel: 'lvl_seed_03',
          completedLevels: {'lvl_seed_01', 'lvl_seed_02'},
        ).toJson(),
      );

      await repository.resolveSyncConflict(SyncConflictResolution.keepLocal);

      final resolved = await repository.getProgress();
      expect(resolved.currentLevel, 'lvl_seed_07');
      expect(resolved.completedLevels, {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03', 'lvl_seed_04', 'lvl_seed_05', 'lvl_seed_06'});
      expect(await repository.getLastSyncTime(), isNotNull);
    });

    test('resolveSyncConflict keepLocal pushes local when cloud has no data',
        () async {
      final local = GameProgress.initial().copyWith(
        currentLevel: 'lvl_seed_05',
        completedLevels: {'lvl_seed_01', 'lvl_seed_02', 'lvl_seed_03', 'lvl_seed_04'},
      );
      await repository.saveProgress(local);

      when(mockSnapshot.exists).thenReturn(false);
      when(mockSnapshot.data()).thenReturn(null);

      int writeAttempts = 0;
      when(mockSubDoc.set(any as dynamic)).thenAnswer((_) async {
        writeAttempts += 1;
      });

      await repository.resolveSyncConflict(SyncConflictResolution.keepLocal);

      expect(writeAttempts, 1);
      expect(await repository.getLastSyncTime(), isNotNull);
    });
  });
}
