import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/game/data/repositories/firebase_game_progress_repository.dart';
import '../features/game/data/repositories/hive_game_progress_repository.dart';
import '../features/game/domain/repositories/game_progress_repository.dart';
import '../features/settings/data/repositories/hive_settings_repository.dart';
import '../features/settings/domain/repositories/settings_repository.dart';
import '../services/logger_service.dart';

const bool _isScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

final hiveBoxProvider = Provider<Box>((ref) {
  try {
    if (Hive.isBoxOpen('garden_save')) {
      return Hive.box('garden_save');
    }
  } catch (e) {
    // If Hive is unavailable outside app initialization, fall back to memory.
  }

  LoggerService.debug(
    'hiveBoxProvider: No Hive box open; using in-memory fallback for tests',
  );
  return _InMemoryBox();
});

class _InMemoryBox implements Box<dynamic> {
  final Map _store = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _store.containsKey(key) ? _store[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => _store[key] = value;

  @override
  Future<void> delete(dynamic key) async => _store.remove(key);

  @override
  Future<int> clear() async {
    final len = _store.length;
    _store.clear();
    return len;
  }

  @override
  bool containsKey(dynamic key) => _store.containsKey(key);

  @override
  Iterable get keys => _store.keys;

  @override
  Iterable get values => _store.values;

  @override
  Map toMap() => Map.from(_store);

  @override
  int get length => _store.length;

  @override
  String get name => 'in_memory_box';

  @override
  bool get isOpen => true;

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final localGameProgressRepositoryProvider = Provider<GameProgressRepository>((
  ref,
) {
  final box = ref.watch(hiveBoxProvider);
  return HiveGameProgressRepository(box);
});

final cloudGameProgressRepositoryProvider = Provider<GameProgressRepository>((
  ref,
) {
  final box = ref.watch(hiveBoxProvider);
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return FirebaseGameProgressRepository(box, firestore, auth);
});

final gameProgressRepositoryProvider = Provider<GameProgressRepository>((ref) {
  if (_isScreenshotMode) {
    return ref.watch(localGameProgressRepositoryProvider);
  }
  return ref.watch(cloudGameProgressRepositoryProvider);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final box = ref.watch(hiveBoxProvider);
  return HiveSettingsRepository(box);
});
