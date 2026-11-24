import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_rail_draw.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_tube_path.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

/// Stroke pass for the rail architecture.
///
/// Every pack skin uses this path. A flat skin is one anti-aliased stroke.
/// A cored skin strokes a rail, then a narrower core, then fills a few
/// vector ornaments. The arrow is a triangle drawn last, sized from the
/// flat stroke so the direction stays readable.
///
/// Draw count stays independent of vine length: the centerline and the
/// ornament paths are cached while the vine is idle. There is no vertex
/// strip and no blur.
class VineRailRenderer {
  /// Shared mutable sample read-out ([VineTrack.sampleAt] contract).
  static final Float32List _sample = Float32List(VineTrack.positionW);

  static void draw({
    required Canvas canvas,
    required VineRailDraw rail,
    required Color coreColor,
    required Color arrowColor,
    Color? railColor,
    Color ornamentColor = const Color(0x00000000),
    Color ornamentDetailColor = const Color(0x00000000),
  }) {
    final track = rail.track;
    final headArc = rail.headArc;
    final windowLength = track.windowLength;
    final alpha = track.fadeAlphaAt(headArc);
    final path = rail.simplePath ?? track.windowPath(headArc, windowLength);

    if (railColor != null) {
      _stroke(
        canvas,
        path,
        railColor.withValues(alpha: railColor.a * alpha),
        VineMetrics.railWidth,
      );
      _stroke(
        canvas,
        path,
        coreColor.withValues(alpha: coreColor.a * alpha),
        VineMetrics.coreWidth,
      );
    } else {
      _stroke(
        canvas,
        path,
        coreColor.withValues(alpha: coreColor.a * alpha),
        VineMetrics.tubeWidth,
      );
    }

    _fill(canvas, rail.ornamentFill, ornamentColor, alpha);
    _fill(canvas, rail.ornamentDetail, ornamentDetailColor, alpha);

    track.sampleAt(headArc, _sample);
    _drawArrow(
      canvas: canvas,
      head: Offset(_sample[0], _sample[1]),
      direction: track.headDirection,
      fill: arrowColor.withValues(alpha: arrowColor.a * alpha),
    );
  }

  static void _stroke(Canvas canvas, Path path, Color color, double width) {
    _bodyPaint
      ..shader = null
      ..strokeWidth = width
      ..color = color;
    canvas.drawPath(path, _bodyPaint);
  }

  static void _fill(Canvas canvas, Path? path, Color color, double alpha) {
    if (path == null || color.a == 0 || path.getBounds().isEmpty) return;
    _fillPaint
      ..shader = null
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: color.a * alpha);
    canvas.drawPath(path, _fillPaint);
  }

  /// Dark rim, then the fill. The rim keeps the tip readable on the rail,
  /// the ornaments, and the day or night board. The triangle is sized from
  /// the flat stroke, not the rail.
  static void _drawArrow({
    required Canvas canvas,
    required Offset head,
    required String direction,
    required Color fill,
  }) {
    final path = VineTubePath.buildArrowHead(
      head,
      direction,
      VineMetrics.tubeWidth,
    );
    _arrowOutline
      ..shader = null
      ..strokeWidth = VineMetrics.tubeWidth * 0.18
      ..color = const Color(0xFF24180F).withValues(alpha: fill.a);
    canvas.drawPath(path, _arrowOutline);
    _headPaint
      ..shader = null
      ..style = PaintingStyle.fill
      ..color = fill;
    canvas.drawPath(path, _headPaint);
  }

  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _headPaint = Paint()..style = PaintingStyle.fill;

  static final Paint _arrowOutline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  static final Paint _bodyPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
}
