import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/game_providers.dart';
import 'grid_component.dart';
import 'projection_lines_component.dart';
import 'pulse_effect_component.dart';

class GardenGame extends FlameGame with TapCallbacks {
  static const double cellSize = 36.0; // Pixels per cell

  late GridComponent grid;
  late ProjectionLinesComponent projectionLines;
  final WidgetRef ref;
  LevelData? _currentLevelData;
  RectangleComponent? _gameBackground;

  // Theme colors - updated dynamically from app theme
  late Color _surfaceColor;

  GardenGame({required this.ref}) {
    debugPrint('GardenGame: Constructor called - creating new instance');
    // Initialize with default theme colors - will be updated by game screen
    _surfaceColor = const Color(0xFF2C3E50); // Default dark surface
  }

  void updateThemeColors(
    Color backgroundColor,
    Color surfaceColor,
    Color gridColor,
  ) {
    debugPrint(
      'GardenGame.updateThemeColors: bg=$backgroundColor, surface=$surfaceColor, grid=$gridColor',
    );
    _surfaceColor = surfaceColor;
    // gridColor parameter and backgroundColor kept for API compatibility but not currently used

    // Update existing components if they exist - must replace the Paint to trigger redraw
    if (_gameBackground != null) {
      debugPrint('GardenGame: Updating _gameBackground to $_surfaceColor');
      _gameBackground!.paint = Paint()..color = _surfaceColor;
    }
  }

  @override
  Future<void> onLoad() async {
    debugPrint('GardenGame: onLoad called');
    await super.onLoad();

    // Reset grace for new level
    ref.read(gameInstanceProvider.notifier).resetGrace();

    // Load current level first
    await loadCurrentLevel();

    // TODO: Replace with actual parable background image
    // Load parable background
    _gameBackground = RectangleComponent(
      size: size,
      paint: Paint()..color = _surfaceColor,
      priority: -2,
    );
    add(_gameBackground!);

    // Create grid and background components
    createLevelComponents();

    // Set level data on grid after it's created
    if (_currentLevelData != null) {
      await setLevelDataOnGrid();
    }

    // Listen to vine state changes (blocking/clearing updates)
    ref.listenManual(vineStatesProvider, (previous, next) {
      if (_currentLevelData != null) {
        grid.setLevelData(_currentLevelData!, next);
        // Force projection lines to redraw when vine states change
        projectionLines.update(0);
      }
    });

    // Listen to projection lines visibility and animation state
    ref.listenManual(projectionLinesVisibleProvider, (previous, next) {
      updateProjectionLinesVisibility();
    });

    ref.listenManual(anyVineAnimatingProvider, (previous, next) {
      updateProjectionLinesVisibility();
    });

    // Center camera
    camera.viewport.size = size;
  }

  void updateProjectionLinesVisibility() {
    final shouldShow = ref.read(projectionLinesVisibleProvider);
    final isAnimating = ref.read(anyVineAnimatingProvider);

    // When animation starts, turn off projection lines visibility
    // so they don't reappear when animation ends
    if (isAnimating && shouldShow) {
      ref.read(projectionLinesVisibleProvider.notifier).setVisible(false);
    }

    // Hide projection lines when any vine is animating
    projectionLines.setVisible(shouldShow && !isAnimating);
  }

  void createLevelComponents() {
    if (_currentLevelData == null) return;

    // Interactive grid
    grid = GridComponent(
      cellSize: cellSize,
      onVineCleared: (vineId) {
        // Update the Riverpod provider when a vine is cleared
        ref.read(vineStatesProvider.notifier).clearVine(vineId);
      },
      onVineTap: (vineId) {
        // Called when user taps a vine (after checking if it's valid)
        // No additional action needed here, component handles sliding animation
      },
      onVineAnimationStateChanged: (vineId, animationState) {
        // Update animation state in provider
        ref
            .read(vineStatesProvider.notifier)
            .setAnimationState(vineId, animationState);
      },
      onVineAttempted: (vineId) {
        // Mark vine as attempted in provider
        ref.read(vineStatesProvider.notifier).markAttempted(vineId);
      },
      onTapIncrement: (count) {
        // Increment tap counter
        for (int i = 0; i < count; i++) {
          ref.read(levelTotalTapsProvider.notifier).increment();
        }
      },
    );
    add(grid);

    // Projection lines component (rendered above grid)
    projectionLines = ProjectionLinesComponent(cellSize: cellSize);
    add(projectionLines);

    // Set initial level data on projection lines
    if (_currentLevelData != null) {
      projectionLines.setLevelData(_currentLevelData!);
    }
  }

  Future<void> loadCurrentLevel() async {
    final gameProgress = ref.read(gameProgressProvider);
    final levelNumber = gameProgress.currentLevel;

    debugPrint(
      'GardenGame: Attempting to load level $levelNumber',
    );
    debugPrint('GardenGame: Game progress: $gameProgress');

    try {
      // Load level data directly by level number
      final assetPath = 'assets/levels/level_$levelNumber.json';
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

      debugPrint('Loaded level $levelNumber: ${_currentLevelData!.name}');
    } catch (e, stackTrace) {
      debugPrint('Error loading level $levelNumber: $e');
      debugPrint('Stack trace: $stackTrace');

      // Check if this is because we've completed all levels
      final modulesAsync = ref.read(modulesProvider);
      final modules = modulesAsync.maybeWhen(
        data: (data) => data,
        orElse: () => <ModuleData>[],
      );

      final totalLevels = modules.fold<int>(
        0,
        (maxEnd, module) => module.endLevel > maxEnd ? module.endLevel : maxEnd,
      );

      debugPrint(
        'GardenGame: Level $levelNumber failed to load. Total levels: $totalLevels',
      );

      if (levelNumber > totalLevels) {
        debugPrint(
          'GardenGame: All levels completed! Setting game as completed.',
        );
        ref.read(gameCompletedProvider.notifier).setCompleted(true);
      } else {
        // Level should exist but failed to load - this is an error
        debugPrint(
          'GardenGame: CRITICAL ERROR - Level $levelNumber should exist but failed to load!',
        );
        debugPrint(
          'GardenGame: Expected asset path: assets/levels/level_$levelNumber.json',
        );
        ref.read(gameOverProvider.notifier).setGameOver(true);
      }
      return;
    }
  }

  Future<void> setLevelDataOnGrid() async {
    if (_currentLevelData == null) return;

    // Get current vine states from the provider
    final vineStates = ref.read(vineStatesProvider);

    // Set data on grid
    grid.setLevelData(_currentLevelData!, vineStates);
  }

  @override
  void onRemove() {
    // No need to dispose ref or container
    super.onRemove();
  }

  // Method to reload the current level (called when progress is reset or level completed)
  Future<void> reloadLevel() async {
    // Check if grid is initialized and mounted before removing
    try {
      if (grid.isMounted) remove(grid);
      if (projectionLines.isMounted) remove(projectionLines);
    } catch (e) {
      // Ignore if grid/projectionLines weren't initialized
    }

    await loadCurrentLevel();

    if (_currentLevelData != null) {
      createLevelComponents();

      // Reset vine states for the new level
      ref.read(vineStatesProvider.notifier).resetForLevel(_currentLevelData!);
      // Reset grace for the new level
      ref.read(gameInstanceProvider.notifier).resetGrace();

      await setLevelDataOnGrid();

      // Reset projection lines visibility
      ref.read(projectionLinesVisibleProvider.notifier).setVisible(false);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);

    // Create pulse effect at tap position
    // Use a theme-aware color with higher visibility
    final pulseColor = _surfaceColor.computeLuminance() > 0.5
        ? Colors.black
            .withValues(alpha: 0.6) // Darker pulse on light background
        : Colors.white
            .withValues(alpha: 0.7); // Lighter pulse on dark background

    final pulseEffect = PulseEffectComponent(
      position: event.localPosition,
      color: pulseColor,
    );

    // Add to world so it appears above everything
    add(pulseEffect);
  }
}
