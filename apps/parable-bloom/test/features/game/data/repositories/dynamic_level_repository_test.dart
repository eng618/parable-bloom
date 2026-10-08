// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import 'package:parable_bloom/features/game/data/repositories/dynamic_level_repository.dart';

// Mocktail mocks — no manual noSuchMethod needed, no codegen.
class MockBox extends Mock implements Box {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

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

    when(() => mockFirestore.collection('levels_dev'))
        .thenReturn(mockCollection);
    when(() => mockCollection.doc('lvl_test')).thenReturn(mockDoc);
    when(() => mockDoc.get()).thenAnswer((_) async => mockSnapshot);
  });

  group('DynamicLevelRepository Baseline & Memory Cache Tests', () {
    test('loads dynamic levels from Firestore and caches in Hive', () async {
      final repository = DynamicLevelRepository(
        firestore: mockFirestore,
        localMappings: {},
        cacheBox: mockCacheBox,
      );

      when(() => mockCacheBox.containsKey('cached_level_lvl_test'))
          .thenReturn(false);
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.data()).thenReturn(testLevelJson);
      when(() => mockCacheBox.put(any(), any())).thenAnswer((_) async {});

      final level = await repository.getLevel('lvl_test');

      expect(level.id, 'lvl_test');
      expect(level.name, 'Test Level');

      // Verifies it hit Firestore and stored in Hive
      verify(() => mockFirestore.collection('levels_dev')).called(1);
      verify(() => mockDoc.get()).called(1);
      verify(() => mockCacheBox.put(
          'cached_level_lvl_test', json.encode(testLevelJson))).called(1);
    });

    test('loads dynamic levels from Hive cache on cache hit', () async {
      final repository = DynamicLevelRepository(
        firestore: mockFirestore,
        localMappings: {},
        cacheBox: mockCacheBox,
      );

      when(() => mockCacheBox.containsKey('cached_level_lvl_test'))
          .thenReturn(true);
      when(() => mockCacheBox.get('cached_level_lvl_test'))
          .thenReturn(json.encode(testLevelJson));

      final level = await repository.getLevel('lvl_test');

      expect(level.id, 'lvl_test');
      verify(() => mockCacheBox.get('cached_level_lvl_test')).called(1);
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
      when(() => mockCacheBox.containsKey('cached_level_lvl_test'))
          .thenReturn(false);
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.data()).thenReturn(testLevelJson);
      when(() => mockCacheBox.put(any(), any())).thenAnswer((_) async {});

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
