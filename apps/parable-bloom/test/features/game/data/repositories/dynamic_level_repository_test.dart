import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';

import 'package:parable_bloom/features/game/data/repositories/dynamic_level_repository.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';

// Generate Mocks for Hive Box and Firestore
class MockBox extends Mock implements Box {
  @override
  bool containsKey(dynamic key) =>
      super.noSuchMethod(Invocation.method(#containsKey, [key]),
          returnValue: false) as bool;

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      super.noSuchMethod(Invocation.method(#get, [key]), returnValue: null);

  @override
  Future<void> put(dynamic key, dynamic value) =>
      super.noSuchMethod(Invocation.method(#put, [key, value]),
          returnValue: Future<void>.value()) as Future<void>;
}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
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
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    return super.noSuchMethod(
      Invocation.method(#get, [options]),
      returnValue: Future.value(MockDocumentSnapshot()),
    ) as Future<DocumentSnapshot<Map<String, dynamic>>>;
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
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockBox mockCacheBox;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDoc;
  late MockDocumentSnapshot mockSnapshot;

  final testLevelJson = {
    'id': 'lvl_test',
    'name': 'Test Level',
    'difficulty': 'easy',
    'grid_size': [3, 3],
    'vines': [
      {
        'id': 'v1',
        'head_direction': 'right',
        'ordered_path': [
          {'x': 0, 'y': 0},
          {'x': 1, 'y': 0}
        ]
      }
    ],
    'max_moves': 10,
    'min_moves': 5,
    'complexity': 'simple',
    'grace': 0,
    'mask': {'mode': 'show-all', 'points': []}
  };

  setUp(() {
    mockCacheBox = MockBox();
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDoc = MockDocumentReference();
    mockSnapshot = MockDocumentSnapshot();

    when(mockFirestore.collection('levels_dev')).thenReturn(mockCollection);
    when(mockCollection.doc('lvl_test')).thenReturn(mockDoc);
    when(mockDoc.get()).thenAnswer((_) async => mockSnapshot);
  });

  group('DynamicLevelRepository Baseline & Memory Cache Tests', () {
    test('loads dynamic levels from Firestore and caches in Hive', () async {
      final repository = DynamicLevelRepository(
        firestore: mockFirestore,
        localMappings: {},
        cacheBox: mockCacheBox,
      );

      when(mockCacheBox.containsKey('cached_level_lvl_test')).thenReturn(false);
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.data()).thenReturn(testLevelJson);
      when(mockCacheBox.put(any, any)).thenAnswer((_) async {});

      final level = await repository.getLevel('lvl_test');

      expect(level.id, 'lvl_test');
      expect(level.name, 'Test Level');

      // Verifies it hit Firestore and stored in Hive
      verify(mockFirestore.collection('levels_dev')).called(1);
      verify(mockDoc.get()).called(1);
      verify(mockCacheBox.put(
              'cached_level_lvl_test', json.encode(testLevelJson)))
          .called(1);
    });

    test('loads dynamic levels from Hive cache on cache hit', () async {
      final repository = DynamicLevelRepository(
        firestore: mockFirestore,
        localMappings: {},
        cacheBox: mockCacheBox,
      );

      when(mockCacheBox.containsKey('cached_level_lvl_test')).thenReturn(true);
      when(mockCacheBox.get('cached_level_lvl_test'))
          .thenReturn(json.encode(testLevelJson));

      final level = await repository.getLevel('lvl_test');

      expect(level.id, 'lvl_test');
      verify(mockCacheBox.get('cached_level_lvl_test')).called(1);
      verifyZeroInteractions(mockFirestore);
    });

    test(
        'subsequent loads should hit memory cache without Firestore or Hive calls',
        () async {
      final repository = DynamicLevelRepository(
        firestore: mockFirestore,
        localMappings: {},
        cacheBox: mockCacheBox,
      );

      // First fetch: Cache miss in memory, cache miss in Hive, fetch from Firestore
      when(mockCacheBox.containsKey('cached_level_lvl_test')).thenReturn(false);
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.data()).thenReturn(testLevelJson);
      when(mockCacheBox.put(any, any)).thenAnswer((_) async {});

      final level1 = await repository.getLevel('lvl_test');
      expect(level1.id, 'lvl_test');

      // Second fetch: Should be served from memory cache immediately!
      // Therefore, mockFirestore and mockCacheBox should not be queried/updated again.
      clearInteractions(mockFirestore);
      clearInteractions(mockCacheBox);

      final level2 = await repository.getLevel('lvl_test');
      expect(level2.id, 'lvl_test');

      // In the baseline (before memory caching), this will FAIL because mockCacheBox/mockFirestore will be called.
      // After our optimization, this will PASS because zero interactions occur on subsequent calls.
      verifyZeroInteractions(mockFirestore);
      verifyZeroInteractions(mockCacheBox);
    });
  });
}
