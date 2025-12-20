import '../entities/level.dart';
import '../repositories/level_repository.dart';

class LoadLevelUseCase {
  final LevelRepository _levelRepository;

  LoadLevelUseCase(this._levelRepository);

  Future<Level?> execute(int levelNumber) async {
    return _levelRepository.getLevel(levelNumber);
  }
}
