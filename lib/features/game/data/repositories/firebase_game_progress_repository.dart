import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/config/environment_config.dart';
import '../../domain/entities/game_progress.dart';
import '../../domain/repositories/game_progress_repository.dart';

/// Firebase-backed game progress repository with offline-first architecture.
/// Uses anonymous authentication and local Hive storage as primary data source.
/// Syncs to Firestore when available and enabled.
class FirebaseGameProgressRepository implements GameProgressRepository {
  final Box _localBox;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Document path
  static const String _progressDoc = 'progress';

  // Local storage keys
  static const String _progressKey = 'progress';
  static const String _cloudSyncEnabledKey = 'cloud_sync_enabled';
  static const String _lastSyncTimeKey = 'last_sync_time';
  static const String _userIdKey = 'firebase_user_id';

  FirebaseGameProgressRepository(this._localBox, this._firestore, this._auth);

  /// Returns the Firestore collection name for the current environment.
  static String get _collectionName =>
      EnvironmentConfig.getFirestoreCollection();

  /// Gets the current user ID for Firestore document path.
  /// Uses anonymous auth - creates user if none exists.
  Future<String?> _getUserId() async {
    // Check if we have a cached user ID
    final cachedUserId = _localBox.get(_userIdKey);
    if (cachedUserId != null) {
      return cachedUserId;
    }

    // Try to get current user
    User? user = _auth.currentUser;

    // If no current user, try anonymous sign in
    if (user == null) {
      try {
        final credential = await _auth.signInAnonymously();
        user = credential.user;
      } catch (e) {
        // Anonymous auth failed - return null for offline-only mode
        return null;
      }
    }

    if (user != null) {
      // Cache the user ID locally
      await _localBox.put(_userIdKey, user.uid);
      return user.uid;
    }

    return null;
  }

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
    // Save locally first
    await _localBox.put(_progressKey, progress.toJson());

    // Trigger background sync if enabled
    if (await isCloudSyncEnabled() && await isCloudSyncAvailable()) {
      try {
        await syncToCloud();
      } catch (e) {
        // Sync failed - that's okay, data is safe locally
        // Could log this for debugging
      }
    }
  }

  @override
  Future<void> resetProgress() async {
    final initialProgress = GameProgress.initial();
    await _localBox.put(_progressKey, initialProgress.toJson());

    // Also reset cloud data if available
    if (await isCloudSyncEnabled() && await isCloudSyncAvailable()) {
      try {
        final userId = await _getUserId();
        if (userId != null) {
          await _firestore
              .collection(_collectionName)
              .doc(userId)
              .collection('data')
              .doc(_progressDoc)
              .delete();
        }
      } catch (e) {
        // Cloud reset failed - local reset succeeded, which is what matters
      }
    }
  }

  @override
  Future<void> syncToCloud() async {
    if (!await isCloudSyncEnabled()) return;

    final userId = await _getUserId();
    if (userId == null) return;

    final localProgress = await getProgress();
    final now = DateTime.now();

    try {
      // Get existing cloud data for conflict resolution
      final cloudDoc = await _firestore
          .collection(_collectionName)
          .doc(userId)
          .collection('data')
          .doc(_progressDoc)
          .get();

      GameProgress? cloudProgress;
      if (cloudDoc.exists) {
        final cloudData = cloudDoc.data();
        if (cloudData != null) {
          cloudProgress = GameProgress.fromJson(cloudData);
        }
      }

      // Last-write-wins strategy with timestamps
      final shouldSyncToCloud = cloudProgress == null ||
          localProgress.currentLevel > cloudProgress.currentLevel ||
          (localProgress.currentLevel == cloudProgress.currentLevel &&
              localProgress.completedLevels.length >
                  cloudProgress.completedLevels.length);

      if (shouldSyncToCloud) {
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
      }
    } catch (e) {
      // Sync failed - throw to indicate sync status
      rethrow;
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
    try {
      // Check if we can get a user ID (indicates auth is working)
      final userId = await _getUserId();
      return userId != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> setCloudSyncEnabled(bool enabled) async {
    await _localBox.put(_cloudSyncEnabledKey, enabled);

    // If enabling sync, try to sync immediately
    if (enabled && await isCloudSyncAvailable()) {
      try {
        await syncToCloud();
      } catch (e) {
        // Initial sync failed - user can try again later
      }
    }
  }

  @override
  Future<bool> isCloudSyncEnabled() async {
    return _localBox.get(_cloudSyncEnabledKey, defaultValue: false);
  }

  /// Manually triggers a sync from cloud to local.
  /// Useful for pulling progress from another device.
  Future<void> syncFromCloud() async {
    if (!await isCloudSyncEnabled()) return;

    final userId = await _getUserId();
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

          // Last-write-wins based on sync timestamp
          final cloudTimestamp = cloudData['syncTimestamp'] as int?;
          final localTimestamp = _localBox.get(_lastSyncTimeKey) as int?;

          final shouldUpdateLocal = cloudTimestamp != null &&
              (localTimestamp == null || cloudTimestamp > localTimestamp);

          if (shouldUpdateLocal) {
            await _localBox.put(_progressKey, cloudProgress.toJson());
            await _localBox.put(_lastSyncTimeKey, cloudTimestamp);
          }
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}
