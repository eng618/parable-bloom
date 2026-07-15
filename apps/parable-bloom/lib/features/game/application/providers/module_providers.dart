import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/infrastructure_providers.dart';
import '../../../../services/logger_service.dart';
import '../../data/repositories/dynamic_level_repository.dart';
import '../../domain/entities/level_data.dart';
import '../../domain/repositories/level_repository.dart';

import '../../../../core/config/environment_config.dart';

class ModuleLoadException implements Exception {
  final String message;

  const ModuleLoadException(this.message);

  @override
  String toString() => 'ModuleLoadException: $message';
}

/// Provides the raw modules registry JSON map.
/// Tries Firestore (configs_{env}/modules), falling back to Hive cache, and finally bundled assets.
final modulesRegistryProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final box = ref.watch(hiveBoxProvider);
  final configsCollection = EnvironmentConfig.getConfigsCollection();

  // 1. Try Firestore
  try {
    final doc = await firestore
        .collection(configsCollection)
        .doc('modules')
        .get()
        .timeout(const Duration(seconds: 2));
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final jsonStr = json.encode(data);
      await box.put('cached_modules_registry', jsonStr);
      LoggerService.info(
        'Successfully fetched and cached modules registry from Firestore ($configsCollection/modules)',
        tag: 'modulesRegistryProvider',
      );
      return data;
    }
  } catch (e) {
    LoggerService.warn(
      'Failed to fetch modules registry from Firestore: $e. Falling back to cache/assets.',
      tag: 'modulesRegistryProvider',
    );
  }

  // 2. Fallback to Hive cache
  try {
    final cachedStr = box.get('cached_modules_registry') as String?;
    if (cachedStr != null && cachedStr.isNotEmpty) {
      final data = json.decode(cachedStr) as Map<String, dynamic>;
      LoggerService.info(
        'Loaded modules registry from local Hive cache',
        tag: 'modulesRegistryProvider',
      );
      return data;
    }
  } catch (e) {
    LoggerService.error(
      'Failed to parse cached modules registry',
      error: e,
      tag: 'modulesRegistryProvider',
    );
  }

  // 3. Fallback to bundled assets
  try {
    final jsonString = await rootBundle.loadString('assets/data/modules.json');
    final data = json.decode(jsonString) as Map<String, dynamic>;
    LoggerService.info(
      'Loaded modules registry from bundled assets/data/modules.json',
      tag: 'modulesRegistryProvider',
    );
    return data;
  } catch (e, stack) {
    LoggerService.error(
      'Failed to load bundled modules.json from assets',
      error: e,
      stackTrace: stack,
      tag: 'modulesRegistryProvider',
    );
    rethrow;
  }
});

final modulesProvider = FutureProvider<List<ModuleData>>((ref) async {
  try {
    final registry = await ref.watch(modulesRegistryProvider.future);
    final modulesList = registry['modules'] as List<dynamic>;

    return modulesList
        .map((moduleJson) =>
            ModuleData.fromJson(moduleJson as Map<String, dynamic>))
        .toList();
  } catch (e, stack) {
    LoggerService.error('Error parsing modules registry list',
        error: e, stackTrace: stack, tag: 'modulesProvider');
    throw const ModuleLoadException('Failed to load module metadata.');
  }
});

final levelMappingsProvider = FutureProvider<Map<String, String>>((ref) async {
  try {
    final registry = await ref.watch(modulesRegistryProvider.future);
    final mappings = Map<String, String>.from(registry['level_mappings'] ?? {});
    return mappings;
  } catch (e, stack) {
    LoggerService.error('Error parsing level mappings from modules registry',
        error: e, stackTrace: stack, tag: 'levelMappingsProvider');
    return {};
  }
});

/// Exposes the canonical [LevelRepository] instance.
final levelRepositoryProvider = Provider<LevelRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final mappings = ref.watch(levelMappingsProvider).value ?? {};
  final box = ref.watch(hiveBoxProvider);
  return DynamicLevelRepository(
    firestore: firestore,
    localMappings: mappings,
    cacheBox: box,
  );
});

/// Asynchronously provides [LevelData] for a specific logical level ID.
final levelDataProvider =
    FutureProvider.family<LevelData, String>((ref, levelId) async {
  final repo = ref.watch(levelRepositoryProvider);
  return repo.getLevel(levelId);
});
