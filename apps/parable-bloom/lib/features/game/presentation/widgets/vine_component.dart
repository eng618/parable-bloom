import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:material_ui/material_ui.dart';

import 'package:parable_bloom/core/board_transform.dart';
import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/core/providers/settings_providers.dart'
    show VineStyle;
import 'package:parable_bloom/core/services/logger_service.dart';
import 'package:parable_bloom/core/vine_color_palette.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/presentation/widgets/grid_component.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_animator.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_dot_reveal.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_bloom_renderer.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_end_sprites.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_foliage_atlas.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_rail_draw.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_skin.dart';
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

  /// Cells this clear has already reported. Each vine keeps its own
  /// cursor, so a dot can throb again when a later tail uncovers it.
  final VineDotReveal _dotReveal = VineDotReveal();

  VineTrack? _railTrack;
  VineTrack? get railTrack => _railTrack;
  WindowBuffers? _stripBuffers;
  WindowBuffers? _wrapBuffers;
  late final VineFoliageMesh? _foliageMesh =
      foliageAtlas == null ? null : VineFoliageMesh(atlas: foliageAtlas!);
  final Float32List _scratch = Float32List(VineTrack.positionW);

  ui.Vertices? _cachedStrip;
  ui.Vertices? _cachedWrapStrip;
  ui.Vertices? _cachedFoliage;
  ui.Vertices? _cachedHeadVerts;
  ui.Vertices? _cachedTailVerts;
  Color? _cacheStripTint;
  Color? _cacheFoliageTint;
  double? _cacheUvPhase;
  VineSkinState? _cacheSkinState;
  bool _railIdleCacheValid = false;
  ui.Path? _cachedSimplePath;

  /// Per-vine body-arc phase offset into the texture so vines sample
  /// different parts of the trellis image (deterministic from the vine id).
  late final double uvPhase = _computeUvPhase(vineData.id);

  static double _computeUvPhase(String id) {
    const fnvPrime = 0x01000193;
    var hash = 0x811C9DC5;
    for (final unit in id.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    // Keep the phase within one texture cycle so it never drifts far.
    return (hash % 1024).toDouble();
  }

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
  /// visible window sub-range every frame (O(window) work, far below the
  /// legacy O(N) path tessellation). The flat/simple style instead builds
  /// the stroked centerline [Path] per window — anti-aliased, no vertex
  /// mesh work, and equally cheap (O(window) points).
  ///
  /// Skin texture phase ([uvPhase]), both tints, and [skinState] are part
  /// of the idle cache key: the withered state flip must rebuild vertex
  /// colors / wrap+end overlays even while the vine is not moving.
  VineRailDraw? prepareRailDraw({
    required VineStyle style,
    required int foliageStride,
    required Color stripTint,
    required Color foliageTint,
    required double uvPhase,
    required int texWidth,
    required int texHeight,
    VineSkinTheme? classicSkin,
    VineSkinState skinState = VineSkinState.live,
  }) {
    final level = parent.getCurrentLevelData();
    if (level == null) return null;

    final track = _railTrack;
    if (track == null) return null;

    final headArc = _slide.headArc;
    final windowLength = track.windowLength;
    final halfWidth = VineMetrics.texturedTubeWidth / 2;
    final simple = style == VineStyle.simple;
    final modular = VineSkinTheme.usesModularLayers(style) && classicSkin != null;

    // Idle caches are keyed on tint + skin state (see doc comment).
    if (!_slide.isAnimating &&
        _railIdleCacheValid &&
        _cacheStripTint == stripTint &&
        _cacheFoliageTint == foliageTint &&
        _cacheUvPhase == uvPhase &&
        _cacheSkinState == skinState) {
      return VineRailDraw(
        track: track,
        headArc: headArc,
        strip: _cachedStrip,
        wrapStrip: _cachedWrapStrip,
        foliage: _cachedFoliage,
        headVerts: _cachedHeadVerts,
        tailVerts: _cachedTailVerts,
        simplePath: _cachedSimplePath,
      );
    }

    ui.Vertices? strip;
    ui.Vertices? wrapStrip;
    ui.Vertices? foliage;
    ui.Vertices? headVerts;
    ui.Vertices? tailVerts;
    ui.Path? simplePath;
    if (simple) {
      // Vector-crisp stroked pass: no strip, no foliage quads.
      simplePath = track.windowPath(headArc, windowLength);
    } else {
      final theme = modular ? classicSkin : null;
      final bodyW = theme?.shaft.width ?? texWidth;
      final bodyH = theme?.shaft.height ?? texHeight;

      _stripBuffers ??= VineStripMesh.allocate(track);
      VineStripMesh.writeWindow(
        track: track,
        headArc: headArc,
        windowLength: windowLength,
        buffers: _stripBuffers!,
        tint: stripTint,
        halfWidth: halfWidth,
        uvPhase: uvPhase,
        texWidth: bodyW,
        texHeight: bodyH,
      );
      strip = VineStripMesh.verticesFor(
          _stripBuffers!, _stripBuffers!.lastVertexCount);

      if (theme != null) {
        // Wrap overlay: identical window geometry, separate buffers so the
        // shaft Vertices stay valid (Vertices.raw does not copy lists).
        _wrapBuffers ??= VineStripMesh.allocate(track);
        VineStripMesh.writeWindow(
          track: track,
          headArc: headArc,
          windowLength: windowLength,
          buffers: _wrapBuffers!,
          tint: const Color(0xFFFFFFFF),
          halfWidth: halfWidth,
          uvPhase: uvPhase,
          texWidth: theme.wrapLive.width,
          texHeight: theme.wrapLive.height,
        );
        wrapStrip = VineStripMesh.verticesFor(
            _wrapBuffers!, _wrapBuffers!.lastVertexCount);

        final endHalf = VineEndSprites.halfSizeForTube();
        const endTint = Color(0xFFFFFFFF);
        headVerts = VineEndSprites.quad(
          theme: theme,
          track: track,
          arc: headArc,
          tile: theme.headTile(skinState),
          tint: endTint,
          halfSize: endHalf,
          flipForTail: false,
        );
        tailVerts = VineEndSprites.quad(
          theme: theme,
          track: track,
          arc: headArc - windowLength,
          tile: theme.tailTile(skinState),
          tint: endTint,
          halfSize: endHalf,
          flipForTail: true,
        );
      }

      final mesh = _foliageMesh;
      if (mesh != null && foliageAtlas!.supportsStyle(style)) {
        mesh.write(
          track: track,
          headArc: headArc,
          windowLength: windowLength,
          stride: foliageStride,
          style: style,
          tint: foliageTint,
          halfWidth: halfWidth,
          scratch: _scratch,
        );
        foliage = mesh.vertices();
      }
    }

    if (_slide.isAnimating) {
      _railIdleCacheValid = false;
      return VineRailDraw(
        track: track,
        headArc: headArc,
        strip: strip,
        wrapStrip: wrapStrip,
        foliage: foliage,
        headVerts: headVerts,
        tailVerts: tailVerts,
        simplePath: simplePath,
      );
    }

    // Idle: freeze the freshly built payload.
    _cachedStrip = strip;
    _cachedWrapStrip = wrapStrip;
    _cachedFoliage = foliage;
    _cachedHeadVerts = headVerts;
    _cachedTailVerts = tailVerts;
    _cachedSimplePath = simplePath;
    _cacheStripTint = stripTint;
    _cacheFoliageTint = foliageTint;
    _cacheUvPhase = uvPhase;
    _cacheSkinState = skinState;
    _railIdleCacheValid = true;
    return VineRailDraw(
      track: track,
      headArc: headArc,
      strip: strip,
      wrapStrip: wrapStrip,
      foliage: foliage,
      headVerts: headVerts,
      tailVerts: tailVerts,
      simplePath: simplePath,
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
    final wasBlockedReverse = _animator.isBlockedAnimation;
    _animator.update(
      dt: dt,
      grid: parent,
      onHeadExitedGrid: () {
        if (!_bloomRenderer.isShowingBloomEffect) {
          final level = parent.getCurrentLevelData();
          if (level != null) {
            _emitSlideEndedSfx(cleared: true);
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
    if (!wasBlockedReverse && _animator.isBlockedAnimation) {
      _emitSlideEndedSfx(cleared: false);
    }
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
    // Measure the tail after this step, including the frame the run ends.
    // A blocked wiggle leaves the cursor where it is.
    _pulseUncoveredDots();
    if (update.justReachedBlocker) {
      parent.markVineAttempted(vineData.id);
      _emitSlideEndedSfx(cleared: false);
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
  bool _slideSfxResolved = false;

  /// Throbs each grid dot once, as the clearing tail uncovers it.
  ///
  /// That includes cells the vine never occupied, along the straight run
  /// the tail takes off the board.
  ///
  /// The legacy painter has no track arc, so this stays on the rail path.
  void _pulseUncoveredDots() {
    final track = _railTrack;
    if (track == null || !_slide.isClearRun) return;
    final uncovered = _dotReveal.takeNewlyUncovered(
      track.pathCells,
      _slide.headArc - track.windowLength,
      clearing: true,
    );
    for (final cell in uncovered) {
      parent.pulseCell(cell.x, cell.y);
    }
  }

  void _emitSlideEndedSfx({required bool cleared}) {
    if (_slideSfxResolved) return;
    _slideSfxResolved = true;
    parent.parent.sink.onVineSlideEnded(
      cleared: cleared,
      vineLength: vineData.orderedPath.length,
    );
  }

  void _startRailBloom() {
    final track = _railTrack;
    if (track == null) return;
    final level = parent.getCurrentLevelData();
    if (level == null) return;
    final headCell = track.headCellAt(_slide.headArc);
    _emitSlideEndedSfx(cleared: true);
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

    final vineLength = vineData.orderedPath.length;
    parent.parent.sink.onVineSlideStarted(vineLength: vineLength);

    final isLastVine = parent.isLastOccupiedVine(vineData.id);

    if (!useRailRenderer) {
      _animator.startSlideOut(
        grid: parent,
        logDebug: _logDebug,
        isLastVine: isLastVine,
      );
      return;
    }

    final rawDistance = railMovementDistance();
    // Solver contract: positive = cells to the board edge (clear),
    // negative = cells until the blocker. The blocked bump travels the
    // absolute distance so the head visibly reaches the blocker before
    // returning (legacy animator used `rawDistance.abs()` here too).
    final approachSteps = rawDistance.abs().clamp(0, 4096);
    final tailClearArc = rawDistance > 0
        ? _viewportTailClearArc(includeFramedBoard: isLastVine)
        : null;
    _buildRailTrack(
      extensionArc: _railExtensionArrangement(
        approachSteps,
        tailClearArc: tailClearArc,
      ),
    );

    _dotReveal.reset();
    _slide.startRun(
      track: _railTrack!,
      approachSteps: approachSteps,
      isClear: rawDistance > 0,
      isLastVine: isLastVine && rawDistance > 0,
      tailClearArc: tailClearArc,
    );
    _railClearFinished = false;
    _railIdleCacheValid = false;
    _slideSfxResolved = false;

    parent.setVineAnimationState(
      vineData.id,
      rawDistance > 0
          ? VineAnimationState.animatingClear
          : VineAnimationState.animatingBlocked,
    );

    _logDebug(
      'Rail slide started: vineId=${vineData.id}, rawDistance=$rawDistance, '
      'approachSteps=$approachSteps',
    );
  }

  /// Track arc the tail must reach before the vine has left the screen.
  ///
  /// Measured from the head cell along the exit ray, in board pixels.
  /// Includes the dark margin around the grid. Null before the camera has
  /// a screen size; the slide then uses the short off-board pad.
  ///
  /// [includeFramedBoard] also measures the centered whole-board frame and
  /// keeps the farther edge. The last vine uses that so a zoom-out does not
  /// remove it while it is still on screen.
  double? _viewportTailClearArc({bool includeFramedBoard = false}) {
    final level = parent.getCurrentLevelData();
    if (level == null || vineData.orderedPath.isEmpty) return null;

    final current = _clearArcForViewport(parent.boardSpaceViewport(), level);
    if (!includeFramedBoard) return current;

    final framed = _clearArcForViewport(parent.framedBoardViewport(), level);
    if (current == null) return framed;
    if (framed == null) return current;
    return current > framed ? current : framed;
  }

  double? _clearArcForViewport(Rect? viewport, LevelData level) {
    if (viewport == null || vineData.orderedPath.isEmpty) return null;
    final head = vineData.orderedPath.first;
    final visualRow = level.gridHeight - 1 - (head['y'] ?? 0);
    final raw = BoardTransform.distanceToViewportEdge(
      headX: GameBoardLayout.cellCenterX(head['x'] ?? 0),
      headY: GameBoardLayout.cellCenterY(visualRow),
      direction: vineData.headDirection,
      left: viewport.left,
      top: viewport.top,
      right: viewport.right,
      bottom: viewport.bottom,
    );
    // Caps and leaves sit outside the centerline. Push past the edge so
    // the last pixel is gone before the component is removed.
    const margin = VineMetrics.texturedTubeWidth * 2;
    final ahead = raw < 0 ? 0.0 : raw;
    return ahead + margin;
  }

  /// Arc length reserved beyond the head cell for the exit slide.
  ///
  /// Blocked bumps keep the short legacy pad. A clear must reach
  /// [tailClearArc] plus the body, so the tail can follow the head all the
  /// way off the viewport.
  double _railExtensionArrangement(
    int approachSteps, {
    double? tailClearArc,
  }) {
    const pitch = GameBoardLayout.pointSpacing;
    final trackProbe = _railTrack;
    final window = trackProbe == null
        ? (vineData.orderedPath.length - 1) * pitch
        : trackProbe.windowLength;
    final legacy = (approachSteps + window / pitch + 7) * pitch;
    if (tailClearArc == null) return legacy;
    final needed = tailClearArc + window + pitch * 2;
    return needed > legacy ? needed : legacy;
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
    _cachedSimplePath = null;
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
