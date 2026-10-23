/// Central visual metrics for the thin-tube vine renderer.
///
/// Target look: thin uniform tubes with generous lane whitespace, tight
/// rounded corners, and compact arrow heads (see reference board art).
/// Lane pitch is 42px ([GameBoardLayout.pointSpacing]), so a 13px tube
/// leaves ~29px of breathing room between parallel vines.
library;

import 'package:flutter/material.dart';

class VineMetrics {
  const VineMetrics._();

  /// Uniform tube width for the flat/simple style (an AA vector stroke).
  static const double tubeWidth = 13.0;

  /// Tube width for the textured skin styles. The baked wood-trellis skin
  /// reads better as a slightly wider dowel than the flat vector stroke.
  static const double texturedTubeWidth = 15.0;

  /// Withered palette: one warm bark brown for the tube, foliage, and caps
  /// after a failed clear attempt. Deliberately theme-independent — dead
  /// vine brown must not follow light/dark theming.
  static const Color witheredColor = Color(0xFF8B5E34);

  /// Corner rounding radius for the spline path. Clamped per-corner to half
  /// the adjacent segment lengths so tight U-turns can't overshoot.
  static const double cornerRadius = 12.0;

  /// Arrow head length as a multiple of [tubeWidth]. Chunky enough to read
  /// as a solid directional marker from across the board.
  static const double arrowLengthScale = 2.1;

  /// Arrow head half-width as a multiple of [tubeWidth].
  static const double arrowHalfWidthScale = 1.05;

  /// Foliage sizes relative to [tubeWidth]. Deliberately small so leaves
  /// and blossoms never bridge the lane gap.
  static const double leafScale = 0.55;
  static const double blossomScale = 0.8;

  /// Board-size-aware foliage LOD: fewer leaf draws per frame on dense
  /// boards. Animations keep stride 2 so motion still reads as lush.
  static int foliageStride(
      {required bool isAnimating, required int vineCount}) {
    if (isAnimating) return 2;
    if (vineCount > 20) return 4;
    return 3;
  }

  /// Per-cell slide time. Long clears use the fast step so total clear time
  /// stays snappy (~1s worst case) instead of scaling linearly with length.
  static double stepDurationFor(int totalSteps) =>
      totalSteps > 12 ? 0.035 : 0.06;

  /// Arc length of the exit fade band (world px). After the head crosses
  /// the board edge (see [VineTrack.exitArc]), per-vertex alpha ramps 1→0
  /// across this distance — the rail renderer's replacement for unclipped
  /// travel + late culling.
  static const double exitFadeArc = 63.0;

  /// Width of the baked strip-edge feather (per side, world px). Replaces
  /// the legacy `MaskFilter.blur` glow and gives CanvasKit-native
  /// `drawVertices` strips soft, anti-aliased-looking edges.
  static const double tubeFeather = 2.0;
}
