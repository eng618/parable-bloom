import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:parable_bloom/features/appearance/domain/vine_skin.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

/// Fill and detail colors for one ornament kind.
///
/// These belong to the skin, not the vine's calm color, so a trellis reads
/// as leaves even when the core stays sage.
class VineOrnamentPaints {
  const VineOrnamentPaints(this.fill, this.detail);

  final Color fill;
  final Color detail;

  static VineOrnamentPaints forKind(VineFoliage foliage) {
    return switch (foliage) {
      VineFoliage.leaves => const VineOrnamentPaints(
          Color(0xFF3E7A32),
          Color(0xFF24521E),
        ),
      VineFoliage.blossom => const VineOrnamentPaints(
          Color(0xFFDE7FA4),
          Color(0xFFF2D36B),
        ),
      VineFoliage.glow => const VineOrnamentPaints(
          Color(0x7374F4FF),
          Color(0x00000000),
        ),
      VineFoliage.needles => const VineOrnamentPaints(
          Color(0xFF2F6B45),
          Color(0xFF9B3A3A),
        ),
      VineFoliage.none => const VineOrnamentPaints(
          Color(0x00000000),
          Color(0x00000000),
        ),
    };
  }
}

/// Vector stamps along a vine, as two paths the stroke renderer fills.
///
/// Stamps sit on the body and stop short of the arrow. The reach off the
/// centerline stays inside [VineMetrics.ornamentReach].
class VineOrnamentPath {
  const VineOrnamentPath._();

  static const double _pitch = 42.0;
  static const double _side = 6.0;

  /// True when [arc] is far enough behind [headArc] to miss the arrow.
  static bool clearsArrow(double headArc, double arc) =>
      headArc - arc >= VineMetrics.arrowClearArc;

  static ({Path fill, Path detail}) build({
    required VineTrack track,
    required double headArc,
    required double windowLength,
    required int stride,
    required VineFoliage foliage,
    required Float32List scratch,
  }) {
    final fill = Path();
    final detail = Path();
    if (foliage == VineFoliage.none) {
      return (fill: fill, detail: detail);
    }

    final strideSafe = math.max(1, stride);
    final maxAnchor = (windowLength / _pitch).ceil().clamp(0, 4096);
    for (var i = strideSafe; i < maxAnchor; i += strideSafe) {
      final arc = headArc - i * _pitch;
      if (arc < headArc - windowLength) break;
      if (!clearsArrow(headArc, arc)) continue;

      track.sampleAt(arc, scratch);
      final origin = Offset(scratch[0], scratch[1]);
      final nx = scratch[2];
      final ny = scratch[3];
      final tangent = math.atan2(-nx, ny);
      switch (foliage) {
        case VineFoliage.leaves:
          _addLeafPair(fill, detail, origin, nx, ny, tangent, i.isEven);
        case VineFoliage.blossom:
          _addBlossom(fill, detail, origin, nx, ny);
        case VineFoliage.glow:
          _addGlow(fill, origin);
        case VineFoliage.needles:
          _addNeedles(fill, detail, origin, nx, ny, tangent);
        case VineFoliage.none:
          break;
      }
    }
    return (fill: fill, detail: detail);
  }

  static void _addLeafPair(
    Path fill,
    Path detail,
    Offset origin,
    double nx,
    double ny,
    double tangent,
    bool flip,
  ) {
    final left = origin + Offset(nx, ny) * _side;
    final right = origin - Offset(nx, ny) * _side;
    _addLeaf(fill, detail, left, tangent, bulge: flip ? 1 : -1);
    _addLeaf(fill, detail, right, tangent, bulge: flip ? -1 : 1);
  }

  static void _addLeaf(
    Path fill,
    Path detail,
    Offset origin,
    double angle, {
    required double bulge,
  }) {
    const len = VineMetrics.leafLength;
    const halfW = 4.5;
    final wy = halfW * bulge;
    fill.addPath(
      Path()
        ..moveTo(-len * 0.35, 0)
        ..quadraticBezierTo(0, wy, len * 0.65, 0)
        ..quadraticBezierTo(0, -wy, -len * 0.35, 0)
        ..close(),
      Offset.zero,
      matrix4: _matrix(origin, angle),
    );
    detail.addPath(
      Path()
        ..moveTo(-len * 0.25, 0)
        ..lineTo(len * 0.5, 0.7)
        ..lineTo(len * 0.5, -0.7)
        ..close(),
      Offset.zero,
      matrix4: _matrix(origin, angle),
    );
  }

  static void _addBlossom(
    Path fill,
    Path detail,
    Offset origin,
    double nx,
    double ny,
  ) {
    final center = origin + Offset(nx, ny) * _side;
    const orbit = 2.2;
    const rx = 2.4;
    const ry = 1.6;
    for (var k = 0; k < 5; k++) {
      final angle = k * math.pi * 2 / 5;
      final petal = center + Offset(math.cos(angle), math.sin(angle)) * orbit;
      fill.addPath(
        Path()
          ..addOval(Rect.fromCenter(
              center: Offset.zero, width: rx * 2, height: ry * 2)),
        Offset.zero,
        matrix4: _matrix(petal, angle),
      );
    }
    detail.addOval(Rect.fromCircle(center: center, radius: 1.7));
  }

  static void _addGlow(Path fill, Offset origin) {
    fill.addOval(Rect.fromCircle(center: origin, radius: 8));
  }

  static void _addNeedles(
    Path fill,
    Path detail,
    Offset origin,
    double nx,
    double ny,
    double tangent,
  ) {
    for (final delta in const [-0.55, 0.0, 0.55]) {
      fill.addPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(9, 1.2)
          ..lineTo(9, -1.2)
          ..close(),
        Offset.zero,
        matrix4: _matrix(origin, tangent + delta),
      );
    }
    final berry = origin + Offset(nx, ny) * 4;
    detail.addOval(Rect.fromCircle(center: berry, radius: 2.2));
  }

  static Float64List _matrix(Offset origin, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Float64List.fromList([
      c,
      s,
      0,
      0,
      -s,
      c,
      0,
      0,
      0,
      0,
      1,
      0,
      origin.dx,
      origin.dy,
      0,
      1,
    ]);
  }
}
