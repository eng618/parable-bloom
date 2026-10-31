import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../../../core/constants/animation_timing.dart';
import '../../../../core/game_board_layout.dart';
import '../../../../core/providers/settings_providers.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/entities/level_data.dart';
import 'gameplay_state_providers.dart';

class CameraState {
  final double zoom;
  final vm.Vector2 panOffset;
  final double minZoom;
  final double maxZoom;
  final bool isAnimating;

  /// Fit-to-board zoom (padding applied) for the current screen/grid.
  /// Resting zoom is [fitZoom] × user [boardZoomScaleProvider].
  final double fitZoom;

  /// Single source of truth for the absolute upper zoom bound floor.
  static const double kMaxZoom = 2.5;

  /// Modest padding so the full board sits inside the viewport with breathing
  /// room (phones + browser chrome).
  static const double kFitPadding = 0.9;

  const CameraState({
    required this.zoom,
    required this.panOffset,
    required this.minZoom,
    required this.maxZoom,
    this.isAnimating = false,
    this.fitZoom = 1.0,
  });

  CameraState copyWith({
    double? zoom,
    vm.Vector2? panOffset,
    double? minZoom,
    double? maxZoom,
    bool? isAnimating,
    double? fitZoom,
  }) {
    return CameraState(
      zoom: zoom ?? this.zoom,
      panOffset: panOffset ?? this.panOffset,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      isAnimating: isAnimating ?? this.isAnimating,
      fitZoom: fitZoom ?? this.fitZoom,
    );
  }

  static CameraState defaultState() {
    // Bounds match updateZoomBounds(): min near fit*0.5, max ≥ kMaxZoom.
    return CameraState(
      zoom: 1.0,
      panOffset: vm.Vector2.zero(),
      minZoom: 0.5,
      maxZoom: kMaxZoom,
      isAnimating: false,
      fitZoom: 1.0,
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
          fitZoom == other.fitZoom &&
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
        fitZoom,
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
  static const double _animationDurationSeconds =
      AnimationTiming.cameraTransitionSeconds;

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

  /// Fit-to-board zoom for the given viewport and grid (shared by bounds,
  /// entry animation, and reset).
  static double computeFitZoom({
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
    double padding = CameraState.kFitPadding,
  }) {
    final gridWidth = GameBoardLayout.boardWidth(gridCols);
    final gridHeight = GameBoardLayout.boardHeight(gridRows);
    if (gridWidth <= 0 || gridHeight <= 0) return 1.0;
    if (screenWidth <= 0 || screenHeight <= 0) return 1.0;

    final zoomToFitWidth = (screenWidth * padding) / gridWidth;
    final zoomToFitHeight = (screenHeight * padding) / gridHeight;
    return math.min(zoomToFitWidth, zoomToFitHeight);
  }

  double _boardZoomScale() => ref.read(boardZoomScaleProvider).value ?? 1.0;

  /// Resting zoom = fit × user scale, clamped to current bounds.
  double restingZoomFor(double fitZoom) {
    final scaled = fitZoom * _boardZoomScale();
    final minZ = state.minZoom > 0 ? state.minZoom : scaled * 0.5;
    final maxZ = state.maxZoom > 0 ? state.maxZoom : CameraState.kMaxZoom;
    return scaled.clamp(minZ, maxZ).toDouble();
  }

  void updateZoomBounds({
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
  }) {
    final fitZoom = computeFitZoom(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: gridCols,
      gridRows: gridRows,
    );

    // Allow the full boardZoomScale range (0.5–2.0) plus a little headroom
    // for the level-entry ease-out start and pinch gestures.
    final minZoom = (fitZoom * 0.45).clamp(0.15, fitZoom);
    final maxZoom = math.max(
      CameraState.kMaxZoom,
      fitZoom * 2.0 * AnimationTiming.entryZoomFactor,
    );

    LoggerService.debug(
      'Updated zoom bounds - min: $minZoom, max: $maxZoom (fit: $fitZoom)',
      tag: 'CameraStateNotifier',
    );

    state = state.copyWith(
      minZoom: minZoom.toDouble(),
      maxZoom: maxZoom.toDouble(),
      fitZoom: fitZoom,
    );
  }

  /// Once per level entry: start slightly zoomed in, ease out to resting
  /// fit-zoom (× user boardZoomScale), pan centered.
  void animateToDefaultZoom({
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
  }) {
    updateZoomBounds(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: gridCols,
      gridRows: gridRows,
    );

    final fitZoom = state.fitZoom;
    final restingZoom = restingZoomFor(fitZoom);
    final entryZoom = (restingZoom * AnimationTiming.entryZoomFactor)
        .clamp(state.minZoom, state.maxZoom)
        .toDouble();

    _animationStartZoom = entryZoom;
    _animationTargetZoom = restingZoom;
    _animationStartOffset = vm.Vector2.zero();
    _animationTargetOffset = vm.Vector2.zero();
    _animationProgress = 0.0;

    state = state.copyWith(
      zoom: entryZoom,
      panOffset: vm.Vector2.zero(),
      isAnimating: true,
    );

    LoggerService.debug(
      'Starting entry ease-out from zoom $entryZoom to $restingZoom (fit $fitZoom)',
      tag: 'CameraStateNotifier',
    );

    if (ref.read(disableAnimationsProvider)) {
      state = state.copyWith(isAnimating: false, zoom: restingZoom);
      LoggerService.debug(
        'Animations disabled - skipping animation',
        tag: 'CameraStateNotifier',
      );
      return;
    }

    _runAnimation();
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
  }) {
    final gridWidth = GameBoardLayout.boardWidth(gridCols) * state.zoom;
    final gridHeight = GameBoardLayout.boardHeight(gridRows) * state.zoom;

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

  /// Returns to full-board resting zoom (fit × boardZoomScale), centered.
  void resetToCenter() {
    // Take over any running animation rather than ignoring the tap.
    _interruptAnimation();

    final resting = restingZoomFor(state.fitZoom);

    state = state.copyWith(
      zoom: resting,
      panOffset: vm.Vector2.zero(),
      isAnimating: false,
    );
  }

  Future<void> animateToPosition({
    required double targetZoom,
    required vm.Vector2 targetPanOffset,
  }) {
    final completer = Completer<void>();
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

  /// Auto-clear helper: keep current zoom (wide view); only pan if the vine
  /// would be off-screen. Nudges just enough to bring cells into the safe
  /// margin — does not zoom in or snap-center on the vine.
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

    final nudge = _panNudgeToRevealVine(
      vine,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: gridCols,
      gridRows: gridRows,
    );

    if (nudge.x == 0 && nudge.y == 0) {
      return;
    }

    final targetPanOffset = vm.Vector2(
      state.panOffset.x + nudge.x,
      state.panOffset.y + nudge.y,
    );

    final constrainedPanOffset = _constrainPanOffset(
      targetPanOffset,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: gridCols,
      gridRows: gridRows,
    );

    // Preserve wide view — never zoom during auto-clear.
    await animateToPosition(
      targetZoom: state.zoom,
      targetPanOffset: constrainedPanOffset,
    );
  }

  /// Minimum pan delta (screen space) so every vine cell sits inside the
  /// safe margin. Prefer nudge-over-center to keep the wide resting view.
  vm.Vector2 _panNudgeToRevealVine(
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

    const margin = 40.0;
    double needDx = 0;
    double needDy = 0;

    for (final cell in vine.orderedPath) {
      final x = cell['x']!;
      final y = cell['y']!;
      final visualRow = gridRows - 1 - y;

      final localX = GameBoardLayout.cellCenterX(x);
      final localY = GameBoardLayout.cellCenterY(visualRow);

      final screenX = gridPosX + localX * state.zoom;
      final screenY = gridPosY + localY * state.zoom;

      if (screenX < margin) {
        needDx = math.max(needDx, margin - screenX);
      } else if (screenX > screenWidth - margin) {
        needDx = math.min(needDx, (screenWidth - margin) - screenX);
      }

      if (screenY < margin) {
        needDy = math.max(needDy, margin - screenY);
      } else if (screenY > screenHeight - margin) {
        needDy = math.min(needDy, (screenHeight - margin) - screenY);
      }
    }

    return vm.Vector2(needDx, needDy);
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
