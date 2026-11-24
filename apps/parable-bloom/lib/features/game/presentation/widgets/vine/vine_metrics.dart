/// Central visual metrics for the thin-tube vine renderer.
///
/// Target look: thin uniform tubes with generous lane whitespace, tight
/// rounded corners, and compact arrow heads (see reference board art).
/// Lane pitch is 42px ([GameBoardLayout.pointSpacing]), so a 13px tube
/// leaves ~29px of breathing room between parallel vines.
library;

import 'package:material_ui/material_ui.dart';

import 'package:parable_bloom/core/constants/animation_timing.dart';
import 'package:parable_bloom/core/providers/settings_providers.dart'
    show VineStyle;
import 'package:parable_bloom/features/appearance/domain/vine_skin.dart';

class VineMetrics {
  const VineMetrics._();

  /// Uniform tube width for the flat/simple style (an AA vector stroke).
  static const double tubeWidth = 13.0;

  /// Tube width for the textured skin styles. The baked wood-trellis skin
  /// reads better as a slightly wider dowel than the flat vector stroke.
  static const double texturedTubeWidth = 18.0;

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
  /// advances one full vertical cycle. A short arc crushes the painting into
  /// a few pixels, so the skin never reads. One cycle spans about six cells.
  static const double textureRepeatArc = 252.0;

  /// Texture px sampled per world px across the tube's width for `u`. A
  /// narrow band keeps the tube reading as a single wood strip.
  static const double textureUPerPx = 2.5;

  /// Vine-stem accent color for caps and arrow heads on textured styles,
  /// per legacy style. Skins carry their own accent. The withered state
  /// overrides with [witheredColor].
  static Color accentColor(VineStyle style) => switch (style) {
        VineStyle.blossom => const Color(0xFFDE7FA4),
        VineStyle.ethereal => const Color(0xFF74F4FF),
        _ => const Color(0xFF5E9C33),
      };

  /// Corner rounding radius for the spline path. Clamped per-corner to half
  /// the adjacent segment lengths so tight U-turns can't overshoot.
  static const double cornerRadius = 12.0;

  /// Outer rail on a cored skin. Lane pitch is 42px, so a 15px rail still
  /// leaves a gap between parallel vines.
  static const double railWidth = 15.0;

  /// Living core drawn on top of [railWidth]. On a wood skin this is the
  /// lighter slat, not the vine.
  static const double coreWidth = 7.0;

  /// Thin vine that winds around a trellis shaft.
  static const double vineWidth = 2.5;

  /// One wrap of that vine, a little longer than a cell.
  static const double windWavelength = 56.0;

  /// How far the wind leaves the centerline. Stamps sit on this curve and
  /// must still fit inside [ornamentReach].
  static const double windAmplitude = 5.5;

  /// Step along the track when building the wind stroke.
  static const double windSample = 6.0;

  /// Arrow head length as a multiple of [tubeWidth]. The head is sized from
  /// the flat stroke, so a wider rail does not grow the triangle.
  static const double arrowLengthScale = 2.4;

  /// Arrow head half-width as a multiple of [tubeWidth].
  static const double arrowHalfWidthScale = 1.15;

  /// Extra gap behind the arrow tip before an ornament may sit.
  static const double arrowClearPad = 8.0;

  /// Leaf length along the vine. Ornaments also stop this far short of the
  /// arrow so a tip cannot land on the head.
  static const double leafLength = 12.0;

  /// Furthest an ornament may extend off the centerline.
  static const double ornamentReach = 11.0;

  static double get arrowClearArc =>
      tubeWidth * arrowLengthScale + arrowClearPad + leafLength * 0.6;

  /// Lighter shade of [body] for a flat arrow. The head stays in the vine's
  /// own family and does not pick up a pack accent.
  static Color contrastArrow(Color body) {
    final hsl = HSLColor.fromColor(body);
    return hsl
        .withLightness((hsl.lightness + 0.28).clamp(0.0, 0.92))
        .withSaturation((hsl.saturation * 0.7).clamp(0.0, 1.0))
        .toColor();
  }

  /// Foliage sizes relative to [tubeWidth]. Deliberately small so leaves
  /// and blossoms never bridge the lane gap.
  static const double leafScale = 0.85;
  static const double blossomScale = 1.05;

  /// Board-size-aware foliage LOD: fewer leaf draws per frame on dense
  /// boards. Animations keep stride 2 so motion still reads as lush.
  static int foliageStride(
      {required bool isAnimating, required int vineCount}) {
    if (isAnimating) return 2;
    if (vineCount > 20) return 4;
    return 3;
  }

  /// Per-cell time for a blocked wiggle. Long bumps stay on the fast step
  /// so a mistake returns home quickly. Successful clears do not use this;
  /// they cruise at [cruiseSecondsPerCell].
  static double stepDurationFor(int totalSteps) =>
      totalSteps > 12 ? 0.035 : 0.06;

  /// Seconds per cell for a clearing slide. The last vine on the board
  /// uses the slower ending cruise.
  static double cruiseSecondsPerCell({required bool isLastVine}) => isLastVine
      ? AnimationTiming.vineLastCruiseSecondsPerCell
      : AnimationTiming.vineCruiseSecondsPerCell;

  /// Extra travel past the board edge when the viewport size is unknown.
  ///
  /// Clearing vines no longer fade. With a live camera they run until the
  /// tail leaves the screen. This pad is only the fallback distance.
  static const double exitFadeArc = 63.0;

  /// Width of the baked strip-edge feather (per side, world px). Replaces
  /// the legacy `MaskFilter.blur` glow and gives CanvasKit-native
  /// `drawVertices` strips soft, anti-aliased-looking edges.
  static const double tubeFeather = 2.0;
}

/// Bucket the legacy path painter still switches on.
extension VineSkinLegacyStyle on VineSkin {
  VineStyle get legacyStyle {
    if (flat || foliage == VineFoliage.none) return VineStyle.simple;
    return switch (foliage) {
      VineFoliage.blossom => VineStyle.blossom,
      VineFoliage.glow => VineStyle.ethereal,
      VineFoliage.leaves || VineFoliage.needles => VineStyle.classic,
      VineFoliage.none => VineStyle.simple,
    };
  }
}
