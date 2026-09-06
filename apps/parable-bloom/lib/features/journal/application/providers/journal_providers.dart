import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/environment_config.dart';
import '../../../../core/providers/infrastructure_providers.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/entities/journal_theme.dart';

/// Expected biblical-themes schema version (assets/data/biblical_themes.json).
/// Bumped on breaking changes (e.g. the 2.0 unified trigger migration) so
/// stale Hive caches from older installs are discarded instead of served.
const String kBiblicalThemesVersion = '2.0';

final biblicalThemesRegistryProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final box = ref.watch(hiveBoxProvider);
  final configsCollection = EnvironmentConfig.getConfigsCollection();

  // 1. Try Firestore
  try {
    final firestore = ref.read(firestoreProvider);
    final doc = await firestore
        .collection(configsCollection)
        .doc('biblical_themes')
        .get()
        .timeout(const Duration(seconds: 2));
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final jsonStr = json.encode(data);
      await box.put('cached_biblical_themes_registry', jsonStr);
      LoggerService.info(
        'Fetched and cached biblical themes from Firestore ($configsCollection/biblical_themes)',
        tag: 'biblicalThemesRegistryProvider',
      );
      return data;
    }
  } catch (e) {
    LoggerService.warn(
      'Failed to fetch biblical themes from Firestore: $e. Falling back to cache/assets.',
      tag: 'biblicalThemesRegistryProvider',
    );
  }

  // 2. Fallback to Hive cache
  try {
    final cachedStr = box.get('cached_biblical_themes_registry') as String?;
    if (cachedStr != null && cachedStr.isNotEmpty) {
      final data = json.decode(cachedStr) as Map<String, dynamic>;
      if (data['version']?.toString() != kBiblicalThemesVersion) {
        // Pre-migration cache (old trigger IDs): drop it and fall through
        // to bundled assets rather than serving stale triggers.
        LoggerService.info(
          'Discarding stale biblical themes cache (version ${data['version']}, expected $kBiblicalThemesVersion)',
          tag: 'biblicalThemesRegistryProvider',
        );
        await box.delete('cached_biblical_themes_registry');
      } else {
        LoggerService.info(
          'Loaded biblical themes registry from local Hive cache',
          tag: 'biblicalThemesRegistryProvider',
        );
        return data;
      }
    }
  } catch (e) {
    LoggerService.error(
      'Failed to parse cached biblical themes registry',
      error: e,
      tag: 'biblicalThemesRegistryProvider',
    );
  }

  // 3. Fallback to bundled assets
  try {
    final jsonString =
        await rootBundle.loadString('assets/data/biblical_themes.json');
    final data = json.decode(jsonString) as Map<String, dynamic>;
    LoggerService.info(
      'Loaded biblical themes registry from bundled assets/data/biblical_themes.json',
      tag: 'biblicalThemesRegistryProvider',
    );
    return data;
  } catch (e) {
    try {
      final file = File('assets/data/biblical_themes.json');
      if (file.existsSync()) {
        final data =
            json.decode(file.readAsStringSync()) as Map<String, dynamic>;
        return data;
      }
    } catch (_) {}

    LoggerService.warn(
      'Could not load biblical_themes.json: $e',
      tag: 'biblicalThemesRegistryProvider',
    );
    return {'themes': []};
  }
});

final journalThemesProvider = FutureProvider<List<JournalTheme>>((ref) async {
  try {
    final registry = await ref.watch(biblicalThemesRegistryProvider.future);
    final themesList = registry['themes'] as List<dynamic>? ?? [];
    return themesList
        .map((t) => JournalTheme.fromJson(t as Map<String, dynamic>))
        .toList();
  } catch (e, stack) {
    LoggerService.error(
      'Error parsing journal themes',
      error: e,
      stackTrace: stack,
      tag: 'journalThemesProvider',
    );
    return [];
  }
});
