import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:parable_bloom/core/providers/settings_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';

class VinePathPainter {
  /// Cached shaders per texture image. The transform is always the same
  /// (uniform [textureScale]), so rebuilding an [ImageShader] every frame
  /// per vine is pure overhead.
  static final Map<ui.Image, ui.ImageShader> _shaderCache = {};

  /// Cached leaf shapes per size. [Path]s are never mutated after creation,
  /// so sharing them across frames and vines is safe.
  static final Map<double, Path> _leafPathCache = {};

  static ui.ImageShader _shaderFor(ui.Image texture) {
    return _shaderCache.putIfAbsent(texture, () {
      final matrix = Float64List(16)
        ..[0] = 1.0
        ..[5] = 1.0
        ..[10] = 1.0
        ..[15] = 1.0;
      const double textureScale = 0.25;
      matrix[0] = textureScale;
      matrix[5] = textureScale;

      return ui.ImageShader(
        texture,
        TileMode.repeated,
        TileMode.repeated,
        matrix,
      );
    });
  }

  static Path _leafPathFor(double size) {
    return _leafPathCache.putIfAbsent(size, () => _createLeafPath(size));
  }

  /// Cached ColorFilters per draw color: `ColorFilter.mode` allocates per
  /// call and was previously rebuilt per vine per frame.
  static final Map<Color, ColorFilter> _colorFilterCache = {};
  static ColorFilter _filterFor(Color c) => _colorFilterCache.putIfAbsent(
        c,
        () => ColorFilter.mode(c, BlendMode.modulate),
      );

  // Reused paints: draws are sequential on one thread, so overwriting color/
  // shader/filter before each draw is safe and avoids per-vine-per-frame
  // Paint + ColorFilter allocations.
  static final Paint _mainPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
  static final Paint _leafPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _leafGlowPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
  static final Paint _petalPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xFFFFC2D8);
  static final Paint _blossomCenterPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xFFFFDB4D);
  static final Paint _headPaint = Paint()..style = PaintingStyle.fill;

  /// Render main vine path, foliage, and directional arrow head.
  ///
  /// [isAnimating] gates the expensive blur-based ethereal glow: idle vines
  /// draw the flat leaf color only, animations get the full glow treatment.
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
    required bool isAnimating,
    Path? cachedPath,
    ui.Image? classicTexture,
    ui.Image? blossomTexture,
    ui.Image? etherealTexture,
  }) {
    if (points.isEmpty) return;

    // Use caller-cached Path for idle vines; build fresh while animating
    // (points mutate every frame) or when no cache was provided.
    final Path path;
    if (cachedPath != null && !isAnimating) {
      path = cachedPath;
    } else {
      path = Path();
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }

    final paint = _mainPaint
      ..strokeWidth = strokeWidth
      ..color = drawColor
      ..shader = null
      ..colorFilter = null;

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
      paint.shader = _shaderFor(texture);
      paint.colorFilter = _filterFor(drawColor);
    }

    // 3. Draw Ethereal Outer Glow (animations only: MaskFilter.blur is
    // one of the most expensive GPU ops in this renderer)
    if (vineStyle == VineStyle.ethereal && isAnimating) {
      _glowPaint.strokeWidth = strokeWidth + 6.0;
      canvas.drawPath(path, _glowPaint);
    }

    // 4. Draw Main Branch/Path
    canvas.drawPath(path, paint);

    // 5. Draw Foliage Details (paints hoisted: reused across segments,
    //    not reallocated per point per frame). Idle vines use LOD stride 2
    //    to halve leaf/blossom overdraw; animations keep full density.
    if (!useSimpleVines) {
      final double leafSize = strokeWidth * 0.95;
      final Path leafPath = _leafPathFor(leafSize);
      final int stride = isAnimating ? 1 : 2;

      Paint? classicLeaf;
      Paint? etherealLeaf;
      Paint? etherealGlow;
      Paint? petal;
      Paint? blossomCenter;
      if (vineStyle == VineStyle.classic) {
        classicLeaf = _leafPaint
          ..color = drawColor
          ..shader = paint.shader
          ..colorFilter = paint.colorFilter;
      } else if (vineStyle == VineStyle.blossom) {
        petal = _petalPaint..colorFilter = _filterFor(drawColor);
        blossomCenter = _blossomCenterPaint
          ..colorFilter = _filterFor(drawColor);
      } else if (vineStyle == VineStyle.ethereal) {
        etherealLeaf = _leafPaint
          ..color = const Color(0xFF00E5FF)
          ..shader = null
          ..colorFilter = _filterFor(drawColor);
        // Per-leaf glow is blur-backed: reuse shared blurred paint only for
        // animations; idle vines reuse the flat leaf paint.
        etherealGlow = isAnimating ? _leafGlowPaint : etherealLeaf;
      }

      for (int i = 1; i < points.length; i++) {
        if (stride > 1 && (i & 1) == 0) continue;

        final nextPoint = points[i - 1];
        final dx = nextPoint.dx - points[i].dx;
        final dy = nextPoint.dy - points[i].dy;
        final double baseAngle = math.atan2(dy, dx);

        if (vineStyle == VineStyle.classic) {
          canvas.save();
          canvas.translate(points[i].dx, points[i].dy);
          canvas.rotate(baseAngle + math.pi / 4.0);
          canvas.drawPath(leafPath, classicLeaf!);
          canvas.restore();

          canvas.save();
          canvas.translate(points[i].dx, points[i].dy);
          canvas.rotate(baseAngle - math.pi / 4.0);
          canvas.drawPath(leafPath, classicLeaf);
          canvas.restore();
        } else if (vineStyle == VineStyle.blossom) {
          _drawCherryBlossom(
            canvas,
            points[i],
            strokeWidth * 1.15,
            petalPaint: petal!,
            centerPaint: blossomCenter!,
          );
        } else if (vineStyle == VineStyle.ethereal) {
          canvas.save();
          canvas.translate(points[i].dx, points[i].dy);
          canvas.rotate(baseAngle + math.pi / 4.0);
          canvas.drawPath(leafPath, etherealGlow!);
          canvas.drawPath(leafPath, etherealLeaf!);
          canvas.restore();

          canvas.save();
          canvas.translate(points[i].dx, points[i].dy);
          canvas.rotate(baseAngle - math.pi / 4.0);
          canvas.drawPath(leafPath, etherealGlow);
          canvas.drawPath(leafPath, etherealLeaf);
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

    final headPaint = _headPaint
      ..color = drawColor
      ..shader = null
      ..colorFilter = null;

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
    Canvas canvas,
    Offset center,
    double size, {
    required Paint petalPaint,
    required Paint centerPaint,
  }) {
    final double petalRadius = size * 0.44;
    final double r = size * 0.34;
    // 5 petal offsets precomputed inline (no per-petal cos/sin per frame).
    canvas.drawCircle(
        Offset(center.dx + petalRadius, center.dy), r, petalPaint);
    canvas.drawCircle(
        Offset(
            center.dx + petalRadius * 0.309, center.dy + petalRadius * 0.951),
        r,
        petalPaint);
    canvas.drawCircle(
        Offset(
            center.dx - petalRadius * 0.809, center.dy + petalRadius * 0.588),
        r,
        petalPaint);
    canvas.drawCircle(
        Offset(
            center.dx - petalRadius * 0.809, center.dy - petalRadius * 0.588),
        r,
        petalPaint);
    canvas.drawCircle(
        Offset(
            center.dx + petalRadius * 0.309, center.dy - petalRadius * 0.951),
        r,
        petalPaint);
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
