import 'package:material_ui/material_ui.dart';

/// Ornament stamped along a vine body.
///
/// [leaves], [blossom], [glow], and [needles] are vector stamps on the
/// stroked vine. [none] is the flat stroke and draws no ornaments.
enum VineFoliage {
  leaves,
  blossom,
  glow,
  needles,
  none;

  static VineFoliage? parse(String? raw) {
    return switch (raw) {
      'leaves' => VineFoliage.leaves,
      'blossom' => VineFoliage.blossom,
      'glow' => VineFoliage.glow,
      'needles' => VineFoliage.needles,
      'none' => VineFoliage.none,
      _ => null,
    };
  }
}

/// One vine look published by an appearance pack.
///
/// The rail strokes [rail] (when set) and then a core. A null [core] uses
/// the vine's own calm color. A null [arrow] uses a lighter shade of that
/// core. [flat] is a single stroke and draws no rail or ornaments.
class VineSkin {
  const VineSkin({
    required this.id,
    required this.label,
    required this.foliage,
    this.textureAsset,
    this.flat = false,
    this.accent = defaultAccent,
    this.rail,
    this.core,
    this.arrow,
  });

  /// Hive id. Garden maps the old `classic` style to `trellis`.
  final String id;

  /// Settings label.
  final String label;

  /// Legacy trellis image. The stroke skins do not sample it.
  final String? textureAsset;

  /// Single calm-colored stroke. Ignores [rail] and [foliage].
  final bool flat;

  final VineFoliage foliage;

  /// Legacy accent. Stroke skins use [arrow] for the head.
  final Color accent;

  /// Outer stroke. Null on the flat skin.
  final Color? rail;

  /// Inner stroke. Null means the vine's calm color.
  final Color? core;

  /// Arrow fill. Null means a lighter shade of the body.
  final Color? arrow;

  /// Classic trellis accent. Matches the old leaf green.
  static const Color defaultAccent = Color(0xFF5E9C33);

  /// Maps a legacy `vineStyle` Hive value onto a garden skin id.
  static String idFromLegacyStyle(String style) {
    return switch (style) {
      'classic' => 'trellis',
      'simple' => 'flat',
      _ => style,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is VineSkin &&
        other.id == id &&
        other.label == label &&
        other.textureAsset == textureAsset &&
        other.flat == flat &&
        other.foliage == foliage &&
        other.accent == accent &&
        other.rail == rail &&
        other.core == core &&
        other.arrow == arrow;
  }

  @override
  int get hashCode => Object.hash(
        id,
        label,
        textureAsset,
        flat,
        foliage,
        accent,
        rail,
        core,
        arrow,
      );
}
