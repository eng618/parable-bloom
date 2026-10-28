import 'dart:ui' as ui;

import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

/// Per-frame rail draw payloads produced by the vine component's
/// [VineComponent.prepareRailDraw] and consumed by the rail renderer.
///
/// `strip` and `foliage` are ready-to-draw [ui.Vertices] objects; the
/// batched layer renders exactly one `drawVertices` call for each, so
/// draw-call count is independent of vine length (foliage may be null).
///
/// `simplePath` carries the stroked centerline for the flat/simple render
/// pass (anti-aliased `drawPath` — vector-crisp at any device pixel ratio).
/// Vertex may be null when the vine renders through the simple pass.
final class VineRailDraw {
  const VineRailDraw({
    required this.track,
    required this.headArc,
    required this.strip,
    required this.foliage,
    this.simplePath,
  });

  final VineTrack track;
  final double headArc;
  final ui.Vertices? strip;
  final ui.Vertices? foliage;

  /// Centerline path for the window `[headArc - windowLength, headArc]`
  /// (simple render pass only; null for textured styles).
  final ui.Path? simplePath;
}
