import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/game/data/repositories/asset_level_repository.dart';
import '../../features/game/data/repositories/hive_game_progress_repository.dart';
import '../../features/game/domain/repositories/game_progress_repository.dart';
import '../../features/game/domain/repositories/level_repository.dart';
import '../../features/game/domain/usecases/complete_level_usecase.dart';
import '../../features/game/domain/usecases/get_game_progress_usecase.dart';
import '../../features/game/domain/usecases/load_level_usecase.dart';

final sl = GetIt.instance;

Future<void> setupDependencies(Box hiveBox) async {
  // Data sources
  sl.registerLazySingleton<Box>(() => hiveBox);

  // Repositories
  sl.registerLazySingleton<GameProgressRepository>(
    () => HiveGameProgressRepository(sl<Box>()),
  );

  sl.registerLazySingleton<LevelRepository>(() => AssetLevelRepository());

  // Use cases
  sl.registerLazySingleton<GetGameProgressUseCase>(
    () => GetGameProgressUseCase(sl<GameProgressRepository>()),
  );

  sl.registerLazySingleton<LoadLevelUseCase>(
    () => LoadLevelUseCase(sl<LevelRepository>()),
  );

  sl.registerLazySingleton<CompleteLevelUseCase>(
    () => CompleteLevelUseCase(sl<GameProgressRepository>()),
  );
}
