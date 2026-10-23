import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';

/// Fixed centerline geometry ("rail") for one vine.
///
/// A clearing vine is a rigid shape sliding along an invariant track: the
/// head extends past the original path and the tail vacates, but the tube's
/// geometry never changes. Representing the vine as a sliding window over a
/// baked polyline is what makes every bind read as one continuous object.
///
/// Coordinate conventions:
/// - Arc position `0` sits at the head cell center at slide start.
/// - Negative arcs run back toward the tail cell.
/// - Positive arcs run forward past the grid edge along `headDirection`
///   (the head extension used to travel off-screen).
/// - Samples are uniformly spaced along arc: arc ↔ sample index is O(1).
///
/// Position and per-vertex fade alpha are static per sample; the renderer
/// only copies the visible sub-range each frame.
class VineTrack {
  /// Uniform sample spacing along the track (world px).
  static const double spacing = 8.0;

  final int gridWidth;
  final int gridHeight;

  /// Grid-space head direction ('right', 'left', 'up', 'down').
  final String headDirection;

  /// Arc where the head center visually crosses the board edge (where the
  /// exit fade begins).
  final double exitArc;

  /// Arc where the head center is one full cell beyond the edge: the bloom
  /// trigger, mirroring the legacy `hasExitedVisibleGrid` moment.
  final double exitTriggerArc;

  /// Baked-path arc length from tail cell to head cell. A moving vine's
  /// body window is exactly this long.
  final double windowLength;

  /// Head extension direction as a world-space unit vector.
  final Offset headDir;

  /// Head cell (grid coordinates) at arc 0.
  final int headCellX;
  final int headCellY;

  // Uniform samples, ascending arc. Arrays cover the whole track.
  late final Float32List sampleX;
  late final Float32List sampleY;
  late final Float32List sampleAlpha;

  /// Baked per-sample unit normals, interleaved (nx, ny).
  late final Float32List sampleNormals;

  /// Baked fine centerline (tail→head) with exact corner arcs — the same
  /// scale-free geometry the legacy `buildRoundedTube` drew. Used by the
  /// stroked-path (simple style) render pass for vector-crisp AA at any DPR.
  int fineCount = 0;
  late final Float32List fineX;
  late final Float32List fineY;
  late final Float32List fineCum;

  /// Track arc of sample i = `i * spacing - headArcOffset` (the fine
  /// resampling grid starts at the tail vertex, so the head cell center sits
  /// at fineArc = headArcOffset = track arc 0).
  final double headArcOffset;

  VineTrack._({
    required this.gridWidth,
    required this.gridHeight,
    required this.headDirection,
    required this.exitArc,
    required this.exitTriggerArc,
    required this.windowLength,
    required this.headDir,
    required this.headCellX,
    required this.headCellY,
    required this.headArcOffset,
  });

  int get sampleCount => sampleX.length;

  /// Arc of sample [i].
  double arcOf(int i) => i * spacing - headArcOffset;

  /// Most negative arc covered by the samples.
  double get startArc => arcOf(0);

  /// Largest arc covered by the samples.
  double get endArc => arcOf(sampleCount - 1);

  /// Whether [arc] lies inside `[startArc, endArc]`.
  bool containsArc(double arc) =>
      arc >= startArc - spacing && arc <= endArc + spacing;

  /// Base sample index at (or just before) [arc].
  int indexOfArc(double arc) {
    final i = ((arc + headArcOffset) / spacing).floor();
    return i.clamp(0, sampleCount - 2);
  }

  /// Interpolated position and normal at [arc].
  ///
  /// [out] receives `x, y, nx, ny` (see [positionW]).
  static const int positionW = 4;

  void sampleAt(double arc, Float32List out) {
    final base = indexOfArc(arc);
    final next = base + 1;
    final t = (arc - arcOf(base)) / spacing;
    final x0 = sampleX[base];
    final y0 = sampleY[base];
    out[0] = x0 + (sampleX[next] - x0) * t;
    out[1] = y0 + (sampleY[next] - y0) * t;

    // Blend normals across segment seams, then renormalize.
    var nx = sampleNormals[base * 2] +
        (sampleNormals[next * 2] - sampleNormals[base * 2]) * t;
    var ny = sampleNormals[base * 2 + 1] +
        (sampleNormals[next * 2 + 1] - sampleNormals[base * 2 + 1]) * t;
    final len = math.sqrt(nx * nx + ny * ny);
    if (len > 1e-6) {
      out[2] = nx / len;
      out[3] = ny / len;
    } else {
      out[2] = sampleNormals[base * 2];
      out[3] = sampleNormals[base * 2 + 1];
    }
  }

  /// World-space head center at [arc].
  Offset headAt(double arc) => Offset(
        lerpDouble(sampleX[indexOfArc(arc)], sampleX[indexOfArc(arc) + 1],
            (arc - arcOf(indexOfArc(arc))) / spacing)!,
        lerpDouble(sampleY[indexOfArc(arc)], sampleY[indexOfArc(arc) + 1],
            (arc - arcOf(indexOfArc(arc))) / spacing)!,
      );

  /// Grid cell under the head at [arc], unclamped: mirrors the legacy
  /// animator's `visualPositions[0]` semantics for exit checks.
  List<int> headCellAt(double arc) {
    final steps = (arc / GameBoardLayout.pointSpacing).round();
    switch (headDirection) {
      case 'right':
        return [headCellX + steps, headCellY];
      case 'left':
        return [headCellX - steps, headCellY];
      case 'up':
        return [headCellX, headCellY + steps];
      default:
        return [headCellX, headCellY - steps];
    }
  }

  /// Fade alpha for a track point at [trackArc]: fully visible inside the
  /// board, ramping to 0 across the exit fade band.
  double fadeAlphaAt(double trackArc) {
    if (trackArc <= exitArc) return 1.0;
    final fadeOut =
        ((trackArc - exitArc) / VineMetrics.exitFadeArc).clamp(0.0, 1.0);
    return 1.0 - fadeOut;
  }

  /// Builds the centerline [Path] for the sliding window
  /// `[headArc - windowLength, headArc]` from the baked fine polyline.
  ///
  /// Both window edges are cut exactly at the requested arc (interpolated
  /// mid-corner if needed), so a stroke along this path is the rigid vine
  /// body. O(fine points in window) — a few hundred at most — and the
  /// result is stroked with AA by the renderer, keeping edges vector-crisp
  /// at any device pixel ratio in both the `simple` render pass.
  Path windowPath(double headArc, double windowLength) {
    final lo =
        ((headArc - windowLength + headArcOffset).clamp(0.0, _fineTotal()));
    final hi = ((headArc + headArcOffset).clamp(lo, _fineTotal()));

    final path = Path();
    final loIdx = _bisectCum(lo);
    final start = _finePointAt(lo, loIdx);
    path.moveTo(start.dx, start.dy);
    for (var i = loIdx; i < fineCount && fineCum[i] <= hi; i++) {
      path.lineTo(fineX[i], fineY[i]);
    }
    final end = _finePointAt(hi, _bisectCum(hi));
    path.lineTo(end.dx, end.dy);
    return path;
  }

  double _fineTotal() => fineCum[fineCount - 1];

  /// First vertex index whose fine-cumulative arc is >= [arc].
  int _bisectCum(double arc) {
    var lo = 0;
    var hi = fineCount - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (fineCum[mid] < arc) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Interpolated point on the fine polyline at fine-arc [arc], binary
  /// bracketed by [idx] (first vertex with cum >= arc).
  Offset _finePointAt(double arc, int idx) {
    if (idx <= 0) return Offset(fineX[0], fineY[0]);
    if (idx >= fineCount) {
      return Offset(fineX[fineCount - 1], fineY[fineCount - 1]);
    }
    final c0 = fineCum[idx - 1];
    final c1 = fineCum[idx];
    if (c1 - c0 <= 1e-9) return Offset(fineX[idx], fineY[idx]);
    final t = ((arc - c0) / (c1 - c0)).clamp(0.0, 1.0);
    return Offset(
      fineX[idx - 1] + (fineX[idx] - fineX[idx - 1]) * t,
      fineY[idx - 1] + (fineY[idx] - fineY[idx - 1]) * t,
    );
  }

  /// Builds a track for one vine.
  ///
  /// [extensionArc] is the forward arc length past the head cell reserved
  /// for the off-screen exit slide (typically the clear-run plan length).
  factory VineTrack.build({
    required List<Map<String, int>> orderedPath,
    required String headDirection,
    required int gridWidth,
    required int gridHeight,
    required double extensionArc,
  }) {
    const pitch = GameBoardLayout.pointSpacing;
    const half = GameBoardLayout.cellSize / 2;
    final dpitch = pitch.toDouble();

    if (orderedPath.isEmpty) {
      throw ArgumentError('VineTrack.build: orderedPath is empty');
    }

    // Screen-space cell centers, legacy visual mapping (y=0 at the bottom).
    Offset center(Map<String, int> cell) {
      final x = cell['x'] ?? 0;
      final y = cell['y'] ?? 0;
      return Offset(x * dpitch + half, (gridHeight - 1 - y) * dpitch + half);
    }

    // Body polyline in tail → head order.
    final body = <Offset>[
      for (final cell in orderedPath.reversed) center(cell),
    ];
    final headCenter = body.last;
    final headCell = orderedPath.first;

    Offset dir;
    switch (headDirection) {
      case 'left':
        dir = const Offset(-1, 0);
      case 'up':
        dir = const Offset(0, -1);
      case 'down':
        dir = const Offset(0, 1);
      case 'right':
      default:
        dir = const Offset(1, 0);
    }

    // Forward extension: straight run past the board edge.
    if (extensionArc > 0) {
      final steps = (extensionArc / dpitch).ceil().clamp(1, 4096);
      for (var i = 1; i <= steps; i++) {
        body.add(headCenter + dir * (dpitch * i.toDouble()));
      }
    }

    // Bake rounded corners, then compute cumulative arc.
    final fine = bakeFinePolyline(body, radius: VineMetrics.cornerRadius);
    final cum = <double>[0.0];
    for (var i = 1; i < fine.length; i++) {
      cum.add(cum[i - 1] + (fine[i] - fine[i - 1]).distance);
    }
    var total = cum.last;

    // Pad the fine polyline to an exact multiple of the sample spacing so
    // arcOf(i) = i * spacing - headCum stays uniform for every sample.
    final remainder = total % spacing;
    if (remainder > 1e-6) {
      final pad = spacing - remainder;
      final lastIdx = fine.length - 1;
      var tx = fine[lastIdx].dx - fine[lastIdx - 1].dx;
      var ty = fine[lastIdx].dy - fine[lastIdx - 1].dy;
      final tlen = math.sqrt(tx * tx + ty * ty);
      if (tlen < 1e-9) {
        tx = 1;
        ty = 0;
      } else {
        tx /= tlen;
        ty /= tlen;
      }
      fine.add(
          Offset(fine[lastIdx].dx + tx * pad, fine[lastIdx].dy + ty * pad));
      cum.add(total + pad);
      total = cum.last;
    }

    // Arc coordinates of tail cell (0 by construction) and head cell.
    final headCum = _cumAtPoint(fine, cum, headCenter);
    // Arc coordinates are fine-arc minus headCum; no index offset needed.
    // Exit trigger: head center one full cell beyond the edge (bloom-time
    // parity with the legacy animator).
    final headCellX = headCell['x'] ?? 0;
    final headCellY = headCell['y'] ?? 0;
    double exitTrigger;
    double exit;
    switch (headDirection) {
      case 'right':
        exitTrigger = (gridWidth - headCellX) * dpitch;
        exit = (gridWidth - 1 - headCellX) * dpitch + half;
      case 'left':
        exitTrigger = (headCellX + 1) * dpitch;
        exit = headCellX * dpitch + half;
      case 'up':
        exitTrigger = (gridHeight - headCellY) * dpitch;
        exit = (gridHeight - 1 - headCellY) * dpitch + half;
      case 'down':
      default:
        exitTrigger = (headCellY + 1) * dpitch;
        exit = headCellY * dpitch + half;
    }

    final track = VineTrack._(
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      headDirection: headDirection,
      exitArc: exit,
      exitTriggerArc: exitTrigger,
      windowLength: headCum,
      headDir: dir,
      headCellX: headCellX,
      headCellY: headCellY,
      headArcOffset: headCum,
    );

    // Bake the fine centerline onto the track (exact path geometry for the
    // stroked-path simple render pass).
    track.fineCount = fine.length;
    track.fineX = Float32List(fine.length);
    track.fineY = Float32List(fine.length);
    track.fineCum = Float32List(fine.length);
    for (var i = 0; i < fine.length; i++) {
      track.fineX[i] = fine[i].dx;
      track.fineY[i] = fine[i].dy;
      track.fineCum[i] = cum[i];
    }

    // Resample uniformly across [0, total] fine arc. The fine grid starts
    // at the tail vertex, so the head cell center sits at fineArc =
    // headCum = track arc 0 — sample arcs are (i * spacing - headCum).
    final count = (total / spacing).ceil() + 1;
    track.sampleX = Float32List(count);
    track.sampleY = Float32List(count);
    track.sampleAlpha = Float32List(count);
    track.sampleNormals = Float32List(count * 2);

    for (var i = 0; i < count; i++) {
      final fineArc = (i * spacing).clamp(0.0, total).toDouble();
      final p = _resamplePoint(fine, cum, fineArc);
      track.sampleX[i] = p.dx;
      track.sampleY[i] = p.dy;

      // Normal from the chord toward the next sample.
      final nextArc = math.min(total, fineArc + spacing);
      final q = _resamplePoint(fine, cum, nextArc);
      var tx = q.dx - p.dx;
      var ty = q.dy - p.dy;
      final len = math.sqrt(tx * tx + ty * ty);
      if (len < 1e-9) {
        // Degenerate end sample: reuse previous normal.
        final pi = i == 0 ? 0 : i - 1;
        tx = -track.sampleNormals[pi * 2 + 1];
        ty = track.sampleNormals[pi * 2];
      } else {
        tx /= len;
        ty /= len;
      }
      track.sampleNormals[i * 2] = -ty;
      track.sampleNormals[i * 2 + 1] = tx;

      // Fade alpha is static per sample (arc in track space).
      final trackArc = fineArc - headCum;
      track.sampleAlpha[i] = track.fadeAlphaAt(trackArc).toDouble();
    }

    return track;
  }

  /// Cumulative fine-arc of the closest fine vertex to [p].
  static double _cumAtPoint(List<Offset> fine, List<double> cum, Offset p) {
    var bestI = 0;
    var bestD = double.infinity;
    for (var i = 0; i < fine.length; i++) {
      final d = (fine[i] - p).distanceSquared;
      if (d < bestD) {
        bestD = d;
        bestI = i;
      }
    }
    return cum[bestI];
  }

  static Offset _resamplePoint(
      List<Offset> fine, List<double> cum, double arc) {
    var lo = 0;
    var hi = cum.length - 1;
    while (lo + 1 < hi) {
      final mid = (lo + hi) >> 1;
      if (cum[mid] <= arc) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = cum[hi] - cum[lo];
    final t = span <= 1e-9 ? 0.0 : ((arc - cum[lo]) / span).clamp(0.0, 1.0);
    return fine[lo] + (fine[hi] - fine[lo]) * t;
  }

  /// Tight bounds of all sampled positions (renderer culling aid).
  Rect get bounds {
    var minX = sampleX[0], minY = sampleY[0];
    var maxX = minX, maxY = minY;
    for (var i = 1; i < sampleCount; i++) {
      if (sampleX[i] < minX) minX = sampleX[i];
      if (sampleY[i] < minY) minY = sampleY[i];
      if (sampleX[i] > maxX) maxX = sampleX[i];
      if (sampleY[i] > maxY) maxY = sampleY[i];
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Bakes the control polyline into a fine polyline with quadratic corner
  /// arcs — the same rounding as [VineTubePath.buildRoundedTube], resolved
  /// once here so corner geometry is invariant during animation.
  static List<Offset> bakeFinePolyline(
    List<Offset> control, {
    double radius = VineMetrics.cornerRadius,
  }) {
    // Drop near-duplicate points.
    final pts = <Offset>[];
    for (final p in control) {
      if (pts.isNotEmpty && (p - pts.last).distance < 1e-6) continue;
      pts.add(p);
    }
    if (pts.length < 3) return List<Offset>.from(pts);

    final out = <Offset>[];
    out.add(pts.first);
    const segments = 8;
    for (var i = 1; i < pts.length - 1; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final next = pts[i + 1];
      final inVec = curr - prev;
      final outVec = next - curr;
      final inLen = inVec.distance;
      final outLen = outVec.distance;

      // Interior collinear point: straight continuation.
      final cross = inVec.dx * outVec.dy - inVec.dy * outVec.dx;
      final dot = inVec.dx * outVec.dx + inVec.dy * outVec.dy;
      if (cross.abs() < 1e-9 && dot > 0) {
        out.add(curr);
        continue;
      }

      final r = radius.clamp(0.0, inLen / 2).clamp(0.0, outLen / 2).toDouble();
      final p1 = curr - (inVec / inLen) * r;
      final p2 = curr + (outVec / outLen) * r;
      out.add(p1);
      // Quadratic bezier through curr: subdivide into [segments] chords.
      for (var s = 1; s <= segments; s++) {
        final t = s / segments;
        final q1 = p1 + (curr - p1) * t;
        final q2 = curr + (p2 - curr) * t;
        out.add(q1 + (q2 - q1) * t);
      }
    }
    out.add(pts.last);
    return out;
  }
}
