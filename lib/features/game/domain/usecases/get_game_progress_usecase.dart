import '../entities/game_progress.dart';
import '../repositories/game_progress_repository.dart';

class GetGameProgressUseCase {
  final GameProgressRepository _repository;

  GetGameProgressUseCase(this._repository);

  Future<GameProgress> execute() async {
    return _repository.getProgress();
  }
}
