import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_skin.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

/// Oriented head/tail quads sampled from a theme's ends atlas.
///
/// One indexed-triangle quad per end — draw-call cost is constant and the
/// sprites ride the same track samples as the tube caps.
class VineEndSprites {
  VineEndSprites();

  static final Float32List _sample = Float32List(VineTrack.positionW);

  /// Builds a single textured quad at [arc] on [track], sampling atlas
  /// tile [tile] (0..3) from an ends atlas of [tileSize] logical px.
  static ui.Vertices? quad({
    required VineSkinTheme theme,
    required VineTrack track,
    required double arc,
    required int tile,
    required Color tint,
    required double halfSize,
    required bool flipForTail,
  }) {
    track.sampleAt(arc, _sample);
    final cx = _sample[0];
    final cy = _sample[1];
    // Tangent from the sampled normal (normal is perpendicular to travel).
    final nx = _sample[2];
    final ny = _sample[3];
    // Travel direction = rotate normal by -90° (n=(nx,ny) → t=(ny,-nx)).
    var tx = ny;
    var ty = -nx;
    final tLen = math.sqrt(tx * tx + ty * ty);
    if (tLen > 1e-6) {
      tx /= tLen;
      ty /= tLen;
    } else {
      tx = 1;
      ty = 0;
    }
    // Head art points +x in the atlas; align +x with travel. Tail art
    // points −x (fletching fans left), so flip the tangent for tails.
    if (flipForTail) {
      tx = -tx;
      ty = -ty;
    }
    final rot = math.atan2(ty, tx);

    final image = theme.endsAtlas;
    // Atlas may be device-pixel denser than logical tileSize; scale UVs
    // from the actual image width (4 tiles across).
    final atlasTileW = image.width / 4.0;
    final atlasH = image.height.toDouble();
    final u0 = tile * atlasTileW;
    final u1 = u0 + atlasTileW;
    final v0 = 0.0;
    final v1 = atlasH;

    final alpha = (track.fadeAlphaAt(arc) * tint.a * 255.0).round().clamp(0, 255);
    if (alpha <= 2) return null;
    final r = (tint.r * 255.0).round().clamp(0, 255);
    final g = (tint.g * 255.0).round().clamp(0, 255);
    final b = (tint.b * 255.0).round().clamp(0, 255);
    final packed = (alpha << 24) | (r << 16) | (g << 8) | b;

    final cos = math.cos(rot);
    final sin = math.sin(rot);
    // Tip offset: nudge head slightly forward so the bud clears the tube.
    final tipPush = flipForTail ? -halfSize * 0.15 : halfSize * 0.35;
    final ox = cx + tx * tipPush;
    final oy = cy + ty * tipPush;

    const cxs = <double>[-1, -1, 1, 1];
    const cys = <double>[-1, 1, 1, -1];
    final us = <double>[u0, u0, u1, u1];
    final vs = <double>[v0, v1, v1, v0];

    final positions = Float32List(8);
    final texCoords = Float32List(8);
    final colors = Int32List(4);
    for (var c = 0; c < 4; c++) {
      final lx = halfSize * cxs[c];
      final ly = halfSize * 0.72 * cys[c];
      positions[c * 2] = ox + lx * cos - ly * sin;
      positions[c * 2 + 1] = oy + lx * sin + ly * cos;
      texCoords[c * 2] = us[c];
      texCoords[c * 2 + 1] = vs[c];
      colors[c] = packed;
    }

    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      colors: colors,
      indices: Uint16List.fromList(const [0, 1, 2, 2, 1, 3]),
    );
  }

  /// Half-size for end sprites relative to the textured tube.
  static double halfSizeForTube() =>
      VineMetrics.texturedTubeWidth * VineMetrics.skinEndScale;
}
