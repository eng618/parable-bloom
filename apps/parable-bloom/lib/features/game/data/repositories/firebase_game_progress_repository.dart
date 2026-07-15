import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/config/environment_config.dart';
import '../../../../services/logger_service.dart';
import '../constants/game_progress_storage_keys.dart';
import '../../domain/entities/cloud_sync_state.dart';
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
  final Duration _cloudReadTimeout;
  final Duration _cloudWriteTimeout;
  final Duration _cloudSyncBaseRetryDelay;

  // Document path
  static const String _progressDoc = 'progress';
  static const Duration _defaultCloudReadTimeout = Duration(seconds: 8);
  static const Duration _defaultCloudWriteTimeout = Duration(seconds: 8);
  static const int _cloudSyncMaxRetries = 3;
  static const Duration _defaultCloudSyncBaseRetryDelay =
      Duration(milliseconds: 200);

  FirebaseGameProgressRepository(
    this._localBox,
    this._firestore,
    this._auth, {
    Duration cloudReadTimeout = _defaultCloudReadTimeout,
    Duration cloudWriteTimeout = _defaultCloudWriteTimeout,
    Duration cloudRetryDelay = _defaultCloudSyncBaseRetryDelay,
  })  : _cloudReadTimeout = cloudReadTimeout,
        _cloudWriteTimeout = cloudWriteTimeout,
        _cloudSyncBaseRetryDelay = cloudRetryDelay;

  /// Returns the Firestore collection name for the current environment.
  static String get _collectionName =>
      EnvironmentConfig.getFirestoreCollection();

  /// Gets the current user ID. Return null if not signed in.
  String? get _userId => _auth.currentUser?.uid;

  bool get _isAnonymousUser => _auth.currentUser?.isAnonymous ?? true;

  DocumentReference<Map<String, dynamic>> _progressRef(String userId) {
    return _firestore
        .collection(_collectionName)
        .doc(userId)
        .collection('data')
        .doc(_progressDoc);
  }

  @override
  Future<GameProgress> getProgress() async {
    // Always return local data first (offline-first)
    final localData = _localBox.get(GameProgressStorageKeys.progress);
    if (localData != null) {
      return GameProgress.fromJson(Map<String, dynamic>.from(localData));
    }
    return GameProgress.initial();
  }

  @override
  Future<void> saveProgress(GameProgress progress) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Save locally
    await _localBox.put(GameProgressStorageKeys.progress, progress.toJson());
    await _localBox.put(GameProgressStorageKeys.lastLocalUpdate, now);

    // 2. Try to sync to cloud if possible
    if (await isCloudSyncEnabled() && _userId != null) {
      // Fire and forget - if it fails, we'll catch it on next sync
      // We don't await this to keep UI responsive, but we could if we wanted validation
      syncToCloud().catchError((e, stack) {
        LoggerService.error('Auto-sync failed',
            error: e, stackTrace: stack, tag: 'FirebaseGameProgressRepository');
      });
    }
  }

  @override
  Future<void> resetProgress() async {
    final initialProgress = GameProgress.initial();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _localBox.put(
      GameProgressStorageKeys.progress,
      initialProgress.toJson(),
    );
    await _localBox.put(GameProgressStorageKeys.lastLocalUpdate, now);

    // Also reset cloud data if available
    if (await isCloudSyncEnabled() && _userId != null) {
      try {
        await _firestore
            .collection(_collectionName)
            .doc(_userId)
            .collection('data')
            .doc(_progressDoc)
            .delete();
      } catch (e, stack) {
        LoggerService.error('Cloud reset failed',
            error: e, stackTrace: stack, tag: 'FirebaseGameProgressRepository');
      }
    }
  }

  @override
  Future<void> syncToCloud() async {
    if (!await isCloudSyncEnabled()) return;

    final userId = _userId;
    if (userId == null) {
      LoggerService.debug('Sync skipped: No user logged in',
          tag: 'FirebaseGameProgressRepository');
      return;
    }

    if (_isAnonymousUser) {
      LoggerService.debug('Sync skipped: Anonymous account cannot sync',
          tag: 'FirebaseGameProgressRepository');
      return;
    }

    final localProgress = await getProgress();
    final lastLocalUpdate =
        _localBox.get(GameProgressStorageKeys.lastLocalUpdate) as int? ?? 0;

    // We get the LAST successful sync time
    final lastSyncTime = await getLastSyncTime();
    final lastSyncMillis = lastSyncTime?.millisecondsSinceEpoch ?? 0;

    // Only push if local changes are newer than last sync
    if (lastLocalUpdate <= lastSyncMillis && lastSyncMillis != 0) {
      LoggerService.debug('Sync skipped: Local data is already synced',
          tag: 'FirebaseGameProgressRepository');
      return;
    }

    try {
      final cloudProgress = await _getCloudProgress(userId);
      if (cloudProgress != null) {
        final conflictType = _compareProgress(localProgress, cloudProgress);
        if (conflictType == SyncConflictType.cloudAhead) {
          await _saveLocalProgress(cloudProgress, updateSyncTime: true);
          LoggerService.info('Cloud progress applied locally before push',
              tag: 'FirebaseGameProgressRepository');
          return;
        }

        if (conflictType == SyncConflictType.divergent) {
          LoggerService.info(
              'Sync push skipped: divergent progress needs user choice',
              tag: 'FirebaseGameProgressRepository');
          return;
        }
      }

      await _saveCloudProgressWithRetry(userId, localProgress);
      LoggerService.info('Sync to cloud successful',
          tag: 'FirebaseGameProgressRepository');
    } catch (e, stack) {
      LoggerService.error('Sync to cloud failed',
          error: e, stackTrace: stack, tag: 'FirebaseGameProgressRepository');
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

    if (_isAnonymousUser) return;

    try {
      final conflict = await inspectSyncConflict();
      if (conflict.type == SyncConflictType.cloudAhead &&
          conflict.cloudProgress != null) {
        await _saveLocalProgress(conflict.cloudProgress!, updateSyncTime: true);
      }
    } catch (e, stack) {
      LoggerService.error('Sync from cloud failed',
          error: e, stackTrace: stack, tag: 'FirebaseGameProgressRepository');
    }
  }

  Future<GameProgress?> _getCloudProgress(String userId) async {
    for (int attempt = 1; attempt <= _cloudSyncMaxRetries; attempt++) {
      try {
        final cloudDoc =
            await _progressRef(userId).get().timeout(_cloudReadTimeout);
        if (attempt > 1) {
          LoggerService.info(
            'Cloud progress read recovered after retry',
            tag: 'FirebaseGameProgressRepository',
            metadata: {
              'attempts_used': attempt,
              'max_retries': _cloudSyncMaxRetries,
            },
          );
        }
        if (!cloudDoc.exists) return null;
        final cloudData = cloudDoc.data();
        if (cloudData == null) return null;
        return GameProgress.fromJson(cloudData);
      } catch (error, stackTrace) {
        final isRetryable = _isTransientCloudError(error);
        final isLastAttempt = attempt == _cloudSyncMaxRetries;
        if (!isRetryable) {
          LoggerService.warn(
            'Cloud progress read failed without retry',
            error: error,
            stackTrace: stackTrace,
            tag: 'FirebaseGameProgressRepository',
            metadata: {
              'attempt': attempt,
              'retryable': false,
              'timeout_ms': _cloudReadTimeout.inMilliseconds,
            },
          );
          return null;
        }
        if (isLastAttempt) {
          LoggerService.warn(
            'Cloud progress read retries exhausted',
            error: error,
            stackTrace: stackTrace,
            tag: 'FirebaseGameProgressRepository',
            metadata: {
              'attempt': attempt,
              'max_retries': _cloudSyncMaxRetries,
              'retryable': true,
              'timeout_ms': _cloudReadTimeout.inMilliseconds,
            },
          );
          return null;
        }
        final backoff = Duration(
          milliseconds:
              _cloudSyncBaseRetryDelay.inMilliseconds * (1 << (attempt - 1)),
        );
        LoggerService.warn(
          'Cloud sync read failed, retrying',
          error: error,
          stackTrace: stackTrace,
          tag: 'FirebaseGameProgressRepository',
          metadata: {
            'attempt': attempt,
            'max_retries': _cloudSyncMaxRetries,
            'backoff_ms': backoff.inMilliseconds,
          },
        );
        await Future<void>.delayed(backoff);
      }
    }
    return null;
  }

  Future<void> _saveLocalProgress(
    GameProgress progress, {
    required bool updateSyncTime,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _localBox.put(GameProgressStorageKeys.progress, progress.toJson());
    await _localBox.put(GameProgressStorageKeys.lastLocalUpdate, now);
    if (updateSyncTime) {
      await _localBox.put(GameProgressStorageKeys.lastSyncTime, now);
    }
  }

  Future<void> _saveCloudProgress(String userId, GameProgress progress) async {
    final now = DateTime.now();
    await _progressRef(userId).set({
      ...progress.toJson(),
      'lastUpdated': now.toIso8601String(),
      'syncTimestamp': now.millisecondsSinceEpoch,
    }).timeout(_cloudWriteTimeout);
    await _localBox.put(
      GameProgressStorageKeys.lastSyncTime,
      now.millisecondsSinceEpoch,
    );
  }

  Future<void> _saveCloudProgressWithRetry(
    String userId,
    GameProgress progress,
  ) async {
    for (int attempt = 1; attempt <= _cloudSyncMaxRetries; attempt++) {
      try {
        await _saveCloudProgress(userId, progress);
        if (attempt > 1) {
          LoggerService.info(
            'Cloud sync write recovered after retry',
            tag: 'FirebaseGameProgressRepository',
            metadata: {
              'attempts_used': attempt,
              'max_retries': _cloudSyncMaxRetries,
            },
          );
        }
        return;
      } catch (error, stackTrace) {
        final isRetryable = _isTransientCloudError(error);
        final isLastAttempt = attempt == _cloudSyncMaxRetries;
        if (!isRetryable) {
          LoggerService.warn(
            'Cloud sync write failed without retry',
            tag: 'FirebaseGameProgressRepository',
            error: error,
            stackTrace: stackTrace,
            metadata: {
              'attempt': attempt,
              'retryable': false,
            },
          );
          rethrow;
        }
        if (isLastAttempt) {
          LoggerService.warn(
            'Cloud sync write retries exhausted',
            tag: 'FirebaseGameProgressRepository',
            error: error,
            stackTrace: stackTrace,
            metadata: {
              'attempt': attempt,
              'max_retries': _cloudSyncMaxRetries,
              'retryable': true,
            },
          );
          rethrow;
        }

        final backoff = Duration(
          milliseconds:
              _cloudSyncBaseRetryDelay.inMilliseconds * (1 << (attempt - 1)),
        );
        LoggerService.warn(
          'Cloud sync write failed, retrying',
          tag: 'FirebaseGameProgressRepository',
          error: error,
          stackTrace: stackTrace,
          metadata: {
            'attempt': attempt,
            'max_retries': _cloudSyncMaxRetries,
            'backoff_ms': backoff.inMilliseconds,
          },
        );
        await Future<void>.delayed(backoff);
      }
    }
  }

  bool _isTransientCloudError(Object error) {
    if (error is TimeoutException) {
      return true;
    }
    if (error is FirebaseException) {
      return error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'aborted' ||
          error.code == 'internal' ||
          error.code == 'resource-exhausted';
    }
    return false;
  }

  SyncConflictType _compareProgress(GameProgress local, GameProgress cloud) {
    if (local == cloud) {
      return SyncConflictType.none;
    }

    final localDominates = _dominates(local, cloud);
    final cloudDominates = _dominates(cloud, local);

    if (localDominates && !cloudDominates) {
      return SyncConflictType.localAhead;
    }

    if (cloudDominates && !localDominates) {
      return SyncConflictType.cloudAhead;
    }

    return SyncConflictType.divergent;
  }

  int _levelIndex(String levelId) {
    if (levelId.startsWith('lesson_')) {
      final numStr = levelId.replaceAll('lesson_', '');
      final num = int.tryParse(numStr) ?? 1;
      return num; // lessons 1 to 5
    }
    int base = 0;
    if (levelId.startsWith('lvl_seed_')) {
      base = 10;
      if (levelId == 'lvl_seed_challenge') return base + 21;
      final numStr = levelId.replaceAll('lvl_seed_', '');
      final num = int.tryParse(numStr) ?? 1;
      return base + num;
    }
    if (levelId.startsWith('lvl_sprout_')) {
      base = 40;
      if (levelId == 'lvl_sprout_challenge') return base + 21;
      final numStr = levelId.replaceAll('lvl_sprout_', '');
      final num = int.tryParse(numStr) ?? 1;
      return base + num;
    }
    if (levelId.startsWith('lvl_blossom_')) {
      base = 70;
      if (levelId == 'lvl_blossom_challenge') return base + 21;
      final numStr = levelId.replaceAll('lvl_blossom_', '');
      final num = int.tryParse(numStr) ?? 1;
      return base + num;
    }
    if (levelId.startsWith('lvl_flourish_')) {
      base = 100;
      if (levelId == 'lvl_flourish_challenge') return base + 21;
      final numStr = levelId.replaceAll('lvl_flourish_', '');
      final num = int.tryParse(numStr) ?? 1;
      return base + num;
    }
    if (levelId.startsWith('lvl_harvest_')) {
      base = 130;
      if (levelId == 'lvl_harvest_challenge') return base + 21;
      final numStr = levelId.replaceAll('lvl_harvest_', '');
      final num = int.tryParse(numStr) ?? 1;
      return base + num;
    }
    return 0;
  }

  bool _dominates(GameProgress left, GameProgress right) {
    final leftIdx = _levelIndex(left.currentLevel);
    final rightIdx = _levelIndex(right.currentLevel);

    final levelCheck = leftIdx >= rightIdx;
    final levelsCheck = left.completedLevels.containsAll(right.completedLevels);
    final lessonSetCheck =
        left.completedLessons.containsAll(right.completedLessons);
    final lessonCompletedCheck = !right.lessonCompleted || left.lessonCompleted;
    final tutorialCheck = !right.tutorialCompleted || left.tutorialCompleted;

    final strictBetter = leftIdx > rightIdx ||
        left.completedLevels.length > right.completedLevels.length ||
        left.completedLessons.length > right.completedLessons.length ||
        (left.lessonCompleted && !right.lessonCompleted) ||
        (left.tutorialCompleted && !right.tutorialCompleted);

    return levelCheck &&
        levelsCheck &&
        lessonSetCheck &&
        lessonCompletedCheck &&
        tutorialCheck &&
        strictBetter;
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    final timestamp = _localBox.get(GameProgressStorageKeys.lastSyncTime);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  @override
  Future<bool> isCloudSyncAvailable() async {
    final availability = await getCloudSyncAvailability();
    return availability.isAvailable;
  }

  @override
  Future<CloudSyncAvailability> getCloudSyncAvailability() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const CloudSyncAvailability(
        isAvailable: false,
        reason: CloudSyncAvailabilityReason.signedOut,
      );
    }

    if (user.isAnonymous) {
      return const CloudSyncAvailability(
        isAvailable: false,
        reason: CloudSyncAvailabilityReason.anonymousAccount,
      );
    }

    return const CloudSyncAvailability(
      isAvailable: true,
      reason: CloudSyncAvailabilityReason.available,
    );
  }

  @override
  Future<void> setCloudSyncEnabled(bool enabled) async {
    await _localBox.put(GameProgressStorageKeys.cloudSyncEnabled, enabled);

    // If enabling sync, try to sync immediately
    if (enabled && await isCloudSyncAvailable()) {
      final conflict = await inspectSyncConflict();
      if (conflict.type == SyncConflictType.cloudAhead &&
          conflict.cloudProgress != null) {
        await _saveLocalProgress(conflict.cloudProgress!, updateSyncTime: true);
      } else if (conflict.type == SyncConflictType.none ||
          !conflict.cloudHasData) {
        await syncToCloud();
      }
    }
  }

  @override
  Future<bool> isCloudSyncEnabled() async {
    return _localBox.get(
      GameProgressStorageKeys.cloudSyncEnabled,
      defaultValue: false,
    );
  }

  @override
  Future<SyncConflictState> inspectSyncConflict() async {
    final localProgress = await getProgress();
    final userId = _userId;
    if (userId == null || _isAnonymousUser) {
      return SyncConflictState(
        type: SyncConflictType.none,
        localProgress: localProgress,
        cloudProgress: null,
      );
    }

    final cloudProgress = await _getCloudProgress(userId);
    if (cloudProgress == null) {
      return SyncConflictState(
        type: SyncConflictType.none,
        localProgress: localProgress,
        cloudProgress: null,
      );
    }

    return SyncConflictState(
      type: _compareProgress(localProgress, cloudProgress),
      localProgress: localProgress,
      cloudProgress: cloudProgress,
    );
  }

  @override
  Future<void> resolveSyncConflict(SyncConflictResolution resolution) async {
    final conflict = await inspectSyncConflict();
    if (!conflict.cloudHasData) {
      final userId = _userId;
      if (userId != null && !_isAnonymousUser) {
        await _saveCloudProgress(userId, conflict.localProgress);
      }
      return;
    }

    final userId = _userId;
    if (userId == null || _isAnonymousUser) {
      return;
    }

    if (resolution == SyncConflictResolution.keepCloud) {
      await _saveLocalProgress(conflict.cloudProgress!, updateSyncTime: true);
      return;
    }

    await _saveCloudProgress(userId, conflict.localProgress);
  }
}
