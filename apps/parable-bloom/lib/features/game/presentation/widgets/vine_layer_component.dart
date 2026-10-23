import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/core/providers/settings_providers.dart'
    show VineRenderMode, VineStyle;
import 'package:parable_bloom/core/services/logger_service.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/presentation/widgets/grid_component.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine_component.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_foliage_atlas.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_rail_renderer.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_skin_atlas.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_path_painter.dart';

/// Single batched renderer for all vines on the board.
///
/// Replaces N per-vine Flame render passes with one component that draws
/// every vine in a single canvas traversal: shared static paints, per-vine
/// frustum culling, and board-size-aware foliage LOD. Logic and
/// animation state stay in [VineComponent]; this component only reads.
///
/// Rendering mode: `rail` batches one `drawVertices` strip + one foliage
/// call per vine (draw calls independent of vine length); `legacy` keeps
/// the per-frame Path painter for A/B regression.
class VineLayerComponent extends PositionComponent
    with ParentIsA<GridComponent> {
  // Shared textures resolved once from the game-level loader (legacy mode
  // keeps sampling the full-scene JPEGs for regression).
  ui.Image? _classicTexture;
  ui.Image? _blossomTexture;
  ui.Image? _etherealTexture;

  /// Startup-baked foliage atlas for the rail renderer.
  final VineFoliageAtlas foliageAtlas = VineFoliageAtlas();

  /// Startup-baked tube-skin atlas for the rail renderer (wood trellis +
  /// wrapped vine per style, plus a withered variant each). Free of new
  /// assets; drawn procedurally once per layer load.
  final VineSkinAtlas skinAtlas = VineSkinAtlas();

  /// Live render mode (set from [vineRenderModeProvider] by GardenGame).
  VineRenderMode renderMode = VineRenderMode.rail;

  VineLayerComponent() : super(priority: 2);

  @override
  Future<void> onLoad() async {
    position = Vector2.zero();
    size = parent.size;
    // Pick up GardenGame's configured renderer mode (fresh grids default
    // to rail; the dynamic setter keeps live layers in sync).
    renderMode = parent.parent.vineRenderMode;
    final game = parent.parent;
    final textures = game.vineTextures;
    await textures.load(game.images);
    _classicTexture = textures.classic;
    _blossomTexture = textures.blossom;
    _etherealTexture = textures.ethereal;

    // Bake once; GPU-cheap via toImageSync. On engines without
    // toImageSync support the try/catch degrades gracefully to flat color.
    try {
      foliageAtlas.bake();
    } catch (e) {
      LoggerService.warn(
        'Foliage atlas bake failed; foliage falls back to nothing',
        tag: 'VineLayer',
        metadata: {'error': '$e'},
      );
    }
    try {
      skinAtlas.bake();
    } catch (e) {
      LoggerService.warn(
        'Skin atlas bake failed; textured vines fall back to flat colors',
        tag: 'VineLayer',
        metadata: {'error': '$e'},
      );
    }
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

    // Cull margin: textured tube half-width + feather + arrow head extent.
    // Uses the widest tube so textured styles never clip; applies to idle
    // vines only: clearing vines exit through the fade band and their
    // components disappear immediately after the bloom completes.
    const cullPad = VineMetrics.texturedTubeWidth * 2;
    final boardRect = Rect.fromLTWH(
      -cullPad,
      -cullPad,
      GameBoardLayout.boardWidth(level.gridWidth) + cullPad * 2,
      GameBoardLayout.boardHeight(gridHeight) + cullPad * 2,
    );

    final foliageStride = VineMetrics.foliageStride(
      isAnimating: false,
      vineCount: vineCount,
    );
    final animatingFoliageStride = VineMetrics.foliageStride(
      isAnimating: true,
      vineCount: vineCount,
    );

    for (final comp in grid.vineLogicComponents) {
      if (comp.isRemoved) continue;
      final vineState = grid.vineStates[comp.vineData.id];
      if (vineState == null) continue;
      if (vineState.isCleared &&
          vineState.animationState != VineAnimationState.animatingClear) {
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

      if (renderMode == VineRenderMode.rail) {
        comp.ensureRailTrack();
        final isAnimating = comp.slide.isAnimating;
        final skinReady = skinAtlas.image != null;

        // Rail tint rules (see [VineRailRenderer.draw]):
        // - tube strip carries white modulate over the fully colored skin
        //   tiles; the withered variant is baked, so no brown tint needed.
        // - flat/simple stroke: withered bark brown after a failed
        //   attempt, otherwise the vine's calm palette color.
        // - foliage quads: per-vine calm color, brown when withered.
        // - caps/arrow head: the style's vine accent color (flat draw,
        //   does not sample the skin atlas), brown when withered.
        // When the skin atlas is missing, textured styles degrade to the
        // flat vector look with these same colors.
        final flatTint = isAttempted ? VineMetrics.witheredColor : calmColor;
        final skinTile =
            VineSkinAtlas.tileFor(vineStyle, isAttempted: isAttempted);
        Color tubeTint;
        Color capTint;
        if (useSimpleVines || !skinReady) {
          tubeTint = flatTint;
          capTint = flatTint;
        } else {
          tubeTint = const Color(0xFFFFFFFF);
          capTint =
              VineSkinAtlas.accentFor(vineStyle, isAttempted: isAttempted);
        }
        final foliageTint = useSimpleVines
            ? flatTint
            : isAttempted
                ? VineMetrics.witheredColor
                : calmColor;

        final rail = comp.prepareRailDraw(
          style: vineStyle,
          foliageStride: isAnimating ? animatingFoliageStride : foliageStride,
          stripTint: tubeTint,
          foliageTint: foliageTint,
          skinTile: skinTile,
        );
        if (rail == null) continue;
        VineRailRenderer.draw(
          canvas: canvas,
          rail: rail,
          vineStyle: vineStyle,
          useSimpleVines: useSimpleVines,
          isAttempted: isAttempted,
          skinAtlasImage: skinAtlas.image,
          foliageAtlasImage: foliageAtlas.image,
          tubeTint: tubeTint,
          foliageTint: foliageTint,
          capTint: capTint,
        );
        comp.bloom.draw(
          canvas: canvas,
          renderColor: drawColor,
          cellSize: comp.cellSize,
        );
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
        foliageStride: isAnimating ? animatingFoliageStride : foliageStride,
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
