import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/core/providers/settings_providers.dart'
    show VineStyle;
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/presentation/widgets/grid_component.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_path_painter.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine_component.dart';

/// Single batched renderer for all vines on the board.
///
/// Replaces N per-vine Flame render passes with one component that draws
/// every vine in a single canvas traversal: shared static paints, per-vine
/// frustum culling, and board-size-aware foliage LOD. Logic and
/// animation state stay in [VineComponent]; this component only reads.
class VineLayerComponent extends PositionComponent
    with ParentIsA<GridComponent> {
  // Shared textures resolved once from the game-level loader.
  ui.Image? _classicTexture;
  ui.Image? _blossomTexture;
  ui.Image? _etherealTexture;

  VineLayerComponent() : super(priority: 2);

  @override
  Future<void> onLoad() async {
    position = Vector2.zero();
    size = parent.size;
    final game = parent.parent;
    final textures = game.vineTextures;
    await textures.load(game.images);
    _classicTexture = textures.classic;
    _blossomTexture = textures.blossom;
    _etherealTexture = textures.ethereal;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final grid = parent;
    final level = grid.getCurrentLevelData();
    if (level == null) return;

    final game = grid.parent;
    final vineStyle = game.vineStyle;
    final useSimpleVines = vineStyle == VineStyle.simple;
    final attemptedColor = game.vineAttemptedColor;

    final gridHeight = level.gridHeight;
    final vineCount = grid.vineCount;

    // NOTE: no board-space clip here. Clearing vines slide outside the
    // board and must stay visible until fully off-screen; clipping to
    // board bounds masks them at the grid edge so they pop out instead of
    // traveling off. (Projection lines likewise run unclipped to the
    // viewport edge; their endpoints are computed on the visible rect, so
    // overdraw stays bounded.)
    // Cull margin: tube half-width + arrow head extent. Applies to idle
    // vines only: clearing vines slide off-board by design and bypass the
    // cull below so they stay visible until fully off-screen.
    const cullPad = VineMetrics.tubeWidth * 2;
    final boardRect = Rect.fromLTWH(
      -cullPad,
      -cullPad,
      GameBoardLayout.boardWidth(level.gridWidth) + cullPad * 2,
      GameBoardLayout.boardHeight(gridHeight) + cullPad * 2,
    );

    for (final comp in grid.vineLogicComponents) {
      if (comp.isRemoved) continue;
      final vineState = grid.vineStates[comp.vineData.id];
      if (vineState == null) continue;
      if (vineState.isCleared &&
          vineState.animationState != VineAnimationState.animatingClear) {
        continue;
      }

      final points = comp.renderPoints(gridHeight);
      if (points.isEmpty) {
        comp.bloom.draw(
          canvas: canvas,
          renderColor: comp.calmColor,
          cellSize: comp.cellSize,
        );
        continue;
      }
      if (!comp.renderBounds(points).overlaps(boardRect) &&
          !comp.animator.isAnimating) {
        continue;
      }

      final calmColor = comp.calmColor;
      final isAttempted = vineState.hasBeenAttempted;
      Color drawColor = VineComponent.computeRenderColor(
        calmColor,
        isAttempted,
        attemptedColor,
      );
      if (!useSimpleVines) {
        drawColor = isAttempted ? calmColor : const Color(0xFFFFFFFF);
      }

      final isAnimating = comp.animator.isAnimating;
      VinePathPainter.drawVine(
        canvas: canvas,
        vineData: comp.vineData,
        points: points,
        strokeWidth: VineMetrics.tubeWidth,
        cellSize: comp.cellSize,
        useSimpleVines: useSimpleVines,
        vineStyle: vineStyle,
        drawColor: drawColor,
        calmColor: calmColor,
        isAttempted: isAttempted,
        isAnimating: isAnimating,
        foliageStride: VineMetrics.foliageStride(
          isAnimating: isAnimating,
          vineCount: vineCount,
        ),
        cachedPath: comp.renderPath(gridHeight, points),
        classicTexture: _classicTexture,
        blossomTexture: _blossomTexture,
        etherealTexture: _etherealTexture,
      );

      comp.bloom.draw(
        canvas: canvas,
        renderColor: drawColor,
        cellSize: comp.cellSize,
      );
    }
  }
}
