// lib/game/components/grid_component.dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/geometry.dart';
import 'package:flutter/material.dart';

import '../garden_game.dart';

// TODO: Add vine rendering system
// This component will eventually render actual vine sprites
// For now, it renders placeholder colored rectangles

class GridComponent extends PositionComponent
    with TapCallbacks, ParentIsA<GardenGame> {
  final int gridSize;
  final double cellSize;

  late List<List<CellComponent>> cells;

  // TODO: Replace with actual vine system from GAME_DESIGN.md
  // Placeholder vine data - replace with actual level loading system
  // Each vine has: id, color, cells (list of {row, col}), and calculated direction
  final List<Map<String, dynamic>> placeholderVines = [
    {
      'id': 'vine_1',
      'color': const Color(0xFF8B4513), // Brown vine - can move right
      'cells': [
        {'row': 1, 'col': 1},
        {'row': 1, 'col': 2},
        {'row': 1, 'col': 3},
      ],
      'direction': 'right', // Head is at col 3 (right edge), can move right
    },
    {
      'id': 'vine_2',
      'color': const Color(0xFF6B8E23), // Green vine - can move down
      'cells': [
        {'row': 3, 'col': 3},
        {'row': 4, 'col': 3},
        {'row': 5, 'col': 3},
      ],
      'direction': 'down', // Head is at row 5 (bottom edge), can move down
    },
    {
      'id': 'vine_3',
      'color': const Color(0xFF6B8E23), // Green vertical vine - blocked
      'cells': [
        {'row': 1, 'col': 4},
        {'row': 2, 'col': 4},
        {'row': 3, 'col': 4},
      ],
      'direction': null, // Blocked - cannot move off grid
    },
  ];

  GridComponent({required this.gridSize, required this.cellSize})
    : super(position: Vector2.zero());

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

    // TODO: Replace with actual vine sprite rendering
    // Render placeholder vines with arrow heads for movable vines
    for (final vine in placeholderVines) {
      final color = vine['color'] as Color;
      final cells = vine['cells'] as List<Map<String, dynamic>>;
      final direction = vine['direction'] as String?;

      if (cells.isEmpty) continue;

      for (int i = 0; i < cells.length; i++) {
        final cell = cells[i];
        final row = cell['row'] as int;
        final col = cell['col'] as int;

        final isHead = direction != null && i == cells.length - 1; // Last cell is head

        final rect = Rect.fromLTWH(
          col * cellSize + 5,
          row * cellSize + 5,
          cellSize - 10,
          cellSize - 10,
        );

        if (isHead && direction != null) {
          // Draw arrow/triangle head
          _drawArrowHead(canvas, rect, color, direction);
        } else {
          // Draw body segment as rectangle
          final vinePaint = Paint()..color = color.withValues(alpha: 0.8 * 255);
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

  void _drawArrowHead(Canvas canvas, Rect rect, Color color, String direction) {
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

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, arrowPaint);

    // Add border
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.8 * 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }

  // Handle cell tap from child CellComponent
  void handleCellTap(int row, int col) {
    final clickedVine = _getVineAtCell(row, col);

    if (clickedVine != null && clickedVine['direction'] != null) {
      // Vine can be moved - trigger animation
      _animateVineOffScreen(clickedVine);
      debugPrint('Clicked movable vine: ${clickedVine['id']}');
    } else {
      debugPrint('Tapped empty cell or blocked vine: ($row, $col)');
    }
  }

  Map<String, dynamic>? _getVineAtCell(int row, int col) {
    for (final vine in placeholderVines) {
      final cells = vine['cells'] as List<Map<String, dynamic>>;
      for (final cell in cells) {
        if (cell['row'] == row && cell['col'] == col) {
          return vine;
        }
      }
    }
    return null;
  }

  void _animateVineOffScreen(Map<String, dynamic> vine) {
    final direction = vine['direction'] as String;
    final vineId = vine['id'] as String;

    // Calculate animation direction vector
    Vector2 directionVector;
    switch (direction) {
      case 'right':
        directionVector = Vector2(1, 0);
        break;
      case 'left':
        directionVector = Vector2(-1, 0);
        break;
      case 'down':
        directionVector = Vector2(0, 1);
        break;
      case 'up':
        directionVector = Vector2(0, -1);
        break;
      default:
        return; // Invalid direction
    }

    // Remove the vine from the placeholder data (simulate clearing)
    placeholderVines.removeWhere((v) => v['id'] == vineId);

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
    paint.color = Colors.white.withOpacity(0.3);
    Future.delayed(const Duration(milliseconds: 200), () {
      paint.color = Colors.transparent;
      update(0);
    });
  }
}
