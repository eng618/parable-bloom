import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../providers/game_providers.dart';
import '../garden_game.dart';

// TODO: Add vine rendering system
// This component will eventually render actual vine sprites
// For now, it renders placeholder colored rectangles

class GridComponent extends PositionComponent with TapCallbacks, ParentIsA<GardenGame> {
  final int gridSize;
  final double cellSize;

  late List<List<CellComponent>> cells;

  // Current level data - will be set by Riverpod
  LevelData? _currentLevel;

  // Vine states - will be managed by Riverpod
  Map<String, VineState> _vineStates = {};

  // Callback to notify when level is complete
  final VoidCallback? onLevelComplete;

  // Callback to clear a vine in the Riverpod provider
  final Function(String)? onVineCleared;

  GridComponent({required this.gridSize, required this.cellSize, this.onLevelComplete, this.onVineCleared})
    : super(position: Vector2.zero());

  // Set level data and vine states from Riverpod providers
  void setLevelData(LevelData levelData, Map<String, VineState> vineStates) {
    _currentLevel = levelData;
    _vineStates = Map.from(vineStates);
    update(0); // Force redraw
  }

  @override
  Future<void> onLoad() async {
    size = Vector2(gridSize * cellSize, gridSize * cellSize);

    // Center the grid on screen
    position = Vector2(
      (parent.size.x - width) / 2,
      (parent.size.y - height) / 2,
    );

    cells = [];

      for (int rangeRow = 0; rangeRow < gridSize; rangeRow++) {
      cells.add([]);
      for (int col = 0; col < gridSize; col++) {
        // Use local variable for calculated visual row
        // Row 0 is at the bottom, so visual Y is proportional to (gridSize - 1 - row)
        final visualRow = gridSize - 1 - rangeRow;
        
        final cell = CellComponent(
          row: rangeRow,
          col: col,
          size: Vector2(cellSize, cellSize),
          position: Vector2(col * cellSize, visualRow * cellSize),
        );
        add(cell);
        cells[rangeRow].add(cell);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_currentLevel == null) return;

    for (final vine in _currentLevel!.vines) {
      final vineState = _vineStates[vine.id];
      if (vineState == null || vineState.isCleared) continue;

      final isBlocked = vineState.isBlocked;
      final isAttempted = vineState.hasBeenAttempted;
      
      // Standardize vine green
      const vineGreen = Color(0xFF8FBC8F);
      
      // The color persists as red if the vine was ever attempted while blocked,
      // even if it is currently unblocked.
      final baseColor = isAttempted ? Colors.red : vineGreen;

      // Calculate direction from vine path
      final direction = _calculateVineDirection(vine);

      // Draw line segments connecting cells (tails)
      final segmentAlpha = isBlocked ? 0.3 : 0.8;
      final segmentPaint = Paint()
        ..color = baseColor.withValues(alpha: segmentAlpha * 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < vine.path.length - 1; i++) {
        final currentCell = vine.path[i];
        final nextCell = vine.path[i + 1];
        
        final currentVisualRow = gridSize - 1 - (currentCell['row'] as int);
        final nextVisualRow = gridSize - 1 - (nextCell['row'] as int);
        
        final start = Offset(
          (currentCell['col'] as int) * cellSize + cellSize / 2,
          currentVisualRow * cellSize + cellSize / 2,
        );
        final end = Offset(
          (nextCell['col'] as int) * cellSize + cellSize / 2,
          nextVisualRow * cellSize + cellSize / 2,
        );
        
        canvas.drawLine(start, end, segmentPaint);
      }

      // Draw dots and heads
      for (int i = 0; i < vine.path.length; i++) {
        final cell = vine.path[i];
        final row = cell['row'] as int;
        final col = cell['col'] as int;
        
        // Calculate visual position based on bottom-left origin
        final visualRow = gridSize - 1 - row;

        final isHead = direction != null && i == vine.path.length - 1; // Last cell is head

        final rect = Rect.fromLTWH(
          col * cellSize + 5,
          visualRow * cellSize + 5,
          cellSize - 10,
          cellSize - 10,
        );

        if (isHead) {
          // Draw arrow head - style indicates blocked vs free
          _drawArrowHead(canvas, rect, baseColor, direction, isBlocked, isAttempted);
        } else {
          // Draw body segment dot
          final alpha = isBlocked ? 0.3 : 0.8; 
          
          final bodyPaint = Paint()
            ..color = baseColor.withValues(alpha: alpha * 255)
            ..style = PaintingStyle.fill;

          canvas.drawCircle(rect.center, 4, bodyPaint);
        }
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Rect rect, Color color, String? direction, bool isBlocked, bool isAttempted) {
    if (direction == null) return;
    
    final center = rect.center;
    final path = Path();
    
    // Reduce the effective size of the arrow head to be more minimalist
    final scale = 0.45; // Scale down further to 45% of original cell-rect width
    final h = rect.height * scale;
    final w = rect.width * scale;
    
    // Calculate centered box for the scaled arrow
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

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black45
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path.shift(const Offset(2, 2)), shadowPaint);

    // Blocked arrows are dimmed
    final arrowAlpha = isBlocked ? 0.4 : 0.9;
    final arrowPaint = Paint()
      ..color = color.withValues(alpha: arrowAlpha * 255)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, arrowPaint);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 1.0 * 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }

  // Handle cell tap from child CellComponent
  void handleCellTap(int row, int col) {
    final clickedVine = _getVineAtCell(row, col);

    if (clickedVine == null) return;

    final state = _vineStates[clickedVine.id];
    if (state == null || state.isCleared) return;

    if (!state.isBlocked) {
      // Vine can be moved (not blocked) - trigger animation
      _clearVine(clickedVine.id);
      debugPrint('Clicked movable vine: ${clickedVine.id}');
    } else {
      // Tapped a blocked vine - show visual feedback via provider
      debugPrint('Tapped blocked vine: ${clickedVine.id}');
      
      // Delegate to provider which handles life decrement and persistent state
      parent.ref.read(vineStatesProvider.notifier).markAttempted(clickedVine.id);
    }
  }

  VineData? _getVineAtCell(int row, int col) {
    if (_currentLevel == null) return null;

    for (final vine in _currentLevel!.vines) {
      for (final cell in vine.path) {
        if (cell['row'] == row && cell['col'] == col) {
          return vine;
        }
      }
    }
    return null;
  }

  String? _calculateVineDirection(VineData vine) {
    if (vine.path.length < 2) return 'right'; // Default for single cell

    final headCell = vine.path.last;
    final secondLastCell = vine.path[vine.path.length - 2];

    final headRow = headCell['row'] as int;
    final headCol = headCell['col'] as int;
    final prevRow = secondLastCell['row'] as int;
    final prevCol = secondLastCell['col'] as int;

    if (headCol > prevCol) return 'right';
    if (headCol < prevCol) return 'left';
    // With bottom-left origin (Row 0 is bottom):
    // If headRow > prevRow, it's moving UP (away from bottom)
    if (headRow > prevRow) return 'up';
    // If headRow < prevRow, it's moving DOWN (towards bottom)
    if (headRow < prevRow) return 'down';

    return 'right'; // Default
  }



  void _clearVine(String vineId) {
    // Update vine state to cleared
    _vineStates[vineId] = _vineStates[vineId]!.copyWith(isCleared: true);

    // Notify Riverpod provider
    onVineCleared?.call(vineId);

    // Trigger parable reveal animation (placeholder)
    debugPrint('Vine $vineId cleared! Trigger parable reveal animation');

    // TODO: Add particle effects and sound when vine is cleared
    // TODO: Gradually reveal parable background/image
    // TODO: Animate parable text appearing

    // Force redraw to show vine removed
    update(0);
  }
}

class CellComponent extends RectangleComponent
    with TapCallbacks, HasGameReference<GardenGame> {
  final int row;
  final int col;

  CellComponent({
    required this.row,
    required this.col,
    required super.size,
    required super.position,
  }) : super(
         paint: Paint()..color = Colors.transparent,
         anchor: Anchor.topLeft,
       );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw small dot in the center of the cell
    final center = size.toRect().center;
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15 * 255)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);
  }

  @override
  void onTapUp(TapUpEvent event) {
    // Delegate to parent GridComponent for vine handling
    (parent as GridComponent).handleCellTap(row, col);

    // Flash feedback
    paint.color = Colors.white.withValues(alpha: 0.3 * 255);
    Future.delayed(const Duration(milliseconds: 200), () {
      paint.color = Colors.transparent;
      update(0);
    });
  }
}
