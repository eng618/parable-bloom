import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:parable_bloom/core/providers/settings_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';

class VinePathPainter {
  /// Render main vine path, foliage, and directional arrow head
  static void drawVine({
    required Canvas canvas,
    required VineData vineData,
    required List<Offset> points,
    required double strokeWidth,
    required double cellSize,
    required bool useSimpleVines,
    required VineStyle vineStyle,
    required Color drawColor,
    required Color calmColor,
    required bool isAttempted,
    ui.Image? classicTexture,
    ui.Image? blossomTexture,
    ui.Image? etherealTexture,
  }) {
    if (points.isEmpty) return;

    // 1. Compute Path
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 2. Resolve Texture / Shader
    ui.Image? texture;
    if (vineStyle == VineStyle.classic) {
      texture = classicTexture;
    } else if (vineStyle == VineStyle.blossom) {
      texture = blossomTexture;
    } else if (vineStyle == VineStyle.ethereal) {
      texture = etherealTexture;
    }

    if (useSimpleVines || texture == null) {
      paint.color = drawColor;
    } else {
      final matrix = Float64List(16)
        ..[0] = 1.0
        ..[5] = 1.0
        ..[10] = 1.0
        ..[15] = 1.0;
      const double textureScale = 0.25;
      matrix[0] = textureScale;
      matrix[5] = textureScale;

      paint.shader = ImageShader(
        texture,
        TileMode.repeated,
        TileMode.repeated,
        matrix,
      );
      paint.colorFilter = ColorFilter.mode(
        drawColor,
        BlendMode.modulate,
      );
    }

    // 3. Draw Ethereal Outer Glow
    if (vineStyle == VineStyle.ethereal) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6.0
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawPath(path, glowPaint);
    }

    // 4. Draw Main Branch/Path
    canvas.drawPath(path, paint);

    // 5. Draw Foliage Details
    if (!useSimpleVines) {
      for (int i = 0; i < points.length; i++) {
        if (i == 0) continue;

        final nextPoint = points[i - 1];
        final dx = nextPoint.dx - points[i].dx;
        final dy = nextPoint.dy - points[i].dy;
        final double baseAngle = math.atan2(dy, dx);

        if (vineStyle == VineStyle.classic) {
          final leafPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = drawColor;
          if (texture != null) {
            leafPaint.shader = paint.shader;
            leafPaint.colorFilter = paint.colorFilter;
          }

          final double leafSize = strokeWidth * 0.95;

          canvas.save();
          canvas.translate(points[i].dx, points[i].dy);
          canvas.rotate(baseAngle + math.pi / 4.0);
          canvas.drawPath(_createLeafPath(leafSize), leafPaint);
          canvas.restore();

          canvas.save();
          canvas.translate(points[i].dx, points[i].dy);
          canvas.rotate(baseAngle - math.pi / 4.0);
          canvas.drawPath(_createLeafPath(leafSize), leafPaint);
          canvas.restore();
        } else if (vineStyle == VineStyle.blossom) {
          _drawCherryBlossom(canvas, points[i], strokeWidth * 1.15, drawColor);
        } else if (vineStyle == VineStyle.ethereal) {
          final leafPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = const Color(0xFF00E5FF)
            ..colorFilter = ColorFilter.mode(drawColor, BlendMode.modulate);

          final leafGlow = Paint()
            ..style = PaintingStyle.fill
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

          final double leafSize = strokeWidth * 0.95;

          canvas.save();
          canvas.translate(points[i].dx, points[i].dy);
          canvas.rotate(baseAngle + math.pi / 4.0);
          canvas.drawPath(_createLeafPath(leafSize), leafGlow);
          canvas.drawPath(_createLeafPath(leafSize), leafPaint);
          canvas.restore();

          canvas.save();
          canvas.translate(points[i].dx, points[i].dy);
          canvas.rotate(baseAngle - math.pi / 4.0);
          canvas.drawPath(_createLeafPath(leafSize), leafGlow);
          canvas.drawPath(_createLeafPath(leafSize), leafPaint);
          canvas.restore();
        }
      }
    }

    // 6. Draw Arrow Head at the Tip
    final head = points.first;
    final String dir = vineData.headDirection;
    final double arrowSize = strokeWidth * 1.45;
    final headPath = Path();

    if (dir == 'up') {
      headPath.moveTo(head.dx, head.dy - arrowSize * 0.85);
      headPath.lineTo(head.dx - arrowSize * 0.72, head.dy + arrowSize * 0.22);
      headPath.lineTo(head.dx + arrowSize * 0.72, head.dy + arrowSize * 0.22);
      headPath.close();
    } else if (dir == 'down') {
      headPath.moveTo(head.dx, head.dy + arrowSize * 0.85);
      headPath.lineTo(head.dx - arrowSize * 0.72, head.dy - arrowSize * 0.22);
      headPath.lineTo(head.dx + arrowSize * 0.72, head.dy - arrowSize * 0.22);
      headPath.close();
    } else if (dir == 'left') {
      headPath.moveTo(head.dx - arrowSize * 0.85, head.dy);
      headPath.lineTo(head.dx + arrowSize * 0.22, head.dy - arrowSize * 0.72);
      headPath.lineTo(head.dx + arrowSize * 0.22, head.dy + arrowSize * 0.72);
      headPath.close();
    } else if (dir == 'right') {
      headPath.moveTo(head.dx + arrowSize * 0.85, head.dy);
      headPath.lineTo(head.dx - arrowSize * 0.22, head.dy - arrowSize * 0.72);
      headPath.lineTo(head.dx - arrowSize * 0.22, head.dy + arrowSize * 0.72);
      headPath.close();
    }

    final headPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = drawColor;

    if (useSimpleVines || texture == null) {
      headPaint.color = drawColor;
    } else {
      headPaint.shader = paint.shader;
      headPaint.colorFilter = paint.colorFilter;
    }

    canvas.drawPath(headPath, headPaint);
  }

  static Path _createLeafPath(double size) {
    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size * 0.5, -size * 0.32, size, 0);
    path.quadraticBezierTo(size * 0.5, size * 0.32, 0, 0);
    path.close();
    return path;
  }

  static void _drawCherryBlossom(
      Canvas canvas, Offset center, double size, Color baseColor) {
    final petalPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFC2D8);
    final centerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFDB4D);

    petalPaint.colorFilter = ColorFilter.mode(baseColor, BlendMode.modulate);
    centerPaint.colorFilter = ColorFilter.mode(baseColor, BlendMode.modulate);

    final double petalRadius = size * 0.44;
    for (int i = 0; i < 5; i++) {
      final double angle = i * 2 * math.pi / 5;
      final px = center.dx + petalRadius * math.cos(angle);
      final py = center.dy + petalRadius * math.sin(angle);
      canvas.drawCircle(Offset(px, py), size * 0.34, petalPaint);
    }
    canvas.drawCircle(center, size * 0.22, centerPaint);
  }

  static Color deriveCalmVariant(Color base, String seed) {
    final hash = _fnv1a32(seed);
    final bucket = hash % 7;
    final lightnessDelta = (bucket - 3) * 0.02;

    final hsl = HSLColor.fromColor(base);
    final adjusted = hsl
        .withSaturation((hsl.saturation * 0.85).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0));
    return adjusted.toColor();
  }

  static int _fnv1a32(String input) {
    const int fnvOffset = 0x811C9DC5;
    const int fnvPrime = 0x01000193;

    var hash = fnvOffset;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash;
  }

  static Color computeRenderColor(
    Color calmColor,
    bool isAttempted,
    Color attemptedColor,
  ) {
    if (isAttempted) {
      return attemptedColor;
    }
    return calmColor;
  }
}
