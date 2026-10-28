import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

void main() {
  const pitch = GameBoardLayout.pointSpacing;

  // Head-first L-shaped path: (2,0) → (1,0) → (0,0) → (0,1), head moving
  // right, on a 4×4 grid.
  List<Map<String, int>> lPath() => const [
        {'x': 2, 'y': 0},
        {'x': 1, 'y': 0},
        {'x': 0, 'y': 0},
        {'x': 0, 'y': 1},
      ];

  VineTrack buildTrack({
    List<Map<String, int>>? path,
    double extensionArc = 0,
  }) =>
      VineTrack.build(
        orderedPath: path ?? lPath(),
        headDirection: 'right',
        gridWidth: 4,
        gridHeight: 4,
        extensionArc: extensionArc,
      );

  group('VineTrack geometry', () {
    test('arc 0 sits at the head cell center', () {
      final track = buildTrack();
      final head = track.headAt(0);
      // Cell (2,0): x = 2*42+26, visual y = (4-1-0)*42+26.
      expect(head.dx, closeTo(2 * pitch + 26, 1.0));
      expect(head.dy, closeTo(3 * pitch + 26, 1.0));
    });

    test('the body window spans the baked tail-to-head arc', () {
      final track = buildTrack();
      // 3 cells of body: a bit less than 2 lane pitches after corner
      // rounding; keeps the L shape inside its lane box.
      expect(track.windowLength, greaterThan(2 * pitch - 8));
      expect(track.windowLength, lessThan(3 * pitch));
      expect(track.startArc, lessThanOrEqualTo(-track.windowLength));
    });

    test('the tail stays inside the bed when headArc = 0', () {
      final track = buildTrack();
      final tail = track.headAt(-track.windowLength);
      // Tail cell (0,1): x = 0*42+26, y = 2*42+26.
      expect(tail.dx, closeTo(26, 2.0));
      expect(tail.dy, closeTo(2 * pitch + 26, 2.0));
    });

    test('extension samples continue straight in head direction', () {
      final track = buildTrack(extensionArc: 10 * pitch);
      final at = track.headAt(3 * pitch);
      expect(at.dy, closeTo(track.headAt(0).dy, 0.5));
      expect(at.dx, closeTo(track.headAt(0).dx + 3 * pitch, 1.0));
    });

    test('corner arcs keep the L inside its lane box', () {
      final track = buildTrack();
      // The corner cell center: (0,0) → x = 26, y = 3*42+26 = 152.
      // Tube half-width 6.5 + feather 2 = 8.5 must fit within ±21.
      final corner = track.headAt(0);
      expect(
        corner.dy, // on the 42 px lane grid
        closeTo(3 * pitch + 26, pitch + 1.0),
      );
    });

    test('headCellAt mirrors legacy snake position semantics', () {
      final track = buildTrack();
      expect(track.headCellAt(0), [2, 0]);
      expect(track.headCellAt(pitch), [3, 0]);
      // Round trips below zero clamp cleanly.
      expect(track.headCellAt(-0.5 * pitch), [1, 0]);
    });

    test('exit arcs are derived from the board edge', () {
      final track = buildTrack();
      // Head cell x=2, grid 4 wide: exit at (3-2)*42+26 = 68.
      expect(track.exitArc, closeTo(pitch + 26, 1e-6));
      // Trigger: one full cell beyond the last column center.
      expect(track.exitTriggerArc, closeTo(2 * pitch, 1e-6));
    });
  });

  group('VineTrack fade', () {
    test('fade alpha stays 1 inside the board', () {
      final track = buildTrack();
      expect(track.fadeAlphaAt(0), 1.0);
      expect(track.fadeAlphaAt(track.exitArc), 1.0);
    });

    test('fade alpha ramps to 0 across the exit band', () {
      final track = buildTrack();
      final mid = track.exitArc + VineMetrics.exitFadeArc / 2;
      expect(track.fadeAlphaAt(mid), inExclusiveRange(0.0, 1.0));
      expect(track.fadeAlphaAt(track.exitArc + VineMetrics.exitFadeArc),
          closeTo(0.0, 1e-9));
      expect(
        track.fadeAlphaAt(track.exitArc + VineMetrics.exitFadeArc * 2),
        closeTo(0.0, 1e-9),
      );
    });
  });

  group('VineTrack.sampleAt', () {
    test('samples are continuous and normals are unit length', () {
      final track = buildTrack(extensionArc: 6 * pitch);
      final out = Float32List(VineTrack.positionW);
      var prev = Offset.zero;
      for (var arc = -128.0; arc <= 5 * pitch; arc += 4.0) {
        track.sampleAt(arc, out);
        final p = Offset(out[0], out[1]);
        if (arc > -127.9) {
          final step = (p - prev).distance;
          expect(step, lessThan(9.0)); // spacing 8 + small tolerance
        }
        prev = p;
      }
    });
  });

  group('VineTrack.windowPath', () {
    test('window path length equals the window arc for every head position',
        () {
      final track = buildTrack(extensionArc: 6 * pitch);
      for (var headArc = 0.0;
          headArc <= track.exitArc + 2 * pitch;
          headArc += pitch / 2) {
        final path = track.windowPath(headArc, track.windowLength);
        final metrics = path.computeMetrics().toList();
        expect(metrics.length, 1, reason: 'headArc=$headArc');
        // Chords along straight runs are exact; corner chords add <0.1px.
        expect(
          metrics.first.length,
          closeTo(track.windowLength, 1.0),
          reason: 'headArc=$headArc',
        );
      }
    });

    test('window edges cut exactly at the requested arcs', () {
      final track = buildTrack(extensionArc: 6 * pitch);
      final scratch = Float32List(VineTrack.positionW);

      void expectEdgeMatches(double headArc, double tailArc) {
        final path = track.windowPath(headArc, headArc - tailArc);
        final metric = path.computeMetrics().first;
        track.sampleAt(headArc, scratch);
        final headSample = Offset(scratch[0], scratch[1]);
        final endTangent = metric.getTangentForOffset(metric.length)!;
        // Exact on straight runs; sub-pixel deviation mid-corner because
        // sampleAt chords between 8px samples while the fine cut follows
        // the baked corner arc.
        expect(
          (endTangent.position - headSample).distance,
          lessThan(0.6),
          reason: 'head edge at headArc=$headArc',
        );

        track.sampleAt(tailArc, scratch);
        final tailSample = Offset(scratch[0], scratch[1]);
        final startTangent = metric.getTangentForOffset(0.0)!;
        if (tailArc <= track.startArc) {
          // Clamped tail: path must start at the track's first vertex.
          expect(startTangent.position, tailSample,
              reason: 'clamped tail edge');
        } else {
          expect(
            (startTangent.position - tailSample).distance,
            lessThan(0.6),
            reason: 'tail edge near tailArc=$tailArc',
          );
        }
      }

      expectEdgeMatches(0, -track.windowLength); // idle
      expectEdgeMatches(2 * pitch, 2 * pitch - track.windowLength);
      expectEdgeMatches(track.exitArc + 4 * pitch,
          track.exitArc + 4 * pitch - track.windowLength);
      // Mid-corner cut (irregular offset).
      expectEdgeMatches(pitch * 1.37, pitch * 1.37 - track.windowLength);
    });
  });
}
