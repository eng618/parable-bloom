import 'package:material_ui/material_ui.dart';

/// How foliage quads are baked for a textured vine skin.
///
/// Counts match the rail atlas: two mirrored leaves, one blossom, or a glow
/// plus two leaves. [none] is the flat stroke, which draws no foliage.
enum VineFoliage {
  leaves,
  blossom,
  glow,
  none;

  static VineFoliage? parse(String? raw) {
    return switch (raw) {
      'leaves' => VineFoliage.leaves,
      'blossom' => VineFoliage.blossom,
      'glow' => VineFoliage.glow,
      'none' => VineFoliage.none,
      _ => null,
    };
  }
}

/// One vine look published by an appearance pack.
///
/// The rail renderer loads [textureAsset], draws [foliage], and paints caps
/// in [accent]. [flat] is the stroked vine and draws no trellis strip.
class VineSkin {
  const VineSkin({
    required this.id,
    required this.label,
    required this.foliage,
    this.textureAsset,
    this.flat = false,
    this.accent = defaultAccent,
  });

  /// Hive id. Garden maps the old `classic` style to `trellis`.
  final String id;

  /// Settings label.
  final String label;

  /// Flutter asset key of the trellis strip. Null when [flat] is set.
  final String? textureAsset;

  /// Stroked vector vine. Ignores [textureAsset].
  final bool flat;

  final VineFoliage foliage;

  /// Arrow and cap color for a textured skin.
  final Color accent;

  /// Classic trellis accent. Matches `VineMetrics.accentColor` for classic.
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
        other.accent == accent;
  }

  @override
  int get hashCode =>
      Object.hash(id, label, textureAsset, flat, foliage, accent);
}
