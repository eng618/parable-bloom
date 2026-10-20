import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:parable_bloom/core/providers/settings_providers.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_rail_draw.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_tube_path.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

/// Native renderer pass for the rail architecture.
///
/// Two render paths per vine, both with draw-call count independent of vine
/// length:
/// - **Textured styles**: one `drawVertices` for the tube strip, one for the
///   foliage quads, plus two round tube caps and a canvas arrow head.
/// - **Simple**: an anti-aliased stroked `Path` along the baked centerline
///   plus a solid arrow head — vector-crisp edges at any device pixel ratio.
///
/// Geometry comes straight from the invariant [VineTrack], so the tube
/// reads as one continuous object through turns and while exiting
/// off-screen.
class VineRailRenderer {
  /// Identity-matrix ImageShaders per texture image (UVs already carry the
  /// legacy 0.25 world scale — see [VineTrack.textureScale]).
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
    required VineStyle vineStyle,
    required bool useSimpleVines,
    required ui.Image? classicTexture,
    required ui.Image? blossomTexture,
    required ui.Image? etherealTexture,
    required ui.Image? foliageAtlasImage,
    required Color tint,
  }) {
    final track = rail.track;
    final headArc = rail.headArc;
    final windowLength = track.windowLength;

    // ---------- Simple render pass: anti-aliased stroked path ----------
    //
    // `drawVertices` never reaches vector-crisp edges (no AA on any
    // backend), so the flat/simple style strokes the baked centerline
    // instead: round cap + round join, solid tint, plus a solid triangle
    // head. Whole-vine alpha follows the head through the exit fade band.
    if (useSimpleVines) {
      final alpha = track.fadeAlphaAt(headArc);
      final color = tint.withValues(alpha: tint.a * alpha);
      final path = rail.simplePath ?? track.windowPath(headArc, windowLength);
      _simplePaint
        ..shader = null
        ..strokeWidth = VineMetrics.tubeWidth
        ..color = color;
      canvas.drawPath(path, _simplePaint);

      track.sampleAt(headArc, _sample);
      final head = Offset(_sample[0], _sample[1]);
      final headPath = VineTubePath.buildArrowHead(
        head,
        track.headDirection,
        VineMetrics.tubeWidth,
      );
      _headPaint
        ..shader = null
        ..color = color;
      canvas.drawPath(headPath, _headPaint);
      return;
    }

    // ---------- Textured styles: vertex strip pipeline ----------
    final texture = switch (vineStyle) {
      VineStyle.classic => classicTexture,
      VineStyle.blossom => blossomTexture,
      VineStyle.ethereal => etherealTexture,
      _ => null,
    };
    final shader = texture == null ? null : _shaderFor(texture);

    // 1. Tube strip (single draw call regardless of vine length).
    if (rail.strip != null) {
      _stripPaint
        ..shader = shader
        ..color = const Color(0xFFFFFFFF);
      canvas.drawVertices(rail.strip!, BlendMode.srcOver, _stripPaint);
    }

    // 2. Rounded caps (the legacy StrokeCap.round look, as two tiny canvas
    // draws — far cheaper than baking cap fans into the strip).
    track.sampleAt(headArc, _sample);
    final head = Offset(_sample[0], _sample[1]);
    final headAlpha = track.fadeAlphaAt(headArc);

    final tailArc = headArc - windowLength;
    track.sampleAt(tailArc, _sample);
    final tail = Offset(_sample[0], _sample[1]);
    final tailAlpha = track.fadeAlphaAt(tailArc);

    final capRadius = VineMetrics.tubeWidth / 2;
    final capPaint = (_capPaint)..shader = shader;
    capPaint.color = tint.withValues(alpha: headAlpha);
    canvas.drawCircle(head, capRadius, capPaint);
    capPaint.color = tint.withValues(alpha: tailAlpha);
    canvas.drawCircle(tail, capRadius, capPaint);

    // 3. Compact arrow head at the tip.
    final headPath = VineTubePath.buildArrowHead(
      head,
      track.headDirection,
      VineMetrics.tubeWidth,
    );
    _headPaint
      ..shader = shader
      ..color = tint.withValues(alpha: headAlpha);
    canvas.drawPath(headPath, _headPaint);

    // 4. Foliage quads (one drawVertices per vine).
    final foliageShader = useSimpleVines || foliageAtlasImage == null
        ? null
        : _shaderFor(foliageAtlasImage);
    if (rail.foliage != null && foliageShader != null) {
      _stripPaint
        ..shader = foliageShader
        ..color = const Color(0xFFFFFFFF);
      canvas.drawVertices(rail.foliage!, BlendMode.srcOver, _stripPaint);
    }
  }

  static final Paint _capPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _headPaint = Paint()..style = PaintingStyle.fill;

  /// Simple-pass stroke: solid AA vector stroke with round caps and joins.
  static final Paint _simplePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFFFFFFFF);
}
