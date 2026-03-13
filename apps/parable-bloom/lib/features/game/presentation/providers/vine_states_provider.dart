import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/game/domain/entities/level_data.dart';
import '../../../../providers/counter_providers.dart';
import '../../../../providers/gameplay_state_providers.dart';
import '../../../../providers/service_providers.dart';
import '../../../../services/logger_service.dart';
import '../../domain/services/level_solver_service.dart';

// Vine state tracking provider

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

    // Active vines are those that can block others (not cleared and not animating clear)
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

      bool isBlocked = false;

      // Only calculate blocking for vines that are in normal state
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
        animationState: animationState,
      );
    }

    return newStates;
  }

  void clearVine(String vineId) {
    LoggerService.debug('Clearing vine',
        tag: 'VineStatesNotifier', metadata: {'vine_id': vineId});
    // Mark as cleared
    final mapWithCleared = Map<String, VineState>.from(state);
    if (mapWithCleared.containsKey(vineId)) {
      mapWithCleared[vineId] = mapWithCleared[vineId]!.copyWith(
        isCleared: true,
      );
    }

    // Recalculate blocking for all
    state = _calculateVineStates(_levelData, mapWithCleared);
  }

  void markAttempted(String vineId) {
    final s = state[vineId];
    if (s == null) return;

    if (!s.hasBeenAttempted) {
      LoggerService.debug(
        'Marking vine as attempted and decrementing life',
        tag: 'VineStatesNotifier',
        metadata: {'vine_id': vineId},
      );
      state = {...state, vineId: s.copyWith(hasBeenAttempted: true)};

      // Increment wrong taps counter
      ref.read(levelWrongTapsProvider.notifier).increment();

      // Log wrong tap analytics
      final currentLevel = ref.read(currentLevelProvider);
      final remainingGrace = ref.read(graceProvider);
      if (currentLevel != null) {
        ref
            .read(analyticsServiceProvider)
            .logWrongTap(currentLevel.id, remainingGrace);
      }

      // Notify parent/provider to decrement grace
      ref.read(gameInstanceProvider.notifier).decrementGrace();
    } else {
      LoggerService.debug(
        'Vine already attempted, skipping life decrement',
        tag: 'VineStatesNotifier',
        metadata: {'vine_id': vineId},
      );
    }
  }

  void _checkLevelComplete() {
    final allFinished = state.values.every((vineState) =>
        vineState.isCleared ||
        vineState.animationState == VineAnimationState.animatingClear);
    LoggerService.debug(
      'Checking completion',
      tag: 'VineStatesNotifier',
      metadata: {
        'all_finished': allFinished,
        'total_vines': state.length,
      },
    );
    if (allFinished) {
      LoggerService.info(
        'LEVEL COMPLETE detected! Triggering provider...',
        tag: 'VineStatesNotifier',
      );
      // Trigger level complete
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

    // Recalculate blocking states when animation state changes
    state = _calculateVineStates(_levelData, state);

    // Check if level is complete when a vine starts clearing animation
    if (animationState == VineAnimationState.animatingClear) {
      _checkLevelComplete();
    }
  }

  void resetForLevel(LevelData levelData) {
    _levelData = levelData;
    state = _calculateVineStates(levelData, {});
  }
}
