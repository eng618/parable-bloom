import '../entities/level.dart';

abstract class LevelRepository {
  Future<Level?> getLevel(int levelNumber);
  Future<List<int>> getAvailableLevelNumbers();
  Future<bool> levelExists(int levelNumber);
}
