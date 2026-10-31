import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../../../core/widgets/garden_loading_view.dart';
import '../../application/providers/camera_providers.dart';
import '../../application/providers/gameplay_state_providers.dart';
import 'garden_game.dart';

/// Pan, pinch, and trackpad-scroll input for the play board.
///
/// Gesture state lives here so [GameScreen] does not own the scale baselines.
/// A finger on the board is camera input: taps stay suppressed until the
/// gesture ends.
class GameBoardGestures extends ConsumerStatefulWidget {
  const GameBoardGestures({super.key, required this.game});

  final GardenGame game;

  @override
  ConsumerState<GameBoardGestures> createState() => _GameBoardGesturesState();
}

class _GameBoardGesturesState extends ConsumerState<GameBoardGestures> {
  double _lastScale = 1.0;
  vm.Vector2 _lastFocalPoint = vm.Vector2.zero();
  vm.Vector2 _panStartOffset = vm.Vector2.zero();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              final cameraNotifier = ref.read(cameraStateProvider.notifier);
              final cameraState = ref.read(cameraStateProvider);
              final currentLevel = ref.read(currentLevelProvider);
              if (currentLevel == null) return;

              final newOffset = cameraState.panOffset -
                  vm.Vector2(
                    pointerSignal.scrollDelta.dx,
                    pointerSignal.scrollDelta.dy,
                  );

              cameraNotifier.updatePanOffset(
                newOffset,
                screenWidth: constraints.maxWidth,
                screenHeight: constraints.maxHeight,
                gridCols: currentLevel.gridWidth,
                gridRows: currentLevel.gridHeight,
              );
            }
          },
          child: GestureDetector(
            onScaleStart: _handleScaleStart,
            onScaleUpdate: (details) => _handleScaleUpdate(
              details,
              constraints.maxWidth,
              constraints.maxHeight,
            ),
            onScaleEnd: _handleScaleEnd,
            child: GameWidget<GardenGame>(
              game: widget.game,
              loadingBuilder: (_) =>
                  const GardenLoadingView(message: 'Preparing garden…'),
            ),
          ),
        );
      },
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    final cameraState = ref.read(cameraStateProvider);
    _lastScale = cameraState.zoom;
    _lastFocalPoint = vm.Vector2(
      details.focalPoint.dx,
      details.focalPoint.dy,
    );
    _panStartOffset = cameraState.panOffset;
    // Any scale gesture (pinch or single-finger pan) suppresses Flame taps
    // until shortly after the gesture ends: fingers on the board are camera
    // input, never tap telemetry.
    widget.game.setCameraGestureActive(true);
  }

  void _handleScaleUpdate(
    ScaleUpdateDetails details,
    double screenWidth,
    double screenHeight,
  ) {
    final currentLevel = ref.read(currentLevelProvider);
    if (currentLevel == null) return;

    // Keep suppression active for the whole gesture (start may have been
    // missed if the game instance was recreated mid-gesture).
    widget.game.setCameraGestureActive(true);

    final cameraNotifier = ref.read(cameraStateProvider.notifier);

    // Handle zoom (pinch)
    if (details.scale != 1.0) {
      final newZoom = _lastScale * details.scale;
      cameraNotifier.updateZoom(newZoom);
    }

    // Handle pan (drag) - only when not zooming significantly
    if ((details.scale - 1.0).abs() < 0.1) {
      final focalDelta = vm.Vector2(
        details.focalPoint.dx - _lastFocalPoint.x,
        details.focalPoint.dy - _lastFocalPoint.y,
      );

      final newOffset = _panStartOffset + focalDelta;

      cameraNotifier.updatePanOffset(
        newOffset,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        gridCols: currentLevel.gridWidth,
        gridRows: currentLevel.gridHeight,
      );
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    // Scale gesture ended - store final state. Tap suppression lingers for
    // a short window (see GardenGame.shouldSuppressTaps) to swallow the
    // finger-lift tap that races onTapUp.
    widget.game.setCameraGestureActive(false);
    _lastScale = ref.read(cameraStateProvider).zoom;
    _panStartOffset = ref.read(cameraStateProvider).panOffset;
  }
}
