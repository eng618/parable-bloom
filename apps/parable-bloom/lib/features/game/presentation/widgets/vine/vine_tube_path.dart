import 'package:flutter/material.dart';

import 'vine_metrics.dart';

/// Pure path builders for the thin-tube vine renderer.
///
/// Both helpers are allocation-light and fully deterministic, so they are
/// unit-testable without a Flame game instance.
class VineTubePath {
  const VineTubePath._();

  /// Build a rounded-corner tube path through [points].
  ///
  /// Straight runs use line segments; each interior corner is rounded with
  /// a quadratic bezier of at most [VineMetrics.cornerRadius], clamped to
  /// half the adjacent segment lengths.
  static Path buildRoundedTube(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length < 3) {
      path.moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      return path;
    }

    var radius = VineMetrics.cornerRadius;
    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];

      final inVec = curr - prev;
      final outVec = next - curr;
      final inLen = inVec.distance;
      final outLen = outVec.distance;
      if (inLen < 1e-6 || outLen < 1e-6) continue;

      final r = radius.clamp(0.0, inLen / 2).clamp(0.0, outLen / 2);
      final p1 = curr - (inVec / inLen) * r;
      final p2 = curr + (outVec / outLen) * r;
      path.lineTo(p1.dx, p1.dy);
      path.quadraticBezierTo(curr.dx, curr.dy, p2.dx, p2.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  /// Build a compact triangular arrow head at [head] pointing in [direction].
  ///
  /// Sized relative to [strokeWidth] so heads stay inside their own lane.
  static Path buildArrowHead(
      Offset head, String direction, double strokeWidth) {
    final length = strokeWidth * VineMetrics.arrowLengthScale;
    final halfWidth = strokeWidth * VineMetrics.arrowHalfWidthScale;
    final path = Path();

    switch (direction) {
      case 'up':
        path.moveTo(head.dx, head.dy - length * 0.7);
        path.lineTo(head.dx - halfWidth, head.dy + length * 0.3);
        path.lineTo(head.dx + halfWidth, head.dy + length * 0.3);
      case 'down':
        path.moveTo(head.dx, head.dy + length * 0.7);
        path.lineTo(head.dx - halfWidth, head.dy - length * 0.3);
        path.lineTo(head.dx + halfWidth, head.dy - length * 0.3);
      case 'left':
        path.moveTo(head.dx - length * 0.7, head.dy);
        path.lineTo(head.dx + length * 0.3, head.dy - halfWidth);
        path.lineTo(head.dx + length * 0.3, head.dy + halfWidth);
      case 'right':
      default:
        path.moveTo(head.dx + length * 0.7, head.dy);
        path.lineTo(head.dx - length * 0.3, head.dy - halfWidth);
        path.lineTo(head.dx - length * 0.3, head.dy + halfWidth);
    }
    path.close();
    return path;
  }
}
