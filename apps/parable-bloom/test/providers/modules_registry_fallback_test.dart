// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:parable_bloom/core/providers/infrastructure_providers.dart';
import 'package:parable_bloom/features/game/application/providers/module_providers.dart';

/// Firestore mock simulating an anonymous client hitting the auth-gated
/// `configs_prod` rules (`allow read: if request.auth != null`).
class _DeniedFirestore extends Mock implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String? collectionPath) {
    return _DeniedCollection();
  }
}

class _DeniedCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _DeniedDoc();
  }
}

class _DeniedDoc extends Mock implements DocumentReference<Map<String, dynamic>> {
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    return Future.error(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      ),
    );
  }
}

/// Firestore mock returning a modules registry document (authed OTA path).
class _SuccessFirestore extends Mock implements FirebaseFirestore {
  final Map<String, dynamic> data;
  _SuccessFirestore(this.data);

  @override
  CollectionReference<Map<String, dynamic>> collection(String? collectionPath) {
    return _SuccessCollection(data);
  }
}

class _SuccessCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {
  final Map<String, dynamic> data;
  _SuccessCollection(this.data);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _SuccessDoc(data);
  }
}

class _SuccessDoc extends Mock implements DocumentReference<Map<String, dynamic>> {
  final Map<String, dynamic> data;
  _SuccessDoc(this.data);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    return Future.value(_SuccessSnapshot(data));
  }
}

class _SuccessSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic> _data;
  _SuccessSnapshot(this._data);

  @override
  bool get exists => true;

  @override
  Map<String, dynamic>? data() => _data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('modulesRegistryProvider resilience (configs_* auth gate)', () {
    test('permission-denied falls back to bundled assets', () async {
      final container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(_DeniedFirestore())],
      );
      addTearDown(container.dispose);

      final registry = await container.read(modulesRegistryProvider.future);

      // Bundled assets/data/modules.json: 24 modules + level mappings.
      expect(registry['modules'], isList);
      expect((registry['modules'] as List), hasLength(24));
      expect(registry['level_mappings'], isMap);
    });

    test('permission-denied prefers Hive cache over bundled assets', () async {
      final cached = {
        'version': '4.0',
        'modules': [
          {'id': 'cached-module'},
        ],
        'level_mappings': <String, dynamic>{},
      };
      final container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(_DeniedFirestore())],
      );
      addTearDown(container.dispose);

      await container.read(hiveBoxProvider).put(
            'cached_modules_registry',
            json.encode(cached),
          );

      final registry = await container.read(modulesRegistryProvider.future);
      expect(registry['modules'], [
        {'id': 'cached-module'},
      ]);
    });

    test('stale-version Hive cache is discarded in favor of bundled assets',
        () async {
      final cached = {
        'version': '3.0',
        'modules': [
          {'id': 'stale-module'},
        ],
        'level_mappings': <String, dynamic>{},
      };
      final container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(_DeniedFirestore())],
      );
      addTearDown(container.dispose);

      final box = await container.read(hiveBoxProvider);
      await box.put(
        'cached_modules_registry',
        json.encode(cached),
      );

      final registry = await container.read(modulesRegistryProvider.future);
      // Bundled assets/data/modules.json: 24 modules + level mappings.
      expect((registry['modules'] as List), hasLength(24));
      expect(box.get('cached_modules_registry'), isNull);
    });

    test('Firestore success stays primary and refreshes the cache', () async {
      final ota = {
        'modules': [
          {'id': 'ota-module'},
        ],
        'level_mappings': <String, dynamic>{'level_1': 'levels/level_1.json'},
      };
      final container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(_SuccessFirestore(ota))],
      );
      addTearDown(container.dispose);

      final registry = await container.read(modulesRegistryProvider.future);
      expect(registry['modules'], [
        {'id': 'ota-module'},
      ]);

      final cachedStr =
          container.read(hiveBoxProvider).get('cached_modules_registry') as String?;
      expect(cachedStr, isNotNull);
      expect((json.decode(cachedStr!) as Map)['modules'], [
        {'id': 'ota-module'},
      ]);
    });
  });
}
