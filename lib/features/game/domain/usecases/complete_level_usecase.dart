import '../entities/game_progress.dart';
import '../repositories/game_progress_repository.dart';

class CompleteLevelUseCase {
  final GameProgressRepository _progressRepository;

  CompleteLevelUseCase(this._progressRepository);

  Future<GameProgress> execute(int levelNumber) async {
    final currentProgress = await _progressRepository.getProgress();
    final updatedProgress = currentProgress.completeLevel(levelNumber);
    await _progressRepository.saveProgress(updatedProgress);
    return updatedProgress;
  }
}
