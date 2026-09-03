import 'package:parable_bloom/core/constants/animation_timing.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/presentation/widgets/grid_component.dart';

class VineAnimator {
  final VineData vineData;
  bool isAnimating = false;
  bool willClearAfterAnimation = false;

  List<Map<String, int>> visualPositions = [];
  int currentAnimationStep = 0;
  int totalAnimationSteps = 0;
  int maxForwardStepsThisRun = 0;
  bool canClearThisRun = false;
  double animationTimer = 0.0;
  double stepDuration = AnimationTiming.vineStepSeconds;

  List<List<Map<String, int>>> positionHistory = [];
  bool isBlockedAnimation = false;

  VineAnimator({required this.vineData}) {
    visualPositions = List<Map<String, int>>.from(
      vineData.orderedPath.map((cell) => Map<String, int>.from(cell)),
    );
  }

  void startSlideOut({
    required GridComponent grid,
    required void Function(String message) logDebug,
  }) {
    if (isAnimating) return;
    isAnimating = true;

    positionHistory = [];
    currentAnimationStep = 0;
    isBlockedAnimation = false;
    animationTimer = 0.0;

    final int rawDistance = calculateMovementDistance(grid);
    canClearThisRun = rawDistance > 0;
    maxForwardStepsThisRun = rawDistance.abs();

    if (canClearThisRun) {
      const int extraOffScreenSteps = 6;
      totalAnimationSteps = maxForwardStepsThisRun +
          vineData.orderedPath.length +
          extraOffScreenSteps;
      willClearAfterAnimation = true;

      grid.setVineAnimationState(
        vineData.id,
        VineAnimationState.animatingClear,
      );

      logDebug(
        'Starting CLEAR animation: vineId=${vineData.id}, '
        'maxForwardSteps=$maxForwardStepsThisRun, totalSteps=$totalAnimationSteps, '
        'headPos=(${visualPositions[0]['x']},${visualPositions[0]['y']}), '
        'direction=${vineData.headDirection}',
      );
    } else {
      totalAnimationSteps = maxForwardStepsThisRun * 2;
      willClearAfterAnimation = false;

      grid.setVineAnimationState(
        vineData.id,
        VineAnimationState.animatingBlocked,
      );

      logDebug(
        'Starting BLOCKED animation: vineId=${vineData.id}, '
        'maxForwardSteps=$maxForwardStepsThisRun (to blocker cell), totalSteps=$totalAnimationSteps, '
        'headPos=(${visualPositions[0]['x']},${visualPositions[0]['y']}), '
        'direction=${vineData.headDirection}',
      );
    }
  }

  int calculateMovementDistance(GridComponent grid) {
    final activeIds = grid.getActiveVineIds();
    final solver = grid.getLevelSolverService();
    final level = grid.getCurrentLevelData();
    if (level == null) return 0;

    return solver.getDistanceToBlocker(
      level,
      vineData.id,
      activeIds,
    );
  }

  bool update({
    required double dt,
    required GridComponent grid,
    required void Function() onHeadExitedGrid,
    required void Function() onFinished,
    required void Function(String message) logDebug,
  }) {
    if (!isAnimating) return false;

    animationTimer += dt;
    if (animationTimer >= stepDuration) {
      animationTimer = 0.0;

      if (isBlockedAnimation) {
        final historyIndex = positionHistory.length - 1 - currentAnimationStep;
        if (historyIndex >= 0) {
          visualPositions = List<Map<String, int>>.from(
            positionHistory[historyIndex].map(
              (pos) => Map<String, int>.from(pos),
            ),
          );
        }

        currentAnimationStep++;

        if (currentAnimationStep >= positionHistory.length) {
          positionHistory.clear();
          isAnimating = false;
          isBlockedAnimation = false;
          maxForwardStepsThisRun = 0;
          canClearThisRun = false;

          grid.setVineAnimationState(vineData.id, VineAnimationState.normal);
        }
        return true;
      }

      if (currentAnimationStep < maxForwardStepsThisRun) {
        if (currentAnimationStep + 1 >= maxForwardStepsThisRun &&
            !canClearThisRun) {
          logDebug(
            'Marking vine attempted before reaching blocker: vineId=${vineData.id}, '
            'step=$currentAnimationStep, maxDistance=$maxForwardStepsThisRun',
          );
          grid.markVineAttempted(vineData.id);
        }

        positionHistory.add(
          List<Map<String, int>>.from(
            visualPositions.map((pos) => Map<String, int>.from(pos)),
          ),
        );

        _stepForward();

        currentAnimationStep++;

        if (currentAnimationStep >= maxForwardStepsThisRun &&
            !canClearThisRun) {
          logDebug(
            'Reached blocker cell, starting reverse: vineId=${vineData.id}, '
            'step=$currentAnimationStep, maxDistance=$maxForwardStepsThisRun, '
            'headPos=(${visualPositions[0]['x']},${visualPositions[0]['y']})',
          );
          isBlockedAnimation = true;
          currentAnimationStep = 0;
          return true;
        }
      } else if (willClearAfterAnimation) {
        positionHistory.add(
          List<Map<String, int>>.from(
            visualPositions.map((pos) => Map<String, int>.from(pos)),
          ),
        );

        _stepForward();
        currentAnimationStep++;

        if (hasExitedVisibleGrid(grid.getCurrentLevelData())) {
          onHeadExitedGrid();
        }

        if (currentAnimationStep >= totalAnimationSteps) {
          logDebug(
            'Animation steps timeout fallback: vineId=${vineData.id}, '
            'starting bloom effect',
          );
          onHeadExitedGrid();
        }
      } else if (!canClearThisRun) {
        isBlockedAnimation = true;
        currentAnimationStep = 0;
      }
    }

    return true;
  }

  void _stepForward() {
    final headIndex = 0;
    final headPos = visualPositions[headIndex];
    var newHeadX = headPos['x'] as int;
    var newHeadY = headPos['y'] as int;

    switch (vineData.headDirection) {
      case 'right':
        newHeadX += 1;
        break;
      case 'left':
        newHeadX -= 1;
        break;
      case 'up':
        newHeadY += 1;
        break;
      case 'down':
        newHeadY -= 1;
        break;
    }

    var prevX = headPos['x'] as int;
    var prevY = headPos['y'] as int;

    for (int i = 1; i < visualPositions.length; i++) {
      final tempX = visualPositions[i]['x'] as int;
      final tempY = visualPositions[i]['y'] as int;

      visualPositions[i]['x'] = prevX;
      visualPositions[i]['y'] = prevY;

      prevX = tempX;
      prevY = tempY;
    }

    visualPositions[headIndex]['x'] = newHeadX;
    visualPositions[headIndex]['y'] = newHeadY;
  }

  bool hasExitedVisibleGrid(LevelData? level) {
    if (level == null || visualPositions.isEmpty) return true;
    final headPos = visualPositions[0];
    final x = headPos['x'] as int;
    final y = headPos['y'] as int;

    return x < 0 || x >= level.gridWidth || y < 0 || y >= level.gridHeight;
  }

  bool isFullyOffScreen(LevelData? level) {
    if (level == null || visualPositions.isEmpty) return true;
    final gridCols = level.gridWidth;
    final gridRows = level.gridHeight;
    const int offScreenMargin = 3;

    for (final pos in visualPositions) {
      final x = pos['x'] as int;
      final y = pos['y'] as int;

      if (x >= -offScreenMargin &&
          x < gridCols + offScreenMargin &&
          y >= -offScreenMargin &&
          y < gridRows + offScreenMargin) {
        return false;
      }
    }

    return true;
  }

  void reset() {
    isAnimating = false;
    willClearAfterAnimation = false;
    positionHistory.clear();
    currentAnimationStep = 0;
    totalAnimationSteps = 0;
    maxForwardStepsThisRun = 0;
    canClearThisRun = false;
    animationTimer = 0.0;
  }
}
