import '../entities/game_progress.dart';

abstract class GameProgressRepository {
  Future<GameProgress> getProgress();
  Future<void> saveProgress(GameProgress progress);
  Future<void> resetProgress();
}
