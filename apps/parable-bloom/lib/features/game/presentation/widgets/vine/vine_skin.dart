import 'dart:ui' as ui;

import 'package:parable_bloom/core/providers/settings_providers.dart'
    show VineStyle;

/// Visual health of a modular vine-arrow skin.
///
/// Moving and bloom reuse these same two looks — there is no distinct
/// "moving" tile set. Withered is sticky for the session after a blocked
/// clear attempt.
enum VineSkinState { live, withered }

/// One theme's layered part set (Classic first; later themes register the
/// same slots under `assets/art/skins/<id>/`).
///
/// Layers:
/// 1. [shaft] — dough / wood base strip (opaque, tileable)
/// 2. wrap — spiral vine overlay strip ([wrapLive] / [wrapWithered])
/// 3. head — oriented end sprite ([headLive] / [headWithered])
/// 4. tail — oriented end sprite ([tailLive] / [tailWithered])
class VineSkinTheme {
  const VineSkinTheme({
    required this.id,
    required this.shaft,
    required this.wrapLive,
    required this.wrapWithered,
    required this.endsAtlas,
    this.tileSize = 128.0,
    this.bodyColumnWidth = 256,
    this.bodyColumnHeight = 512,
  });

  /// Folder / registry id (`classic`, later `blossom`, …).
  final String id;

  final ui.Image shaft;
  final ui.Image wrapLive;
  final ui.Image wrapWithered;

  /// Row atlas: head_live | head_withered | tail_live | tail_withered.
  final ui.Image endsAtlas;

  /// Logical end-sprite tile size (atlas is [tileSize] × 4 wide).
  final double tileSize;

  final int bodyColumnWidth;
  final int bodyColumnHeight;

  ui.Image wrapFor(VineSkinState state) =>
      state == VineSkinState.withered ? wrapWithered : wrapLive;

  /// Tile index into [endsAtlas]: 0 head_live, 1 head_withered, 2 tail_live,
  /// 3 tail_withered.
  int headTile(VineSkinState state) =>
      state == VineSkinState.withered ? 1 : 0;

  int tailTile(VineSkinState state) =>
      state == VineSkinState.withered ? 3 : 2;

  /// Whether [style] should use this modular layered pass.
  static bool usesModularLayers(VineStyle style) => style == VineStyle.classic;
}

/// Classic theme asset paths under Flame's `assets/images/` root
/// (files live in `assets/art/skins/classic/` and are remapped via the
/// art→images convention used by existing vine textures).
class ClassicVineSkinPaths {
  const ClassicVineSkinPaths._();

  static const String folder = 'skins/classic';
  static const String shaft = '$folder/shaft.png';
  static const String wrapLive = '$folder/wrap_live.png';
  static const String wrapWithered = '$folder/wrap_withered.png';
  static const String endsAtlas = '$folder/ends_atlas.png';
  static const String bodyAtlas = '$folder/body_atlas.png';
}
