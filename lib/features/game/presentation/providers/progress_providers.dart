import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/game_providers.dart';
import '../../domain/entities/game_progress.dart';
import '../../domain/repositories/global_level_repository.dart';

// Progress tracking providers

final moduleProgressProvider = NotifierProvider<ModuleProgressNotifier, int>(
  ModuleProgressNotifier.new,
);

class ModuleProgressNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void setModuleId(int moduleId) {
    state = moduleId;
  }
}

final globalProgressProvider =
    NotifierProvider<GlobalProgressNotifier, GlobalProgress>(
      GlobalProgressNotifier.new,
    );

class GlobalProgressNotifier extends Notifier<GlobalProgress> {
  @override
  GlobalProgress build() {
    // Load from repository synchronously at build time
    final box = ref.watch(hiveBoxProvider);

    // Use Hive directly for synchronous read at build time
    // The repository provides abstraction for mutations (completeLevel, resetProgress)
    final currentGlobalLevel =
        box.get('currentGlobalLevel', defaultValue: 1) as int;
    final completedLevels = Set<int>.from(
      box.get('completedLevels', defaultValue: <int>[]),
    );

    final progress = GlobalProgress(
      currentGlobalLevel: currentGlobalLevel,
      completedLevels: completedLevels,
    );

    debugPrint('GlobalProgressNotifier: Built with $progress');

    return progress;
  }

  Future<void> completeLevel(int globalLevelNumber) async {
    final repository = ref.read(globalLevelRepositoryProvider);

    final newCompletedLevels = Set<int>.from(state.completedLevels)
      ..add(globalLevelNumber);

    final newState = state.copyWith(
      currentGlobalLevel: globalLevelNumber + 1,
      completedLevels: newCompletedLevels,
    );

    await repository.setCurrentGlobalLevel(newState.currentGlobalLevel);
    state = newState;

    debugPrint(
      'GlobalProgressNotifier: Completed level $globalLevelNumber, advanced to ${newState.currentGlobalLevel}',
    );
  }

  Future<void> resetProgress() async {
    final repository = ref.read(globalLevelRepositoryProvider);

    const defaultProgress = GlobalProgress(
      currentGlobalLevel: 1,
      completedLevels: {},
    );

    await repository.setCurrentGlobalLevel(defaultProgress.currentGlobalLevel);
    state = defaultProgress;

    debugPrint('GlobalProgressNotifier: Progress reset to $defaultProgress');
  }
}

// Current level provider
final currentLevelProvider = NotifierProvider<CurrentLevelNotifier, LevelData?>(
  CurrentLevelNotifier.new,
);

class CurrentLevelNotifier extends Notifier<LevelData?> {
  @override
  LevelData? build() => null;

  void setLevel(LevelData? level) {
    state = level;
  }
}

// Grace/lives provider
final graceProvider = NotifierProvider<GraceNotifier, int>(GraceNotifier.new);

class GraceNotifier extends Notifier<int> {
  @override
  int build() => 3;

  void setGrace(int value) {
    state = value;
  }

  void decrement() {
    if (state > 0) {
      state = state - 1;
    }
  }
}

// Game progress provider (persists game progress using repository)
final gameProgressProvider =
    NotifierProvider<GameProgressNotifier, GameProgress>(
      GameProgressNotifier.new,
    );

// Cloud sync state provider
final cloudSyncEnabledProvider = FutureProvider<bool>((ref) async {
  final notifier = ref.watch(gameProgressProvider.notifier);
  return notifier.isCloudSyncEnabled();
});

final cloudSyncAvailableProvider = FutureProvider<bool>((ref) async {
  final notifier = ref.watch(gameProgressProvider.notifier);
  return notifier.isCloudSyncAvailable();
});

final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  final notifier = ref.watch(gameProgressProvider.notifier);
  return notifier.getLastSyncTime();
});
