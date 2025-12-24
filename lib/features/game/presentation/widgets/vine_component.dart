import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../providers/game_providers.dart';
import 'grid_component.dart';

class VineComponent extends PositionComponent with ParentIsA<GridComponent> {
  final VineData vineData;
  final double cellSize;
  final int gridSize;

  bool _isAnimating = false;

  VineComponent({
    required this.vineData,
    required this.cellSize,
    required this.gridSize,
  });

  @override
  Future<void> onLoad() async {
    // Initial position is zero within GridComponent coordinate space
    position = Vector2.zero();
    size = parent.size;

    debugPrint('VineComponent loaded for vine ${vineData.id}');
    debugPrint(
      'Vine path: ${vineData.path.map((p) => "(${p['row']},${p['col']})").join(' -> ')}',
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

    // Calculate direction from vine path
    final direction = _calculateVineDirection();

    // Draw line segments connecting cells (tails)
    final segmentAlpha = isBlocked ? 0.3 : 0.8;
    final segmentPaint = Paint()
      ..color = baseColor.withValues(alpha: segmentAlpha * 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < vineData.path.length - 1; i++) {
      final currentCell = vineData.path[i];
      final nextCell = vineData.path[i + 1];

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
    for (int i = 0; i < vineData.path.length; i++) {
      final cell = vineData.path[i];
      final row = cell['row'] as int;
      final col = cell['col'] as int;
      final visualRow = gridSize - 1 - row;

      final isHead = direction != null && i == vineData.path.length - 1;

      final rect = Rect.fromCenter(
        center: Offset(
          col * cellSize + cellSize / 2,
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
        final alpha = isBlocked ? 0.3 : 0.8;
        final bodyPaint = Paint()
          ..color = baseColor.withValues(alpha: alpha * 255)
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

  String? _calculateVineDirection() {
    if (vineData.path.length < 2) return 'right';

    final headCell = vineData.path.last;
    final secondLastCell = vineData.path[vineData.path.length - 2];

    final headRow = headCell['row'] as int;
    final headCol = headCell['col'] as int;
    final prevRow = secondLastCell['row'] as int;
    final prevCol = secondLastCell['col'] as int;

    if (headCol > prevCol) return 'right';
    if (headCol < prevCol) return 'left';
    if (headRow > prevRow) return 'up';
    if (headRow < prevRow) return 'down';

    return 'right';
  }

  void slideOut() {
    if (_isAnimating) return;
    _isAnimating = true;

    // Snake-like movement: head moves in head_direction, body follows as queue
    final headDirection = vineData.headDirection;
    final slideDistance = (gridSize + 5) * cellSize;
    Vector2 delta;

    switch (headDirection) {
      case 'right':
        delta = Vector2(slideDistance, 0);
        break;
      case 'left':
        delta = Vector2(-slideDistance, 0);
        break;
      case 'up':
        delta = Vector2(0, -slideDistance); // Visual Y is up
        break;
      case 'down':
        delta = Vector2(0, slideDistance);
        break;
      default:
        delta = Vector2.zero();
    }

    // For now, simple slide - will be replaced with proper queue movement
    add(
      MoveByEffect(
        delta,
        EffectController(duration: 0.5, curve: Curves.easeIn),
        onComplete: () {
          // Notify parent to update Riverpod state
          parent.notifyVineCleared(vineData.id);
          removeFromParent();
        },
      ),
    );
  }

  void slideBump(int distanceInCells) {
    if (_isAnimating) return;
    _isAnimating = true;

    final headDirection = vineData.headDirection;

    // Animate to blocker + half a cell for a "bump" feel
    final bumpDistance = (distanceInCells + 0.4) * cellSize;
    Vector2 delta;

    switch (headDirection) {
      case 'right':
        delta = Vector2(bumpDistance, 0);
        break;
      case 'left':
        delta = Vector2(-bumpDistance, 0);
        break;
      case 'up':
        delta = Vector2(0, -bumpDistance);
        break;
      case 'down':
        delta = Vector2(0, bumpDistance);
        break;
      default:
        delta = Vector2.zero();
    }

    // Move forward, then move back
    add(
      SequenceEffect([
        MoveByEffect(
          delta,
          EffectController(duration: 0.2, curve: Curves.easeOut),
          onComplete: () {
            // Trigger persistent state update (turns red)
            parent.markVineAttempted(vineData.id);
          },
        ),
        MoveByEffect(
          -delta,
          EffectController(duration: 0.2, curve: Curves.easeIn),
          onComplete: () {
            _isAnimating = false;
          },
        ),
      ]),
    );
  }
}
