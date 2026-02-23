import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../../providers/game_providers.dart';
import 'garden_game.dart';

/// Component that renders projection lines from vine heads
/// extending in their facing direction off-screen
class ProjectionLinesComponent extends PositionComponent
    with ParentIsA<GardenGame> {
  final double cellSize;

  LevelData? _currentLevel;
  bool _isVisible = false;

  // Camera transform properties
  double _screenWidth = 0.0;
  double _screenHeight = 0.0;

  ProjectionLinesComponent({required this.cellSize}) : super(priority: 5);

  void setLevelData(LevelData levelData) {
    _currentLevel = levelData;

    // Update size
    final cols = levelData.gridWidth;
    final rows = levelData.gridHeight;
    size = Vector2(cols * cellSize, rows * cellSize);

    // Position will be set by camera transform
    // Initialize with centered position if camera not yet applied
    if (_screenWidth == 0.0 || _screenHeight == 0.0) {
      position = Vector2(
        (parent.size.x - width) / 2,
        (parent.size.y - height) / 2,
      );
    }
  }

  void setVisible(bool visible) {
    _isVisible = visible;
  }

  // Apply camera transform (zoom and pan)
  void applyCameraTransform({
    required double zoom,
    required Vector2 panOffset,
    required double screenWidth,
    required double screenHeight,
  }) {
    _screenWidth = screenWidth;
    _screenHeight = screenHeight;

    // Update scale
    scale = Vector2.all(zoom);

    // Calculate scaled dimensions
    if (_currentLevel != null) {
      final scaledWidth = _currentLevel!.gridWidth * cellSize * zoom;
      final scaledHeight = _currentLevel!.gridHeight * cellSize * zoom;

      // Calculate centered position with pan offset
      final centeredX = (screenWidth - scaledWidth) / 2;
      final centeredY = (screenHeight - scaledHeight) / 2;

      position = Vector2(
        centeredX + panOffset.x,
        centeredY + panOffset.y,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (!_isVisible || _currentLevel == null) return;

    // Get vine states to check which vines are cleared or animating
    final vineStates = parent.ref.read(vineStatesProvider);

    // Paint for projection lines - semi-transparent gray
    final linePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final visualHeight = _currentLevel!.gridHeight;

    // Draw projection line for each active vine head
    for (final vine in _currentLevel!.vines) {
      final vineState = vineStates[vine.id];

      // Skip if vine is cleared or animating
      if (vineState == null ||
          vineState.isCleared ||
          vineState.animationState == VineAnimationState.animatingClear) {
        continue;
      }

      // Get head position (first position in ordered_path)
      if (vine.orderedPath.isEmpty) continue;

      final headCell = vine.orderedPath[0];
      final headX = headCell['x'] as int;
      final headY = headCell['y'] as int;

      // Transform to visual coordinates (y=0 at bottom)
      final visualY = visualHeight - 1 - headY;

      // Get head center position (relative to this component)
      final headCenter = Offset(
        headX * cellSize + cellSize / 2,
        visualY * cellSize + cellSize / 2,
      );

      // Calculate direction vector
      final direction = vine.headDirection;
      Offset directionVector;

      switch (direction) {
        case 'right':
          directionVector = const Offset(1, 0);
          break;
        case 'left':
          directionVector = const Offset(-1, 0);
          break;
        case 'up':
          directionVector = const Offset(0, -1);
          break;
        case 'down':
          directionVector = const Offset(0, 1);
          break;
        default:
          continue; // Skip if direction is unknown
      }

      // Calculate end point far off-screen
      // Extend the line to go well beyond the visible area
      final maxDimension = (_currentLevel!.gridWidth > _currentLevel!.gridHeight
              ? _currentLevel!.gridWidth
              : _currentLevel!.gridHeight) *
          cellSize;
      final extensionLength = maxDimension * 2; // Go 2x the max dimension

      final endPoint = Offset(
        headCenter.dx + directionVector.dx * extensionLength,
        headCenter.dy + directionVector.dy * extensionLength,
      );

      // Draw the projection line
      canvas.drawLine(headCenter, endPoint, linePaint);
    }
  }
}
