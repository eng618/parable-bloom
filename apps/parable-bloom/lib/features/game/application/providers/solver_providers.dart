import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/level_solver_service.dart';

final levelSolverServiceProvider = Provider<LevelSolverService>((ref) {
  return LevelSolverService();
});
