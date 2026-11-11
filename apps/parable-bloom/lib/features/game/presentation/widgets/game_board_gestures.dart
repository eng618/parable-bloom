import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../../../core/board_transform.dart';
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
  /// Camera and focal point at [ScaleStartDetails]. Flutter restarts the
  /// scale gesture when a second finger lands, so these rest on each start.
  double _gestureStartZoom = 1.0;
  vm.Vector2 _gestureStartPan = vm.Vector2.zero();
  vm.Vector2 _gestureStartFocal = vm.Vector2.zero();

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
    _gestureStartZoom = cameraState.zoom;
    // Copy: CameraState shares its Vector2, and a later write must not
    // move the gesture baseline.
    _gestureStartPan = vm.Vector2(
      cameraState.panOffset.x,
      cameraState.panOffset.y,
    );
    // Widget-local. The anchor is the board widget's center, not the screen.
    _gestureStartFocal = vm.Vector2(
      details.localFocalPoint.dx,
      details.localFocalPoint.dy,
    );
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

    final cameraState = ref.read(cameraStateProvider);
    final cameraNotifier = ref.read(cameraStateProvider.notifier);
    // Clamp before the pan math so a pinch at the zoom limit still anchors
    // on the zoom the board will actually use.
    final newZoom = (_gestureStartZoom * details.scale)
        .clamp(cameraState.minZoom, cameraState.maxZoom)
        .toDouble();
    final pan = BoardTransform.panForAnchoredZoom(
      zoom0: _gestureStartZoom,
      panX0: _gestureStartPan.x,
      panY0: _gestureStartPan.y,
      zoom1: newZoom,
      focalX0: _gestureStartFocal.x,
      focalY0: _gestureStartFocal.y,
      focalX: details.localFocalPoint.dx,
      focalY: details.localFocalPoint.dy,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );

    cameraNotifier.applyGestureTransform(
      zoom: newZoom,
      panOffset: vm.Vector2(pan.x, pan.y),
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      gridCols: currentLevel.gridWidth,
      gridRows: currentLevel.gridHeight,
    );
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    // Tap suppression lingers for a short window (see
    // GardenGame.shouldSuppressTaps) to swallow the finger-lift tap that
    // races onTapUp.
    widget.game.setCameraGestureActive(false);
  }
}
