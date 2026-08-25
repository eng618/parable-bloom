import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../../../core/config/environment_config.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/entities/level_data.dart';
import '../../domain/repositories/level_repository.dart';

/// Resilient, offline-first implementation of [LevelRepository].
/// Combines local assets, local Hive database cache, and Cloud Firestore.
class DynamicLevelRepository implements LevelRepository {
  final FirebaseFirestore _firestore;
  final Map<String, String> _localMappings;
  final Box _cacheBox;

  DynamicLevelRepository({
    required FirebaseFirestore firestore,
    required Map<String, String> localMappings,
    required Box cacheBox,
  })  : _firestore = firestore,
        _localMappings = localMappings,
        _cacheBox = cacheBox;

  @override
  Future<LevelData> getLevel(String levelId) async {
    LoggerService.info(
      'Retrieving level data for $levelId',
      tag: 'DynamicLevelRepository',
    );

    // 1. Check local assets mappings first
    if (_localMappings.containsKey(levelId)) {
      final file = _localMappings[levelId]!;
      final assetPath = 'assets/$file';
      LoggerService.debug(
        'Level found in local mappings. Loading asset: $assetPath',
        tag: 'DynamicLevelRepository',
      );
      try {
        final levelJson = await rootBundle.loadString(assetPath);
        final jsonMap = json.decode(levelJson) as Map<String, dynamic>;
        return LevelData.fromJson(jsonMap, idOverride: levelId);
      } catch (e, stack) {
        LoggerService.error(
          'Failed to load local level asset $assetPath',
          error: e,
          stackTrace: stack,
          tag: 'DynamicLevelRepository',
        );
        throw Exception('Failed to load local level data for $levelId');
      }
    }

    // 2. Check local Hive cache for previously fetched dynamic levels
    final cacheKey = 'cached_level_$levelId';
    if (_cacheBox.containsKey(cacheKey)) {
      LoggerService.debug(
        'Level found in local cache. Key: $cacheKey',
        tag: 'DynamicLevelRepository',
      );
      try {
        final cachedJsonStr = _cacheBox.get(cacheKey) as String;
        final jsonMap = json.decode(cachedJsonStr) as Map<String, dynamic>;
        return LevelData.fromJson(jsonMap, idOverride: levelId);
      } catch (e, stack) {
        LoggerService.error(
          'Failed to load cached level from Hive box for key $cacheKey',
          error: e,
          stackTrace: stack,
          tag: 'DynamicLevelRepository',
        );
        // Fall through to Firestore fetch if cache load fails
      }
    }

    // 3. Fetch from Cloud Firestore on cache miss
    final collection = EnvironmentConfig.getLevelsCollection();
    LoggerService.info(
      'Cache miss. Fetching $levelId from Firestore collection: $collection',
      tag: 'DynamicLevelRepository',
    );

    try {
      final doc = await _firestore.collection(collection).doc(levelId).get();
      if (!doc.exists) {
        LoggerService.error(
          'Level $levelId not found in Firestore collection $collection',
          tag: 'DynamicLevelRepository',
        );
        throw Exception('Level data not found in cloud storage: $levelId');
      }

      final data = doc.data();
      if (data == null) {
        throw Exception('Empty document data for level: $levelId');
      }

      // Convert double or numeric values in coordinates to integer if needed,
      // Firestore sometimes deserializes them differently than standard JSON.
      // But standard Map parsing inside LevelData.fromJson handles most fields.
      final levelData = LevelData.fromJson(data, idOverride: levelId);

      // Save to local Hive cache box for future offline use
      final jsonStr = json.encode(data);
      await _cacheBox.put(cacheKey, jsonStr);
      LoggerService.debug(
        'Successfully cached dynamic level $levelId to Hive cache',
        tag: 'DynamicLevelRepository',
      );

      return levelData;
    } catch (e, stack) {
      LoggerService.error(
        'Failed to fetch dynamic level $levelId from Firestore or write to cache',
        error: e,
        stackTrace: stack,
        tag: 'DynamicLevelRepository',
      );
      throw Exception('Failed to load dynamic level data for $levelId: $e');
    }
  }
}
