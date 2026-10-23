import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/core/providers/settings_providers.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_skin_atlas.dart';
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
        skinTile: 0,
        skinPhase: 0.0,
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
        skinTile: 0,
        skinPhase: 0.0,
      );
      expect(tiny, 2 * VineStripMesh.columns);
    });

    test('UVs wrap inside the skin tile column (no neighbor bleed)', () {
      final track = buildTrack();
      final buffers = VineStripMesh.allocate(track);
      const skinTile = VineSkinAtlas.tileBlossom;
      VineStripMesh.writeWindow(
        track: track,
        headArc: 0,
        windowLength: track.windowLength,
        buffers: buffers,
        tint: const Color(0xFF123456),
        halfWidth: VineMetrics.tubeWidth / 2,
        skinTile: skinTile,
        skinPhase: 5.0,
      );
      final tilePx = VineSkinAtlas.tileLength * VineSkinAtlas.bakeScale;
      final lo = skinTile * tilePx;
      final hi = (skinTile + 1) * tilePx;
      final uvCount = buffers.lastVertexCount * 2;
      for (var i = 0; i < uvCount; i += 2) {
        final u = buffers.texCoords[i];
        expect(
          u,
          inExclusiveRange(lo - 0.01, hi + 0.01),
          reason: 'u=$u must stay inside tile $skinTile',
        );
      }
    });

    test(
        'skin is pinned to the vine body: per-row u is stable while '
        'sliding', () {
      final track = buildTrack();
      final buffers = VineStripMesh.allocate(track);
      // Rows keep their body-relative arc (rowArc - headArc), so every
      // row's u is invariant under a slide (modulo the tile-wrap seam,
      // which sits where bodyArc + phase == 0). Sample rows with a
      // mid-tile phase: nowhere near the seam.
      List<double> rowUs(double headArc) {
        VineStripMesh.writeWindow(
          track: track,
          headArc: headArc,
          windowLength: track.windowLength,
          buffers: buffers,
          tint: const Color(0xFF123456),
          halfWidth: VineMetrics.tubeWidth / 2,
          skinTile: 0,
          skinPhase: 31.0,
        );
        return [
          buffers.texCoords[0],
          buffers.texCoords[buffers.lastVertexCount ~/ 2 * 2],
        ];
      }

      final a = rowUs(0.0);
      final b = rowUs(31.0); // three quarters of a cell slide
      expect(b[0], closeTo(a[0], 1.0));
    });

    test('skin phase shifts u deterministically', () {
      final track = buildTrack();
      final buffers = VineStripMesh.allocate(track);
      VineStripMesh.writeWindow(
        track: track,
        headArc: 0,
        windowLength: track.windowLength,
        buffers: buffers,
        tint: const Color(0xFF123456),
        halfWidth: VineMetrics.tubeWidth / 2,
        skinTile: 0,
        skinPhase: 0.0,
      );
      final u0 = buffers.texCoords[0];
      VineStripMesh.writeWindow(
        track: track,
        headArc: 0,
        windowLength: track.windowLength,
        buffers: buffers,
        tint: const Color(0xFF123456),
        halfWidth: VineMetrics.tubeWidth / 2,
        skinTile: 0,
        skinPhase: 7.0,
      );
      final u1 = buffers.texCoords[0];
      expect(u1, closeTo(u0 + 7 * VineSkinAtlas.bakeScale, 0.5));
    });

    test('v spans the expanded tube around the tile center per column', () {
      final track = buildTrack();
      final buffers = VineStripMesh.allocate(track);
      VineStripMesh.writeWindow(
        track: track,
        headArc: 0,
        windowLength: track.windowLength,
        buffers: buffers,
        tint: const Color(0xFF123456),
        halfWidth: VineMetrics.tubeWidth / 2,
        skinTile: 0,
        skinPhase: 0.0,
      );
      final centerV = VineSkinAtlas.halfHeight * VineSkinAtlas.bakeScale;
      double minV = double.infinity, maxV = -double.infinity;
      for (var c = 0; c < VineStripMesh.columns; c++) {
        final v = buffers.texCoords[c * 2 + 1];
        minV = math.min(minV, v);
        maxV = math.max(maxV, v);
        expect(v, greaterThanOrEqualTo(0.0));
        expect(
            v,
            lessThanOrEqualTo(
                VineSkinAtlas.tileHeight * VineSkinAtlas.bakeScale));
      }
      final expectedSpan = 2 *
          ((VineMetrics.tubeWidth / 2) + VineMetrics.tubeFeather) *
          VineSkinAtlas.bakeScale;
      expect(maxV - minV, closeTo(expectedSpan, 0.1));
      expect((minV + maxV) / 2, closeTo(centerV, 0.1));
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
        skinTile: 0,
        skinPhase: 0.0,
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
        skinTile: 0,
        skinPhase: 0.0,
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
        skinTile: 0,
        skinPhase: 0.0,
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
        skinTile: 0,
        skinPhase: 0.0,
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

  group('VineSkinAtlas helpers', () {
    const styleSet = <VineStyle>[
      VineStyle.classic,
      VineStyle.blossom,
      VineStyle.ethereal,
    ];

    test('tileFor maps style × state to distinct withered variants', () {
      for (final style in styleSet) {
        final healthy = VineSkinAtlas.tileFor(style, isAttempted: false);
        final withered = VineSkinAtlas.tileFor(style, isAttempted: true);
        expect(healthy + 3, withered); // withered column mirrors the look
      }
    });

    test('accentFor turns withered bark brown after a failed attempt', () {
      for (final style in styleSet) {
        expect(
          VineSkinAtlas.accentFor(style, isAttempted: true),
          VineMetrics.witheredColor,
        );
      }
    });

    test('wrapU stays in [0, tileLength) for negative body arcs', () {
      expect(VineSkinAtlas.wrapU(10), 10.0);
      expect(VineSkinAtlas.wrapU(-63.0), closeTo(0.0, 1e-9));
      expect(VineSkinAtlas.wrapU(-630.0), closeTo(0.0, 1e-9));
      expect(VineSkinAtlas.wrapU(-1.0), closeTo(62.0, 1e-9));
    });
  });
}
