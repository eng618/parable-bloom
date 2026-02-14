import '../entities/game_progress.dart';

/// Repository for game progress persistence with optional cloud sync.
/// Supports both local and cloud implementations for offline-first architecture.
abstract class GameProgressRepository {
  /// Gets the current game progress from storage.
  /// Returns initial progress if no data exists.
  Future<GameProgress> getProgress();

  /// Saves game progress to storage.
  Future<void> saveProgress(GameProgress progress);

  /// Resets all progress to initial state.
  Future<void> resetProgress();

  /// Syncs progress to cloud if available and enabled.
  /// This is a no-op for local-only repositories.
  Future<void> syncToCloud();

  /// Syncs progress from cloud if available and enabled.
  /// This is a no-op for local-only repositories.
  Future<void> syncFromCloud();

  /// Gets the last sync timestamp.
  /// Returns null if never synced or not applicable.
  Future<DateTime?> getLastSyncTime();

  /// Checks if cloud sync is available and enabled.
  Future<bool> isCloudSyncAvailable();

  /// Enables or disables cloud sync.
  /// Local storage continues to work regardless of this setting.
  Future<void> setCloudSyncEnabled(bool enabled);

  /// Checks if cloud sync is enabled by user preference.
  Future<bool> isCloudSyncEnabled();
}
