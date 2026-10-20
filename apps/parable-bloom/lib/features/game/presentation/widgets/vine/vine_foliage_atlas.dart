import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:parable_bloom/core/providers/settings_providers.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

/// Baked foliage atlas for the rail renderer.
///
/// Five logical tiles in one row, drawn white (plus the fixed blossom
/// center) so per-vine tinting happens through vertex colors at draw time —
/// the same modulate `texture * color` contract the legacy painter used,
/// with zero per-leaf canvas draw calls at runtime.
///
/// Tile order:
/// 0. classic leaf, tip toward +x
/// 1. classic leaf mirrored vertically
/// 2. ethereal leaf core (hard edge)
/// 3. ethereal glow halo (soft edge)
/// 4. blossom flower (5 white petals + yellow center)
class VineFoliageAtlas {
  /// Logical tile size in world px (tiles are square).
  static const double tileSize = 20.0;

  /// Atlas resolution scale (image px per logical px).
  static const double bakeScale = 4.0;

  static const int tileClassicA = 0;
  static const int tileClassicB = 1;
  static const int tileEtherealA = 2;
  static const int tileEtherealGlow = 3;
  static const int tileBlossom = 4;
  static const int tileCount = 5;

  ui.Image? image;

  /// Bakes the atlas once per layer. GPU cheap via toImageSync; safe on
  /// Impeller, CanvasKit, and Skwasm.
  void bake() {
    final logicalW = tileSize * tileCount;
    final logicalH = tileSize;
    final w = (logicalW * bakeScale).round();
    final h = (logicalH * bakeScale).round();

    final recorder = ui.PictureRecorder();
    final canvas =
        ui.Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    canvas.scale(bakeScale);

    final white = Paint()..color = const Color(0xFFFFFFFF);

    // Classic leaf: same silhouette as the legacy painter's leaf path,
    // anchored around the tile center.
    const leafLen = tileSize * 0.45;
    final leaf = Path()
      ..moveTo(-leafLen / 2, 0)
      ..quadraticBezierTo(0, -leafLen * 0.32, leafLen / 2, 0)
      ..quadraticBezierTo(0, leafLen * 0.32, -leafLen / 2, 0)
      ..close();
    void drawTile(int tile, double scale, Paint paint, {bool flipY = false}) {
      canvas.save();
      canvas.translate(tileCenterX(tile), tileSize / 2);
      canvas.scale(scale, flipY ? -scale : scale);
      canvas.drawPath(leaf, paint);
      canvas.restore();
    }

    drawTile(tileClassicA, 1.0, white);
    drawTile(tileClassicB, 1.0, white, flipY: true);

    // Ethereal leaf core: slightly larger, hard edge.
    drawTile(tileEtherealA, 1.35, white);

    // Ethereal glow: soft halo around the leaf silhouette.
    drawTile(
      tileEtherealGlow,
      1.35,
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );

    // Blossom: 5 petals + yellow center (center color survives tinting).
    const petalRadius = tileSize * 0.20;
    const petalR = tileSize * 0.14;
    final blossomCenter = tileCenterX(tileBlossom);
    final cy = tileSize / 2;
    for (var i = 0; i < 5; i++) {
      final angle = (i / 5) * 2 * math.pi;
      canvas.drawCircle(
        Offset(
          blossomCenter + petalRadius * math.cos(angle),
          cy + petalRadius * math.sin(angle),
        ),
        petalR,
        white,
      );
    }
    canvas.drawCircle(
      Offset(blossomCenter, cy),
      tileSize * 0.10,
      Paint()..color = const Color(0xFFFFDB4D),
    );

    final picture = recorder.endRecording();
    image = picture.toImageSync(w, h);
  }

  static double tileCenterX(int tile) => (tile + 0.5) * tileSize;

  /// Whether foliage rendering is available for [style].
  bool supportsStyle(VineStyle style) =>
      image != null && style != VineStyle.simple;

  void dispose() {
    image?.dispose();
    image = null;
  }
}

/// Per-frame foliage quad builder: one [ui.Vertices] per vine regardless of
/// leaf count.
///
/// Quads are two indexed triangles (`triangles` mode), so consecutive leaves
/// are never chained by degenerate strip bridges.
class VineFoliageMesh {
  VineFoliageMesh({required this.atlas});

  final VineFoliageAtlas atlas;

  Float32List positions = Float32List(0);
  Float32List texCoords = Float32List(0);
  Int32List colors = Int32List(0);
  Uint16List indices = Uint16List(0);

  /// Number of quads written by the last [write] call.
  int quadCount = 0;

  void _ensure(int quads) {
    if (positions.length >= quads * 8) return;
    positions = Float32List(quads * 8);
    texCoords = Float32List(quads * 8);
    colors = Int32List(quads * 4);
    indices = Uint16List(quads * 6);
  }

  /// Writes leaf quads anchored to body cells along the vine window.
  ///
  /// Anchors mirror the legacy painter: foliage sits at cell body
  /// positions (it travels with the vine), every [stride]th cell, skipping
  /// the head cell. [halfWidth] is the tube half width for placement.
  void write({
    required VineTrack track,
    required double headArc,
    required double windowLength,
    required int stride,
    required VineStyle style,
    required Color tint,
    required double halfWidth,
    required Float32List scratch,
  }) {
    if (atlas.image == null || style == VineStyle.simple) {
      quadCount = 0;
      return;
    }
    final image = atlas.image!;
    final tilePx = VineFoliageAtlas.tileSize * VineFoliageAtlas.bakeScale;
    final atlasH = image.height.toDouble();

    // Cell-anchored foliage travels with the head: anchor i sits at arc
    // headArc - i * pitch (legacy foliage indexes body points).
    const pitch = 42.0;
    final maxAnchor = (windowLength / pitch).ceil().clamp(0, 4096);
    final quadsPerLeaf = switch (style) {
      VineStyle.classic => 2, // two mirrored leaves
      VineStyle.ethereal => 3, // glow + two mirrored leaves
      VineStyle.blossom => 1,
      _ => 0,
    };

    final strideSafe = math.max(1, stride);
    final anchorCount = (maxAnchor / strideSafe).ceil();
    _ensure(math.max(1, anchorCount * quadsPerLeaf + 1));

    var quad = 0;
    final capacity = positions.length ~/ 8;

    final int r;
    final int g;
    final int b;
    if (style == VineStyle.ethereal) {
      r = 255;
      g = 255;
      b = 255;
    } else {
      // Vertex color channels (API avoids the deprecated 8-bit getters).
      r = (tint.r * 255.0).round().clamp(0, 255);
      g = (tint.g * 255.0).round().clamp(0, 255);
      b = (tint.b * 255.0).round().clamp(0, 255);
    }

    for (var i = strideSafe; i < maxAnchor; i += strideSafe) {
      final arc = headArc - i * pitch;
      if (arc < headArc - windowLength) break;
      if (quad + quadsPerLeaf + 1 > capacity) break;

      track.sampleAt(arc, scratch);
      final x = scratch[0];
      final y = scratch[1];
      final nx = scratch[2];
      final ny = scratch[3];
      final alpha = (track.fadeAlphaAt(arc) * 255).round().clamp(0, 255);
      if (alpha <= 2) continue;

      final glow = style == VineStyle.ethereal;
      if (glow) {
        quad += _writeQuad(
          quad: quad,
          cx: x,
          cy: y,
          rot: 0,
          halfW: halfWidth * 2.6,
          halfH: halfWidth * 2.6,
          tile: VineFoliageAtlas.tileEtherealGlow,
          tilePx: tilePx,
          atlasH: atlasH,
          alphaValue: (alpha * 0.55).round(),
          tintR: 255,
          tintG: 255,
          tintB: 255,
        );
      }

      final tangentAngle = math.atan2(ny, nx);
      final rotA = tangentAngle + math.pi / 4;
      final rotB = tangentAngle - math.pi / 4;
      final halfSize = halfWidth * VineMetrics.leafScale * 2;

      if (style == VineStyle.blossom) {
        quad += _writeQuad(
          quad: quad,
          cx: x,
          cy: y,
          rot: 0,
          halfW: halfWidth * VineMetrics.blossomScale,
          halfH: halfWidth * VineMetrics.blossomScale,
          tile: VineFoliageAtlas.tileBlossom,
          tilePx: tilePx,
          atlasH: atlasH,
          alphaValue: alpha,
          tintR: r,
          tintG: g,
          tintB: b,
        );
      } else {
        quad += _writeQuad(
          quad: quad,
          cx: x,
          cy: y,
          rot: rotA,
          halfW: halfSize,
          halfH: halfSize * 0.7,
          tile: VineFoliageAtlas.tileClassicA,
          tilePx: tilePx,
          atlasH: atlasH,
          alphaValue: alpha,
          tintR: r,
          tintG: g,
          tintB: b,
        );
        quad += _writeQuad(
          quad: quad,
          cx: x,
          cy: y,
          rot: rotB,
          halfW: halfSize,
          halfH: halfSize * 0.7,
          tile: style == VineStyle.ethereal
              ? VineFoliageAtlas.tileEtherealA
              : VineFoliageAtlas.tileClassicB,
          tilePx: tilePx,
          atlasH: atlasH,
          alphaValue: alpha,
          tintR: r,
          tintG: g,
          tintB: b,
        );
      }
    }

    quadCount = quad;
  }

  /// Writes one textured quad at tile [tile] with rotation [rot].
  int _writeQuad({
    required int quad,
    required double cx,
    required double cy,
    required double rot,
    required double halfW,
    required double halfH,
    required int tile,
    required double tilePx,
    required double atlasH,
    required int alphaValue,
    required int tintR,
    required int tintG,
    required int tintB,
  }) {
    final cos = math.cos(rot);
    final sin = math.sin(rot);
    final u0 = tile * tilePx;
    final u1 = u0 + tilePx;
    final v0 = 0.0;
    final v1 = atlasH;
    final packed = (alphaValue << 24) | (tintR << 16) | (tintG << 8) | tintB;

    // Corner order: tl, bl, br, tr (indices build two triangles per quad).
    const cxs = <double>[-1, -1, 1, 1];
    const cys = <double>[-1, 1, 1, -1];
    final us = <double>[u0, u0, u1, u1];
    final vs = <double>[v0, v1, v1, v0];

    final p = quad * 8;
    final base = quad * 4;
    for (var c = 0; c < 4; c++) {
      final lx = halfW * cxs[c];
      final ly = halfH * cys[c];
      positions[p + c * 2] = cx + lx * cos - ly * sin;
      positions[p + c * 2 + 1] = cy + lx * sin + ly * cos;
      texCoords[p + c * 2] = us[c];
      texCoords[p + c * 2 + 1] = vs[c];
      colors[base + c] = packed;
    }
    final io = quad * 6;
    indices[io] = base;
    indices[io + 1] = base + 1;
    indices[io + 2] = base + 2;
    indices[io + 3] = base + 2;
    indices[io + 4] = base + 1;
    indices[io + 5] = base + 3;
    return 1;
  }

  /// Builds the [ui.Vertices] for the foliage quads, or null when empty.
  ui.Vertices? vertices() {
    if (quadCount <= 0 || atlas.image == null) return null;
    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.sublistView(positions, 0, quadCount * 8),
      textureCoordinates: Float32List.sublistView(texCoords, 0, quadCount * 8),
      colors: Int32List.sublistView(colors, 0, quadCount * 4),
      indices: Uint16List.sublistView(indices, 0, quadCount * 6),
    );
  }

  void dispose() {
    positions = Float32List(0);
    texCoords = Float32List(0);
    colors = Int32List(0);
    quadCount = 0;
  }
}
