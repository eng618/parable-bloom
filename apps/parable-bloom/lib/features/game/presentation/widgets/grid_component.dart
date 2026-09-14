import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/game_board_layout.dart';
import '../../../../core/board_transform.dart';
import '../../../../core/constants/animation_timing.dart';
import '../../../../features/game/domain/entities/level_data.dart';
import '../../../../core/services/logger_service.dart';
import '../../application/providers/gameplay_state_providers.dart';
import '../../../game/domain/services/level_solver_service.dart';
import '../../../tutorial/presentation/widgets/tutorial_guide_overlay.dart';
import 'garden_game.dart';
import 'vine_component.dart';

class GridComponent extends PositionComponent
    with TapCallbacks, ParentIsA<GardenGame> {
  final double cellSize;

  late List<List<CellComponent>> cells;
  late int rows;
  late int cols;

  // Camera transform properties
  double _screenWidth = 0.0;
  double _screenHeight = 0.0;
  double _lastZoom = double.nan;

  // Cached per-level cell visibility: avoids `mask.points.any()` scan per
  // cell per frame. Null means show-all (no lookup).
  Set<(int, int)>? _visibleCells;

  /// Cached debug flag, refreshed once per frame in [update] instead of a
  /// Riverpod read per cell per frame in [CellComponent.render].
  bool debugCoordinatesCached = false;

  // Current level data - will be set by Riverpod
  LevelData? _currentLevel;

  // Pre-computed map from (x, y) coordinates to VineData for fast lookup
  final Map<(int, int), VineData> _coordinateToVineMap = {};

  // Vine states - managed via callbacks
  Map<String, VineState> _vineStates = {};
  Map<String, VineState> get vineStates => _vineStates;

  // Callbacks for decoupled communication with state management
  final VoidCallback? onLevelComplete;
  final Function(String)? onVineCleared;
  final Function(String)? onVineTap; // Callback when user taps a vine
  final Function(String, VineAnimationState)? onVineAnimationStateChanged;
  final Function(String)? onVineAttempted;
  final Function(int)? onTapIncrement; // Callback to increment tap counter
  final Function(Vector2)?
      onTapEffect; // Callback to create tap effect at position

  // Map to track active vine components
  final Map<String, VineComponent> _vineComponents = {};

  bool _isAutoClearingInProgress = false;

  /// Shared solver instance. Injected so per-tap distance checks reuse one
  /// (stateless) service instead of allocating a fresh one per call.
  final LevelSolverService solver;

  GridComponent({
    required this.cellSize,
    this.onLevelComplete,
    this.onVineCleared,
    this.onVineTap,
    this.onVineAnimationStateChanged,
    this.onVineAttempted,
    this.onTapIncrement,
    this.onTapEffect,
    LevelSolverService? solver,
  })  : solver = solver ?? LevelSolverService(),
        super(position: Vector2.zero());

  // Set level data and vine states from Riverpod providers.
  // Riverpod is the single owner of vine state; the grid keeps a read-only
  // mirror refreshed via [updateVineStates]. Identity comparison would
  // mistake a reloaded-but-identical level for a new one, so compare by id.
  void setLevelData(LevelData levelData, Map<String, VineState> vineStates) {
    final isNewLevel = _currentLevel?.id != levelData.id;
    _currentLevel = levelData;
    // In-place mirror update: avoids a full Map.from copy on every provider
    // tick (fired on attempted/animating/cleared). Flame reads the mirror on
    // the next frame; identity is preserved for unchanged entries.
    if (_vineStates.length != vineStates.length) {
      _vineStates = Map<String, VineState>.from(vineStates);
    } else {
      vineStates.forEach((key, value) {
        if (_vineStates[key] != value) _vineStates[key] = value;
      });
      // Remove stale keys without allocating when sizes match but keys differ
      // (rare: only on level reload).
      if (!_vineStates.keys.every(vineStates.containsKey)) {
        _vineStates.removeWhere((key, _) => !vineStates.containsKey(key));
      }
    }

    // Grid dimensions are driven by grid_size.
    cols = levelData.gridWidth;
    rows = levelData.gridHeight;

    // Only recreate components if it's a new level
    if (isNewLevel) {
      // Cache cell visibility once per level: show-all needs no set.
      if (levelData.mask.mode == 'show-all') {
        _visibleCells = null;
      } else if (levelData.mask.mode == 'show') {
        _visibleCells = {
          for (final p in levelData.mask.points) (p['x'] ?? -1, p['y'] ?? -1),
        };
      } else {
        // 'hide': precompute visible set for the board bounds.
        final hidden = {
          for (final p in levelData.mask.points) (p['x'] ?? -1, p['y'] ?? -1),
        };
        _visibleCells = {
          for (int y = 0; y < levelData.gridHeight; y++)
            for (int x = 0; x < levelData.gridWidth; x++)
              if (!hidden.contains((x, y))) (x, y),
        };
      }

      // Create grid cells for the new level
      _createGridCells();

      // Clear old vine components
      for (final comp in _vineComponents.values) {
        comp.removeFromParent();
      }
      _vineComponents.clear();

      // Pre-compute coordinate-to-vine map
      _coordinateToVineMap.clear();
      for (final vine in levelData.vines) {
        for (final cell in vine.orderedPath) {
          final x = cell['x'];
          final y = cell['y'];
          if (x != null && y != null) {
            _coordinateToVineMap[(x, y)] = vine;
          }
        }
      }

      // Add new vine components for each vine in the level
      for (final vine in levelData.vines) {
        final comp = VineComponent(vineData: vine, cellSize: cellSize);
        add(comp);
        _vineComponents[vine.id] = comp;
      }
    }
    // For state updates, just update the state without recreating components.
    // No forced redraw: Flame renders continuously, and update(0) only pumps
    // children with dt=0 (a no-op for idle vines).

    if (!isNewLevel) {
      _processAutoClearing();
    }
  }

  VineState? getCurrentVineState(String vineId) => _vineStates[vineId];

  VineComponent? getVineComponent(String vineId) => _vineComponents[vineId];

  void setVineAnimationState(String vineId, VineAnimationState animationState) {
    // Optimistic mirror update (same pattern as _clearVine): the provider
    // round-trip lands after the next tap may already have read the mirror,
    // and a stale animationState resurrects cleared/clearing vines as ghost
    // blockers in getActiveVineIds/distance checks. The listen path
    // overwrites this with computed state.
    final existing = _vineStates[vineId];
    if (existing != null && existing.animationState != animationState) {
      _vineStates[vineId] = existing.copyWith(animationState: animationState);
    }
    onVineAnimationStateChanged?.call(vineId, animationState);
  }

  void markVineAttempted(String vineId) {
    onVineAttempted?.call(vineId);
  }

  void notifyVineCleared(String vineId) {
    _clearVine(vineId);
  }

  // Apply camera transform (zoom and pan)
  void applyCameraTransform({
    required double zoom,
    required Vector2 panOffset,
    required double screenWidth,
    required double screenHeight,
  }) {
    _screenWidth = screenWidth;
    _screenHeight = screenHeight;

    // Update grid scale in place (no Vector2.all alloc per camera frame).
    scale.setValues(zoom, zoom);

    // Centered position with pan offset (single formula in BoardTransform)
    final pos = BoardTransform.boardPosition(
      cols: cols,
      rows: rows,
      zoom: zoom,
      panX: panOffset.x,
      panY: panOffset.y,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
    position.setValues(pos.x, pos.y);

    // Vine zoom is a no-op (handled via parent scale); skip the per-vine
    // loop unless zoom actually changed.
    if (zoom != _lastZoom) {
      _lastZoom = zoom;
      for (final comp in _vineComponents.values) {
        comp.updateZoom(zoom);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Cache the debug flag once per frame: CellComponent.render runs per
    // cell per frame and must not hit Riverpod 100x/frame.
    debugCoordinatesCached = parent.sink.debugShowGridCoordinates;
  }

  /// Fast visibility check backed by the per-level cache built in
  /// [setLevelData]. Falls back to the level mask when no cache exists
  /// (e.g. before the first level loads).
  bool isCellVisibleCached(int x, int y) {
    final cached = _visibleCells;
    if (cached == null) {
      // show-all fast path or no level yet: avoid set lookup.
      if (_currentLevel == null || _currentLevel!.mask.mode == 'show-all') {
        return true;
      }
      return _currentLevel!.isCellVisible(x, y);
    }
    return cached.contains((x, y));
  }

  List<String> getActiveVineIds() {
    return _vineStates.entries
        .where(
          (e) =>
              !e.value.isCleared &&
              e.value.animationState != VineAnimationState.animatingClear,
        )
        .map((e) => e.key)
        .toList();
  }

  LevelData? getCurrentLevelData() => _currentLevel;

  LevelSolverService getLevelSolverService() {
    return solver;
  }

  @override
  Future<void> onLoad() async {
    // Initialize cells list
    cells = [];

    // Grid will be sized and positioned when level data is set
    size = Vector2.zero();
    position = Vector2.zero();
  }

  // Create or update grid cells based on level data
  void _createGridCells() {
    // Remove existing cells
    for (final row in cells) {
      for (final cell in row) {
        if (cell.isMounted) {
          remove(cell);
        }
      }
    }

    cells = [];

    for (int y = 0; y < rows; y++) {
      cells.add([]);
      for (int x = 0; x < cols; x++) {
        // Use local variable for calculated visual row
        // y=0 is at the bottom, so visual Y is proportional to (rows - 1 - y)
        final visualRow = rows - 1 - y;

        final cell = CellComponent(
          gridX: x,
          gridY: y,
          size: Vector2.all(GameBoardLayout.tapTargetSize),
          position: Vector2(
            GameBoardLayout.cellLeft(x),
            GameBoardLayout.cellTop(visualRow),
          ),
        );
        add(cell);
        cells[y].add(cell);
      }
    }

    // Update grid size
    size = Vector2(
      GameBoardLayout.boardWidth(cols),
      GameBoardLayout.boardHeight(rows),
    );

    // Position will be set by camera transform
    // Initialize with centered position if camera not yet applied
    if (_screenWidth == 0.0 || _screenHeight == 0.0) {
      position = Vector2(
        (parent.size.x - width) / 2,
        (parent.size.y - height) / 2,
      );
    }
  }

  // Individual vines are now rendered by VineComponent children

  // Handle cell tap from child CellComponent
  void handleCellTap(int row, int col) {
    // Notify tap counter via callback
    onTapIncrement?.call(1);

    final level = _currentLevel;
    if (level == null) return;

    // Masked-out cells are not interactive.
    if (!level.isCellVisible(col, row)) return;

    final clickedVine = _getVineAtCell(row, col);

    if (clickedVine == null) return;

    // Gesture restrictions for progressive tutorial
    if (level.difficulty == 'tutorial') {
      if (level.id == '1') {
        // Lesson 1: Only allow tapping vine_1's head at (3, 1)
        if (clickedVine.id != 'vine_1' || col != 3 || row != 1) {
          return;
        }
      }
    }

    final state = _vineStates[clickedVine.id];
    if (state == null || state.isCleared) return;

    final comp = _vineComponents[clickedVine.id];
    if (comp == null) return;

    // If vine is blocked, calculate screenspace offsets for visual collision feedback
    if (state.isBlocked) {
      final head = clickedVine.orderedPath.first;
      final dir = clickedVine.headDirection;
      int nextX = head['x']!;
      int nextY = head['y']!;
      if (dir == 'right') nextX++;
      if (dir == 'left') nextX--;
      if (dir == 'up') nextY++;
      if (dir == 'down') nextY--;

      final headOffset = parent.getCellScreenPosition(head['x']!, head['y']!);
      final blockerOffset = parent.getCellScreenPosition(nextX, nextY);

      parent.sink.onBlockedTap(BlockedTapState(
        headPosition: headOffset,
        blockerPosition: blockerOffset,
        timestamp: DateTime.now(),
      ));
    }

    // Notify that a vine was tapped
    onVineTap?.call(clickedVine.id);
    LoggerService.debug('Sliding out vine',
        tag: 'GridComponent', metadata: {'vine_id': clickedVine.id});
    comp.slideOut();
  }

  VineData? _getVineAtCell(int row, int col) {
    if (_currentLevel == null) return null;

    // Convert from grid coordinates to world coordinates.
    // With grid_size, grid coordinates are the world coordinates.
    final worldX = col;
    final worldY = row;

    return _coordinateToVineMap[(worldX, worldY)];
  }

  void _clearVine(String vineId) {
    // Optimistic mirror exclusion: the provider round-trip
    // (onVineCleared -> clearVine -> listen -> updateVineStates) lands after
    // the next tap may already have read the mirror. A still-listed vine
    // acts as a ghost blocker in getActiveVineIds/distance checks and can
    // deadlock the level, so exclude it here too. The provider remains the
    // single owner; the listen path overwrites this with computed state.
    final existing = _vineStates[vineId];
    if (existing != null && !existing.isCleared) {
      _vineStates[vineId] = existing.copyWith(isCleared: true);
    }
    onVineCleared?.call(vineId);
    LoggerService.info('Vine cleared',
        tag: 'GridComponent', metadata: {'vine_id': vineId});

    // TODO: Add particle effects and sound when vine is cleared
    // TODO: Gradually reveal parable background/image
    // TODO: Animate parable text appearing
  }

  void _processAutoClearing() async {
    if (_isAutoClearingInProgress) return;

    final level = _currentLevel;
    if (level == null) return;

    // Check if any vine is currently animating
    final isAnyAnimating = parent.sink.isAnyAnimating;
    if (isAnyAnimating) return;

    // Find first vine that meets the auto-clear criteria
    String? targetVineId;
    for (final vine in level.vines) {
      final state = _vineStates[vine.id];
      if (state != null &&
          !state.isCleared &&
          state.animationState == VineAnimationState.normal &&
          state.hasBeenAttempted &&
          !state.isBlocked) {
        targetVineId = vine.id;
        break;
      }
    }

    if (targetVineId == null) return;

    _isAutoClearingInProgress = true;

    try {
      final vine = level.vines.firstWhere((v) => v.id == targetVineId);
      final comp = _vineComponents[targetVineId];
      if (comp != null) {
        LoggerService.info(
          'Auto-clearing vine $targetVineId because it has a clear path',
          tag: 'GridComponent',
        );

        // 1. Adjust camera so the vine is visible
        await parent.sink.onEnsureVineVisible(vine);

        // 2. Add a 200ms delay to allow player to register camera zoom/pan
        await Future.delayed(AnimationTiming.autoClearPause);

        // 3. Automatically clear the blocked vine
        comp.slideOut();
      }
    } catch (e, stack) {
      LoggerService.error(
        'Error auto-clearing vine: $e',
        tag: 'GridComponent',
        stackTrace: stack,
      );
    } finally {
      _isAutoClearingInProgress = false;
    }
  }
}

class CellComponent extends RectangleComponent
    with TapCallbacks, HasGameReference<GardenGame> {
  final int gridX;
  final int gridY;
  bool _isLongPressed = false;

  /// Shared dot paint: the beige tint is identical in both themes, so one
  /// instance serves all cells instead of one allocation per cell per frame.
  static final Paint _dotPaint = Paint()
    ..color = const Color(0x26E2D6C4)
    ..style = PaintingStyle.fill;

  static final Paint _transparentPaint = Paint()..color = Colors.transparent;

  CellComponent({
    required this.gridX,
    required this.gridY,
    required super.size,
    required super.position,
  }) : super(
          paint: _transparentPaint,
          anchor: Anchor.topLeft,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final grid = parent as GridComponent;
    if (grid.getCurrentLevelData() == null) return;

    // Masked-out cells are not drawn (cached bitmask, no per-frame scan).
    if (!grid.isCellVisibleCached(gridX, gridY)) return;

    // Draw small dot in the center of the cell (shared paint, no per-frame
    // allocation; avoids the Rect allocation of size.toRect().center).
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      GameBoardLayout.gridDotRadius,
      _dotPaint,
    );

    // Debug: draw x,y labels in corner only if debug mode is enabled.
    // Flag is cached once per frame on the grid (no per-cell provider read).
    final showCoordinates = grid.debugCoordinatesCached;

    if (kDebugMode && showCoordinates) {
      final theme = Theme.of(game.buildContext!);
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: '$gridX,$gridY',
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 14,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(2, 2));
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    _isLongPressed = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _isLongPressed = false;
  }

  @override
  void onLongTapDown(TapDownEvent event) {
    _isLongPressed = true;
    final gridParent = parent as GridComponent;
    final clickedVine = gridParent._getVineAtCell(gridY, gridX);
    if (clickedVine != null) {
      final state = gridParent.getCurrentVineState(clickedVine.id);
      if (state != null && !state.isCleared) {
        // Trigger haptic feedback on long press if enabled
        if (game.sink.hapticsEnabled) {
          HapticFeedback.mediumImpact();
        }
        // Add this vine ID to the hinted set
        game.sink.onHintVine(clickedVine.id);
      }
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (_isLongPressed) {
      // Releasing a long press should keep the hint line visible and not trigger normal tap actions
      _isLongPressed = false;
      return;
    }

    // No haptics here: GardenGame.onTapDown already fires lightImpact for
    // every canvas tap (single owner), so this would double-vibrate.
    final gridParent = parent as GridComponent;

    // Clear hints on tap
    game.sink.onClearHints();

    // Create tap effect at the tap position
    // Convert cell-local position to grid-local position
    final gridLocalPos = position + event.localPosition;

    // Trigger tap effect
    gridParent.onTapEffect?.call(gridLocalPos);

    // Delegate to parent GridComponent for vine handling
    gridParent.handleCellTap(gridY, gridX);
  }
}
