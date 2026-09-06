import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/core/services/logger_service.dart';
import 'package:parable_bloom/core/vine_color_palette.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/core/providers/settings_providers.dart'
    show VineStyle;
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/presentation/widgets/grid_component.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_animator.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_bloom_renderer.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_path_painter.dart';

class VineComponent extends PositionComponent with ParentIsA<GridComponent> {
  final VineData vineData;
  final double cellSize;

  static ui.Image? _classicTextureImage;
  static ui.Image? _blossomTextureImage;
  static ui.Image? _etherealTextureImage;

  late final VineAnimator _animator;
  final VineBloomRenderer _bloomRenderer = VineBloomRenderer();
  bool _alreadyNotifiedCleared = false;

  // Immutable per vine: resolved once instead of every frame.
  late final Color _calmColor;

  // Cached screen-space geometry. Rebuilt only when the vine
  // actually moved (or the grid height changed).
  List<Offset> _cachedPoints = const [];
  Rect _cachedBounds = Rect.zero;
  int _cachedVisualVersion = -1;
  int _cachedVisualHeight = -1;

  VineComponent({required this.vineData, required this.cellSize}) {
    _animator = VineAnimator(vineData: vineData);
    final seedColor = VineColorPalette.resolve(vineData.vineColor);
    _calmColor = VinePathPainter.deriveCalmVariant(seedColor, vineData.id);
  }

  @override
  Future<void> onLoad() async {
    position = Vector2.zero();
    size = parent.size;

    final game = parent.parent;
    _classicTextureImage ??= await game.images.load('classic_vine_texture.png');
    _blossomTextureImage ??= await game.images.load('blossom_vine_texture.png');
    _etherealTextureImage ??=
        await game.images.load('ethereal_vine_texture.png');

    LoggerService.debug('VineComponent loaded',
        tag: 'VineComponent',
        metadata: {
          'vine_id': vineData.id,
          'head_direction': vineData.headDirection,
        });
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final vineState = parent.getCurrentVineState(vineData.id);
    if (vineState == null) return;
    if (vineState.isCleared &&
        vineState.animationState != VineAnimationState.animatingClear) {
      return;
    }

    final level = parent.getCurrentLevelData();
    if (level == null || _animator.visualPositions.isEmpty) return;

    final calmColor = _calmColor;
    final isAttempted = vineState.hasBeenAttempted;
    final baseColor = computeRenderColor(
      calmColor,
      isAttempted,
      parent.parent.vineAttemptedColor,
    );

    final game = parent.parent;
    final vineStyle = game.vineStyle;
    final useSimpleVines = vineStyle == VineStyle.simple;

    Color drawColor = baseColor;
    if (!useSimpleVines) {
      drawColor = isAttempted ? calmColor : const Color(0xFFFFFFFF);
    }

    // Rebuild visual offsets from grid coordinates only when the vine
    // actually moved (or the grid height changed). Idle vines reuse cache.
    final visualHeight = level.gridHeight;
    if (_cachedVisualVersion != _animator.visualVersion ||
        _cachedVisualHeight != visualHeight) {
      final List<Offset> points = [];
      var minX = double.infinity;
      var minY = double.infinity;
      var maxX = double.negativeInfinity;
      var maxY = double.negativeInfinity;
      for (final cell in _animator.visualPositions) {
        final x = cell['x'] as int;
        final y = cell['y'] as int;
        final visualY = visualHeight - 1 - y;

        final point = Offset(
          GameBoardLayout.cellCenterX(x),
          GameBoardLayout.cellCenterY(visualY),
        );
        points.add(point);
        if (point.dx < minX) minX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy > maxY) maxY = point.dy;
      }
      _cachedPoints = points;
      _cachedBounds =
          points.isEmpty ? Rect.zero : Rect.fromLTRB(minX, minY, maxX, maxY);
      _cachedVisualVersion = _animator.visualVersion;
      _cachedVisualHeight = visualHeight;
    }
    final points = _cachedPoints;
    final isAnimating = _animator.isAnimating;

    // Frustum culling: a clearing vine slides fully off-board, in which case
    // there is no path left to draw (the edge bloom still renders below).
    if (isAnimating && points.isNotEmpty) {
      final boardRect = Rect.fromLTWH(
        0,
        0,
        GameBoardLayout.boardWidth(level.gridWidth),
        GameBoardLayout.boardHeight(visualHeight),
      );
      if (!_cachedBounds.overlaps(boardRect)) {
        _bloomRenderer.draw(
          canvas: canvas,
          renderColor: drawColor,
          cellSize: cellSize,
        );
        return;
      }
    }

    final double strokeWidth = useSimpleVines ? 26.0 : 16.0;

    // Delegate main vine path drawing to VinePathPainter
    VinePathPainter.drawVine(
      canvas: canvas,
      vineData: vineData,
      points: points,
      strokeWidth: strokeWidth,
      cellSize: cellSize,
      useSimpleVines: useSimpleVines,
      vineStyle: vineStyle,
      drawColor: drawColor,
      calmColor: calmColor,
      isAttempted: isAttempted,
      isAnimating: isAnimating,
      classicTexture: _classicTextureImage,
      blossomTexture: _blossomTextureImage,
      etherealTexture: _etherealTextureImage,
    );

    // Delegate bloom rendering to VineBloomRenderer
    _bloomRenderer.draw(
      canvas: canvas,
      renderColor: drawColor,
      cellSize: cellSize,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

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

  void slideOut() {
    _animator.startSlideOut(
      grid: parent,
      logDebug: _logDebug,
    );
  }

  void updateZoom(double zoom) {
    // Handled via parent scale transform
  }

  void _finishAnimation() {
    _animator.reset();
    _bloomRenderer.reset();

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
