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

  // Theme colors - updated dynamically from app theme
  late Color _backgroundColor;
  late Color _surfaceColor;
  late Color _gridColor;

  GardenGame({required this.ref}) {
    // Initialize with default theme colors - will be updated by game screen
    _backgroundColor = const Color(0xFF1A2E3F); // Default dark background
    _surfaceColor = const Color(0xFF2C3E50); // Default dark surface
    _gridColor = const Color(0xFF3E5366); // Default dark grid
  }

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

    final gridSize = _currentLevelData!.gridSize[0];

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
    final moduleProgress = ref.read(moduleProgressProvider);
    final moduleId = moduleProgress.currentModule;
    final levelInModule = moduleProgress.currentLevelInModule;

    debugPrint(
      'GardenGame: Attempting to load module $moduleId level $levelInModule',
    );
    debugPrint('GardenGame: Module progress: $moduleProgress');

    try {
      // Load level data from JSON in module structure
      final assetPath =
          'assets/levels/module_$moduleId/level_$levelInModule.json';
      debugPrint('GardenGame: Loading asset: $assetPath');

      final levelJson = await rootBundle.loadString(assetPath);
      debugPrint(
        'GardenGame: Successfully loaded JSON string, length: ${levelJson.length}',
      );

      final jsonMap = json.decode(levelJson);
      debugPrint('GardenGame: Successfully parsed JSON: $jsonMap');

      _currentLevelData = LevelData.fromJson(jsonMap);
      debugPrint(
        'GardenGame: Successfully created LevelData: ${_currentLevelData!.name}',
      );

      // Update providers
      ref.read(currentLevelProvider.notifier).setLevel(_currentLevelData);

      // Ensure gameCompleted is false if we found a level
      ref.read(gameCompletedProvider.notifier).setCompleted(false);

      // Reset tap counters for new level
      ref.read(levelTotalTapsProvider.notifier).reset();
      ref.read(levelWrongTapsProvider.notifier).reset();

      // Log level start analytics
      ref.read(analyticsServiceProvider).logLevelStart(_currentLevelData!.id);

      debugPrint(
        'Loaded module $moduleId level $levelInModule: ${_currentLevelData!.name}',
      );
    } catch (e, stackTrace) {
      debugPrint('Error loading module $moduleId level $levelInModule: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't set game completed on startup load failure - this might be due to asset loading issues
      // Only set completed when we actually finish all available levels
      debugPrint('GardenGame: Level loading failed, creating fallback level');

      // Create a fallback level programmatically
      _currentLevelData = _createFallbackLevel();
      debugPrint(
        'GardenGame: Created fallback level: ${_currentLevelData!.name}',
      );

      // Update providers with fallback level
      ref.read(currentLevelProvider.notifier).setLevel(_currentLevelData);
      ref.read(gameCompletedProvider.notifier).setCompleted(false);
      ref.read(levelTotalTapsProvider.notifier).reset();
      ref.read(levelWrongTapsProvider.notifier).reset();
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
      // Reset grace for the new level
      ref.read(gameInstanceProvider.notifier).resetGrace();

      await _setLevelDataOnGrid();
    }
  }

  LevelData _createFallbackLevel() {
    // Create a simple fallback level programmatically
    return LevelData(
      id: 999,
      moduleId: 1,
      name: 'Fallback Level',
      gridSize: [9, 9],
      difficulty: 'Seedling',
      vines: [
        VineData(
          id: 'fallback_vine',
          headDirection: 'right',
          orderedPath: [
            {'x': 4, 'y': 4}, // Head (moving right)
            {
              'x': 3,
              'y': 4,
            }, // First segment LEFT of head (x decreases, opposite direction)
          ],
          color: 'moss_green',
        ),
      ],
      maxMoves: 5,
      minMoves: 1,
      complexity: 'low',
      grace: 3,
    );
  }
}
