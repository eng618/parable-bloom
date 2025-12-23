import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../../../providers/game_providers.dart';
import 'garden_game.dart';
import 'vine_component.dart';

// TODO: Add vine rendering system
// This component will eventually render actual vine sprites
// For now, it renders placeholder colored rectangles

class GridComponent extends PositionComponent
    with TapCallbacks, ParentIsA<GardenGame> {
  final int gridSize;
  final double cellSize;

  late List<List<CellComponent>> cells;

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
    required this.gridSize,
    required this.cellSize,
    this.onLevelComplete,
    this.onVineCleared,
  }) : super(position: Vector2.zero());

  // Set level data and vine states from Riverpod providers
  void setLevelData(LevelData levelData, Map<String, VineState> vineStates) {
    _currentLevel = levelData;
    _vineStates = Map.from(vineStates);

    // Clear old vine components
    for (final comp in _vineComponents.values) {
      comp.removeFromParent();
    }
    _vineComponents.clear();

    // Add new vine components for each vine in the level
    for (final vine in levelData.vines) {
      final comp = VineComponent(
        vineData: vine,
        cellSize: cellSize,
        gridSize: gridSize,
      );
      add(comp);
      _vineComponents[vine.id] = comp;
    }

    update(0); // Force redraw
  }

  VineState? getCurrentVineState(String vineId) => _vineStates[vineId];

  void markVineAttempted(String vineId) {
    parent.ref.read(vineStatesProvider.notifier).markAttempted(vineId);
  }

  void notifyVineCleared(String vineId) {
    _clearVine(vineId);
  }

  @override
  Future<void> onLoad() async {
    size = Vector2(gridSize * cellSize, gridSize * cellSize);

    // Center the grid on screen
    position = Vector2(
      (parent.size.x - width) / 2,
      (parent.size.y - height) / 2,
    );

    cells = [];

    for (int rangeRow = 0; rangeRow < gridSize; rangeRow++) {
      cells.add([]);
      for (int col = 0; col < gridSize; col++) {
        // Use local variable for calculated visual row
        // Row 0 is at the bottom, so visual Y is proportional to (gridSize - 1 - row)
        final visualRow = gridSize - 1 - rangeRow;

        final cell = CellComponent(
          row: rangeRow,
          col: col,
          size: Vector2(cellSize, cellSize),
          position: Vector2(col * cellSize, visualRow * cellSize),
        );
        add(cell);
        cells[rangeRow].add(cell);
      }
    }
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

    if (!state.isBlocked) {
      // Vine can be moved (not blocked) - trigger animation
      comp.slideOut();
      debugPrint('Clicked movable vine: ${clickedVine.id}');
    } else {
      // Tapped a blocked vine - calculate distance and trigger bump animation
      debugPrint('Tapped blocked vine: ${clickedVine.id}');

      final activeIds = _vineStates.entries
          .where((e) => !e.value.isCleared)
          .map((e) => e.key)
          .toList();

      final distance = LevelSolver.getDistanceToBlocker(
        _currentLevel!,
        clickedVine.id,
        activeIds,
      );
      comp.slideBump(distance);
    }
  }

  VineData? _getVineAtCell(int row, int col) {
    if (_currentLevel == null) return null;

    for (final vine in _currentLevel!.vines) {
      for (final cell in vine.path) {
        if (cell['row'] == row && cell['col'] == col) {
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
  final int row;
  final int col;

  CellComponent({
    required this.row,
    required this.col,
    required super.size,
    required super.position,
  }) : super(
         paint: Paint()..color = Colors.transparent,
         anchor: Anchor.topLeft,
       );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw small dot in the center of the cell
    final center = size.toRect().center;
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15 * 255)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);
  }

  @override
  void onTapUp(TapUpEvent event) {
    // Delegate to parent GridComponent for vine handling
    (parent as GridComponent).handleCellTap(row, col);
  }
}
