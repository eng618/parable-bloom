import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/service_providers.dart';
import '../../../../services/logger_service.dart';
import '../../domain/entities/level_data.dart';
import '../../domain/services/level_solver_service.dart';
import '../../presentation/widgets/garden_game.dart';
import 'counter_providers.dart';

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

final levelCompleteProvider = NotifierProvider<LevelCompleteNotifier, bool>(
  LevelCompleteNotifier.new,
);

class LevelCompleteNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setComplete(bool complete) {
    state = complete;
  }
}

final gameCompletedProvider = NotifierProvider<GameCompletedNotifier, bool>(
  GameCompletedNotifier.new,
);

class GameCompletedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setCompleted(bool completed) {
    state = completed;
  }
}

final graceProvider = NotifierProvider<GraceNotifier, int>(GraceNotifier.new);

class GraceNotifier extends Notifier<int> {
  @override
  int build() => 3;

  void setGrace(int grace) {
    state = grace;
  }
}

final gameOverProvider = NotifierProvider<GameOverNotifier, bool>(
  GameOverNotifier.new,
);

class GameOverNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setGameOver(bool gameOver) {
    state = gameOver;
  }
}

final gameInstanceProvider =
    NotifierProvider<GameInstanceNotifier, GardenGame?>(
  GameInstanceNotifier.new,
);

class GameInstanceNotifier extends Notifier<GardenGame?> {
  @override
  GardenGame? build() => null;

  void setGame(GardenGame game) {
    state = game;
  }

  void resetGrace() {
    ref.read(graceProvider.notifier).setGrace(3);
    ref.read(gameOverProvider.notifier).setGameOver(false);
  }

  void decrementGrace() {
    final currentGrace = ref.read(graceProvider);
    if (currentGrace > 0) {
      ref.read(graceProvider.notifier).setGrace(currentGrace - 1);
      if (currentGrace - 1 == 0) {
        ref.read(gameOverProvider.notifier).setGameOver(true);
      }
    }
  }
}

class DebugSelectedLevelNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setLevel(int? level) => state = level;
}

final debugSelectedLevelProvider =
    NotifierProvider<DebugSelectedLevelNotifier, int?>(
  DebugSelectedLevelNotifier.new,
);

final debugPlayModeProvider = Provider<bool>((ref) {
  return ref.watch(debugSelectedLevelProvider) != null;
});

enum CelebrationEffect {
  pondRipples,
  leafPetals,
  confetti,
  rippleFireworks,
}

final celebrationEffectProvider =
    NotifierProvider<CelebrationEffectNotifier, CelebrationEffect>(
  CelebrationEffectNotifier.new,
);

class CelebrationEffectNotifier extends Notifier<CelebrationEffect> {
  @override
  CelebrationEffect build() {
    return CelebrationEffect.rippleFireworks;
  }

  void setEffect(CelebrationEffect effect) {
    state = effect;
  }
}

enum VineAnimationState {
  normal,
  animatingClear,
  animatingBlocked,
  cleared,
}

class VineState {
  final String id;
  final bool isBlocked;
  final bool isCleared;
  final bool hasBeenAttempted;
  final bool isWithered;
  final VineAnimationState animationState;

  VineState({
    required this.id,
    required this.isBlocked,
    required this.isCleared,
    this.hasBeenAttempted = false,
    this.isWithered = false,
    this.animationState = VineAnimationState.normal,
  });

  VineState copyWith({
    bool? isBlocked,
    bool? isCleared,
    bool? hasBeenAttempted,
    bool? isWithered,
    VineAnimationState? animationState,
  }) {
    return VineState(
      id: id,
      isBlocked: isBlocked ?? this.isBlocked,
      isCleared: isCleared ?? this.isCleared,
      hasBeenAttempted: hasBeenAttempted ?? this.hasBeenAttempted,
      isWithered: isWithered ?? this.isWithered,
      animationState: animationState ?? this.animationState,
    );
  }
}

final vineStatesProvider =
    NotifierProvider<VineStatesNotifier, Map<String, VineState>>(
  VineStatesNotifier.new,
);

class VineStatesNotifier extends Notifier<Map<String, VineState>> {
  LevelData? _levelData;
  LevelSolverService? _solverService;

  @override
  Map<String, VineState> build() {
    final levelData = ref.watch(currentLevelProvider);
    _levelData = levelData;
    _solverService = ref.watch(levelSolverServiceProvider);
    return _calculateVineStates(levelData, {});
  }

  Map<String, VineState> _calculateVineStates(
    LevelData? levelData,
    Map<String, VineState> currentStates,
  ) {
    if (levelData == null || _solverService == null) return {};

    final blockingVineIds = <String>[];
    for (final vine in levelData.vines) {
      final currentState = currentStates[vine.id];
      final isCleared = currentState?.isCleared ?? false;
      final animationState =
          currentState?.animationState ?? VineAnimationState.normal;

      if (!isCleared && animationState != VineAnimationState.animatingClear) {
        blockingVineIds.add(vine.id);
      }
    }

    final newStates = <String, VineState>{};
    for (final vine in levelData.vines) {
      final currentState = currentStates[vine.id];
      final isCleared = currentState?.isCleared ?? false;
      final animationState =
          currentState?.animationState ?? VineAnimationState.normal;
      final hasBeenAttempted = currentState?.hasBeenAttempted ?? false;
      final isWithered = currentState?.isWithered ?? false;

      var isBlocked = false;
      if (!isCleared && animationState == VineAnimationState.normal) {
        isBlocked = _solverService!.isVineBlockedInState(
          levelData,
          vine.id,
          blockingVineIds,
        );
      }

      newStates[vine.id] = VineState(
        id: vine.id,
        isBlocked: isBlocked,
        isCleared: isCleared,
        hasBeenAttempted: hasBeenAttempted,
        isWithered: isWithered,
        animationState: animationState,
      );
    }

    return newStates;
  }

  void clearVine(String vineId) {
    LoggerService.debug('Clearing vine $vineId', tag: 'VineStatesNotifier');
    final mapWithCleared = Map<String, VineState>.from(state);
    if (mapWithCleared.containsKey(vineId)) {
      mapWithCleared[vineId] = mapWithCleared[vineId]!.copyWith(
        isCleared: true,
      );
    }

    state = _calculateVineStates(_levelData, mapWithCleared);
  }

  void markAttempted(String vineId) {
    final currentState = state[vineId];
    if (currentState == null) return;

    if (!currentState.hasBeenAttempted) {
      LoggerService.info(
        'Marking $vineId as attempted and decrementing life',
        tag: 'VineStatesNotifier',
      );

      state = {
        ...state,
        vineId: currentState.copyWith(
          hasBeenAttempted: true,
          isWithered: true,
        ),
      };

      ref.read(levelWrongTapsProvider.notifier).increment();

      final currentLevel = ref.read(currentLevelProvider);
      final remainingGrace = ref.read(graceProvider);
      if (currentLevel != null) {
        ref
            .read(analyticsServiceProvider)
            .logWrongTap(currentLevel.id, remainingGrace);
      }

      ref.read(gameInstanceProvider.notifier).decrementGrace();
    } else {
      LoggerService.debug(
        '$vineId already attempted, skipping life decrement',
        tag: 'VineStatesNotifier',
      );
    }
  }

  void _checkLevelComplete() {
    final allFinished = state.values.every((vineState) =>
        vineState.isCleared ||
        vineState.animationState == VineAnimationState.animatingClear);
    LoggerService.debug(
      'Checking completion - allFinished: $allFinished, total vines: ${state.length}',
      tag: 'VineStatesNotifier',
    );
    if (allFinished && state.isNotEmpty) {
      LoggerService.info(
        'LEVEL COMPLETE detected! Setting levelCompleteProvider to true',
        tag: 'VineStatesNotifier',
      );
      ref.read(levelCompleteProvider.notifier).setComplete(true);
    }
  }

  void setAnimationState(String vineId, VineAnimationState animationState) {
    final currentState = state[vineId];
    if (currentState == null) return;

    state = {
      ...state,
      vineId: currentState.copyWith(animationState: animationState),
    };

    state = _calculateVineStates(_levelData, state);

    if (animationState == VineAnimationState.animatingClear) {
      _checkLevelComplete();
    }
  }

  void resetForLevel(LevelData levelData) {
    _levelData = levelData;
    state = _calculateVineStates(levelData, {});
  }
}

final projectionLinesVisibleProvider =
    NotifierProvider<ProjectionLinesVisibleNotifier, bool>(
  ProjectionLinesVisibleNotifier.new,
);

class ProjectionLinesVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void setVisible(bool visible) {
    state = visible;
  }
}

final anyVineAnimatingProvider = Provider<bool>((ref) {
  final vineStates = ref.watch(vineStatesProvider);
  return vineStates.values.any(
    (state) =>
        state.animationState == VineAnimationState.animatingClear ||
        state.animationState == VineAnimationState.animatingBlocked,
  );
});

final disableAnimationsProvider = Provider<bool>((ref) => false);
