import '../entities/game_progress.dart';

/// Abstract repository for game progress persistence.
/// Supports both local and cloud implementations.
abstract class ProgressRepository {
  /// Loads game progress from storage.
  /// Returns initial progress if no data exists.
  Future<GameProgress> loadProgress();

  /// Saves game progress to storage.
  Future<void> saveProgress(GameProgress progress);

  /// Resets all progress to initial state.
  Future<void> resetProgress();

  /// Syncs progress to cloud if available.
  /// This is a no-op for local-only repositories.
  Future<void> syncToCloud();

  /// Gets the last sync timestamp.
  /// Returns null if never synced or not applicable.
  Future<DateTime?> getLastSyncTime();

  /// Checks if cloud sync is available.
  Future<bool> isCloudSyncAvailable();
}
