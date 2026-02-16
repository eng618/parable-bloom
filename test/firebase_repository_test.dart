import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/mockito.dart';

import 'package:parable_bloom/features/game/data/repositories/firebase_game_progress_repository.dart';
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
  bool get exists => super.noSuchMethod(Invocation.getter(#exists), returnValue: false) as bool;
  
  @override
  Map<String, dynamic>? data() => super.noSuchMethod(Invocation.method(#data, []), returnValue: null) as Map<String, dynamic>?;
}

void main() {
  late Box box;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late FirebaseGameProgressRepository repository;
  late Directory tempDir;

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
    final mockSubDoc = MockDocumentReference();
    final mockSnapshot = MockDocumentSnapshot();

    // Stub chain: firestore -> collection -> doc -> collection -> doc
    // Using explicit values to satisfy sound null safety for non-nullable parameters
    when(mockFirestore.collection('game_progress_dev')).thenReturn(mockCollection);
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

      expect(progress.currentLevel, equals(1));
      expect(progress.completedLevels, isEmpty);
    });

    test('should save and retrieve progress correctly', () async {
      final originalProgress = GameProgress.initial().copyWith(
        currentLevel: 3,
        completedLevels: {1, 2},
        tutorialCompleted: false,
      );

      await repository.saveProgress(originalProgress);
      final retrievedProgress = await repository.getProgress();

      expect(retrievedProgress.currentLevel, equals(3));
      expect(retrievedProgress.completedLevels, equals({1, 2}));
    });

    test('should reset progress correctly', () async {
      final progress = GameProgress.initial().copyWith(
        currentLevel: 5,
        completedLevels: {1, 2, 3, 4},
        tutorialCompleted: false,
      );

      await repository.saveProgress(progress);
      await repository.resetProgress();

      final resetProgress = await repository.getProgress();
      expect(resetProgress.currentLevel, equals(1));
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

    test('should detect cloud sync availability', () async {
      // With mocked signed-in user, should be available
      final available = await repository.isCloudSyncAvailable();
      expect(available, isTrue);
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
        currentLevel: 2,
        completedLevels: {1},
        tutorialCompleted: false,
      );

      await repository.saveProgress(progress);

      // Sync should not throw (even if Firestore is mocked)
      await expectLater(repository.syncToCloud(), completes);
    });
  });
}
