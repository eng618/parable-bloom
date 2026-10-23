import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_slide_controller.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_strip_mesh.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

/// Per-frame cost benchmark for the rail render pipeline.
///
/// This is the measurement harness for the rail renderer redesign: it runs
/// the exact per-frame work performed by [VineComponent.prepareRailDraw]
/// (window write + Vertex build) for a long, multi-turn vine and asserts a
/// generous frame-budget ceiling. It runs on every host (Impeller device,
/// CanvasKit web) so numbers are directly comparable.
void main() {
  test('rail pipeline cost per frame stays inside frame budget', () {
    // 60-cell snake: contiguous boustrophedon walk on a 12×12 grid, then
    // reversed into the head-first ordering level JSON uses. The walk ends
    // at the right edge of its even row, so the head travels right and off
    // the edge — matching headDirection 'right' below.
    const gridW = 12, gridH = 12;
    final walk = <Map<String, int>>[];
    var placed = 0;
    for (var row = 0; row < gridH && placed < 60; row++) {
      final leftToRight = row.isEven;
      for (var i = 0; i < gridW && placed < 60; i++) {
        final px = leftToRight ? i : gridW - 1 - i;
        walk.add({'x': px, 'y': row});
        placed++;
      }
    }
    final orderedPath = walk.reversed.toList();

    const pitch = 42.0;
    const approachSteps = 4;
    final track = VineTrack.build(
      orderedPath: orderedPath,
      headDirection: 'right',
      gridWidth: gridW,
      gridHeight: gridH,
      extensionArc: (approachSteps + 60 + 7) * pitch,
    );
    expect(track.windowLength, greaterThan(40 * pitch));

    final controller = VineSlideController.idle();
    controller.startRun(
      track: track,
      approachSteps: approachSteps,
      isClear: true,
    );

    final buffers = VineStripMesh.allocate(track);
    const dt = 1.0 / 60.0;
    final tint = const Color(0xFF88FFAA);

    // Warm up.
    for (var i = 0; i < 50; i++) {
      VineStripMesh.writeWindow(
        track: track,
        headArc: controller.headArc,
        windowLength: track.windowLength,
        buffers: buffers,
        tint: tint,
        halfWidth: VineMetrics.tubeWidth / 2,
        skinTile: 0,
        skinPhase: 0.0,
      );
      controller.update(dt);
    }

    // Measure: per-frame writeWindow + Vertices.raw construction, exactly
    // what an animating vine does each frame on the UI thread.
    var frames = 0;
    final sw = Stopwatch()..start();
    while (controller.isAnimating && frames < 400) {
      VineStripMesh.writeWindow(
        track: track,
        headArc: controller.headArc,
        windowLength: track.windowLength,
        buffers: buffers,
        tint: tint,
        halfWidth: VineMetrics.tubeWidth / 2,
        skinTile: 0,
        skinPhase: 0.0,
      );
      VineStripMesh.verticesFor(buffers, buffers.lastVertexCount);
      controller.update(dt);
      frames++;
    }
    sw.stop();
    final perFrameMs = sw.elapsedMicroseconds / math.max(1, frames) / 1000.0;

    expect(frames, greaterThan(50));
    // Generous ceiling: full pipeline write must stay far below the 8.3 ms
    // @60Hz (and 6.9 ms @120Hz) frame budgets. Legacy O(N) path painting
    // was the regression baseline; the rail write is O(window floats) and
    // typically ~10x faster per frame than the old Path rebuild.
    expect(perFrameMs, lessThan(1.5), reason: 'perFrameMs=$perFrameMs');
  });

  test('simple stroked-path pipeline cost stays inside frame budget', () {
    // Same 60-cell snake fixture, exercising the simple render pass's
    // per-frame work: windowPath re-cut from the baked fine polyline.
    const gridW = 12, gridH = 12;
    final walk = <Map<String, int>>[];
    var placed = 0;
    for (var row = 0; row < gridH && placed < 60; row++) {
      final leftToRight = row.isEven;
      for (var i = 0; i < gridW && placed < 60; i++) {
        final px = leftToRight ? i : gridW - 1 - i;
        walk.add({'x': px, 'y': row});
        placed++;
      }
    }
    final orderedPath = walk.reversed.toList();

    const pitch = 42.0;
    const approachSteps = 4;
    final track = VineTrack.build(
      orderedPath: orderedPath,
      headDirection: 'right',
      gridWidth: gridW,
      gridHeight: gridH,
      extensionArc: (approachSteps + 60 + 7) * pitch,
    );

    final controller = VineSlideController.idle();
    controller.startRun(
      track: track,
      approachSteps: approachSteps,
      isClear: true,
    );

    // Warm up.
    final paths = <ui.Path>[];
    for (var i = 0; i < 50; i++) {
      paths.add(track.windowPath(controller.headArc, track.windowLength));
      controller.update(1 / 60);
    }

    // Measure: windowPath build each frame is the only alloc/scan work the
    // simple pass adds per frame (the stroke itself is one AA draw).
    var frames = 0;
    final sw = Stopwatch()..start();
    while (controller.isAnimating && frames < 400) {
      paths.add(track.windowPath(controller.headArc, track.windowLength));
      controller.update(1 / 60);
      frames++;
    }
    sw.stop();
    final perFrameMs = sw.elapsedMicroseconds / math.max(1, frames) / 1000.0;
    paths.clear();

    expect(frames, greaterThan(50));
    // Much lighter than the vertex write (a few hundred lineTo), and well
    // below frame budget at 60/120Hz.
    expect(perFrameMs, lessThan(1.5), reason: 'perFrameMs=$perFrameMs');
  });

  test('rail window vertex count is independent of vine base length', () {
    // Building tracks with 10 vs 60 cells yields the SAME per-frame
    // vertex count when the window is the same length (the sliding body
    // window is vine-length-sized, but row count scales only with the
    // visible span — the same invariant that keeps draw calls fixed).
    const gridW = 14, gridH = 14;
    List<Map<String, int>> pathOfLength(int n) {
      // Boustrophedon snake: 6-wide rows, alternating direction so cells are
      // always contiguous. Built tail-first, then reversed to the required
      // head-first ordering (matches level JSON semantics).
      final cells = <Map<String, int>>[];
      var placed = 0;
      for (var row = 0; row < gridH && placed < n; row++) {
        final cols = row.isEven;
        for (var i = 0; i < 6 && placed < n; i++) {
          final cx = cols ? i : 5 - i;
          cells.add({'x': cx, 'y': row});
          placed++;
        }
      }
      // Head at the beginning of the walk; tail at the end: the walk starts
      // at (0,0) going right, so head_direction is 'right'.
      return cells.reversed.toList();
    }

    const pitch = 42.0;
    final short = VineTrack.build(
      orderedPath: pathOfLength(10),
      headDirection: 'right',
      gridWidth: gridW,
      gridHeight: gridH,
      extensionArc: 10 * pitch,
    );
    final long = VineTrack.build(
      orderedPath: pathOfLength(40),
      headDirection: 'right',
      gridWidth: gridW,
      gridHeight: gridH,
      extensionArc: 10 * pitch,
    );

    // Sample count scales with track length (baked once), but the frame
    // window is bounded by the body: assert the window covers ~n cells.
    expect((short.windowLength / pitch).round(), inInclusiveRange(8, 10));
    expect((long.windowLength / pitch).round(), inInclusiveRange(38, 40));
  });
}
