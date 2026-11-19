import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../../../core/board_transform.dart';
import '../../../../core/constants/animation_timing.dart';
import '../../../../core/game_board_layout.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/entities/level_data.dart';
import 'gameplay_state_providers.dart';

class CameraState {
  final double zoom;
  final vm.Vector2 panOffset;
  final double minZoom;
  final double maxZoom;
  final bool isAnimating;

  /// Single source of truth for the upper zoom bound.
  static const double kMaxZoom = BoardTransform.maxCameraZoom;

  const CameraState({
    required this.zoom,
    required this.panOffset,
    required this.minZoom,
    required this.maxZoom,
    this.isAnimating = false,
  });

  CameraState copyWith({
    double? zoom,
    vm.Vector2? panOffset,
    double? minZoom,
    double? maxZoom,
    bool? isAnimating,
  }) {
    return CameraState(
      zoom: zoom ?? this.zoom,
      panOffset: panOffset ?? this.panOffset,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      isAnimating: isAnimating ?? this.isAnimating,
    );
  }

  static CameraState defaultState() {
    // Bounds match updateZoomBounds(): min in (fit * 0.85).clamp(0.3, 1.0),
    // max is kMaxZoom. Keep them in sync.
    return CameraState(
      zoom: 1.0,
      panOffset: vm.Vector2.zero(),
      minZoom: 0.5,
      maxZoom: kMaxZoom,
      isAnimating: false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraState &&
          runtimeType == other.runtimeType &&
          zoom == other.zoom &&
          minZoom == other.minZoom &&
          maxZoom == other.maxZoom &&
          isAnimating == other.isAnimating &&
          panOffset.x == other.panOffset.x &&
          panOffset.y == other.panOffset.y;

  @override
  int get hashCode => Object.hash(
        zoom,
        panOffset.x,
        panOffset.y,
        minZoom,
        maxZoom,
        isAnimating,
      );
}

final cameraStateProvider = NotifierProvider<CameraStateNotifier, CameraState>(
  CameraStateNotifier.new,
);

class CameraStateNotifier extends Notifier<CameraState> {
  Timer? _animationTimer;
  Completer<void>? _animationCompleter;
  double _animationStartZoom = 1.0;
  double _animationTargetZoom = 1.0;
  vm.Vector2 _animationStartOffset = vm.Vector2.zero();
  vm.Vector2 _animationTargetOffset = vm.Vector2.zero();
  double _animationProgress = 0.0;
  double _animationDurationSeconds = AnimationTiming.cameraTransitionSeconds;

  /// Play-bounds fit, and the slightly closer start of the level-open ease.
  /// The ease settles on [AnimationTiming.levelCompleteBoardPadding].
  static const double _levelOpenZoomIn = 1.08;
  static const double _playFitPadding = 0.9;

  @override
  CameraState build() {
    ref.onDispose(() {
      _animationTimer?.cancel();
      _animationTimer = null;
      _animationCompleter?.complete();
      _animationCompleter = null;
    });
    return CameraState.defaultState();
  }

  void updateZoomBounds({
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
  }) {
    final gridWidth = GameBoardLayout.boardWidth(gridCols);
    final gridHeight = GameBoardLayout.boardHeight(gridRows);

    final zoomToFit = BoardTransform.zoomToFit(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      padding: _playFitPadding,
    );

    var minZoom = (zoomToFit * 0.85).clamp(0.3, 1.0);
    final wholeBoard = BoardTransform.levelCompleteFrame(
      cols: gridCols,
      rows: gridRows,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    ).zoom;
    if (wholeBoard.isFinite && wholeBoard > 0 && wholeBoard < minZoom) {
      minZoom = wholeBoard;
    }
    final maxZoom = CameraState.kMaxZoom;

    LoggerService.debug(
      'Updated zoom bounds - min: $minZoom, max: $maxZoom (fit: $zoomToFit)',
      tag: 'CameraStateNotifier',
    );

    state = state.copyWith(
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
  }

  /// Eases out onto the whole board, centered.
  ///
  /// A level opens this way, including a return visit whose camera is
  /// already on that frame. The ease starts a little closer than the
  /// frame so the pull-back is visible, and it ignores a leftover close
  /// zoom. The reset control still jumps straight to the frame.
  void animateToDefaultZoom({
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
  }) {
    _interruptAnimation();
    _animationDurationSeconds = AnimationTiming.cameraTransitionSeconds;

    if (screenWidth <= 0 ||
        screenHeight <= 0 ||
        gridCols <= 0 ||
        gridRows <= 0) {
      state = state.copyWith(
        panOffset: vm.Vector2.zero(),
        isAnimating: false,
      );
      return;
    }

    final targetZoom = _wholeBoardZoom(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: gridCols,
      gridRows: gridRows,
    );
    final startZoom = _levelOpenStartZoom(
      targetZoom: targetZoom,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: gridCols,
      gridRows: gridRows,
    );

    _animationStartZoom = startZoom;
    _animationTargetZoom = targetZoom;
    _animationStartOffset = vm.Vector2.zero();
    _animationTargetOffset = vm.Vector2.zero();
    _animationProgress = 0.0;

    final alreadyFramed = (startZoom - targetZoom).abs() <= 0.001;
    if (alreadyFramed || ref.read(disableAnimationsProvider)) {
      state = state.copyWith(
        zoom: targetZoom,
        panOffset: vm.Vector2.zero(),
        isAnimating: false,
      );
      LoggerService.debug(
        'Opened on the whole board at zoom $targetZoom',
        tag: 'CameraStateNotifier',
      );
      return;
    }

    state = state.copyWith(
      zoom: startZoom,
      panOffset: vm.Vector2.zero(),
      isAnimating: true,
    );
    LoggerService.debug(
      'Easing out from zoom $startZoom to $targetZoom',
      tag: 'CameraStateNotifier',
    );
    _runAnimation();
  }

  /// Zoom the level-open ease starts from. The play fit is a little closer
  /// than the whole-board frame. When that fit is not closer, nudge in by
  /// [_levelOpenZoomIn] and stay inside the max zoom.
  double _levelOpenStartZoom({
    required double targetZoom,
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
  }) {
    var start = BoardTransform.zoomToFit(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridWidth: GameBoardLayout.boardWidth(gridCols),
      gridHeight: GameBoardLayout.boardHeight(gridRows),
      padding: _playFitPadding,
    );
    if (start > state.maxZoom) start = state.maxZoom;
    if (start <= targetZoom + 0.001) {
      start = targetZoom * _levelOpenZoomIn;
      if (start > state.maxZoom) start = state.maxZoom;
    }
    return start;
  }

  /// Zoom that shows the whole grid. Lowers [CameraState.minZoom] when that
  /// fit sits under the play floor, and never goes above the max zoom.
  /// Returns the current zoom when the screen or the grid has no size.
  double _wholeBoardZoom({
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
  }) {
    if (screenWidth <= 0 ||
        screenHeight <= 0 ||
        gridCols <= 0 ||
        gridRows <= 0) {
      return state.zoom;
    }
    final fit = BoardTransform.levelCompleteFrame(
      cols: gridCols,
      rows: gridRows,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    ).zoom;
    if (!fit.isFinite || fit <= 0) return state.zoom;
    if (fit < state.minZoom) {
      state = state.copyWith(minZoom: fit);
    }
    return fit.clamp(state.minZoom, state.maxZoom).toDouble();
  }

  /// Shared 60fps interpolation driver. Per-tick values go straight to Flame
  /// via [applyCameraFrame] (no provider notification); Riverpod gets a
  /// throttled progress write (~10fps, keeps overlays aligned) plus one
  /// final settled write. Previously every 16ms tick wrote state (~50
  /// notifications per 0.8s animation, each rebuilding all watchers).
  ///
  /// If [completer] is given (from [animateToPosition]), it completes when
  /// the animation settles OR is interrupted by a gesture/dispose, so
  /// awaiters (e.g. auto-clear) never hang.
  void _runAnimation({Completer<void>? completer}) {
    _animationCompleter = completer;
    _animationTimer?.cancel();
    final startTime = DateTime.now();
    var tick = 0;
    _animationTimer = Timer.periodic(
      AnimationTiming.cameraTick,
      (timer) {
        if (ref.read(disableAnimationsProvider)) {
          timer.cancel();
          _animationTimer = null;
          state = state.copyWith(isAnimating: false);
          LoggerService.debug(
            'Animations disabled during run - cancelling',
            tag: 'CameraStateNotifier',
          );
          _animationCompleter?.complete();
          _animationCompleter = null;
          return;
        }

        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        _animationProgress =
            (elapsed / (_animationDurationSeconds * 1000)).clamp(0.0, 1.0);

        final t = _easeInOutCubic(_animationProgress);

        final newZoom = _animationStartZoom +
            (_animationTargetZoom - _animationStartZoom) * t;
        // Compute offset as plain doubles: avoids a Vector2 alloc per 16ms
        // tick. A Vector2 is only allocated on throttled state writes.
        final newOffsetX = _animationStartOffset.x +
            (_animationTargetOffset.x - _animationStartOffset.x) * t;
        final newOffsetY = _animationStartOffset.y +
            (_animationTargetOffset.y - _animationStartOffset.y) * t;

        // Smooth path: straight to Flame, no notification.
        ref.read(gameInstanceProvider)?.applyCameraFrame(
              zoom: newZoom,
              panX: newOffsetX,
              panY: newOffsetY,
            );

        // Throttled progress sync for Riverpod watchers (zoom controls,
        // tutorial overlay alignment).
        tick++;
        if (tick % 6 == 0) {
          state = state.copyWith(
            zoom: newZoom,
            panOffset: vm.Vector2(newOffsetX, newOffsetY),
          );
        }

        if (_animationProgress >= 1.0) {
          timer.cancel();
          _animationTimer = null;
          state = state.copyWith(
            zoom: _animationTargetZoom,
            panOffset: _animationTargetOffset,
            isAnimating: false,
          );
          LoggerService.debug('Animation complete', tag: 'CameraStateNotifier');
          _animationCompleter?.complete();
          _animationCompleter = null;
        }
      },
    );
  }

  /// Stops a running animation without writing state. The caller immediately
  /// overwrites state itself (gesture takeover / reset), so no extra
  /// notification is needed here. Awaiters are released.
  void _interruptAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
    _animationCompleter?.complete();
    _animationCompleter = null;
  }

  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - _pow(-2 * t + 2, 3) / 2;
  }

  void updateZoom(double newZoom, {bool clamp = true}) {
    // A user gesture takes over: interrupt the running animation instead of
    // dropping the input (previous behavior silently returned).
    if (state.isAnimating) {
      _interruptAnimation();
    }

    final clampedZoom =
        clamp ? newZoom.clamp(state.minZoom, state.maxZoom) : newZoom;

    state = state.copyWith(zoom: clampedZoom, isAnimating: false);
  }

  /// One camera write for a pinch or drag. Zoom and pan land together so
  /// Flame never paints a center-anchored zoom frame before the pan that
  /// keeps the pinch point still. [panOffset] is constrained at the clamped
  /// zoom, not the zoom from before this gesture frame.
  void applyGestureTransform({
    required double zoom,
    required vm.Vector2 panOffset,
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
  }) {
    if (state.isAnimating) {
      _interruptAnimation();
    }

    final clampedZoom = zoom.clamp(state.minZoom, state.maxZoom).toDouble();
    final constrainedOffset = _constrainPanOffset(
      panOffset,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: gridCols,
      gridRows: gridRows,
      zoom: clampedZoom,
    );

    state = state.copyWith(
      zoom: clampedZoom,
      panOffset: constrainedOffset,
      isAnimating: false,
    );
  }

  void updatePanOffset(
    vm.Vector2 newOffset, {
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
  }) {
    // Same gesture-takeover policy as updateZoom.
    if (state.isAnimating) {
      _interruptAnimation();
    }

    final constrainedOffset = _constrainPanOffset(
      newOffset,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: gridCols,
      gridRows: gridRows,
    );

    state = state.copyWith(panOffset: constrainedOffset, isAnimating: false);
  }

  vm.Vector2 _constrainPanOffset(
    vm.Vector2 offset, {
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
    double? zoom,
  }) {
    final effectiveZoom = zoom ?? state.zoom;
    final gridWidth = GameBoardLayout.boardWidth(gridCols) * effectiveZoom;
    final gridHeight = GameBoardLayout.boardHeight(gridRows) * effectiveZoom;

    const visibleThreshold = 0.2;
    final maxOffsetX = screenWidth > gridWidth
        ? gridWidth * 0.2
        : gridWidth * (1 - visibleThreshold);

    final maxOffsetY = screenHeight > gridHeight
        ? gridHeight * 0.2
        : gridHeight * (1 - visibleThreshold);

    final constrainedX = offset.x.clamp(
      -maxOffsetX,
      maxOffsetX,
    );
    final constrainedY = offset.y.clamp(
      -maxOffsetY,
      maxOffsetY,
    );

    return vm.Vector2(constrainedX, constrainedY);
  }

  void reset() {
    _interruptAnimation();
    state = CameraState.defaultState();
  }

  void resetToCenter() {
    // Take over any running animation rather than ignoring the tap.
    _interruptAnimation();

    final game = ref.read(gameInstanceProvider);
    final level = ref.read(currentLevelProvider);
    final targetZoom = _wholeBoardZoom(
      screenWidth: game?.size.x ?? 0,
      screenHeight: game?.size.y ?? 0,
      gridCols: level?.gridWidth ?? 0,
      gridRows: level?.gridHeight ?? 0,
    );

    state = state.copyWith(
      zoom: targetZoom,
      panOffset: vm.Vector2.zero(),
      isAnimating: false,
    );
  }

  /// Eases out and centers so the whole board is on screen.
  ///
  /// Starts immediately. A gesture still takes over, and that resolves the
  /// returned future. Does nothing when there is no board to frame, or when
  /// the camera is already there.
  Future<void> frameEntireBoard() {
    final game = ref.read(gameInstanceProvider);
    final level = ref.read(currentLevelProvider);
    if (game == null || level == null) return Future<void>.value();

    final screenWidth = game.size.x;
    final screenHeight = game.size.y;
    if (screenWidth <= 0 || screenHeight <= 0) return Future<void>.value();
    if (level.gridWidth <= 0 || level.gridHeight <= 0) {
      return Future<void>.value();
    }

    final fit = BoardTransform.levelCompleteFrame(
      cols: level.gridWidth,
      rows: level.gridHeight,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    ).zoom;
    if (!fit.isFinite || fit <= 0) return Future<void>.value();

    var minZoom = state.minZoom;
    if (fit < minZoom) {
      minZoom = fit;
      state = state.copyWith(minZoom: minZoom);
    }
    final targetZoom = fit.clamp(minZoom, state.maxZoom).toDouble();

    final alreadyFramed = !state.isAnimating &&
        (state.zoom - targetZoom).abs() <= 0.001 &&
        state.panOffset.x.abs() <= 1 &&
        state.panOffset.y.abs() <= 1;
    if (alreadyFramed) return Future<void>.value();

    return animateToPosition(
      targetZoom: targetZoom,
      targetPanOffset: vm.Vector2.zero(),
      durationSeconds: AnimationTiming.levelCompleteCameraSeconds,
    );
  }

  Future<void> animateToPosition({
    required double targetZoom,
    required vm.Vector2 targetPanOffset,
    double? durationSeconds,
  }) {
    _interruptAnimation();
    final completer = Completer<void>();
    _animationDurationSeconds =
        durationSeconds ?? AnimationTiming.cameraTransitionSeconds;
    _animationStartZoom = state.zoom;
    _animationTargetZoom = targetZoom.clamp(state.minZoom, state.maxZoom);
    _animationStartOffset = state.panOffset;
    _animationTargetOffset = targetPanOffset;
    _animationProgress = 0.0;

    state = state.copyWith(
      isAnimating: true,
    );

    LoggerService.debug(
      'Starting animation to zoom $targetZoom, offset $targetPanOffset',
      tag: 'CameraStateNotifier',
    );

    if (ref.read(disableAnimationsProvider)) {
      state = state.copyWith(
        isAnimating: false,
        zoom: _animationTargetZoom,
        panOffset: _animationTargetOffset,
      );
      completer.complete();
      return completer.future;
    }

    _runAnimation(completer: completer);

    return completer.future;
  }

  Future<void> ensureVineVisible(VineData vine) async {
    final game = ref.read(gameInstanceProvider);
    final level = ref.read(currentLevelProvider);
    if (game == null || level == null) return;

    final screenWidth = game.size.x;
    final screenHeight = game.size.y;
    final gridCols = level.gridWidth;
    final gridRows = level.gridHeight;

    if (_isVineFullyVisible(
      vine,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: gridCols,
      gridRows: gridRows,
    )) {
      LoggerService.debug(
        'Vine ${vine.id} is already fully visible, skipping camera adjustment',
        tag: 'CameraStateNotifier',
      );
      return;
    }

    final vineCenter = _calculateVineCenter(vine, gridRows);
    final gridWidth = GameBoardLayout.boardWidth(gridCols);
    final gridHeight = GameBoardLayout.boardHeight(gridRows);

    final targetZoom = state.zoom;

    final targetPanOffset = vm.Vector2(
      (gridWidth / 2 - vineCenter.x) * targetZoom,
      (gridHeight / 2 - vineCenter.y) * targetZoom,
    );

    final constrainedPanOffset = _constrainPanOffset(
      targetPanOffset,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: gridCols,
      gridRows: gridRows,
    );

    await animateToPosition(
      targetZoom: targetZoom,
      targetPanOffset: constrainedPanOffset,
    );
  }

  /// Pans, and zooms out only when it has to, so the vines still on the
  /// board sit in the middle of the view.
  ///
  /// Used when a slide or wiggle has finished and the grid in view is empty.
  /// Keeps the current zoom when the group already fits, matching the pan
  /// that brings a freed vine on screen before it clears. Does nothing when
  /// a vine is already in view, the level is over, a gesture is in progress,
  /// or another camera move is running.
  Future<void> frameRemainingVines() {
    if (state.isAnimating) return Future<void>.value();
    if (ref.read(levelCompleteProvider)) return Future<void>.value();

    final game = ref.read(gameInstanceProvider);
    final level = ref.read(currentLevelProvider);
    if (game == null || level == null) return Future<void>.value();
    if (game.shouldSuppressTaps) return Future<void>.value();

    final screenWidth = game.size.x;
    final screenHeight = game.size.y;
    if (screenWidth <= 0 || screenHeight <= 0) return Future<void>.value();

    final states = ref.read(vineStatesProvider);
    final remaining = <VineData>[];
    for (final vine in level.vines) {
      final vineState = states[vine.id];
      if (vineState != null && vineState.isClearedOrClearing) continue;
      if (vine.orderedPath.isEmpty) continue;
      remaining.add(vine);
    }
    if (remaining.isEmpty) return Future<void>.value();

    final gridCols = level.gridWidth;
    final gridRows = level.gridHeight;
    if (_anyVineOnScreen(
      remaining,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: gridCols,
      gridRows: gridRows,
    )) {
      return Future<void>.value();
    }

    final bounds = _vineBounds(remaining, gridRows);
    if (bounds == null) return Future<void>.value();

    final clusterWidth = (bounds.maxX - bounds.minX) + GameBoardLayout.cellSize;
    final clusterHeight =
        (bounds.maxY - bounds.minY) + GameBoardLayout.cellSize;
    final fitZoom = BoardTransform.zoomToFit(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridWidth: clusterWidth,
      gridHeight: clusterHeight,
      padding: AnimationTiming.levelCompleteBoardPadding,
    );
    // Never zoom in. A tight group keeps the zoom the player already has.
    var targetZoom = state.zoom;
    if (fitZoom < targetZoom) targetZoom = fitZoom;
    targetZoom = targetZoom.clamp(state.minZoom, state.maxZoom).toDouble();

    final gridWidth = GameBoardLayout.boardWidth(gridCols);
    final gridHeight = GameBoardLayout.boardHeight(gridRows);
    final centerX = (bounds.minX + bounds.maxX) / 2;
    final centerY = (bounds.minY + bounds.maxY) / 2;
    final targetPanOffset = _constrainPanOffset(
      vm.Vector2(
        (gridWidth / 2 - centerX) * targetZoom,
        (gridHeight / 2 - centerY) * targetZoom,
      ),
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: gridCols,
      gridRows: gridRows,
      zoom: targetZoom,
    );

    final alreadyFramed = (state.zoom - targetZoom).abs() <= 0.001 &&
        (state.panOffset.x - targetPanOffset.x).abs() <= 1 &&
        (state.panOffset.y - targetPanOffset.y).abs() <= 1;
    if (alreadyFramed) return Future<void>.value();

    return animateToPosition(
      targetZoom: targetZoom,
      targetPanOffset: targetPanOffset,
    );
  }

  bool _isVineFullyVisible(
    VineData vine, {
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
  }) {
    final gridWidth = GameBoardLayout.boardWidth(gridCols) * state.zoom;
    final gridHeight = GameBoardLayout.boardHeight(gridRows) * state.zoom;

    final centeredX = (screenWidth - gridWidth) / 2;
    final centeredY = (screenHeight - gridHeight) / 2;

    final gridPosX = centeredX + state.panOffset.x;
    final gridPosY = centeredY + state.panOffset.y;

    const margin = 40.0; // Margin from screen boundaries

    for (final cell in vine.orderedPath) {
      final x = cell['x']!;
      final y = cell['y']!;
      final visualRow = gridRows - 1 - y;

      final localX = GameBoardLayout.cellCenterX(x);
      final localY = GameBoardLayout.cellCenterY(visualRow);

      final screenX = gridPosX + localX * state.zoom;
      final screenY = gridPosY + localY * state.zoom;

      if (screenX < margin ||
          screenX > screenWidth - margin ||
          screenY < margin ||
          screenY > screenHeight - margin) {
        return false; // Cell is off screen or too close to the edge
      }
    }
    return true;
  }

  /// True when any cell center of [vines] lies on the screen. A vine peeking
  /// into the view counts, so the camera stays until the view is actually empty.
  bool _anyVineOnScreen(
    List<VineData> vines, {
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
  }) {
    final gridWidth = GameBoardLayout.boardWidth(gridCols) * state.zoom;
    final gridHeight = GameBoardLayout.boardHeight(gridRows) * state.zoom;
    final gridPosX = (screenWidth - gridWidth) / 2 + state.panOffset.x;
    final gridPosY = (screenHeight - gridHeight) / 2 + state.panOffset.y;

    for (final vine in vines) {
      for (final cell in vine.orderedPath) {
        final x = cell['x']!;
        final y = cell['y']!;
        final visualRow = gridRows - 1 - y;
        final screenX = gridPosX + GameBoardLayout.cellCenterX(x) * state.zoom;
        final screenY =
            gridPosY + GameBoardLayout.cellCenterY(visualRow) * state.zoom;
        if (screenX >= 0 &&
            screenX <= screenWidth &&
            screenY >= 0 &&
            screenY <= screenHeight) {
          return true;
        }
      }
    }
    return false;
  }

  ({double minX, double minY, double maxX, double maxY})? _vineBounds(
    List<VineData> vines,
    int gridRows,
  ) {
    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;
    var found = false;

    for (final vine in vines) {
      for (final cell in vine.orderedPath) {
        final x = cell['x']!;
        final y = cell['y']!;
        final visualRow = gridRows - 1 - y;
        final cx = GameBoardLayout.cellCenterX(x);
        final cy = GameBoardLayout.cellCenterY(visualRow);
        if (cx < minX) minX = cx;
        if (cx > maxX) maxX = cx;
        if (cy < minY) minY = cy;
        if (cy > maxY) maxY = cy;
        found = true;
      }
    }
    if (!found) return null;
    return (minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }

  vm.Vector2 _calculateVineCenter(VineData vine, int gridRows) {
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final cell in vine.orderedPath) {
      final x = cell['x']!;
      final y = cell['y']!;
      final visualRow = gridRows - 1 - y;

      final cx = GameBoardLayout.cellCenterX(x);
      final cy = GameBoardLayout.cellCenterY(visualRow);

      if (cx < minX) minX = cx;
      if (cx > maxX) maxX = cx;
      if (cy < minY) minY = cy;
      if (cy > maxY) maxY = cy;
    }

    return vm.Vector2((minX + maxX) / 2, (minY + maxY) / 2);
  }

  double _pow(double x, int exp) {
    if (exp == 0) return 1;
    if (exp == 1) return x;
    double result = 1;
    for (int i = 0; i < exp.abs(); i++) {
      result *= x;
    }
    return exp > 0 ? result : 1 / result;
  }
}
