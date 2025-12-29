/// Abstract repository for managing global level progress.
/// Tracks which level the player is currently on across the entire game.
abstract class GlobalLevelRepository {
  /// Get the current global level (1-indexed).
  /// Returns 1 if no progress exists.
  Future<int> getCurrentGlobalLevel();

  /// Set the current global level.
  Future<void> setCurrentGlobalLevel(int level);
}
