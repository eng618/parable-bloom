import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_rail_draw.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_tube_path.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

/// Native renderer pass for the rail architecture.
///
/// Two render paths per vine, both with draw-call count independent of vine
/// length:
/// - **Textured styles**: one `drawVertices` for the tube strip sampling the
///   real trellis/ivy texture with body-pinned cylindrical wrap UVs, one for
///   the foliage quads, a tail cap, and an outlined arrow head in the
///   skin's accent color. The arrow is last so leaves and bark do not
///   cover the direction.
/// - **Simple**: an anti-aliased stroked `Path` along the baked centerline
///   plus that same outlined arrow — vector-crisp edges at any device
///   pixel ratio.
///
/// Geometry comes straight from the invariant [VineTrack], so the tube
/// reads as one continuous object through turns and while exiting
/// off-screen. A failed clear attempt (withered) modulates the tube in
/// warm bark brown and paints caps/head/foliage brown.
class VineRailRenderer {
  /// Identity-matrix ImageShader per texture image (cylindrical UVs already
  /// carry the wrap).
  static final Map<ui.Image, ui.ImageShader> _shaderCache = {};

  static final Float64List _identityMatrix = Float64List(16)
    ..[0] = 1.0
    ..[5] = 1.0
    ..[10] = 1.0
    ..[15] = 1.0;

  static ui.ImageShader? _shaderFor(ui.Image? texture) {
    if (texture == null) return null;
    return _shaderCache.putIfAbsent(
      texture,
      () => ui.ImageShader(
          texture, TileMode.repeated, TileMode.repeated, _identityMatrix),
    );
  }

  /// Reused paints. `drawVertices` derives tint/alpha from vertex colors;
  /// the paint color stays white so it cannot erase them.
  static final Paint _stripPaint = Paint()..color = const Color(0xFFFFFFFF);

  /// Shared mutable sample read-out ([VineTrack.sampleAt] contract).
  static final Float32List _sample = Float32List(VineTrack.positionW);

  static void draw({
    required Canvas canvas,
    required VineRailDraw rail,
    required bool useSimpleVines,

    /// The real trellis/ivy texture for textured styles; null degrades to
    /// flat-colored vertex strips.
    required ui.Image? textureImage,
    required ui.Image? foliageAtlasImage,

    /// Vertex RGB+alpha for the tube: white (healthy) lets the real texture
    /// show; [VineMetrics.witheredColor] turns dead vines brown.
    required Color tubeTint,

    /// Vertex RGB+alpha for foliage quads.
    required Color foliageTint,

    /// Flat fill color for caps and arrow head.
    required Color capTint,
  }) {
    final track = rail.track;
    final headArc = rail.headArc;
    final windowLength = track.windowLength;

    // ---------- Simple render pass: anti-aliased stroked path ----------
    //
    // `drawVertices` never reaches vector-crisp edges (no AA on any
    // backend), so the flat/simple style strokes the baked centerline
    // instead: round cap + round join, solid tint, plus an outlined arrow
    // in the skin accent. The vine stays fully opaque until it has left
    // the viewport.
    if (useSimpleVines) {
      final alpha = track.fadeAlphaAt(headArc);
      final color = tubeTint.withValues(alpha: tubeTint.a * alpha);
      _drawSimpleBody(
        canvas: canvas,
        rail: rail,
        track: track,
        headArc: headArc,
        windowLength: windowLength,
        color: color,
        arrowColor: capTint.withValues(alpha: capTint.a * alpha),
      );
      return;
    }

    // ---------- Textured styles: vertex strip pipeline ----------
    final shader = _shaderFor(textureImage);
    final tubeWidth = VineMetrics.texturedTubeWidth;

    // 1. Tube strip (single draw call regardless of vine length).
    if (rail.strip != null) {
      _stripPaint
        ..shader = shader
        ..color = const Color(0xFFFFFFFF);
      canvas.drawVertices(rail.strip!, BlendMode.srcOver, _stripPaint);
    }

    // 2. Foliage before the arrow, so a leaf cannot sit on the head.
    final foliageShader = _shaderFor(foliageAtlasImage);
    if (rail.foliage != null && foliageShader != null) {
      _stripPaint
        ..shader = foliageShader
        ..color = const Color(0xFFFFFFFF);
      canvas.drawVertices(rail.foliage!, BlendMode.srcOver, _stripPaint);
    }

    // 3. Tail cap only. A disc under the head turns the arrow into a blob.
    final tailArc = headArc - windowLength;
    track.sampleAt(tailArc, _sample);
    final tail = Offset(_sample[0], _sample[1]);
    final tailAlpha = track.fadeAlphaAt(tailArc);
    final capPaint = (_capPaint)..shader = null;
    capPaint.color = capTint.withValues(alpha: tailAlpha);
    canvas.drawCircle(tail, tubeWidth / 2, capPaint);

    // 4. Outlined arrow, last, in the skin accent.
    track.sampleAt(headArc, _sample);
    final head = Offset(_sample[0], _sample[1]);
    final headAlpha = track.fadeAlphaAt(headArc);
    _drawArrow(
      canvas: canvas,
      head: head,
      direction: track.headDirection,
      tubeWidth: tubeWidth,
      fill: capTint.withValues(alpha: headAlpha),
    );
  }

  static void _drawSimpleBody({
    required Canvas canvas,
    required VineRailDraw rail,
    required VineTrack track,
    required double headArc,
    required double windowLength,
    required Color color,
    required Color arrowColor,
  }) {
    final path = rail.simplePath ?? track.windowPath(headArc, windowLength);
    _simplePaint
      ..shader = null
      ..strokeWidth = VineMetrics.tubeWidth
      ..color = color;
    canvas.drawPath(path, _simplePaint);

    track.sampleAt(headArc, _sample);
    _drawArrow(
      canvas: canvas,
      head: Offset(_sample[0], _sample[1]),
      direction: track.headDirection,
      tubeWidth: VineMetrics.tubeWidth,
      fill: arrowColor,
    );
  }

  /// Dark rim, then the accent fill. The rim is what keeps the tip readable
  /// on bark, leaves, and the day or night board.
  static void _drawArrow({
    required Canvas canvas,
    required Offset head,
    required String direction,
    required double tubeWidth,
    required Color fill,
  }) {
    final path = VineTubePath.buildArrowHead(head, direction, tubeWidth);
    _arrowOutline
      ..shader = null
      ..strokeWidth = tubeWidth * 0.18
      ..color = const Color(0xFF24180F).withValues(alpha: fill.a);
    canvas.drawPath(path, _arrowOutline);
    _headPaint
      ..shader = null
      ..style = PaintingStyle.fill
      ..color = fill;
    canvas.drawPath(path, _headPaint);
  }

  static final Paint _capPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _headPaint = Paint()..style = PaintingStyle.fill;

  static final Paint _arrowOutline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  /// Simple-pass stroke: solid AA vector stroke with round caps and joins.
  static final Paint _simplePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFFFFFFFF);
}
