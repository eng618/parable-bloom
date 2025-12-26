import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../providers/game_providers.dart';
import 'grid_component.dart';

class VineComponent extends PositionComponent with ParentIsA<GridComponent> {
  final VineData vineData;
  final double cellSize;
  final int gridSize;

  bool _isAnimating = false;
  bool _willClearAfterAnimation =
      false; // Whether this vine should be cleared when animation completes

  // Track current visual positions during animation (separate from vineData.path)
  List<Map<String, int>> _currentVisualPositions = [];

  // Animation state
  int _currentAnimationStep = 0;
  int _totalAnimationSteps = 0;
  bool _isMovingForward = true;
  double _animationTimer = 0.0;
  double _stepDuration = 0.1; // seconds per step

  VineComponent({
    required this.vineData,
    required this.cellSize,
    required this.gridSize,
  }) {
    // Initialize visual positions immediately to avoid render issues
    // Convert from Map<String, int> (x,y) to Map<String, int>
    _currentVisualPositions = vineData.orderedPath.map((cell) {
      return {'x': cell['x'] as int, 'y': cell['y'] as int};
    }).toList();
  }

  @override
  Future<void> onLoad() async {
    // Initial position is zero within GridComponent coordinate space
    position = Vector2.zero();
    size = parent.size;

    // Visual positions are already initialized in constructor
    // This is just for logging

    debugPrint('VineComponent loaded for vine ${vineData.id}');
    debugPrint(
      'Vine ordered path: ${vineData.orderedPath.map((p) => "(${p['x']},${p['y']})").join(' -> ')}',
    );
    debugPrint('Head direction: ${vineData.headDirection}');
    debugPrint('Calculated direction: ${_calculateVineDirection()}');
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final vineState = parent.getCurrentVineState(vineData.id);
    if (vineState == null || (vineState.isCleared && !_isAnimating)) return;

    final isBlocked = vineState.isBlocked;
    final isAttempted = vineState.hasBeenAttempted;

    // Use centralized theme colors
    final baseColor = isAttempted ? AppTheme.vineAttempted : AppTheme.vineGreen;

    // Calculate direction from vine data
    final direction = _calculateVineDirection();

    // Draw line segments connecting cells (tails)
    final segmentPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < _currentVisualPositions.length - 1; i++) {
      final currentCell = _currentVisualPositions[i];
      final nextCell = _currentVisualPositions[i + 1];

      final currentX = currentCell['x'] as int;
      final currentY = currentCell['y'] as int;
      final nextX = nextCell['x'] as int;
      final nextY = nextCell['y'] as int;

      final start = Offset(
        currentX * cellSize + cellSize / 2,
        (gridSize - 1 - currentY) * cellSize + cellSize / 2,
      );
      final end = Offset(
        nextX * cellSize + cellSize / 2,
        (gridSize - 1 - nextY) * cellSize + cellSize / 2,
      );

      canvas.drawLine(start, end, segmentPaint);
    }

    // Draw dots and heads
    for (int i = 0; i < _currentVisualPositions.length; i++) {
      final cell = _currentVisualPositions[i];
      final x = cell['x'] as int;
      final y = cell['y'] as int;
      final visualRow = gridSize - 1 - y;

      final isHead = direction != null && i == 0; // Head is at position 0

      final rect = Rect.fromCenter(
        center: Offset(
          x * cellSize + cellSize / 2,
          visualRow * cellSize + cellSize / 2,
        ),
        width: cellSize * 0.6,
        height: cellSize * 0.6,
      );

      if (isHead) {
        _drawArrowHead(
          canvas,
          rect,
          baseColor,
          direction,
          isBlocked,
          isAttempted,
        );
      } else {
        final bodyPaint = Paint()
          ..color = baseColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(rect.center, 3, bodyPaint);
      }
    }
  }

  void _drawArrowHead(
    Canvas canvas,
    Rect rect,
    Color color,
    String direction,
    bool isBlocked,
    bool isAttempted,
  ) {
    final center = rect.center;
    final path = Path();

    final scale = 0.45;
    final h = rect.height * scale;
    final w = rect.width * scale;

    final left = center.dx - w / 2;
    final right = center.dx + w / 2;
    final top = center.dy - h / 2;
    final bottom = center.dy + h / 2;

    switch (direction) {
      case 'right':
        path.moveTo(left, top + h * 0.1);
        path.lineTo(right, center.dy);
        path.lineTo(left, bottom - h * 0.1);
        path.close();
        break;
      case 'left':
        path.moveTo(right, top + h * 0.1);
        path.lineTo(left, center.dy);
        path.lineTo(right, bottom - h * 0.1);
        path.close();
        break;
      case 'down':
        path.moveTo(left + w * 0.1, top);
        path.lineTo(right - w * 0.1, top);
        path.lineTo(center.dx, bottom);
        path.close();
        break;
      case 'up':
        path.moveTo(left + w * 0.1, bottom);
        path.lineTo(right - w * 0.1, bottom);
        path.lineTo(center.dx, top);
        path.close();
        break;
    }

    final shadowPaint = Paint()
      ..color = Colors.black45
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path.shift(const Offset(2, 2)), shadowPaint);

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, arrowPaint);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 1.0 * 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }

  String? _calculateVineDirection() {
    // Direction comes directly from the level data, not calculated from positions
    return vineData.headDirection;
  }

  String? _calculateVineDirectionFromPositions(
    List<Map<String, int>> positions,
  ) {
    if (positions.length < 2) return 'right';

    // positions[0] is head, positions[1] is first segment
    final headCell = positions[0];
    final nextCell = positions[1];

    final headX = headCell['x'] as int;
    final headY = headCell['y'] as int;
    final nextX = nextCell['x'] as int;
    final nextY = nextCell['y'] as int;

    if (headX < nextX) return 'right';
    if (headX > nextX) return 'left';
    if (headY < nextY) return 'down'; // Down increases y
    if (headY > nextY) return 'up'; // Up decreases y

    return 'right';
  }

  void slideOut() {
    if (_isAnimating) return;
    _isAnimating = true;

    // Initialize animation state
    final rawDistance = _calculateMovementDistance();
    _currentAnimationStep = 0;
    _isMovingForward = true;
    _animationTimer = 0.0;

    // Calculate animation parameters based on whether vine can clear
    final canClear = rawDistance > 0;
    final maxDistance = rawDistance.abs();

    if (canClear) {
      // Vine can reach edge - animate until completely off screen
      // Add extra steps to ensure all segments exit the grid
      _totalAnimationSteps = maxDistance + vineData.orderedPath.length;
      _willClearAfterAnimation = true;
    } else {
      // Vine is blocked - animate to blocker, bump, then reverse
      _totalAnimationSteps =
          maxDistance * 2; // Forward to blocker + reverse back
      _willClearAfterAnimation = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!_isAnimating) return;

    _animationTimer += dt;

    if (_animationTimer >= _stepDuration) {
      _animationTimer = 0.0;

      final rawDistance = _calculateMovementDistance();
      final canClear = rawDistance > 0;
      final maxForwardDistance = rawDistance.abs();

      // Handle animation phases
      if (_isMovingForward) {
        if (_currentAnimationStep < maxForwardDistance) {
          // Still moving forward in snake animation
        } else if (!canClear && _currentAnimationStep == maxForwardDistance) {
          // Reached the blocker - do bump effect and mark as attempted
          parent.markVineAttempted(vineData.id);
          // Continue to next step for reverse animation
        }
      } else {
        // Moving backward to original position
      }

      // Calculate which step to use for position calculation
      int positionStep;
      if (_isMovingForward) {
        positionStep = _currentAnimationStep;
      } else {
        // Reverse phase: calculate backward step
        final reverseStep = _currentAnimationStep - maxForwardDistance;
        positionStep = maxForwardDistance - reverseStep - 1;
      }

      // Update each segment's position for this step
      for (
        int segmentIndex = 0;
        segmentIndex < _currentVisualPositions.length;
        segmentIndex++
      ) {
        final targetPosition = _calculateSegmentTargetPosition(
          segmentIndex,
          positionStep,
          _isMovingForward,
        );

        if (targetPosition != null) {
          final targetX = targetPosition['x'];
          final targetY = targetPosition['y'];
          if (targetX != null && targetY != null) {
            _currentVisualPositions[segmentIndex] = {
              'x': targetX,
              'y': targetY,
            };
          }
        }
      }

      _currentAnimationStep++;

      // Check for phase transitions
      if (_isMovingForward &&
          _currentAnimationStep > maxForwardDistance &&
          !canClear) {
        // Finished forward phase for blocked vine - start reverse phase
        _isMovingForward = false;
      } else if (_currentAnimationStep >= _totalAnimationSteps) {
        // Animation complete
        if (_willClearAfterAnimation) {
          // Vine cleared off screen
          parent.notifyVineCleared(vineData.id);
          removeFromParent();
        } else {
          // Vine returned to original position
          _isAnimating = false;
        }
      }
    }
  }

  int _calculateMovementDistance() {
    // Get distance from LevelSolver - this tells us how far we can move before being blocked
    final activeIds = parent.getActiveVineIds();
    return LevelSolver.getDistanceToBlocker(
      parent.getCurrentLevelData()!,
      vineData.id,
      activeIds,
    );
  }

  Map<String, int>? _calculateSegmentTargetPosition(
    int segmentIndex,
    int step,
    bool forward,
  ) {
    // Calculate position for each segment at the given animation step
    // For forward movement: head moves step positions forward, body follows
    // For reverse movement: head moves backward, body follows

    final originalHead = vineData.orderedPath[0];
    final headX = originalHead['x'] as int;
    final headY = originalHead['y'] as int;

    // Calculate effective step (negative for reverse)
    final effectiveStep = forward ? step : -step;

    // Calculate direction deltas
    var deltaX = 0;
    var deltaY = 0;
    switch (vineData.headDirection) {
      case 'right':
        deltaX = 1;
        break;
      case 'left':
        deltaX = -1;
        break;
      case 'up':
        deltaY = 1; // Up increases y
        break;
      case 'down':
        deltaY = -1; // Down decreases y
        break;
    }

    // For each segment: position = original_position + (effectiveStep - segmentIndex) * direction
    // This creates the snake-like following behavior
    final segmentStep = effectiveStep - segmentIndex;

    return {
      'x': headX + segmentStep * deltaX,
      'y': headY + segmentStep * deltaY,
    };
  }

  String _getReverseDirection(String direction) {
    switch (direction) {
      case 'right':
        return 'left';
      case 'left':
        return 'right';
      case 'up':
        return 'down';
      case 'down':
        return 'up';
      default:
        return direction;
    }
  }

  void slideBump(int distanceInCells) {
    if (_isAnimating) return;
    _isAnimating = true;

    // Initialize bump animation state
    _currentAnimationStep = 0;
    _totalAnimationSteps = distanceInCells * 2; // forward + backward
    _isMovingForward = true;
    _animationTimer = 0.0;
    _stepDuration = 0.05; // faster for bump animation
  }
}
