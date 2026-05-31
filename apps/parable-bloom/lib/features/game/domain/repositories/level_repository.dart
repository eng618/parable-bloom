import '../entities/level_data.dart';

/// Abstract contract for retrieving level data.
/// Decouples physical asset storage from logical level fetching.
abstract class LevelRepository {
  /// Loads a level by its logical string identifier.
  Future<LevelData> getLevel(String levelId);
}
