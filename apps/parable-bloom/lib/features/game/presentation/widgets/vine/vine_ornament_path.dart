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

/// Vector stamps along a vine, plus the winding stroke they sit on.
///
/// The wind is a sine off the centerline. Stamps sit on that curve and stop
/// short of the arrow. The reach off the centerline stays inside
/// [VineMetrics.ornamentReach].
class VineOrnamentPath {
  const VineOrnamentPath._();

  static const double _pitch = 42.0;

  /// True when [arc] is far enough behind [headArc] to miss the arrow.
  static bool clearsArrow(double headArc, double arc) =>
      headArc - arc >= VineMetrics.arrowClearArc;

  static ({Path wind, Path fill, Path detail}) build({
    required VineTrack track,
    required double headArc,
    required double windowLength,
    required int stride,
    required VineFoliage foliage,
    required Float32List scratch,
  }) {
    final wind = Path();
    final fill = Path();
    final detail = Path();
    if (foliage == VineFoliage.none) {
      return (wind: wind, fill: fill, detail: detail);
    }

    _addWind(wind, track, headArc, windowLength, scratch);

    final strideSafe = math.max(1, stride);
    final maxAnchor = (windowLength / _pitch).ceil().clamp(0, 4096);
    for (var i = strideSafe; i < maxAnchor; i += strideSafe) {
      final arc = headArc - i * _pitch;
      if (arc < headArc - windowLength) break;
      if (!clearsArrow(headArc, arc)) continue;

      track.sampleAt(arc, scratch);
      final origin = _alongWind(
        Offset(scratch[0], scratch[1]),
        scratch[2],
        scratch[3],
        arc,
      );
      final nx = scratch[2];
      final ny = scratch[3];
      final tangent = math.atan2(-nx, ny);
      switch (foliage) {
        case VineFoliage.leaves:
          _addLeaf(
            fill,
            detail,
            origin,
            tangent,
            bulge: i.isEven ? 1 : -1,
            scale: 0.55,
          );
        case VineFoliage.blossom:
          if (i.isEven) {
            _addBlossom(fill, detail, origin);
          } else {
            _addLeaf(fill, detail, origin, tangent, bulge: 1, scale: 0.42);
            final bud =
                origin + Offset(math.cos(tangent), math.sin(tangent)) * 5;
            detail
                .addOval(Rect.fromCenter(center: bud, width: 2.0, height: 2.8));
          }
        case VineFoliage.glow:
          _addGlow(fill, origin);
        case VineFoliage.needles:
          _addNeedles(fill, detail, origin, nx, ny, tangent);
        case VineFoliage.none:
          break;
      }
    }
    return (wind: wind, fill: fill, detail: detail);
  }

  static void _addWind(
    Path wind,
    VineTrack track,
    double headArc,
    double windowLength,
    Float32List scratch,
  ) {
    final tail = headArc - windowLength;
    final end = headArc - VineMetrics.arrowClearArc;
    if (end <= tail) return;
    var started = false;
    for (var arc = tail; arc <= end; arc += VineMetrics.windSample) {
      track.sampleAt(arc, scratch);
      final point = _alongWind(
        Offset(scratch[0], scratch[1]),
        scratch[2],
        scratch[3],
        arc,
      );
      if (!started) {
        wind.moveTo(point.dx, point.dy);
        started = true;
      } else {
        wind.lineTo(point.dx, point.dy);
      }
    }
  }

  /// Sine offset shared by the stroke and the stamps.
  static Offset _alongWind(Offset origin, double nx, double ny, double arc) {
    final off = math.sin(arc / VineMetrics.windWavelength * math.pi * 2) *
        VineMetrics.windAmplitude;
    return origin + Offset(nx, ny) * off;
  }

  static void _addLeaf(
    Path fill,
    Path detail,
    Offset origin,
    double angle, {
    required double bulge,
    double scale = 1,
  }) {
    final len = VineMetrics.leafLength * scale;
    final halfW = 4.5 * scale;
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

  /// Five teardrop petals and a gold center. The petal path points along +X.
  static void _addBlossom(Path fill, Path detail, Offset center) {
    const petalLen = 2.6;
    const petalW = 1.35;
    const orbit = 0.7;
    for (var k = 0; k < 5; k++) {
      final angle = k * math.pi * 2 / 5 - math.pi / 2;
      final base = center + Offset(math.cos(angle), math.sin(angle)) * orbit;
      fill.addPath(
        Path()
          ..moveTo(petalLen, 0)
          ..quadraticBezierTo(petalLen * 0.35, petalW, 0, 0.35)
          ..quadraticBezierTo(-0.15, 0, 0, -0.35)
          ..quadraticBezierTo(petalLen * 0.35, -petalW, petalLen, 0)
          ..close(),
        Offset.zero,
        matrix4: _matrix(base, angle),
      );
    }
    detail.addOval(Rect.fromCircle(center: center, radius: 1.05));
  }

  static void _addGlow(Path fill, Offset origin) {
    fill.addOval(Rect.fromCircle(center: origin, radius: 5));
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
          ..lineTo(7.5, 1.1)
          ..lineTo(7.5, -1.1)
          ..close(),
        Offset.zero,
        matrix4: _matrix(origin, tangent + delta),
      );
    }
    final berry = origin + Offset(nx, ny) * 3;
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
