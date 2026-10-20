import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/core/providers/settings_providers.dart'
    show VineStyle;
import 'package:parable_bloom/core/services/logger_service.dart';
import 'package:parable_bloom/core/vine_color_palette.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/presentation/widgets/grid_component.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_animator.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_bloom_renderer.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_foliage_atlas.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_rail_draw.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_slide_controller.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_strip_mesh.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_path_painter.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_tube_path.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

/// Per-frame rail draw payloads produced by [VineComponent.prepareRailDraw]
/// and consumed by the rail renderer (see [VineRailDraw]).

/// Logic + geometry owner for one vine.
///
/// Rendering moved to [VineLayerComponent] (single batched pass over all
/// vines). This component owns animation state, the rail track (when the
/// rail renderer is active), bloom state, calm color, and cached geometry;
/// it draws nothing itself.
class VineComponent extends PositionComponent with ParentIsA<GridComponent> {
  VineComponent({
    required this.vineData,
    required this.cellSize,
    this.useRailRenderer = true,
    this.foliageAtlas,
  }) {
    _animator = VineAnimator(vineData: vineData);
    final seedColor = VineColorPalette.resolve(vineData.vineColor);
    _calmColor = VinePathPainter.deriveCalmVariant(seedColor, vineData.id);
  }

  final VineData vineData;
  final double cellSize;

  /// Whether the new rail renderer drives this vine. The legacy per-frame
  /// Path painter stays reachable through [VineRenderMode.legacy] for A/B
  /// regression until the cut-over.
  final bool useRailRenderer;

  /// Shared startup-baked foliage-atlas provider set by the layer.
  final VineFoliageAtlas? foliageAtlas;

  late final VineAnimator _animator;
  VineAnimator get animator => _animator;

  // ---- Rail state -------------------------------------------------------
  final VineSlideController _slide = VineSlideController.idle();
  VineSlideController get slide => _slide;

  VineTrack? _railTrack;
  VineTrack? get railTrack => _railTrack;
  WindowBuffers? _stripBuffers;
  late final VineFoliageMesh? _foliageMesh =
      foliageAtlas == null ? null : VineFoliageMesh(atlas: foliageAtlas!);
  final Float32List _scratch = Float32List(VineTrack.positionW);

  ui.Vertices? _cachedStrip;
  ui.Vertices? _cachedFoliage;
  Color? _cacheTint;
  bool _railIdleCacheValid = false;

  final VineBloomRenderer _bloomRenderer = VineBloomRenderer();
  VineBloomRenderer get bloom => _bloomRenderer;

  bool _alreadyNotifiedCleared = false;

  // Immutable per vine: resolved once instead of every frame.
  late final Color _calmColor;
  Color get calmColor => _calmColor;

  // Cached screen-space geometry (legacy renderer only). Rebuilt only when
  // the vine actually moved (or the grid height changed). Animating vines
  // bypass the cache: interpolated positions change every frame.
  List<Offset> _cachedPoints = const [];
  Rect _cachedBounds = Rect.zero;
  int _cachedVisualVersion = -1;
  int _cachedVisualHeight = -1;
  Path? _cachedPath;

  @override
  Future<void> onLoad() async {
    position = Vector2.zero();
    size = parent.size;

    LoggerService.debug('VineComponent loaded',
        tag: 'VineComponent',
        metadata: {
          'vine_id': vineData.id,
          'head_direction': vineData.headDirection,
        });
  }

  /// Prepares (or reuses) this frame's rail payload for the batched layer.
  ///
  /// Idle vines freeze their vertex objects; animating vines rebuild the
  /// visible window sub-range every frame (O(window) float copies, far
  /// below the legacy O(N) path tessellation).
  VineRailDraw? prepareRailDraw({
    required VineStyle style,
    required int foliageStride,
    required Color tint,
  }) {
    final level = parent.getCurrentLevelData();
    if (level == null) return null;

    final track = _railTrack;
    if (track == null) return null;

    final headArc = _slide.headArc;
    final windowLength = track.windowLength;
    final halfWidth = VineMetrics.tubeWidth / 2;

    // Idle caches are keyed on tint: attempted-state color changes must
    // rebuild the vertex colors even while the vine is not moving.
    if (!_slide.isAnimating && _railIdleCacheValid && _cacheTint == tint) {
      return VineRailDraw(
        track: track,
        headArc: headArc,
        strip: _cachedStrip,
        foliage: _cachedFoliage,
      );
    }

    _stripBuffers ??= VineStripMesh.allocate(track);
    VineStripMesh.writeWindow(
      track: track,
      headArc: headArc,
      windowLength: windowLength,
      buffers: _stripBuffers!,
      tint: tint,
      halfWidth: halfWidth,
    );
    final strip = VineStripMesh.verticesFor(
        _stripBuffers!, _stripBuffers!.lastVertexCount);

    ui.Vertices? foliage;
    final mesh = _foliageMesh;
    if (mesh != null && foliageAtlas!.supportsStyle(style)) {
      mesh.write(
        track: track,
        headArc: headArc,
        windowLength: windowLength,
        stride: foliageStride,
        style: style,
        tint: tint,
        halfWidth: halfWidth,
        scratch: _scratch,
      );
      foliage = mesh.vertices();
    }

    if (_slide.isAnimating) {
      _railIdleCacheValid = false;
      return VineRailDraw(
        track: track,
        headArc: headArc,
        strip: strip,
        foliage: foliage,
      );
    }

    // Idle: freeze the freshly built payload.
    _cachedStrip = strip;
    _cachedFoliage = foliage;
    _cacheTint = tint;
    _railIdleCacheValid = true;
    return VineRailDraw(
      track: track,
      headArc: headArc,
      strip: strip,
      foliage: foliage,
    );
  }

  void invalidateRailCache() => _railIdleCacheValid = false;

  @override
  void update(double dt) {
    super.update(dt);

    if (useRailRenderer) {
      _updateRail(dt);
      return;
    }

    if (!_animator.isAnimating) return;

    // Update bloom particles
    if (_bloomRenderer.isShowingBloomEffect) {
      _bloomRenderer.update(dt);

      final isFullyOffScreen =
          _animator.isFullyOffScreen(parent.getCurrentLevelData());
      if (isFullyOffScreen &&
          _bloomRenderer.bloomEffectTimer >=
              _bloomRenderer.bloomEffectDuration) {
        _logDebug(
          'Fully off-screen and bloom complete: vineId=${vineData.id}, calling _finishAnimation()',
        );
        _finishAnimation();
        return;
      }
    }

    // Update step-by-step animator
    _animator.update(
      dt: dt,
      grid: parent,
      onHeadExitedGrid: () {
        if (!_bloomRenderer.isShowingBloomEffect) {
          final level = parent.getCurrentLevelData();
          if (level != null) {
            _bloomRenderer.startBloomEffect(
              vineData: vineData,
              level: level,
              visualPositions: _animator.visualPositions,
            );
          }
        }
      },
      onFinished: _finishAnimation,
      logDebug: _logDebug,
    );
  }

  void _updateRail(double dt) {
    if (_bloomRenderer.isShowingBloomEffect) {
      _bloomRenderer.update(dt);
    }

    if (!_slide.isAnimating) {
      // The clear run finished; wait for the bloom to complete before
      // removing (parity with the legacy off-screen + bloom gating).
      if (_railClearFinished &&
          (!_bloomRenderer.isShowingBloomEffect ||
              _bloomRenderer.bloomEffectTimer >=
                  _bloomRenderer.bloomEffectDuration)) {
        _logDebug(
          'Rail run complete and bloom finished: vineId=${vineData.id}, _finishAnimation()',
        );
        _finishAnimation();
      }
      return;
    }

    final update = _slide.update(dt);
    if (update.justReachedBlocker) {
      parent.markVineAttempted(vineData.id);
    }
    if (update.justExitedBoard && !_bloomRenderer.isShowingBloomEffect) {
      _startRailBloom();
    }
    if (update.justReturnedHome) {
      parent.setVineAnimationState(vineData.id, VineAnimationState.normal);
    }
    if (update.justFinished && _slide.isClearRun) {
      _railClearFinished = true;
    }
  }

  bool _railClearFinished = false;

  void _startRailBloom() {
    final track = _railTrack;
    if (track == null) return;
    final level = parent.getCurrentLevelData();
    if (level == null) return;
    final headCell = track.headCellAt(_slide.headArc);
    _bloomRenderer.startBloomEffect(
      vineData: vineData,
      level: level,
      visualPositions: [
        {
          'x': headCell[0],
          'y': headCell[1],
        }
      ],
    );
  }

  /// Starts a slide run (tap on a movable vine).
  void slideOut() {
    if (_slide.isAnimating) return;
    final level = parent.getCurrentLevelData();
    if (level == null) return;

    if (!useRailRenderer) {
      _animator.startSlideOut(grid: parent, logDebug: _logDebug);
      return;
    }

    final approachSteps = railMovementDistance().clamp(0, 4096);
    _buildRailTrack(extensionArc: _railExtensionArrangement(approachSteps));

    _slide.startRun(
      track: _railTrack!,
      approachSteps: approachSteps,
      isClear: approachSteps > 0,
    );
    _railClearFinished = false;
    _railIdleCacheValid = false;

    parent.setVineAnimationState(
      vineData.id,
      approachSteps > 0
          ? VineAnimationState.animatingClear
          : VineAnimationState.animatingBlocked,
    );

    _logDebug(
      'Rail slide started: vineId=${vineData.id}, approachSteps=$approachSteps, '
      'isClear=${approachSteps > 0}',
    );
  }

  /// Arc length reserved beyond the head cell for the off-screen exit,
  /// mirroring the legacy step-plan (`approach + length + 6` cells).
  double _railExtensionArrangement(int approachSteps) {
    const pitch = GameBoardLayout.pointSpacing;
    final trackProbe = _railTrack;
    final windowSteps = trackProbe == null
        ? (vineData.orderedPath.length - 1).toDouble()
        : trackProbe.windowLength / pitch;
    return (approachSteps + windowSteps + 7) * pitch;
  }

  /// Solver-backed distance to the blocker for this vine (same body as the
  /// legacy animator's check).
  int railMovementDistance() {
    final activeIds = parent.getActiveVineIds();
    final solver = parent.getLevelSolverService();
    final level = parent.getCurrentLevelData();
    if (level == null) return 0;
    return solver.getDistanceToBlocker(level, vineData.id, activeIds);
  }

  /// Builds (or rebuilds) this vine's invariant rail track.
  void _buildRailTrack({required double extensionArc}) {
    final level = parent.getCurrentLevelData();
    if (level == null) return;
    _railTrack = VineTrack.build(
      orderedPath: vineData.orderedPath,
      headDirection: vineData.headDirection,
      gridWidth: level.gridWidth,
      gridHeight: level.gridHeight,
      extensionArc: extensionArc,
    );
    _stripBuffers = null;
    _railIdleCacheValid = false;
  }

  /// Builds the idle rail track once per level load.
  void ensureRailTrack() {
    if (_railTrack != null) return;
    _buildRailTrack(extensionArc: 0);
  }

  /// Screen-space centers for the current frame (legacy renderer only).
  List<Offset> renderPoints(int gridHeight) {
    if (_animator.isAnimating) {
      return _buildPoints(_animator.renderGridPositions(), gridHeight);
    }
    if (_cachedVisualVersion != _animator.visualVersion ||
        _cachedVisualHeight != gridHeight) {
      _rebuildCache(gridHeight);
    }
    return _cachedPoints;
  }

  /// Rounded tube path matching [renderPoints]. Idle vines reuse the baked
  /// path; animating vines rebuild it every frame.
  Path? renderPath(int gridHeight, List<Offset> points) {
    if (_animator.isAnimating || points.isEmpty) {
      if (points.isEmpty) return null;
      return VineTubePath.buildRoundedTube(points);
    }
    return _cachedPath;
  }

  /// Tight bounds of the current centerline, for frustum culling.
  Rect renderBounds(List<Offset> points) {
    if (points.isEmpty) return Rect.zero;
    if (!_animator.isAnimating && identical(points, _cachedPoints)) {
      return _cachedBounds;
    }
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _rebuildCache(int gridHeight) {
    final cells = _animator.visualPositions
        .map(
            (c) => <double>[(c['x'] ?? 0).toDouble(), (c['y'] ?? 0).toDouble()])
        .toList();
    final points = _buildPoints(cells, gridHeight);
    _cachedPoints = points;
    _cachedBounds = renderBounds(points);
    _cachedVisualVersion = _animator.visualVersion;
    _cachedVisualHeight = gridHeight;
    _cachedPath = points.isEmpty ? null : VineTubePath.buildRoundedTube(points);
  }

  /// Map grid-space positions (ints or interpolated doubles) to
  /// screen-space centers. Same formula as [GameBoardLayout.cellCenterX/Y],
  /// generalized to doubles.
  List<Offset> _buildPoints(List<List<double>> cells, int gridHeight) {
    const half = GameBoardLayout.cellSize / 2;
    const spacing = GameBoardLayout.pointSpacing;
    return List<Offset>.generate(cells.length, (i) {
      final x = cells[i][0];
      final y = cells[i][1];
      final visualY = (gridHeight - 1) - y;
      return Offset(x * spacing + half, visualY * spacing + half);
    });
  }

  void updateZoom(double zoom) {
    // Handled via parent scale transform
  }

  void _finishAnimation() {
    _slide.reset();
    _animator.reset();
    _bloomRenderer.reset();
    _railClearFinished = false;

    parent.setVineAnimationState(vineData.id, VineAnimationState.cleared);

    _logDebug(
      'Animation finished: vineId=${vineData.id}, state=cleared, notifying parent and removing component',
    );

    if (!_alreadyNotifiedCleared) {
      _alreadyNotifiedCleared = true;
      parent.notifyVineCleared(vineData.id);
    }

    removeFromParent();
  }

  void _logDebug(String message) {
    final debugEnabled = parent.parent.sink.debugVineAnimationLogging;
    if (debugEnabled) {
      LoggerService.debug(message,
          tag: 'VineComponent', metadata: {'vine_id': vineData.id});
    }
  }

  /// Preserved static helper method for computing render color
  static Color computeRenderColor(
    Color calmColor,
    bool isAttempted,
    Color attemptedColor,
  ) {
    return VinePathPainter.computeRenderColor(
      calmColor,
      isAttempted,
      attemptedColor,
    );
  }
}
