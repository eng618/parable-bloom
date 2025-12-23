import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/game_providers.dart';
import 'grid_component.dart';

class GardenGame extends FlameGame {
  static const double cellSize = 80.0; // Pixels per cell

  late GridComponent grid;
  final WidgetRef ref;
  LevelData? _currentLevelData;
  RectangleComponent? _gridBackground;
  RectangleComponent? _gameBackground;

  // Theme colors - can be updated dynamically
  Color _backgroundColor = const Color(0xFF1E3528);
  Color _surfaceColor = const Color(0xFF2D4A3A);
  Color _gridColor = const Color(0xFF3D5A4A);

  GardenGame({required this.ref});

  void updateThemeColors(
    Color backgroundColor,
    Color surfaceColor,
    Color gridColor,
  ) {
    debugPrint(
      'GardenGame.updateThemeColors: bg=$backgroundColor, surface=$surfaceColor, grid=$gridColor',
    );
    _backgroundColor = backgroundColor;
    _surfaceColor = surfaceColor;
    _gridColor = gridColor;

    // Update existing components if they exist - must replace the Paint to trigger redraw
    if (_gameBackground != null) {
      debugPrint('GardenGame: Updating _gameBackground to $_surfaceColor');
      _gameBackground!.paint = Paint()..color = _surfaceColor;
    }
    if (_gridBackground != null) {
      debugPrint('GardenGame: Updating _gridBackground to $_gridColor');
      _gridBackground!.paint = Paint()..color = _gridColor;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load current level first
    await _loadCurrentLevel();

    // TODO: Replace with actual parable background image
    // Load parable background
    _gameBackground = RectangleComponent(
      size: size,
      paint: Paint()..color = _surfaceColor,
      priority: -2,
    );
    add(_gameBackground!);

    // Create grid and background components
    _createLevelComponents();

    // Set level data on grid after it's created
    if (_currentLevelData != null) {
      await _setLevelDataOnGrid();
    }

    // Listen to vine state changes (blocking/clearing updates)
    ref.listenManual(vineStatesProvider, (previous, next) {
      if (_currentLevelData != null) {
        grid.setLevelData(_currentLevelData!, next);
      }
    });

    // Center camera
    camera.viewport.size = size;
  }

  void _createLevelComponents() {
    if (_currentLevelData == null) return;

    final gridSize = _currentLevelData!.grid['rows'] as int;

    // Grid background
    _gridBackground = RectangleComponent(
      size: Vector2(gridSize * cellSize + 20, gridSize * cellSize + 20),
      position: Vector2(
        (size.x - (gridSize * cellSize + 20)) / 2,
        (size.y - (gridSize * cellSize + 20)) / 2,
      ),
      paint: Paint()..color = _gridColor,
      priority: -1,
    );
    add(_gridBackground!);

    // Interactive grid
    grid = GridComponent(
      gridSize: gridSize,
      cellSize: cellSize,
      onVineCleared: (vineId) {
        // Update the Riverpod provider when a vine is cleared
        ref.read(vineStatesProvider.notifier).clearVine(vineId);
      },
    );
    add(grid);
  }

  Future<void> _loadCurrentLevel() async {
    final progress = ref.read(gameProgressProvider);
    final levelNumber = progress.currentLevel;

    try {
      // Load level data from JSON
      final levelJson = await rootBundle.loadString(
        'assets/levels/level_$levelNumber.json',
      );
      _currentLevelData = LevelData.fromJson(json.decode(levelJson));

      // Update providers
      ref.read(currentLevelProvider.notifier).setLevel(_currentLevelData);

      // Ensure gameCompleted is false if we found a level
      ref.read(gameCompletedProvider.notifier).setCompleted(false);

      // Reset tap counters for new level
      ref.read(levelTotalTapsProvider.notifier).reset();
      ref.read(levelWrongTapsProvider.notifier).reset();

      // Log level start analytics
      ref.read(analyticsServiceProvider).logLevelStart(levelNumber);

      debugPrint('Loaded level $levelNumber: ${_currentLevelData!.title}');
    } catch (e) {
      debugPrint('Error loading level $levelNumber: $e');
      // If we can't load the level, it likely means we reached the end
      ref.read(gameCompletedProvider.notifier).setCompleted(true);
    }
  }

  Future<void> _setLevelDataOnGrid() async {
    if (_currentLevelData == null) return;

    // Get current vine states from the provider
    final vineStates = ref.read(vineStatesProvider);

    // Set data on grid
    grid.setLevelData(_currentLevelData!, vineStates);
  }

  @override
  Color backgroundColor() => _backgroundColor;

  @override
  void onRemove() {
    // No need to dispose ref or container
    super.onRemove();
  }

  // Method to reload the current level (called when progress is reset or level completed)
  Future<void> reloadLevel() async {
    // Remove existing components
    if (_gridBackground != null) {
      if (_gridBackground!.isMounted) remove(_gridBackground!);
      _gridBackground = null;
    }

    // Check if grid is initialized and mounted before removing
    try {
      if (grid.isMounted) remove(grid);
    } catch (e) {
      // Ignore if grid wasn't initialized
    }

    await _loadCurrentLevel();

    if (_currentLevelData != null) {
      _createLevelComponents();

      // Reset vine states for the new level
      ref.read(vineStatesProvider.notifier).resetForLevel(_currentLevelData!);
      // Reset lives for the new level
      ref.read(gameInstanceProvider.notifier).resetLives();

      await _setLevelDataOnGrid();
    }
  }
}
