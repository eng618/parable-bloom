import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/game_progress.dart';
import '../../domain/repositories/game_progress_repository.dart';

/// Local-only game progress repository using Hive.
/// Implements cloud sync methods as no-ops since this is local storage only.
class HiveGameProgressRepository implements GameProgressRepository {
  final Box _box;

  static const String _progressKey = 'progress';
  static const String _cloudSyncEnabledKey = 'cloud_sync_enabled';
  static const String _lastSyncTimeKey = 'last_sync_time';

  HiveGameProgressRepository(this._box);

  @override
  Future<GameProgress> getProgress() async {
    final data = _box.get(_progressKey);
    if (data != null) {
      return GameProgress.fromJson(Map<String, dynamic>.from(data));
    }
    return GameProgress.initial();
  }

  @override
  Future<void> saveProgress(GameProgress progress) async {
    await _box.put(_progressKey, progress.toJson());
  }

  @override
  Future<void> resetProgress() async {
    await _box.put(_progressKey, GameProgress.initial().toJson());
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
    final timestamp = _box.get(_lastSyncTimeKey);
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
  Future<void> setCloudSyncEnabled(bool enabled) async {
    await _box.put(_cloudSyncEnabledKey, enabled);
  }

  @override
  Future<bool> isCloudSyncEnabled() async {
    return _box.get(_cloudSyncEnabledKey, defaultValue: false);
  }
}
