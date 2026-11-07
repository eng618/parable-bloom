import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/infrastructure_providers.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/repositories/dynamic_level_repository.dart';
import '../../domain/entities/level_data.dart';
import '../../domain/repositories/level_repository.dart';

import '../../../../core/config/environment_config.dart';

const bool _isScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

class ModuleLoadException implements Exception {
  final String message;

  const ModuleLoadException(this.message);

  @override
  String toString() => 'ModuleLoadException: $message';
}

/// Expected modules registry schema version (assets/data/modules.json).
/// Bumped on breaking changes (e.g. the 4.0 unified level-ID migration) so
/// stale Hive caches from older installs are discarded instead of served.
const String kModulesRegistryVersion = '4.0';

/// Provides the raw modules registry JSON map.
/// Tries Firestore (configs_{env}/modules), falling back to Hive cache, and finally bundled assets.
final modulesRegistryProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final box = ref.watch(hiveBoxProvider);
  final configsCollection = EnvironmentConfig.getConfigsCollection();

  // 1. Try Firestore. Screenshot captures run with Firebase disabled, so
  // skip the client entirely and load the bundled registry. Read inside
  // the try so a missing Firebase app falls through to cache/assets
  // instead of failing the provider before the fallback.
  if (!_isScreenshotMode) {
    try {
      final firestore = ref.read(firestoreProvider);
      final doc = await firestore
          .collection(configsCollection)
          .doc('modules')
          .get()
          .timeout(const Duration(seconds: 2));
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        // Same gate as the Hive cache. A fast network used to prefer a
        // pre-migration remote doc (old lesson triggers) over bundled
        // assets, so tutorial completion unlocked nothing in the journal.
        if (data['version']?.toString() == kModulesRegistryVersion) {
          final jsonStr = json.encode(data);
          await box.put('cached_modules_registry', jsonStr);
          LoggerService.info(
            'Successfully fetched and cached modules registry from Firestore ($configsCollection/modules)',
            tag: 'modulesRegistryProvider',
          );
          return data;
        }
        LoggerService.info(
          'Ignoring remote modules registry version ${data['version']} (expected $kModulesRegistryVersion)',
          tag: 'modulesRegistryProvider',
        );
      }
    } catch (e) {
      LoggerService.warn(
        'Failed to fetch modules registry from Firestore: $e. Falling back to cache/assets.',
        tag: 'modulesRegistryProvider',
      );
    }
  }

  // 2. Fallback to Hive cache
  try {
    final cachedStr = box.get('cached_modules_registry') as String?;
    if (cachedStr != null && cachedStr.isNotEmpty) {
      final data = json.decode(cachedStr) as Map<String, dynamic>;
      if (data['version']?.toString() != kModulesRegistryVersion) {
        // Pre-migration cache (old level-ID scheme): drop it and fall
        // through to bundled assets rather than serving stale IDs.
        LoggerService.info(
          'Discarding stale modules registry cache (version ${data['version']}, expected $kModulesRegistryVersion)',
          tag: 'modulesRegistryProvider',
        );
        await box.delete('cached_modules_registry');
      } else {
        LoggerService.info(
          'Loaded modules registry from local Hive cache',
          tag: 'modulesRegistryProvider',
        );
        return data;
      }
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
    final data = await _loadBundledModulesRegistry();
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
    final fromRegistry = _parseLevelMappings(registry['level_mappings']);
    final bundled = _parseLevelMappings(
      (await _loadBundledModulesRegistry())['level_mappings'],
    );
    if (fromRegistry.isEmpty) {
      if (bundled.isNotEmpty) {
        LoggerService.warn(
          'Registry level_mappings missing or empty; using ${bundled.length} bundled mappings',
          tag: 'levelMappingsProvider',
        );
      }
      return bundled;
    }

    // Registry paths win per key. Bundled keys stay when the registry omits
    // them, so a partial or empty OTA/cache document cannot hide shipped levels.
    final merged = {...bundled, ...fromRegistry};
    final filled = bundled.keys.where((key) => !fromRegistry.containsKey(key));
    if (filled.isNotEmpty) {
      LoggerService.info(
        'Added ${filled.length} bundled level mappings missing from the registry',
        tag: 'levelMappingsProvider',
      );
    }
    return merged;
  } catch (e, stack) {
    LoggerService.error('Error parsing level mappings from modules registry',
        error: e, stackTrace: stack, tag: 'levelMappingsProvider');
    try {
      return _parseLevelMappings(
        (await _loadBundledModulesRegistry())['level_mappings'],
      );
    } catch (fallbackError, fallbackStack) {
      LoggerService.error(
        'Bundled level mappings unavailable',
        error: fallbackError,
        stackTrace: fallbackStack,
        tag: 'levelMappingsProvider',
      );
      return {};
    }
  }
});

/// String-to-string entries only. Non-string values are skipped so one bad
/// entry cannot blank the table.
Map<String, String> _parseLevelMappings(dynamic raw) {
  if (raw is! Map) return {};
  final mappings = <String, String>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String || value is! String) continue;
    if (key.isEmpty || value.isEmpty) continue;
    mappings[key] = value;
  }
  return mappings;
}

Future<Map<String, dynamic>> _loadBundledModulesRegistry() async {
  final jsonString = await rootBundle.loadString('assets/data/modules.json');
  return json.decode(jsonString) as Map<String, dynamic>;
}

/// Exposes the canonical [LevelRepository] instance.
///
/// Async so bundled/OTA level mappings are always resolved before the first
/// fetch. (A previous sync snapshot could serve an empty mapping table on
/// cold start, sending every level to Firestore despite bundled assets.)
final levelRepositoryProvider = FutureProvider<LevelRepository>((ref) async {
  final mappings = await ref.watch(levelMappingsProvider.future);
  final box = ref.watch(hiveBoxProvider);
  // Screenshot mode has no Firebase app. Levels resolve from bundled assets.
  final firestore = _isScreenshotMode ? null : ref.watch(firestoreProvider);
  return DynamicLevelRepository(
    firestore: firestore,
    localMappings: mappings,
    cacheBox: box,
  );
});

/// Asynchronously provides [LevelData] for a specific logical level ID.
final levelDataProvider =
    FutureProvider.family<LevelData, String>((ref, levelId) async {
  final repo = await ref.watch(levelRepositoryProvider.future);
  return repo.getLevel(levelId);
});
