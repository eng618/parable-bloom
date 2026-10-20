import 'dart:ui' as ui;

import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

/// Per-frame rail draw payloads produced by the vine component's
/// [VineComponent.prepareRailDraw] and consumed by the rail renderer.
///
/// `strip` and `foliage` are ready-to-draw [ui.Vertices] objects; the
/// batched layer renders exactly one `drawVertices` call for each, so
/// draw-call count is independent of vine length (foliage may be null).
final class VineRailDraw {
  const VineRailDraw({
    required this.track,
    required this.headArc,
    required this.strip,
    required this.foliage,
  });

  final VineTrack track;
  final double headArc;
  final ui.Vertices? strip;
  final ui.Vertices? foliage;
}
