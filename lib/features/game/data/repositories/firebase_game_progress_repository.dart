import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/config/environment_config.dart';
import '../../domain/entities/game_progress.dart';
import '../../domain/repositories/game_progress_repository.dart';

/// Firebase-backed game progress repository with offline-first architecture.
///
/// robust-sync strategy:
/// 1. Always save to local Hive box immediately.
/// 2. If online and auth'd, attempt to sync to Firestore.
/// 3. If offline, data remains "dirty" locally (tracked by timestamps).
/// 4. On startup or auth change, trigger syncFromCloud to pull/merge remote changes.
class FirebaseGameProgressRepository implements GameProgressRepository {
  final Box _localBox;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Document path
  static const String _progressDoc = 'progress';

  // Local storage keys
  static const String _progressKey = 'progress';
  static const String _cloudSyncEnabledKey = 'cloud_sync_enabled';
  static const String _lastSyncTimeKey =
      'last_sync_time'; // When we last successfully synced with cloud
  static const String _lastLocalUpdateKey =
      'last_local_update'; // When local data was last changed

  FirebaseGameProgressRepository(this._localBox, this._firestore, this._auth);

  /// Returns the Firestore collection name for the current environment.
  static String get _collectionName =>
      EnvironmentConfig.getFirestoreCollection();

  /// Gets the current user ID. Return null if not signed in.
  String? get _userId => _auth.currentUser?.uid;

  @override
  Future<GameProgress> getProgress() async {
    // Always return local data first (offline-first)
    final localData = _localBox.get(_progressKey);
    if (localData != null) {
      return GameProgress.fromJson(Map<String, dynamic>.from(localData));
    }
    return GameProgress.initial();
  }

  @override
  Future<void> saveProgress(GameProgress progress) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Save locally
    await _localBox.put(_progressKey, progress.toJson());
    await _localBox.put(_lastLocalUpdateKey, now);

    // 2. Try to sync to cloud if possible
    if (await isCloudSyncEnabled() && _userId != null) {
      // Fire and forget - if it fails, we'll catch it on next sync
      // We don't await this to keep UI responsive, but we could if we wanted validation
      syncToCloud().catchError((e) {
        debugPrint('Auto-sync failed: $e');
      });
    }
  }

  @override
  Future<void> resetProgress() async {
    final initialProgress = GameProgress.initial();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _localBox.put(_progressKey, initialProgress.toJson());
    await _localBox.put(_lastLocalUpdateKey, now);

    // Also reset cloud data if available
    if (await isCloudSyncEnabled() && _userId != null) {
      try {
        await _firestore
            .collection(_collectionName)
            .doc(_userId)
            .collection('data')
            .doc(_progressDoc)
            .delete();
      } catch (e) {
        debugPrint('Cloud reset failed: $e');
      }
    }
  }

  @override
  Future<void> syncToCloud() async {
    if (!await isCloudSyncEnabled()) return;

    final userId = _userId;
    if (userId == null) {
      debugPrint('Sync skipped: No user logged in');
      return;
    }

    final localProgress = await getProgress();
    final lastLocalUpdate = _localBox.get(_lastLocalUpdateKey) as int? ?? 0;

    // We get the LAST successful sync time
    final lastSyncTime = await getLastSyncTime();
    final lastSyncMillis = lastSyncTime?.millisecondsSinceEpoch ?? 0;

    // Only push if local changes are newer than last sync
    if (lastLocalUpdate <= lastSyncMillis && lastSyncMillis != 0) {
      debugPrint('Sync skipped: Local data is already synced');
      return;
    }

    final now = DateTime.now();

    try {
      // OPTIONAL: Read cloud first to check for conflict?
      // For now, to be "Robust", we should probably read it if we suspect conflict,
      // but simpler "Last Write Wins" or "Max Progress Wins" is often better for games.
      // Let's implement "Merge/Max Progress" strategy.

      final cloudDoc = await _firestore
          .collection(_collectionName)
          .doc(userId)
          .collection('data')
          .doc(_progressDoc)
          .get();

      bool shouldPush = true;

      if (cloudDoc.exists) {
        final cloudData = cloudDoc.data();
        if (cloudData != null) {
          final cloudProgress = GameProgress.fromJson(cloudData);

          // IF cloud has strictly MORE progress, maybe we should pull instead?
          // OR merge?
          // Current Strategy: If Local has equal or greater level, push.
          // If Cloud is ahead, we might have a conflict.

          if (cloudProgress.currentLevel > localProgress.currentLevel) {
            // Cloud is ahead! We should actually PULL this data to local, not overwrite it.
            // But we are in 'syncToCloud'.
            // Let's trigger a merge/pull logic.
            debugPrint(
                'Cloud is ahead (L${cloudProgress.currentLevel} vs L${localProgress.currentLevel}). handling conflict by merging.');
            shouldPush = false;
            await _mergeRemoteToLocal(cloudProgress);
          }
        }
      }

      if (shouldPush) {
        await _firestore
            .collection(_collectionName)
            .doc(userId)
            .collection('data')
            .doc(_progressDoc)
            .set({
          ...localProgress.toJson(),
          'lastUpdated': now.toIso8601String(),
          'syncTimestamp': now.millisecondsSinceEpoch,
        });

        // Update local sync timestamp
        await _localBox.put(_lastSyncTimeKey, now.millisecondsSinceEpoch);
        debugPrint('Sync to cloud successful');
      }
    } catch (e) {
      debugPrint('Sync to cloud failed: $e');
      // Rethrow? No, fail silently but log.
    }
  }

  /// Manually triggers a sync from cloud to local.
  /// Also called on auth change.
  @override
  Future<void> syncFromCloud() async {
    if (!await isCloudSyncEnabled()) return;

    final userId = _userId;
    if (userId == null) return;

    try {
      final cloudDoc = await _firestore
          .collection(_collectionName)
          .doc(userId)
          .collection('data')
          .doc(_progressDoc)
          .get();

      if (cloudDoc.exists) {
        final cloudData = cloudDoc.data();
        if (cloudData != null) {
          final cloudProgress = GameProgress.fromJson(cloudData);
          await _mergeRemoteToLocal(cloudProgress);
        }
      }
    } catch (e) {
      debugPrint('Sync from cloud failed: $e');
    }
  }

  /// Merges remote progress into local.
  /// Strategy:
  /// - Max Level wins.
  /// - Completed Levels are unioned.
  /// - Tutorial completed is OR'd.
  Future<void> _mergeRemoteToLocal(GameProgress cloudProgress) async {
    final localProgress = await getProgress();

    // Merge Logic
    final maxCurrentLevel =
        (cloudProgress.currentLevel > localProgress.currentLevel)
            ? cloudProgress.currentLevel
            : localProgress.currentLevel;

    final mergedCompletedLevels = Set<int>.from(localProgress.completedLevels)
      ..addAll(cloudProgress.completedLevels);

    final mergedTutorialCompleted =
        localProgress.tutorialCompleted || cloudProgress.tutorialCompleted;

    // Check if anything actually changed
    final isDifferent = maxCurrentLevel != localProgress.currentLevel ||
        mergedCompletedLevels.length != localProgress.completedLevels.length ||
        mergedTutorialCompleted != localProgress.tutorialCompleted;

    if (isDifferent) {
      debugPrint('Merging cloud data into local...');
      final newProgress = localProgress.copyWith(
        currentLevel: maxCurrentLevel,
        completedLevels: mergedCompletedLevels,
        tutorialCompleted: mergedTutorialCompleted,
        // We could merge lessons too if we had that logic exposed
      );

      // Save merged result locally
      await _localBox.put(_progressKey, newProgress.toJson());
      // Update update time
      await _localBox.put(
          _lastLocalUpdateKey, DateTime.now().millisecondsSinceEpoch);
      // We can consider this "Synced" since it includes cloud data,
      // BUT if we merged local data IN, we might want to push back to cloud?
      // Let's assume next save or auto-sync will handle pushing the merged state back.
    } else {
      // If data is identical, we can just update the sync timestamp
      final cloudTimestamp = DateTime.now()
          .millisecondsSinceEpoch; // Or specific timestamp from cloud if we had it
      await _localBox.put(_lastSyncTimeKey, cloudTimestamp);
    }
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    final timestamp = _localBox.get(_lastSyncTimeKey);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  @override
  Future<bool> isCloudSyncAvailable() async {
    return _userId != null;
  }

  @override
  Future<void> setCloudSyncEnabled(bool enabled) async {
    await _localBox.put(_cloudSyncEnabledKey, enabled);

    // If enabling sync, try to sync immediately
    if (enabled && await isCloudSyncAvailable()) {
      // Try to pull first to avoid overwriting remote with stale local
      await syncFromCloud();
      await syncToCloud();
    }
  }

  @override
  Future<bool> isCloudSyncEnabled() async {
    return _localBox.get(_cloudSyncEnabledKey, defaultValue: false);
  }
}
