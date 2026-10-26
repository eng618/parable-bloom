/// Central visual metrics for the thin-tube vine renderer.
///
/// Target look: thin uniform tubes with generous lane whitespace, tight
/// rounded corners, and compact arrow heads (see reference board art).
/// Lane pitch is 42px ([GameBoardLayout.pointSpacing]), so a 13px tube
/// leaves ~29px of breathing room between parallel vines.
library;

import 'package:flutter/material.dart';

import 'package:parable_bloom/core/providers/settings_providers.dart'
    show VineStyle;

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

  /// Tube-texture UV parameters for the textured rail styles.
  ///
  /// The real trellis/ivy image is wrapped around the tube with cylindrical
  /// UVs: `v` (along the tube axis) advances with the vine body so the
  /// texture is pinned to the rigid vine and travels with it; `u`
  /// (around the tube's circumference) is a narrow, per-column sliver of
  /// bark so the tube reads as a wood dowel, not random color bands.
  ///
  /// [textureRepeatArc] is the body arc (world px) over which the texture
  /// advances one full vertical cycle. Smaller = tighter pattern repeat.
  static const double textureRepeatArc = 63.0;

  /// Texture px sampled per world px across the tube's width for `u`. A
  /// narrow band keeps the tube reading as a single wood strip.
  static const double textureUPerPx = 2.5;

  /// Vine-stem accent color for caps and arrow heads on textured styles,
  /// per style. The withered state overrides with [witheredColor].
  static Color accentColor(VineStyle style) => switch (style) {
        VineStyle.blossom => const Color(0xFFDE7FA4),
        VineStyle.ethereal => const Color(0xFF74F4FF),
        _ => const Color(0xFF5E9C33),
      };

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
