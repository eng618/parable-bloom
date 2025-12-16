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

    for (int row = 0; row < gridSize; row++) {
      cells.add([]);
      for (int col = 0; col < gridSize; col++) {
        final cell = CellComponent(
          row: row,
          col: col,
          size: Vector2(cellSize, cellSize),
          position: Vector2(col * cellSize, row * cellSize),
        );
        add(cell);
        cells[row].add(cell);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_currentLevel == null) return;

    // Render all vines with arrows - blocked vs free indicated by arrow style
    for (final vine in _currentLevel!.vines) {
      final vineState = _vineStates[vine.id];
      if (vineState == null || vineState.isCleared) continue;

      final color = Color(int.parse(vine.color.replaceFirst('#', '0xFF')));
      final isBlocked = vineState.isBlocked;

      // Calculate direction from vine path
      final direction = _calculateVineDirection(vine);

      for (int i = 0; i < vine.path.length; i++) {
        final cell = vine.path[i];
        final row = cell['row'] as int;
        final col = cell['col'] as int;

        final isHead = direction != null && i == vine.path.length - 1; // Last cell is head

        final rect = Rect.fromLTWH(
          col * cellSize + 5,
          row * cellSize + 5,
          cellSize - 10,
          cellSize - 10,
        );

        if (isHead && direction != null) {
          // Draw arrow head - style indicates blocked vs free
          _drawArrowHead(canvas, rect, color, direction, isBlocked);
        } else {
          // Draw body segment as rectangle
          final alpha = isBlocked ? 0.5 : 0.8; // Dim blocked vines
          final vinePaint = Paint()..color = color.withValues(alpha: alpha * 255);
          canvas.drawRect(rect, vinePaint);

          // Add subtle border
          final borderPaint = Paint()
            ..color = color.withValues(alpha: 1.0 * 255)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          canvas.drawRect(rect, borderPaint);
        }
      }
    }


  }

  void _drawArrowHead(Canvas canvas, Rect rect, Color color, String direction, bool isBlocked) {
    final center = rect.center;
    final path = Path();

    switch (direction) {
      case 'right':
        // Arrow pointing right
        path.moveTo(rect.left, rect.top);
        path.lineTo(rect.right, center.dy);
        path.lineTo(rect.left, rect.bottom);
        path.close();
        break;
      case 'left':
        // Arrow pointing left
        path.moveTo(rect.right, rect.top);
        path.lineTo(rect.left, center.dy);
        path.lineTo(rect.right, rect.bottom);
        path.close();
        break;
      case 'down':
        // Arrow pointing down
        path.moveTo(rect.left, rect.top);
        path.lineTo(rect.right, rect.top);
        path.lineTo(center.dx, rect.bottom);
        path.close();
        break;
      case 'up':
        // Arrow pointing up
        path.moveTo(rect.left, rect.bottom);
        path.lineTo(rect.right, rect.bottom);
        path.lineTo(center.dx, rect.top);
        path.close();
        break;
    }

    // Blocked arrows are dimmed and have a different style
    final arrowColor = isBlocked ? color.withValues(alpha: 0.4 * 255) : color;
    final borderColor = isBlocked ? color.withValues(alpha: 0.3 * 255) : color.withValues(alpha: 0.8 * 255);

    final arrowPaint = Paint()
      ..color = arrowColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, arrowPaint);

    // Add border - blocked arrows have dashed/different style
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isBlocked ? 1 : 2;
    canvas.drawPath(path, borderPaint);

    // Add "X" mark on blocked arrows
    if (isBlocked) {
      final crossPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.6 * 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      // Draw X through the arrow
      canvas.drawLine(
        Offset(rect.left + 5, rect.top + 5),
        Offset(rect.right - 5, rect.bottom - 5),
        crossPaint,
      );
      canvas.drawLine(
        Offset(rect.right - 5, rect.top + 5),
        Offset(rect.left + 5, rect.bottom - 5),
        crossPaint,
      );
    }
  }

  // Handle cell tap from child CellComponent
  void handleCellTap(int row, int col) {
    final clickedVine = _getVineAtCell(row, col);

    if (clickedVine != null && _vineStates[clickedVine.id]?.isCleared == false && !(_vineStates[clickedVine.id]?.isBlocked ?? true)) {
      // Vine can be moved (not blocked) - trigger animation
      _clearVine(clickedVine.id);
      debugPrint('Clicked movable vine: ${clickedVine.id}');
    } else {
      debugPrint('Tapped empty cell or blocked vine: ($row, $col)');
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
    if (headRow > prevRow) return 'down';
    if (headRow < prevRow) return 'up';

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

    // Draw soft border
    final borderPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(size.toRect(), borderPaint);

    // Optional: Debug label
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: '$row,$col',
      style: const TextStyle(color: Colors.white38, fontSize: 14),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(4, 4));
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
