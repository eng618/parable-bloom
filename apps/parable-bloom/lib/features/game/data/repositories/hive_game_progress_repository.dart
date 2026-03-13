import 'package:hive_flutter/hive_flutter.dart';

import '../constants/game_progress_storage_keys.dart';
import '../../domain/entities/cloud_sync_state.dart';
import '../../domain/entities/game_progress.dart';
import '../../domain/repositories/game_progress_repository.dart';

/// Local-only game progress repository using Hive.
/// Implements cloud sync methods as no-ops since this is local storage only.
class HiveGameProgressRepository implements GameProgressRepository {
  final Box _box;

  HiveGameProgressRepository(this._box);

  @override
  Future<GameProgress> getProgress() async {
    final data = _box.get(GameProgressStorageKeys.progress);
    if (data != null) {
      return GameProgress.fromJson(Map<String, dynamic>.from(data));
    }
    return GameProgress.initial();
  }

  @override
  Future<void> saveProgress(GameProgress progress) async {
    await _box.put(GameProgressStorageKeys.progress, progress.toJson());
  }

  @override
  Future<void> resetProgress() async {
    await _box.put(
        GameProgressStorageKeys.progress, GameProgress.initial().toJson());
    // Optionally clear sync metadata but keep cloud sync preference
  }

  @override
  Future<void> syncToCloud() async {
    // No-op for local-only repository
    // Could potentially trigger a manual sync if cloud repo is available
  }

  @override
  Future<void> syncFromCloud() async {
    // No-op for local-only repository
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    final timestamp = _box.get(GameProgressStorageKeys.lastSyncTime);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  @override
  Future<bool> isCloudSyncAvailable() async {
    // Local repository doesn't provide cloud sync
    return false;
  }

  @override
  Future<CloudSyncAvailability> getCloudSyncAvailability() async {
    return const CloudSyncAvailability(
      isAvailable: false,
      reason: CloudSyncAvailabilityReason.signedOut,
    );
  }

  @override
  Future<void> setCloudSyncEnabled(bool enabled) async {
    await _box.put(GameProgressStorageKeys.cloudSyncEnabled, enabled);
  }

  @override
  Future<bool> isCloudSyncEnabled() async {
    return _box.get(GameProgressStorageKeys.cloudSyncEnabled,
        defaultValue: false);
  }

  @override
  Future<SyncConflictState> inspectSyncConflict() async {
    final localProgress = await getProgress();
    return SyncConflictState(
      type: SyncConflictType.none,
      localProgress: localProgress,
      cloudProgress: null,
    );
  }

  @override
  Future<void> resolveSyncConflict(SyncConflictResolution resolution) async {
    // No-op in local repository.
  }
}
