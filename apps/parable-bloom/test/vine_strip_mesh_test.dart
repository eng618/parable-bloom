import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_strip_mesh.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

void main() {
  const pitch = GameBoardLayout.pointSpacing;

  List<Map<String, int>> path() => const [
        {'x': 2, 'y': 0},
        {'x': 1, 'y': 0},
        {'x': 0, 'y': 0},
        {'x': 0, 'y': 1},
      ];

  VineTrack buildTrack() => VineTrack.build(
        orderedPath: path(),
        headDirection: 'right',
        gridWidth: 4,
        gridHeight: 4,
        extensionArc: 8 * pitch,
      );

  group('VineStripMesh.writeWindow', () {
    test('static window covers the body; tiny windows still yield rows', () {
      final track = buildTrack();
      final buffers = VineStripMesh.allocate(track);
      final vertexCount = VineStripMesh.writeWindow(
        track: track,
        headArc: 0,
        windowLength: track.windowLength,
        buffers: buffers,
        tint: const Color(0xFF123456),
        halfWidth: VineMetrics.tubeWidth / 2,
      );
      expect(buffers.lastVertexCount, vertexCount);
      expect(
        vertexCount,
        greaterThanOrEqualTo(3 * VineStripMesh.columns),
      );
      // A window narrower than one sample spacing still makes one row.
      final tiny = VineStripMesh.writeWindow(
        track: track,
        headArc: 2.0,
        windowLength: 1.0,
        buffers: buffers,
        tint: const Color(0xFF123456),
        halfWidth: VineMetrics.tubeWidth / 2,
      );
      expect(tiny, 2 * VineStripMesh.columns);
    });

    test('UVs anchor to the world via the legacy 0.25 scale', () {
      final track = buildTrack();
      final buffers = VineStripMesh.allocate(track);
      VineStripMesh.writeWindow(
        track: track,
        headArc: 0,
        windowLength: track.windowLength,
        buffers: buffers,
        tint: const Color(0xFF123456),
        halfWidth: VineMetrics.tubeWidth / 2,
      );
      // Row 0 is the tail edge (tail cell x = 0*42 + 26 = 26 → u = 6.5).
      final u = buffers.texCoords[0];
      expect(u, closeTo(26 * VineTrack.textureScale, 0.5));
      // Columns within one row share the same world-anchored UV.
      final uLast = buffers.texCoords[(2 * VineStripMesh.columns - 1) * 2];
      expect(uLast, closeTo(u, 0.5));
    });

    test('vertex colors encode tint and fade alpha', () {
      final track = buildTrack();
      final buffers = VineStripMesh.allocate(track);
      // Head is far past the fade band.
      VineStripMesh.writeWindow(
        track: track,
        headArc: track.exitArc + VineMetrics.exitFadeArc,
        windowLength: track.windowLength,
        buffers: buffers,
        tint: const Color(0xFFFF00FF),
        halfWidth: VineMetrics.tubeWidth / 2,
      );
      final lastVertexColor = buffers.colors[buffers.lastVertexCount - 1];
      expect((lastVertexColor >> 24) & 0xFF, 0);

      // Tail (inside board): opaque tinted core vertices of row 0.
      VineStripMesh.writeWindow(
        track: track,
        headArc: 0,
        windowLength: track.windowLength,
        buffers: buffers,
        tint: const Color(0xFFFF00FF),
        halfWidth: VineMetrics.tubeWidth / 2,
      );
      for (var k = 1; k < VineStripMesh.columns - 1; k++) {
        final coreColor = buffers.colors[k];
        expect(
          (coreColor >> 24) & 0xFF,
          greaterThan(200),
          reason: 'core vertex $k must be opaque',
        );
        expect((coreColor >> 8) & 0xFF, 0); // green channel of 0xFFFF00FF
      }
    });

    test('strip vertices stay inside the expanded tube width', () {
      final track = buildTrack();
      final buffers = VineStripMesh.allocate(track);
      VineStripMesh.writeWindow(
        track: track,
        headArc: 0,
        windowLength: track.windowLength,
        buffers: buffers,
        tint: const Color(0xFF000000),
        halfWidth: VineMetrics.tubeWidth / 2,
      );
      final limit = (VineMetrics.tubeWidth / 2) + VineMetrics.tubeFeather + 0.1;
      // Vertex column opposite the row's centerline point: verify each
      // vertex sits within the expanded tube width of its own row center.
      final scratch = Float32List(VineTrack.positionW);
      final rowCount = buffers.lastVertexCount ~/ VineStripMesh.columns;
      for (var row = 0; row < rowCount; row++) {
        final t = rowCount <= 1 ? 0.0 : row / (rowCount - 1);
        final arc = -track.windowLength + t * track.windowLength;
        track.sampleAt(arc, scratch);
        final center = Offset(scratch[0], scratch[1]);
        for (var c = 0; c < VineStripMesh.columns; c++) {
          final v = (row * VineStripMesh.columns + c) * 2;
          final dx = buffers.positions[v] - center.dx;
          final dy = buffers.positions[v + 1] - center.dy;
          expect(
            math.sqrt(dx * dx + dy * dy),
            lessThanOrEqualTo(limit + 2.0), // coarse row↔arc association
            reason: 'row $row col $c',
          );
        }
      }
    });
  });

  group('WindowBuffers', () {
    test('allocation is sized to the sample count', () {
      final track = buildTrack();
      final buffers = VineStripMesh.allocate(track);
      expect(
        buffers.colors.length,
        greaterThanOrEqualTo(track.sampleCount * VineStripMesh.columns),
      );
    });

    test('indices tile the full quad grid (no gaps between row pairs)', () {
      // Regression: a chained triangle-strip across a 6-column row renders
      // almost entirely degenerate triangles — the tube appears as dashes.
      // Indexed triangles must cover every column pair of every row pair.
      final track = buildTrack();
      final buffers = VineStripMesh.allocate(track);
      VineStripMesh.writeWindow(
        track: track,
        headArc: 0,
        windowLength: track.windowLength,
        buffers: buffers,
        tint: const Color(0xFF000000),
        halfWidth: VineMetrics.tubeWidth / 2,
      );

      final rows = buffers.lastVertexCount ~/ VineStripMesh.columns;
      expect(
        buffers.lastIndexCount,
        (rows - 1) * (VineStripMesh.columns - 1) * 6,
      );

      // Every index must be in range, all vertices must be referenced, and
      // each quad's first triangle must join its bottom-left, bottom-right,
      // and top-left corners (i.e., real area, not a same-row sliver).
      final cols = VineStripMesh.columns;
      final referenced = List<bool>.filled(buffers.lastVertexCount, false);
      for (var i = 0; i < buffers.lastIndexCount; i++) {
        final idx = buffers.indices[i];
        expect(idx, lessThan(buffers.lastVertexCount));
        referenced[idx] = true;
      }
      for (var v = 0; v < buffers.lastVertexCount; v++) {
        expect(referenced[v], isTrue, reason: 'vertex $v unreferenced');
      }

      final rowIndex = buffers.indices;
      for (var t = 0; t + 1 < buffers.lastIndexCount; t += 3) {
        final a = rowIndex[t];
        final b = rowIndex[t + 1];
        final c = rowIndex[t + 2];
        // Every triangle spans two distinct rows — no same-row slivers.
        expect(
          (a ~/ cols == b ~/ cols) && (b ~/ cols == c ~/ cols),
          isFalse,
          reason: 'degenerate same-row triangle at $t',
        );
      }
    });
  });
}
