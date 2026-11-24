import 'package:flame/components.dart';
import 'package:material_ui/material_ui.dart';

import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/core/providers/settings_providers.dart'
    show VineRenderMode;
import 'package:parable_bloom/core/services/logger_service.dart';
import 'package:parable_bloom/features/appearance/domain/appearance_pack.dart';
import 'package:parable_bloom/features/appearance/domain/vine_skin.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/presentation/widgets/grid_component.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine_component.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_foliage_atlas.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_ornament_path.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_rail_renderer.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_path_painter.dart';

/// Single batched renderer for all vines on the board.
///
/// Replaces N per-vine Flame render passes with one component that draws
/// every vine in a single canvas traversal: shared static paints, per-vine
/// frustum culling, and board-size-aware foliage LOD. Logic and
/// animation state stay in [VineComponent]; this component only reads.
///
/// Rendering mode: `rail` strokes each vine (a rail, a core, ornaments, and
/// an arrow) with draw count independent of vine length; `legacy` keeps
/// the per-frame Path painter for A/B regression.
class VineLayerComponent extends PositionComponent
    with ParentIsA<GridComponent> {
  /// Startup-baked foliage atlas for the rail renderer.
  final VineFoliageAtlas foliageAtlas = VineFoliageAtlas();

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
    final keys = <String>{
      ...AppearancePack.garden.vineTextureAssets,
      if (game.vineSkin.textureAsset case final asset?) asset,
    };
    try {
      await textures.ensureLoaded(game.images, keys);
    } catch (e) {
      LoggerService.warn(
        'Vine textures failed to load; the board falls back to the flat stroke',
        tag: 'VineLayer',
        metadata: {'error': '$e'},
      );
    }

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
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final grid = parent;
    final level = grid.getCurrentLevelData();
    if (level == null) return;

    final game = grid.parent;
    final skin = game.vineSkin;
    final vineStyle = skin.legacyStyle;
    final useSimpleVines = skin.flat;
    final textureImage = game.vineTextures.imageFor(skin.textureAsset);
    final attemptedColor = game.vineAttemptedColor;

    final gridHeight = level.gridHeight;
    final vineCount = grid.vineCount;

    // Cull margin: textured tube half-width + feather + arrow head extent.
    // Uses the widest tube so textured styles never clip. Idle vines only:
    // a clearing vine is drawn at full opacity until its tail leaves the
    // viewport, then the component is removed.
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

        // The skin's trellis strip. Null degrades to a flat-colored vertex
        // strip until the loader finishes.
        final texW = textureImage?.width ?? 1024;
        final texH = textureImage?.height ?? 1024;

        // Stroke skins. A failed clear paints the rail, core, ornaments,
        // and arrow in one brown. Otherwise the core is the skin color or
        // the vine's calm color, and a null arrow is a lighter shade of
        // that core.
        final brown = VineMetrics.witheredColor;
        final coreColor = isAttempted ? brown : (skin.core ?? calmColor);
        final railColor =
            skin.rail == null ? null : (isAttempted ? brown : skin.rail);
        final arrowColor = isAttempted
            ? brown
            : (skin.arrow ?? VineMetrics.contrastArrow(coreColor));
        final windColor = !skin.winds
            ? null
            : (isAttempted ? brown : (skin.vine ?? calmColor));
        final ornamentPaints = VineOrnamentPaints.forKind(skin.foliage);
        final ornamentColor = isAttempted ? brown : ornamentPaints.fill;
        final ornamentDetailColor = isAttempted ? brown : ornamentPaints.detail;

        final rail = comp.prepareRailDraw(
          simple: true,
          foliageKind: skin.flat ? VineFoliage.none : skin.foliage,
          foliageStride: isAnimating ? animatingFoliageStride : foliageStride,
          stripTint: coreColor,
          foliageTint: ornamentColor,
          uvPhase: comp.uvPhase,
          texWidth: texW,
          texHeight: texH,
        );
        if (rail == null) continue;
        VineRailRenderer.draw(
          canvas: canvas,
          rail: rail,
          coreColor: coreColor,
          arrowColor: arrowColor,
          railColor: railColor,
          windColor: windColor,
          ornamentColor: ornamentColor,
          ornamentDetailColor: ornamentDetailColor,
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
        classicTexture: textureImage,
        blossomTexture: textureImage,
        etherealTexture: textureImage,
      );

      comp.bloom.draw(
        canvas: canvas,
        renderColor: drawColor,
        cellSize: comp.cellSize,
      );
    }
  }
}
