import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'package:parable_bloom/core/providers/settings_providers.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_rail_draw.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_skin.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_tube_path.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

/// Native renderer pass for the rail architecture.
///
/// Two render paths per vine, both with draw-call count independent of vine
/// length:
/// - **Classic modular**: shaft strip + wrap overlay strip + head/tail
///   end sprites from the theme atlases (≤4 textured draws + optional
///   foliage). Themes/states swap by overlay tile, not by rebuilding
///   geometry.
/// - **Other textured styles**: one `drawVertices` for the tube strip
///   sampling the trellis/ivy JPEG, one for foliage quads, plus two flat
///   tube caps and a canvas arrow head.
/// - **Simple**: an anti-aliased stroked `Path` along the baked centerline
///   plus a solid arrow head — vector-crisp edges at any device pixel ratio.
///
/// Geometry comes straight from the invariant [VineTrack], so the tube
/// reads as one continuous object through turns and while exiting
/// off-screen. A failed clear attempt (withered) swaps wrap/head/tail to
/// the withered tiles (Classic) or modulates the JPEG tube brown.
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
    required VineStyle vineStyle,
    required bool useSimpleVines,

    /// The real trellis/ivy texture for non-modular textured styles; null
    /// degrades to flat-colored vertex strips.
    required ui.Image? textureImage,
    required ui.Image? foliageAtlasImage,

    /// Classic modular theme (shaft / wrap / ends). Null falls back to the
    /// single-texture pass even for [VineStyle.classic].
    VineSkinTheme? classicSkin,
    VineSkinState skinState = VineSkinState.live,

    /// Vertex RGB+alpha for the tube: white (healthy) lets the real texture
    /// show; [VineMetrics.witheredColor] turns dead vines brown.
    required Color tubeTint,

    /// Vertex RGB+alpha for foliage quads.
    required Color foliageTint,

    /// Flat fill color for caps and arrow head (non-modular styles).
    required Color capTint,
  }) {
    final track = rail.track;
    final headArc = rail.headArc;
    final windowLength = track.windowLength;

    // ---------- Simple render pass: anti-aliased stroked path ----------
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
      );
      return;
    }

    // ---------- Classic modular layered pass ----------
    if (VineSkinTheme.usesModularLayers(vineStyle) && classicSkin != null) {
      _drawClassicModular(
        canvas: canvas,
        rail: rail,
        theme: classicSkin,
        skinState: skinState,
        foliageAtlasImage: foliageAtlasImage,
      );
      return;
    }

    // ---------- Other textured styles: vertex strip pipeline ----------
    final shader = _shaderFor(textureImage);
    final tubeWidth = VineMetrics.texturedTubeWidth;

    if (rail.strip != null) {
      _stripPaint
        ..shader = shader
        ..color = const Color(0xFFFFFFFF);
      canvas.drawVertices(rail.strip!, BlendMode.srcOver, _stripPaint);
    }

    track.sampleAt(headArc, _sample);
    final head = Offset(_sample[0], _sample[1]);
    final headAlpha = track.fadeAlphaAt(headArc);

    final tailArc = headArc - windowLength;
    track.sampleAt(tailArc, _sample);
    final tail = Offset(_sample[0], _sample[1]);
    final tailAlpha = track.fadeAlphaAt(tailArc);

    final capRadius = tubeWidth / 2;
    final capPaint = (_capPaint)..shader = null;
    capPaint.color = capTint.withValues(alpha: headAlpha);
    canvas.drawCircle(head, capRadius, capPaint);
    capPaint.color = capTint.withValues(alpha: tailAlpha);
    canvas.drawCircle(tail, capRadius, capPaint);

    final headPath =
        VineTubePath.buildArrowHead(head, track.headDirection, tubeWidth);
    _headPaint
      ..shader = null
      ..color = capTint.withValues(alpha: headAlpha);
    canvas.drawPath(headPath, _headPaint);

    final foliageShader = _shaderFor(foliageAtlasImage);
    if (rail.foliage != null && foliageShader != null) {
      _stripPaint
        ..shader = foliageShader
        ..color = const Color(0xFFFFFFFF);
      canvas.drawVertices(rail.foliage!, BlendMode.srcOver, _stripPaint);
    }
  }

  static void _drawClassicModular({
    required Canvas canvas,
    required VineRailDraw rail,
    required VineSkinTheme theme,
    required VineSkinState skinState,
    required ui.Image? foliageAtlasImage,
  }) {
    // 1. Shaft (dough) base.
    final shaftShader = _shaderFor(theme.shaft);
    if (rail.strip != null && shaftShader != null) {
      _stripPaint
        ..shader = shaftShader
        ..color = const Color(0xFFFFFFFF);
      canvas.drawVertices(rail.strip!, BlendMode.srcOver, _stripPaint);
    }

    // 2. Wrap overlay (live or withered tile — alpha lets shaft show).
    final wrapShader = _shaderFor(theme.wrapFor(skinState));
    if (rail.wrapStrip != null && wrapShader != null) {
      _stripPaint
        ..shader = wrapShader
        ..color = const Color(0xFFFFFFFF);
      canvas.drawVertices(rail.wrapStrip!, BlendMode.srcOver, _stripPaint);
    }

    // 3. Sparse foliage garnish (calm/withered tint already in verts).
    final foliageShader = _shaderFor(foliageAtlasImage);
    if (rail.foliage != null && foliageShader != null) {
      _stripPaint
        ..shader = foliageShader
        ..color = const Color(0xFFFFFFFF);
      canvas.drawVertices(rail.foliage!, BlendMode.srcOver, _stripPaint);
    }

    // 4. Tail then head end sprites (head on top).
    final endsShader = _shaderFor(theme.endsAtlas);
    if (endsShader != null) {
      _stripPaint
        ..shader = endsShader
        ..color = const Color(0xFFFFFFFF);
      if (rail.tailVerts != null) {
        canvas.drawVertices(rail.tailVerts!, BlendMode.srcOver, _stripPaint);
      }
      if (rail.headVerts != null) {
        canvas.drawVertices(rail.headVerts!, BlendMode.srcOver, _stripPaint);
      }
    }
  }

  static void _drawSimpleBody({
    required Canvas canvas,
    required VineRailDraw rail,
    required VineTrack track,
    required double headArc,
    required double windowLength,
    required Color color,
  }) {
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
