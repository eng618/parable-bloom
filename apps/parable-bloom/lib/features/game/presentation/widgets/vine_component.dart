import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/core/services/logger_service.dart';
import 'package:parable_bloom/core/vine_color_palette.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/presentation/widgets/grid_component.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_animator.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_bloom_renderer.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_path_painter.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_tube_path.dart';

/// Logic + geometry owner for one vine.
///
/// Rendering moved to [VineLayerComponent] (single batched pass over all
/// vines). This component owns the animator, bloom state, calm color, and
/// cached screen-space geometry; it draws nothing itself.
class VineComponent extends PositionComponent with ParentIsA<GridComponent> {
  final VineData vineData;
  final double cellSize;

  late final VineAnimator _animator;
  VineAnimator get animator => _animator;

  final VineBloomRenderer _bloomRenderer = VineBloomRenderer();
  VineBloomRenderer get bloom => _bloomRenderer;

  bool _alreadyNotifiedCleared = false;

  // Immutable per vine: resolved once instead of every frame.
  late final Color _calmColor;
  Color get calmColor => _calmColor;

  // Cached screen-space geometry. Rebuilt only when the vine
  // actually moved (or the grid height changed). Animating vines bypass
  // the cache: interpolated positions change every frame.
  List<Offset> _cachedPoints = const [];
  Rect _cachedBounds = Rect.zero;
  int _cachedVisualVersion = -1;
  int _cachedVisualHeight = -1;
  Path? _cachedPath;

  VineComponent({required this.vineData, required this.cellSize}) {
    _animator = VineAnimator(vineData: vineData);
    final seedColor = VineColorPalette.resolve(vineData.vineColor);
    _calmColor = VinePathPainter.deriveCalmVariant(seedColor, vineData.id);
  }

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

  /// Screen-space centerline points for the current frame. Idle vines reuse
  /// the cache; animating vines rebuild from interpolated grid positions.
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
