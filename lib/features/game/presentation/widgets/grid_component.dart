import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../../../providers/game_providers.dart';
import '../../../game/domain/services/level_solver_service.dart';
import 'garden_game.dart';
import 'vine_component.dart';

// TODO: Add vine rendering system
// This component will eventually render actual vine sprites
// For now, it renders placeholder colored rectangles

class GridComponent extends PositionComponent
    with TapCallbacks, ParentIsA<GardenGame> {
  final double cellSize;

  late List<List<CellComponent>> cells;
  late int rows;
  late int cols;

  // Current level data - will be set by Riverpod
  LevelData? _currentLevel;

  // Vine states - will be managed by Riverpod
  Map<String, VineState> _vineStates = {};

  // Callback to notify when level is complete
  final VoidCallback? onLevelComplete;

  // Callback to clear a vine in the Riverpod provider
  final Function(String)? onVineCleared;

  // Map to track active vine components
  final Map<String, VineComponent> _vineComponents = {};

  GridComponent({
    required this.cellSize,
    this.onLevelComplete,
    this.onVineCleared,
  }) : super(position: Vector2.zero());

  // Set level data and vine states from Riverpod providers
  void setLevelData(LevelData levelData, Map<String, VineState> vineStates) {
    final isNewLevel = _currentLevel != levelData;
    _currentLevel = levelData;
    _vineStates = Map.from(vineStates);

    // Calculate grid dimensions from vine bounds
    final bounds = levelData.getBounds();
    rows = bounds.maxY - bounds.minY + 1;
    cols = bounds.maxX - bounds.minX + 1;

    // Only recreate components if it's a new level
    if (isNewLevel) {
      // Create grid cells for the new level
      _createGridCells();

      // Clear old vine components
      for (final comp in _vineComponents.values) {
        comp.removeFromParent();
      }
      _vineComponents.clear();

      // Add new vine components for each vine in the level
      for (final vine in levelData.vines) {
        final comp = VineComponent(vineData: vine, cellSize: cellSize);
        add(comp);
        _vineComponents[vine.id] = comp;
      }
    }
    // For state updates, just update the state without recreating components

    update(0); // Force redraw
  }

  VineState? getCurrentVineState(String vineId) => _vineStates[vineId];

  VineComponent? getVineComponent(String vineId) => _vineComponents[vineId];

  void setVineAnimationState(String vineId, VineAnimationState animationState) {
    parent.ref
        .read(vineStatesProvider.notifier)
        .setAnimationState(vineId, animationState);
  }

  void markVineAttempted(String vineId) {
    parent.ref.read(vineStatesProvider.notifier).markAttempted(vineId);
  }

  void notifyVineCleared(String vineId) {
    _clearVine(vineId);
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
    return parent.ref.read(levelSolverServiceProvider);
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
          size: Vector2(cellSize, cellSize),
          position: Vector2(x * cellSize, visualRow * cellSize),
        );
        add(cell);
        cells[y].add(cell);
      }
    }

    // Update grid size and position
    size = Vector2(cols * cellSize, rows * cellSize);
    position = Vector2(
      (parent.size.x - width) / 2,
      (parent.size.y - height) / 2,
    );
  }

  // Individual vines are now rendered by VineComponent children

  // Handle cell tap from child CellComponent
  void handleCellTap(int row, int col) {
    // Increment total taps counter
    parent.ref.read(levelTotalTapsProvider.notifier).increment();

    final clickedVine = _getVineAtCell(row, col);

    if (clickedVine == null) return;

    final state = _vineStates[clickedVine.id];
    if (state == null || state.isCleared) return;

    final comp = _vineComponents[clickedVine.id];
    if (comp == null) return;

    debugPrint('Sliding out vine: ${clickedVine.id}');
    comp.slideOut();
  }

  VineData? _getVineAtCell(int row, int col) {
    if (_currentLevel == null) return null;

    // Convert from grid coordinates to world coordinates
    final bounds = _currentLevel!.getBounds();
    final worldX = bounds.minX + col;
    final worldY = bounds.minY + row;

    for (final vine in _currentLevel!.vines) {
      for (final cell in vine.orderedPath) {
        if (cell['x'] == worldX && cell['y'] == worldY) {
          return vine;
        }
      }
    }
    return null;
  }

  void _clearVine(String vineId) {
    // Update vine state to cleared
    _vineStates[vineId] = _vineStates[vineId]!.copyWith(isCleared: true);

    // Notify Riverpod provider
    onVineCleared?.call(vineId);

    // Trigger parable reveal animation (placeholder)
    debugPrint('Vine $vineId cleared! Trigger parable reveal animation');

    // TODO: Add particle effects and sound when vine is cleared
    // TODO: Gradually reveal parable background/image
    // TODO: Animate parable text appearing

    // Force redraw to show vine removed
    update(0);
  }
}

class CellComponent extends RectangleComponent
    with TapCallbacks, HasGameReference<GardenGame> {
  final int gridX;
  final int gridY;

  CellComponent({
    required this.gridX,
    required this.gridY,
    required super.size,
    required super.position,
  }) : super(
         paint: Paint()..color = Colors.transparent,
         anchor: Anchor.topLeft,
       );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Use theme-aware colors for grid dots
    final theme = Theme.of(game.buildContext!);
    final isDark = theme.brightness == Brightness.dark;

    // Draw small dot in the center of the cell
    final center = size.toRect().center;
    final dotColor = isDark
        ? const Color(0x26E2D6C4) // Beige tint for dark mode
        : const Color(0x26E2D6C4); // Same beige tint for light mode
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);

    // Debug: draw x,y labels in corner with theme-aware colors
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: '$gridX,$gridY',
      style: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        fontSize: 10,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(2, 2));
  }

  @override
  void onTapUp(TapUpEvent event) {
    // Delegate to parent GridComponent for vine handling
    (parent as GridComponent).handleCellTap(
      gridY,
      gridX,
    ); // Convert x,y to row,col for GridComponent
  }
}
