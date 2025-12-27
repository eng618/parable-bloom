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
  double _animationTimer = 0.0;
  double _stepDuration = 0.1; // seconds per step

  // History-based animation (snake-like movement)
  List<List<Map<String, int>>> _positionHistory = [];
  bool _isBlockedAnimation = false;

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



  void slideOut() {
    if (_isAnimating) return;
    _isAnimating = true;

    // Initialize history-based animation
    _positionHistory = [];
    _currentAnimationStep = 0;
    _isBlockedAnimation = false;
    _animationTimer = 0.0;

    final rawDistance = _calculateMovementDistance();
    final canClear = rawDistance > 0;
    final maxDistance = rawDistance.abs();

    if (canClear) {
      // Vine can reach edge - calculate steps needed to exit completely
      _totalAnimationSteps = maxDistance + vineData.orderedPath.length;
      _willClearAfterAnimation = true;
    } else {
      // Vine is blocked - move forward to blocker, then reverse
      _totalAnimationSteps = maxDistance * 2;
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

      if (_isBlockedAnimation) {
        // Animate backwards through history
        final historyIndex =
            _positionHistory.length - 1 - _currentAnimationStep;
        if (historyIndex >= 0) {
          // Set vine positions to historical state
          _currentVisualPositions = List<Map<String, int>>.from(
            _positionHistory[historyIndex].map(
              (pos) => Map<String, int>.from(pos),
            ),
          );
        }

        _currentAnimationStep++;

        if (_currentAnimationStep >= _positionHistory.length) {
          // Finished reverse animation
          _positionHistory.clear();
          _isAnimating = false;
          _isBlockedAnimation = false;
        }
        return;
      }

      // Normal forward movement (history-based snake animation)
      final rawDistance = _calculateMovementDistance();
      final canClear = rawDistance > 0;
      final maxForwardDistance = rawDistance.abs();

      if (_currentAnimationStep <= maxForwardDistance) {
        // Save current positions to history
        _positionHistory.add(
          List<Map<String, int>>.from(
            _currentVisualPositions.map((pos) => Map<String, int>.from(pos)),
          ),
        );

        // Move head based on direction
        final headIndex = 0;
        final headPos = _currentVisualPositions[headIndex];
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
            newHeadY += 1; // Up increases y
            break;
          case 'down':
            newHeadY -= 1; // Down decreases y
            break;
        }

        // Update each following segment to previous segment's old position
        var prevX = headPos['x'] as int;
        var prevY = headPos['y'] as int;

        for (int i = 1; i < _currentVisualPositions.length; i++) {
          final tempX = _currentVisualPositions[i]['x'] as int;
          final tempY = _currentVisualPositions[i]['y'] as int;

          _currentVisualPositions[i]['x'] = prevX;
          _currentVisualPositions[i]['y'] = prevY;

          prevX = tempX;
          prevY = tempY;
        }

        // Move head to new position
        _currentVisualPositions[headIndex]['x'] = newHeadX;
        _currentVisualPositions[headIndex]['y'] = newHeadY;

        _currentAnimationStep++;

        // Check if we've reached the blocker
        if (_currentAnimationStep > maxForwardDistance && !canClear) {
          // Hit blocker - start reverse animation
          parent.markVineAttempted(vineData.id);
          _isBlockedAnimation = true;
          _currentAnimationStep = 0;
        }
      } else if (_willClearAfterAnimation) {
        // Continue moving off screen for clearing vines
        // Save current positions to history
        _positionHistory.add(
          List<Map<String, int>>.from(
            _currentVisualPositions.map((pos) => Map<String, int>.from(pos)),
          ),
        );

        // Move head further in direction
        final headIndex = 0;
        final headPos = _currentVisualPositions[headIndex];
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
            newHeadY += 1; // Up increases y
            break;
          case 'down':
            newHeadY -= 1; // Down decreases y
            break;
        }

        // Update each following segment to previous segment's old position
        var prevX = headPos['x'] as int;
        var prevY = headPos['y'] as int;

        for (int i = 1; i < _currentVisualPositions.length; i++) {
          final tempX = _currentVisualPositions[i]['x'] as int;
          final tempY = _currentVisualPositions[i]['y'] as int;

          _currentVisualPositions[i]['x'] = prevX;
          _currentVisualPositions[i]['y'] = prevY;

          prevX = tempX;
          prevY = tempY;
        }

        // Move head to new position
        _currentVisualPositions[headIndex]['x'] = newHeadX;
        _currentVisualPositions[headIndex]['y'] = newHeadY;

        _currentAnimationStep++;

        // Check if all segments are off screen
        final gridRows = parent.getCurrentLevelData()!.gridSize[0];
        final gridCols = parent.getCurrentLevelData()!.gridSize[1];
        bool allOffScreen = true;

        for (final pos in _currentVisualPositions) {
          final x = pos['x'] as int;
          final y = pos['y'] as int;
          if (x >= 0 && x < gridCols && y >= 0 && y < gridRows) {
            allOffScreen = false;
            break;
          }
        }

        if (allOffScreen || _currentAnimationStep >= _totalAnimationSteps) {
          // Vine cleared off screen
          parent.notifyVineCleared(vineData.id);
          removeFromParent();
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



  void slideBump(int distanceInCells) {
    if (_isAnimating) return;
    _isAnimating = true;

    // Initialize bump animation state
    _currentAnimationStep = 0;
    _totalAnimationSteps = distanceInCells * 2; // forward + backward
    _animationTimer = 0.0;
    _stepDuration = 0.05; // faster for bump animation
    // Note: slideBump not implemented with history-based animation yet
  }
}