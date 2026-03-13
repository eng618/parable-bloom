import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../../../core/constants/animation_timing.dart';
import '../../../../core/game_board_layout.dart';
import '../../../../providers/settings_providers.dart';
import '../../../../services/logger_service.dart';
import 'gameplay_state_providers.dart';

class CameraState {
  final double zoom;
  final vm.Vector2 panOffset;
  final double minZoom;
  final double maxZoom;
  final bool isAnimating;

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
    return CameraState(
      zoom: 1.0,
      panOffset: vm.Vector2.zero(),
      minZoom: 0.5,
      maxZoom: 2.0,
      isAnimating: false,
    );
  }
}

final cameraStateProvider = NotifierProvider<CameraStateNotifier, CameraState>(
  CameraStateNotifier.new,
);

class CameraStateNotifier extends Notifier<CameraState> {
  Timer? _animationTimer;
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

    const padding = 0.9;
    final zoomToFitWidth = (screenWidth * padding) / gridWidth;
    final zoomToFitHeight = (screenHeight * padding) / gridHeight;
    final zoomToFit =
        zoomToFitWidth < zoomToFitHeight ? zoomToFitWidth : zoomToFitHeight;

    final minZoom = (zoomToFit * 0.85).clamp(0.3, 1.0);
    final maxZoom = 2.5;

    LoggerService.debug(
      'Updated zoom bounds - min: $minZoom, max: $maxZoom (fit: $zoomToFit)',
      tag: 'CameraStateNotifier',
    );

    state = state.copyWith(
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
  }

  void animateToDefaultZoom({
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
  }) {
    final gridWidth = GameBoardLayout.boardWidth(gridCols);
    final gridHeight = GameBoardLayout.boardHeight(gridRows);

    const padding = 0.9;
    final zoomToFitWidth = (screenWidth * padding) / gridWidth;
    final zoomToFitHeight = (screenHeight * padding) / gridHeight;
    final initialZoom =
        zoomToFitWidth < zoomToFitHeight ? zoomToFitWidth : zoomToFitHeight;

    final boardZoomScale = ref.read(boardZoomScaleProvider).value ?? 1.0;

    _animationStartZoom = initialZoom;
    _animationTargetZoom = 1.0 * boardZoomScale;
    _animationStartOffset = vm.Vector2.zero();
    _animationTargetOffset = vm.Vector2.zero();
    _animationProgress = 0.0;

    state = state.copyWith(
      zoom: initialZoom,
      panOffset: vm.Vector2.zero(),
      isAnimating: true,
    );

    LoggerService.debug(
      'Starting animation from zoom $initialZoom to $_animationTargetZoom',
      tag: 'CameraStateNotifier',
    );

    if (ref.read(disableAnimationsProvider)) {
      state = state.copyWith(isAnimating: false, zoom: _animationTargetZoom);
      LoggerService.debug(
        'Animations disabled - skipping animation',
        tag: 'CameraStateNotifier',
      );
      return;
    }

    _animationTimer?.cancel();
    final startTime = DateTime.now();
    _animationTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (timer) {
        if (ref.read(disableAnimationsProvider)) {
          timer.cancel();
          state = state.copyWith(isAnimating: false);
          LoggerService.debug(
            'Animations disabled during run - cancelling',
            tag: 'CameraStateNotifier',
          );
          return;
        }

        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        _animationProgress =
            (elapsed / (_animationDurationSeconds * 1000)).clamp(0.0, 1.0);

        final t = _easeInOutCubic(_animationProgress);

        final newZoom = _animationStartZoom +
            (_animationTargetZoom - _animationStartZoom) * t;
        final newOffset = vm.Vector2(
          _animationStartOffset.x +
              (_animationTargetOffset.x - _animationStartOffset.x) * t,
          _animationStartOffset.y +
              (_animationTargetOffset.y - _animationStartOffset.y) * t,
        );

        state = state.copyWith(
          zoom: newZoom,
          panOffset: newOffset,
        );

        if (_animationProgress >= 1.0) {
          timer.cancel();
          state = state.copyWith(isAnimating: false);
          LoggerService.debug('Animation complete', tag: 'CameraStateNotifier');
        }
      },
    );
  }

  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - _pow(-2 * t + 2, 3) / 2;
  }

  void updateZoom(double newZoom, {bool clamp = true}) {
    if (state.isAnimating) {
      return;
    }

    final clampedZoom =
        clamp ? newZoom.clamp(state.minZoom, state.maxZoom) : newZoom;

    state = state.copyWith(zoom: clampedZoom);
  }

  void updatePanOffset(
    vm.Vector2 newOffset, {
    required double screenWidth,
    required double screenHeight,
    required int gridCols,
    required int gridRows,
  }) {
    if (state.isAnimating) {
      return;
    }

    final constrainedOffset = _constrainPanOffset(
      newOffset,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: gridCols,
      gridRows: gridRows,
    );

    state = state.copyWith(panOffset: constrainedOffset);
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
    _animationTimer?.cancel();
    state = CameraState.defaultState();
  }

  void resetToCenter() {
    if (state.isAnimating) return;

    final boardZoomScale = ref.read(boardZoomScaleProvider).value ?? 1.0;

    state = state.copyWith(
      zoom: 1.0 * boardZoomScale,
      panOffset: vm.Vector2.zero(),
    );
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
