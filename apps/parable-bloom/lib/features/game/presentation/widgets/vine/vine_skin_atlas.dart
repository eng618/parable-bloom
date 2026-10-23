import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:parable_bloom/core/providers/settings_providers.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';

/// Baked tube-skin atlas for the rail renderer's textured styles.
///
/// One row of six fully colored tiles, each a self-contained slice of
/// "a wooden trellis dowel with a green vine wrapped around it": warm wood
/// grain along the tube axis, one diagonal vine coil per tile with a leaf
/// cluster where the vine wraps behind the dowel, and baked cylindrical
/// shading (dark edges, off-center highlight) so the tube reads as a
/// 3-D rounded object without any runtime blur.
///
/// The tile is mapped with **cylindrical wrap UVs** (see
/// [VineStripMesh.writeWindow]): `u` runs along the vine's arc length —
/// pinned to the vine body so the skin travels with the rigid vine — and
/// `v` runs across the tube (around the dowel). This replaces the legacy
/// world-anchored sampling of full-scene JPEGs, whose 13px slices looked
/// like arbitrary color bands.
///
/// Tile order (fully colored; vertex tint stays white so the baked look is
/// the final look):
///
/// | i | style   | state    |
/// |---|---------|----------|
/// | 0 | classic | healthy  |
/// | 1 | blossom | healthy  |
/// | 2 | ethereal| healthy  |
/// | 3 | classic | withered |
/// | 4 | blossom | withered |
/// | 5 | ethereal| withered |
class VineSkinAtlas {
  /// Logical tile length along the tube (world px). One full vine coil
  /// (plus its leaf cluster) per tile: 1.5 cells at the 42px lane pitch,
  /// so the wrap reads snug while wood stays visible between coils.
  static const double tileLength = 63.0;

  /// Logical tile height across the tube (world px). Covers the expanded
  /// textured half-width (7.5 + 2 feather = 9.5) plus shading margin.
  static const double tileHeight = 20.0;

  /// Atlas resolution scale (image px per logical px).
  static const double bakeScale = 4.0;

  static const int tileClassic = 0;
  static const int tileBlossom = 1;
  static const int tileEthereal = 2;
  static const int tileClassicWithered = 3;
  static const int tileBlossomWithered = 4;
  static const int tileEtherealWithered = 5;
  static const int tileCount = 6;

  /// Half of [tileHeight]: the tile's `v` center matches the tube
  /// centerline, so image `y = halfHeight + crossTubeOffset`.
  static const double halfHeight = tileHeight / 2;

  ui.Image? image;

  /// Wraps a raw body-space arc coordinate into `[0, tileLength)` so manual
  /// UV repetition stays inside this tile's atlas column (the single-row
  /// atlas must not bleed into neighboring style tiles).
  static double wrapU(double u) {
    final m = u % tileLength;
    return m < 0 ? m + tileLength : m;
  }

  /// Skin tile for [style]/[isAttempted]. [style] must not be
  /// [VineStyle.simple] (the simple style strokes a path instead).
  static int tileFor(VineStyle style, {required bool isAttempted}) {
    if (isAttempted) {
      return switch (style) {
        VineStyle.blossom => tileBlossomWithered,
        VineStyle.ethereal => tileEtherealWithered,
        _ => tileClassicWithered,
      };
    }
    return switch (style) {
      VineStyle.blossom => tileBlossom,
      VineStyle.ethereal => tileEthereal,
      _ => tileClassic,
    };
  }

  /// Flat tube-end color for the textured styles: the caps and arrow head
  /// read as the vine's tip, so they use the style's vine/stem tone rather
  /// than sampling the wood texture. The withered state overrides with
  /// [VineMetrics.witheredColor].
  static Color accentFor(VineStyle style, {required bool isAttempted}) {
    if (isAttempted) return VineMetrics.witheredColor;
    return switch (style) {
      VineStyle.blossom => const Color(0xFFDE7FA4),
      VineStyle.ethereal => const Color(0xFF74F4FF),
      _ => const Color(0xFF4C8F3A),
    };
  }

  /// Bakes the atlas once per layer (GPU-cheap via [ui.Picture.toImageSync];
  /// safe on Impeller, CanvasKit, and Skwasm). Callers must handle bake
  /// failure (try/catch) and fall back to flat-color rendering.
  void bake() {
    final logicalW = tileLength * tileCount;
    final logicalH = tileHeight;
    final w = (logicalW * bakeScale).round();
    final h = (logicalH * bakeScale).round();

    final recorder = ui.PictureRecorder();
    final canvas =
        ui.Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    canvas.scale(bakeScale);

    // Deterministic per-tile variation (grain wobble); fixed seed so the
    // baked look is stable across sessions.
    final rng = math.Random(7);
    for (var tile = 0; tile < tileCount; tile++) {
      final style = switch (tile % 3) {
        0 => VineStyle.classic,
        1 => VineStyle.blossom,
        _ => VineStyle.ethereal,
      };
      final withered = tile >= 3;
      _bakeTile(canvas,
          x0: tile * tileLength, style: style, withered: withered, rng: rng);
    }

    final picture = recorder.endRecording();
    image = picture.toImageSync(w, h);
  }

  /// Draws one skin tile with its left edge at logical [x0].
  void _bakeTile(
    ui.Canvas canvas, {
    required double x0,
    required VineStyle style,
    required bool withered,
    required math.Random rng,
  }) {
    _bakeWood(canvas, x0, style, withered, rng);
    _bakeVine(canvas, x0, style, withered);
    _bakeFoliageDetails(canvas, x0, style, withered);
    // Cylinder shading: darken both v-edges with a vertical gradient so the
    // dowel reads as round. Drawn last so everything dims near the edges.
    final shade = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x73000000),
          Color(0x00000000),
          Color(0x00000000),
          Color(0x73000000),
        ],
        stops: [0.0, 0.34, 0.58, 1.0],
      ).createShader(Rect.fromLTWH(x0, 0, tileLength, tileHeight));
    canvas.drawRect(Rect.fromLTWH(x0, 0, tileLength, tileHeight), shade);
  }

  /// Wood trellis: base tone plus wobbly grain streaks running along the
  /// tube axis (`u`), the way grain runs along a real trellis stick.
  void _bakeWood(
    ui.Canvas canvas,
    double x0,
    VineStyle style,
    bool withered,
    math.Random rng,
  ) {
    final (base, dark, light) = switch ((style, withered)) {
      (VineStyle.ethereal, false) => (
          const Color(0xFF39304A),
          const Color(0xFF2C2540),
          const Color(0xFF4A4166),
        ),
      (_, true) => (
          const Color(0xFF6E5A44),
          const Color(0xFF594736),
          const Color(0xFF83705C),
        ),
      _ => (
          const Color(0xFF9A6B42),
          const Color(0xFF7E5533),
          const Color(0xFFB98A5B),
        ),
    };
    canvas.drawRect(
      Rect.fromLTWH(x0, 0, tileLength, tileHeight),
      Paint()..color = base,
    );

    // Grain: ~14 horizontal wobble streaks, alternating dark/light, plus a
    // couple of wide soft bands for tone variation.
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    const lines = 14;
    for (var k = 0; k < lines; k++) {
      grain.color = k.isEven
          ? dark.withValues(alpha: 0.45)
          : light.withValues(alpha: 0.45);
      // Hand-drawn feel: rise/run per knot, sine phase per line.
      final seedPhase = rng.nextDouble() * 2 * math.pi;
      final wobble = 0.5 + rng.nextDouble() * 0.9;
      final path = Path();
      for (var x = 0.0; x <= tileLength; x += 6) {
        final y = (k + 0.5) * tileHeight / lines +
            math.sin(seedPhase + x / tileLength * 4 * math.pi) * wobble;
        if (x == 0) {
          path.moveTo(x0 + x, y);
        } else {
          path.lineTo(x0 + x, y);
        }
      }
      canvas.drawPath(path, grain);
    }
    for (final bandY in [tileHeight * 0.28, tileHeight * 0.72]) {
      canvas.drawRect(
        Rect.fromLTWH(x0, bandY - 1.4, tileLength, 2.8),
        Paint()..color = light.withValues(alpha: 0.14),
      );
    }
  }

  /// The wrapped vine: one diagonal sine coil across the tile face — green
  /// over wood, glowing teal over dark wood, dead brown when withered.
  /// Rendered as shadow + body + highlight strokes so it reads as a clingy
  /// round stem rather than a painted stripe.
  void _bakeVine(ui.Canvas canvas, double x0, VineStyle style, bool withered) {
    final cy = halfHeight;
    const amplitude = 6.4; // < halfHeight - clearance for leaves
    final path = Path();
    for (var x = 0.0; x <= tileLength; x += 2) {
      final y = cy + amplitude * math.sin(2 * math.pi * x / tileLength);
      if (x == 0) {
        path.moveTo(x0 + x, y);
      } else {
        path.lineTo(x0 + x, y);
      }
    }
    const bodyWidth = 6.2;

    if (style == VineStyle.ethereal && !withered) {
      // Glowing teal coil: soft outer glow, bright core, hot center line.
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x6600E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bodyWidth + 4.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF74F4FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bodyWidth - 2.0
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xE0EFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final (shadow, body, highlight) = withered
        ? (
            const Color(0x4D000000),
            VineMetrics.witheredColor,
            const Color(0xFF5EC9A2),
          )
        : (
            const Color(0x59000000),
            const Color(0xFF4C8F3A),
            const Color(0xFF7FC05B),
          );

    // Drop shadow (down-right) grounds the stem on the wood.
    canvas.save();
    canvas.translate(0.9, 1.1);
    canvas.drawPath(
      path,
      Paint()
        ..color = shadow
        ..style = PaintingStyle.stroke
        ..strokeWidth = bodyWidth + 0.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..color = body
        ..style = PaintingStyle.stroke
        ..strokeWidth = bodyWidth
        ..strokeCap = StrokeCap.round,
    );

    // Off-center highlight sells the round stem.
    canvas.save();
    canvas.translate(-0.8, -0.9);
    canvas.drawPath(
      path,
      Paint()
        ..color = highlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  /// Style flourishes riding on the coil: clustered leaves where the vine
  /// wraps out of sight (within the withered state they droop and brown);
  /// blossom adds a five-petal flower that fades to pale petals when
  /// withered.
  void _bakeFoliageDetails(
    ui.Canvas canvas,
    double x0,
    VineStyle style,
    bool withered,
  ) {
    final cy = halfHeight;
    const amplitude = 6.4;
    void drawLeaf(double len, Paint paint) {
      final p = Path()
        ..moveTo(-len / 2, 0)
        ..quadraticBezierTo(0, -len * 0.34, len / 2, 0)
        ..quadraticBezierTo(0, len * 0.32, -len / 2, 0)
        ..close();
      canvas.drawPath(p, paint);
    }

    final (leafPaint, glowPaint) = switch ((style, withered)) {
      (VineStyle.ethereal, false) => (
          Paint()..color = const Color(0xFF9BEBFF),
          Paint()
            ..color = const Color(0x5500E5FF)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
        ),
      (_, true) => (Paint()..color = const Color(0xFF77683F), null),
      _ => (Paint()..color = const Color(0xFF3E7A2F), null),
    };

    // Two clusters at the coil extremes (the wrap-behind points).
    for (final fx in [0.25, 0.75]) {
      final px = x0 + fx * tileLength;
      final py = cy + amplitude * math.sin(2 * math.pi * fx);
      for (final angleDeg in const [42.0, -38.0, 150.0]) {
        canvas.save();
        canvas.translate(px, py);
        canvas
            .rotate((angleDeg + (withered ? 24 : 0)) * math.pi / 180); // droop
        drawLeaf(9.5, glowPaint ?? leafPaint);
        if (glowPaint != null) drawLeaf(9.5, leafPaint);
        canvas.restore();
      }
    }

    if (style == VineStyle.blossom) {
      final px = x0 + tileLength * 0.5;
      final py = cy + amplitude * math.sin(2 * math.pi * 0.5);
      final petalPaint = Paint()
        ..color = withered ? const Color(0xFFC4B2A4) : const Color(0xFFF6B9CC);
      final centerPaint = Paint()
        ..color = withered ? const Color(0xFFB39D87) : const Color(0xFFFFD75E);
      const petalR = 4.6;
      const petalRadius = 3.4;
      for (var i = 0; i < 5; i++) {
        final angle = (i / 5) * 2 * math.pi - math.pi / 2;
        canvas.drawCircle(
          Offset(px + petalRadius * math.cos(angle),
              py + petalRadius * math.sin(angle)),
          petalR * 0.62,
          petalPaint,
        );
      }
      canvas.drawCircle(Offset(px, py), 2.4, centerPaint);
    }
  }

  void dispose() {
    image?.dispose();
    image = null;
  }
}
