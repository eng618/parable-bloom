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

  // Level completion state
  bool _levelComplete = false;

  // TODO: Replace with actual vine system from GAME_DESIGN.md
  // Placeholder vine data - NO overlapping cells (each cell holds max 1 vine segment)
  // Blocking occurs when arrow path hits another vine's segments in the movement direction
  final List<Map<String, dynamic>> placeholderVines = [
    {
      'id': 'vine_1',
      'color': const Color(0xFF8B4513), // Brown horizontal vine
      'cells': [
        {'row': 1, 'col': 1},
        {'row': 1, 'col': 2},
        {'row': 1, 'col': 3}, // Head points right
      ],
      // Arrow points right, path hits Vine 2's [2,4] segment immediately
    },
    {
      'id': 'vine_2',
      'color': const Color(0xFF6B8E23), // Green L-shaped vine
      'cells': [
        {'row': 2, 'col': 4}, // No overlap with Vine 1
        {'row': 3, 'col': 4},
        {'row': 3, 'col': 5}, // Head points down
      ],
      // Arrow points down, path hits Vine 3's [4,5] segment
    },
    {
      'id': 'vine_3',
      'color': const Color(0xFF6B8E23), // Green vertical vine
      'cells': [
        {'row': 4, 'col': 5}, // No overlap with Vine 2 ([3,5])
        {'row': 5, 'col': 5}, // Head points down
      ],
      // Arrow points down, clear path to bottom edge (no other vines in way)
    },
  ];

  GridComponent({required this.gridSize, required this.cellSize})
    : super(position: Vector2.zero()) {
    // Calculate which vines can move and in which direction
    _calculateVineDirections();
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

    // TODO: Replace with actual vine sprite rendering
    // Render all vines with arrows - blocked vs free indicated by arrow style
    for (final vine in placeholderVines) {
      final color = vine['color'] as Color;
      final cells = vine['cells'] as List<Map<String, dynamic>>;
      final direction = vine['direction'] as String?;
      final isBlocked = vine['isBlocked'] as bool? ?? true;

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

    // Render level complete overlay
    if (_levelComplete) {
      _drawLevelCompleteOverlay(canvas);
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

    if (clickedVine != null && clickedVine['direction'] != null && !(clickedVine['isBlocked'] as bool? ?? true)) {
      // Vine can be moved (not blocked) - trigger animation
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

  void _drawLevelCompleteOverlay(Canvas canvas) {
    // Semi-transparent background overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7 * 255);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), overlayPaint);

    // Level complete text
    const text = 'LEVEL COMPLETE!\n\nGood Job!';
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: size.x * 0.8);

    final textOffset = Offset(
      (size.x - textPainter.width) / 2,
      (size.y - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);

    // Add a subtle glow effect around the text
    final glowPaint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.3 * 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(
      Rect.fromCenter(
        center: textOffset + Offset(textPainter.width / 2, textPainter.height / 2),
        width: textPainter.width + 20,
        height: textPainter.height + 20,
      ),
      glowPaint,
    );
  }

  void _calculateVineDirections() {
    // All vines get arrows, but we check if their movement path is blocked
    // Horizontal vines point right, vertical vines point down
    // If arrow points to another vine segment, the vine is blocked
    // If arrow points to empty space off grid, the vine is free

    for (final vine in placeholderVines) {
      final cells = vine['cells'] as List<Map<String, dynamic>>;
      if (cells.isEmpty) continue;

      final headCell = cells.last; // Last cell is the head
      final headRow = headCell['row'] as int;
      final headCol = headCell['col'] as int;

      // Determine arrow direction based on vine orientation
      String arrowDirection;
      if (cells.length >= 2) {
        final secondLastCell = cells[cells.length - 2];
        final prevRow = secondLastCell['row'] as int;
        final prevCol = secondLastCell['col'] as int;

        // Determine direction from second-to-last cell to head
        if (headCol > prevCol) arrowDirection = 'right';
        else if (headCol < prevCol) arrowDirection = 'left';
        else if (headRow > prevRow) arrowDirection = 'down';
        else arrowDirection = 'up';
      } else {
        // Single cell vine - point right by default
        arrowDirection = 'right';
      }

      // Check if the arrow path is blocked (hits another vine segment)
      bool isBlocked = _isArrowPathBlocked(vine, arrowDirection);

      // Store both direction and blocked status
      vine['direction'] = arrowDirection;
      vine['isBlocked'] = isBlocked;

      debugPrint('Vine ${vine['id']}: arrow $arrowDirection, blocked: $isBlocked');
    }
  }

  bool _isArrowPathBlocked(Map<String, dynamic> vine, String direction) {
    final cells = vine['cells'] as List<Map<String, dynamic>>;
    final headCell = cells.last;
    final headRow = headCell['row'] as int;
    final headCol = headCell['col'] as int;

    // Check cells in the arrow direction for other vine segments
    int checkRow = headRow;
    int checkCol = headCol;

    while (true) {
      // Move in arrow direction
      switch (direction) {
        case 'right': checkCol++; break;
        case 'left': checkCol--; break;
        case 'down': checkRow++; break;
        case 'up': checkRow--; break;
      }

      // Check if we're off the grid (free path)
      if (checkRow < 0 || checkRow >= gridSize || checkCol < 0 || checkCol >= gridSize) {
        return false; // Path is clear to edge
      }

      // Check if this cell contains another vine segment
      for (final otherVine in placeholderVines) {
        if (otherVine['id'] == vine['id']) continue; // Skip self

        final otherCells = otherVine['cells'] as List<Map<String, dynamic>>;
        for (final otherCell in otherCells) {
          if (otherCell['row'] == checkRow && otherCell['col'] == checkCol) {
            return true; // Path is blocked by another vine
          }
        }
      }
    }
  }

  void _animateVineOffScreen(Map<String, dynamic> vine) {
    final direction = vine['direction'] as String;
    final vineId = vine['id'] as String;

    // TODO: Add smooth animation moving vine off screen in the direction
    // For now, just remove instantly

    // Remove the vine from the placeholder data (simulate clearing)
    placeholderVines.removeWhere((v) => v['id'] == vineId);

    // Check if level is complete (all vines cleared)
    if (placeholderVines.isEmpty) {
      _levelComplete = true;
      debugPrint('LEVEL COMPLETE! All vines cleared.');
    } else {
      // Recalculate directions for remaining vines (some may now be unblocked)
      _calculateVineDirections();
    }

    // Trigger parable reveal animation (placeholder)
    debugPrint('Vine $vineId cleared! Trigger parable reveal animation');

    // TODO: Add particle effects and sound when vine is cleared
    // TODO: Gradually reveal parable background/image
    // TODO: Animate parable text appearing

    // Force redraw to show vine removed, arrows updated, or level complete overlay
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
