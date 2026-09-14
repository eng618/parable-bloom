import 'package:parable_bloom/core/constants/animation_timing.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/presentation/widgets/grid_component.dart';

class VineAnimator {
  final VineData vineData;
  bool isAnimating = false;
  bool willClearAfterAnimation = false;

  List<Map<String, int>> visualPositions = [];

  /// Bumped every time [visualPositions] changes, so renderers can cache
  /// derived geometry and only rebuild on actual movement.
  int visualVersion = 0;

  int currentAnimationStep = 0;
  int totalAnimationSteps = 0;
  int maxForwardStepsThisRun = 0;
  bool canClearThisRun = false;
  double animationTimer = 0.0;
  double stepDuration = AnimationTiming.vineStepSeconds;

  List<List<int>> positionHistory = [];
  bool isBlockedAnimation = false;

  /// Snapshot current head-to-tail positions as a flat [x0,y0,x1,y1,...]
  /// list. Flat ints avoid the per-step `Map.from` deep copies that used to
  /// allocate N maps per animation step.
  List<int> _snapshotFlat() {
    final flat = List<int>.filled(visualPositions.length * 2, 0);
    for (int i = 0; i < visualPositions.length; i++) {
      final pos = visualPositions[i];
      flat[i * 2] = pos['x'] ?? 0;
      flat[i * 2 + 1] = pos['y'] ?? 0;
    }
    return flat;
  }

  /// Restore a flat snapshot in place: mutates the existing maps instead of
  /// allocating a new outer list + N new maps.
  void _restore(List<int> flat) {
    final count = flat.length ~/ 2;
    for (int i = 0; i < count && i < visualPositions.length; i++) {
      visualPositions[i]['x'] = flat[i * 2];
      visualPositions[i]['y'] = flat[i * 2 + 1];
    }
    visualVersion++;
  }

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

    positionHistory.clear();
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
        if (historyIndex >= 0 && historyIndex < positionHistory.length) {
          _restore(positionHistory[historyIndex]);
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
          _snapshotFlat(),
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
          _snapshotFlat(),
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
    if (visualPositions.isEmpty) return;
    final positions = visualPositions;
    final headPos = positions[0];
    var newHeadX = headPos['x'] ?? 0;
    var newHeadY = headPos['y'] ?? 0;

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

    var prevX = headPos['x'] ?? 0;
    var prevY = headPos['y'] ?? 0;

    for (int i = 1; i < positions.length; i++) {
      final cell = positions[i];
      final tempX = cell['x'] ?? 0;
      final tempY = cell['y'] ?? 0;

      cell['x'] = prevX;
      cell['y'] = prevY;

      prevX = tempX;
      prevY = tempY;
    }

    headPos['x'] = newHeadX;
    headPos['y'] = newHeadY;
    visualVersion++;
  }

  bool hasExitedVisibleGrid(LevelData? level) {
    if (level == null || visualPositions.isEmpty) return true;
    final headPos = visualPositions[0];
    final x = headPos['x'] ?? 0;
    final y = headPos['y'] ?? 0;

    return x < 0 || x >= level.gridWidth || y < 0 || y >= level.gridHeight;
  }

  bool isFullyOffScreen(LevelData? level) {
    if (level == null || visualPositions.isEmpty) return true;
    final gridCols = level.gridWidth;
    final gridRows = level.gridHeight;
    const int offScreenMargin = 3;

    for (final pos in visualPositions) {
      final x = pos['x'] ?? 0;
      final y = pos['y'] ?? 0;

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
