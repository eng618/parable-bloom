import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_skin_atlas.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

/// Vertex buffers for the rail strip renderer.
///
/// The tube is an indexed triangle grid extruded perpendicular to the
/// track: each cross-tube row holds [columns] vertices spanning a slightly
/// widened tube with an alpha feather on both edges. The feather band
/// answers two constraints at once: CanvasKit does not anti-alias
/// `drawVertices` edges, and the legacy `MaskFilter.blur` glow cost
/// disappears entirely.
///
/// Positions, UVs, and base alpha are static per [VineTrack] sample; the
/// only per-frame work is copying the visible window's rows into reusable
/// arrays and rebuilding the two-triangles-per-quad index list for the
/// window (`O(window)` writes), then a single `canvas.drawVertices` call
/// per vine regardless of vine length. Indexed triangles are used instead
/// of a chained triangle strip so every column pair between two rows
/// actually rasterizes (a strip chain across a wide row is all
/// degenerates).
///
/// Texture anchoring: UVs are a **cylindrical wrap** over the baked skin
/// atlas (see [VineSkinAtlas]). `u` runs along the vine body —
/// `(rowArc - headArc) + perVinePhase`, wrapped into the tile — so the
/// skin is pinned to the rigid vine and travels with it; `v` is a fixed
/// per-column cross-tube offset centered on the tube's axis. The old
/// world-anchored `(worldX, worldY) * 0.25` sampling produced arbitrary
/// 13px slices of a full-scene JPEG and is gone.
class VineStripMesh {
  /// Vertices per cross-tube row: two feather columns per side, two opaque
  /// core columns in the middle.
  static const int columns = 6;

  VineStripMesh._();

  /// Reusable per-vine vertex buffers.
  static WindowBuffers allocate(VineTrack track) {
    final maxRows = track.sampleCount + 2;
    final verts = maxRows * columns;
    return WindowBuffers(
      positions: Float32List(verts * 2),
      texCoords: Float32List(verts * 2),
      colors: Int32List(verts),
      indices: Uint16List((maxRows - 1) * (columns - 1) * 6),
    );
  }

  /// Expanded tube half-width (core + half of the feather band on each
  /// side). The opaque core still spans legacy [VineMetrics.tubeWidth].
  static double expandedHalfWidth(double halfWidth) =>
      halfWidth + VineMetrics.tubeFeather;

  /// Writes the vertex grid for the body window
  /// `[headArc - windowLength, headArc]` into [buffers].
  ///
  /// Returns the vertex count. Rows hold [columns] vertices; quads between
  /// consecutive rows are indexed in [WindowBuffers.indices].
  static int writeWindow({
    required VineTrack track,
    required double headArc,
    required double windowLength,
    required WindowBuffers buffers,
    required Color tint,
    required double halfWidth,
    required int skinTile,
    required double skinPhase,
  }) {
    final tailArc = headArc - windowLength;
    final baseIndex = track.indexOfArc(tailArc);
    final headIndex = track.indexOfArc(headArc);

    final positions = buffers.positions;
    final texCoords = buffers.texCoords;
    final colors = buffers.colors;
    // Vertex color channels (API avoids the deprecated 8-bit getters).
    final r = (tint.r * 255.0).round().clamp(0, 255);
    final g = (tint.g * 255.0).round().clamp(0, 255);
    final b = (tint.b * 255.0).round().clamp(0, 255);
    final halfExp = expandedHalfWidth(halfWidth);
    final feather = VineMetrics.tubeFeather;
    // Per-column position offsets across the tube and their base alpha.
    final offs = Float32List(columns);
    final weights = Float32List(columns);
    for (var c = 0; c < columns; c++) {
      final t = c / (columns - 1);
      offs[c] = -halfExp + 2 * halfExp * t;
      // Alpha profile: opaque core (legacy tube width), smooth feather at
      // both edges across [VineMetrics.tubeFeather].
      final distanceFromCoreEdge = halfExp - offs[c].abs();
      weights[c] =
          _smoothStep((distanceFromCoreEdge / feather).clamp(0.0, 1.0));
    }

    var row = 0;
    final maxRows = colors.length ~/ columns;

    void writeRow(double frac, int idx) {
      if (row >= maxRows) return;
      // Interpolate the sample row between idx and idx+1 for exact window
      // edges (edges cut mid-row; the sample grid is coarser than motion).
      final nl = idx * 2;
      final x0 = track.sampleX[idx];
      final y0 = track.sampleY[idx];
      final x1 = track.sampleX[idx + 1];
      final y1 = track.sampleY[idx + 1];
      final x = x0 + (x1 - x0) * frac;
      final y = y0 + (y1 - y0) * frac;
      final nx0 = track.sampleNormals[nl];
      final ny0 = track.sampleNormals[nl + 1];
      final nx1 = track.sampleNormals[nl + 2];
      final ny1 = track.sampleNormals[nl + 3];
      var nX = nx0 + (nx1 - nx0) * frac;
      var nY = ny0 + (ny1 - ny0) * frac;
      final len = _length(nX, nY);
      if (len > 1e-6) {
        nX /= len;
        nY /= len;
      } else {
        nX = nx0;
        nY = ny0;
      }
      final alphaBase = (track.sampleAlpha[idx] +
              (track.sampleAlpha[idx + 1] - track.sampleAlpha[idx]) * frac)
          .clamp(0.0, 1.0);

      // Cylindrical wrap UVs: u follows the vine body along the tube's
      // arc length (pinned to the head, plus a per-vine phase for
      // variety), wrapped into this tile's atlas column; v is the fixed
      // cross-tube offset per column, ImageShader samples in image px, so
      // both axes are scaled by [VineSkinAtlas.bakeScale].
      final bodyArc = track.arcOf(idx) + frac * VineTrack.spacing - headArc;
      final uLocal = VineSkinAtlas.wrapU(bodyArc + skinPhase);
      final u = (skinTile * VineSkinAtlas.tileLength + uLocal) *
          VineSkinAtlas.bakeScale;

      final p = row * columns * 2;
      for (var c = 0; c < columns; c++) {
        final o = offs[c];
        positions[p + c * 2] = (x + nX * o).toDouble();
        positions[p + c * 2 + 1] = (y + nY * o).toDouble();
        texCoords[p + c * 2] = u;
        texCoords[p + c * 2 + 1] =
            (VineSkinAtlas.halfHeight + o) * VineSkinAtlas.bakeScale;
        final alphaC = alphaBase * weights[c] * 255.0;
        colors[row * columns + c] =
            ((alphaC.round().clamp(0, 255) << 24) | (r << 16) | (g << 8) | b)
                .toInt();
      }
      row++;
    }

    // Exact tail edge, then interior sample rows, then exact head edge.
    writeRow(_fracOf(track, tailArc, baseIndex), baseIndex);
    for (var i = baseIndex + 1; i <= headIndex; i++) {
      writeRow(0.0, i);
    }
    if (headArc > track.arcOf(headIndex)) {
      final tailSample = track.arcOf(headIndex);
      writeRow(
        ((headArc - tailSample) / VineTrack.spacing).clamp(0.0, 1.0).toDouble(),
        headIndex,
      );
    }

    // Quad grid between consecutive rows: two triangles per column pair.
    final quads = (columns - 1) * (row - 1);
    final needed = quads * 6;
    if (buffers.indices.length < needed) {
      buffers.indices =
          Uint16List(math.max(needed, buffers.indices.length * 2));
    }
    final indices = buffers.indices;
    var o = 0;
    for (var r = 0; r < row - 1; r++) {
      final rowA = r * columns;
      final rowB = (r + 1) * columns;
      for (var c = 0; c < columns - 1; c++) {
        final a = rowA + c;
        final b = rowB + c;
        final c2 = rowA + c + 1;
        final d = rowB + c + 1;
        indices[o++] = a;
        indices[o++] = b;
        indices[o++] = c2;
        indices[o++] = c2;
        indices[o++] = b;
        indices[o++] = d;
      }
    }
    buffers.lastIndexCount = o;

    buffers.lastVertexCount = row * columns;
    return buffers.lastVertexCount;
  }

  static double _fracOf(VineTrack track, double arc, int index) {
    final base = track.arcOf(index);
    return ((arc - base) / VineTrack.spacing).clamp(0.0, 1.0).toDouble();
  }

  /// Builds the [Vertices] for the freshly written grid.
  static Vertices verticesFor(WindowBuffers buffers, int vertexCount) {
    return Vertices.raw(
      VertexMode.triangles,
      Float32List.sublistView(buffers.positions, 0, vertexCount * 2),
      textureCoordinates:
          Float32List.sublistView(buffers.texCoords, 0, vertexCount * 2),
      colors: Int32List.sublistView(buffers.colors, 0, vertexCount),
      indices:
          Uint16List.sublistView(buffers.indices, 0, buffers.lastIndexCount),
    );
  }

  static double _smoothStep(double t) => t * t * (3 - 2 * t);

  static double _length(double x, double y) {
    final l = x * x + y * y;
    if (l <= 0) return 0.0;
    return math.sqrt(l);
  }
}

/// Per-vine reusable vertex buffers.
class WindowBuffers {
  Float32List positions;
  Float32List texCoords;
  Int32List colors;
  Uint16List indices;

  /// Vertex count written by the most recent [VineStripMesh.writeWindow]
  /// call on these buffers.
  int lastVertexCount = 0;

  /// Index count written by the most recent [VineStripMesh.writeWindow].
  int lastIndexCount = 0;

  WindowBuffers({
    required this.positions,
    required this.texCoords,
    required this.colors,
    required this.indices,
  });
}
