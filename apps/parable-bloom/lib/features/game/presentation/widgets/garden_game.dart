import 'dart:convert';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/game_providers.dart';
import '../../../tutorial/domain/entities/lesson_data.dart';
import 'grid_component.dart';
import 'projection_lines_component.dart';
import 'tap_effect_component.dart';

class GardenGame extends FlameGame with TapCallbacks {
  static const double cellSize = 36.0; // Pixels per cell

  late GridComponent grid;
  late ProjectionLinesComponent projectionLines;
  final WidgetRef ref;
  LevelData? _currentLevelData;
  LessonData? _currentLessonData;
  SpriteComponent? _gameBackground;
  Sprite? _bgDaySprite;
  Sprite? _bgNightSprite;

  // Theme colors - updated dynamically from app theme
  late Color _backgroundColor;
  late Color _surfaceColor;
  late Color _tapEffectColor;
  late Color _vineAttemptedColor;

  GardenGame({required this.ref}) {
    debugPrint('GardenGame: Constructor called - creating new instance');
    // Initialize with default theme colors - will be updated by game screen
    _backgroundColor = const Color(0xFF1A2E3F); // Default dark background
    _surfaceColor = const Color(0xFF2C3E50); // Default dark surface
    _tapEffectColor = const Color(0xFFE6E1E5); // Default light for dark theme
    _vineAttemptedColor = const Color(0xFFFFFFFF);
  }

  /// Factory constructor for loading a lesson
  factory GardenGame.fromLesson(LessonData lessonData,
      {required WidgetRef ref}) {
    final game = GardenGame(ref: ref);
    game._currentLessonData = lessonData;
    return game;
  }

  /// Get the current lesson ID (null if not a lesson)
  int? get currentLessonId => _currentLessonData?.id;

  void updateThemeColors(
    Color backgroundColor,
    Color surfaceColor,
    Color gridColor, {
    Color? tapEffectColor,
    Color? vineAttemptedColor,
  }) {
    debugPrint(
      'GardenGame.updateThemeColors: bg=$backgroundColor, surface=$surfaceColor, grid=$gridColor, tap=$tapEffectColor, vineAttempted=$vineAttemptedColor',
    );
    _backgroundColor = backgroundColor;
    _surfaceColor = surfaceColor;
    if (tapEffectColor != null) {
      _tapEffectColor = tapEffectColor;
    }
    if (vineAttemptedColor != null) {
      _vineAttemptedColor = vineAttemptedColor;
    }
    // gridColor parameter kept for API compatibility but not currently used

    // Update existing components if they exist - must replace the Paint to trigger redraw
    // Update background color
    _backgroundColor = backgroundColor;
    _surfaceColor = surfaceColor;

    if (_gameBackground != null) {
      final isDark = _backgroundColor.computeLuminance() < 0.5;
      _gameBackground!.sprite = isDark ? _bgNightSprite : _bgDaySprite;
    }

    // We no longer tint the _gameBackground sprite with a solid color
    // as it should show the actual artwork.
  }

  void _updateBackgroundSize() {
    if (_gameBackground != null && _gameBackground!.sprite != null) {
      final spriteSize = _gameBackground!.sprite!.srcSize;
      final scaleX = size.x / spriteSize.x;
      final scaleY = size.y / spriteSize.y;
      final scale = math.max(scaleX, scaleY);
      
      _gameBackground!.size = spriteSize * scale;
      _gameBackground!.position = Vector2(
        (size.x - _gameBackground!.size.x) / 2,
        (size.y - _gameBackground!.size.y) / 2,
      );
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _updateBackgroundSize();
  }

  /// Expose current vine-attempted color for renderers (VineComponent)
  Color get vineAttemptedColor => _vineAttemptedColor;

  @override
  Future<void> onLoad() async {
    debugPrint('GardenGame: onLoad called');
    images.prefix = 'assets/art/';
    await super.onLoad();

    // Reset grace for new level
    ref.read(gameInstanceProvider.notifier).resetGrace();

    // Load current level first
    await _loadCurrentLevel();

    // Load parable background artwork
    try {
      _bgDaySprite = await loadSprite('bg_day.png');
      _bgNightSprite = await loadSprite('bg_night.png');
      
      final isDark = _backgroundColor.computeLuminance() < 0.5;

      _gameBackground = SpriteComponent(
        sprite: isDark ? _bgNightSprite : _bgDaySprite,
        priority: -2,
      );
      add(_gameBackground!);
      _updateBackgroundSize();
    } catch (e) {
      debugPrint('GardenGame: Failed to load background sprite: $e');
      // Continue without background or use a fallback color
    }

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
        // Force projection lines to redraw when vine states change
        projectionLines.update(0);
      }
    });

    // Listen to projection lines visibility and animation state
    ref.listenManual(projectionLinesVisibleProvider, (previous, next) {
      _updateProjectionLinesVisibility();
    });

    ref.listenManual(anyVineAnimatingProvider, (previous, next) {
      _updateProjectionLinesVisibility();
    });

    // Listen to camera state changes and apply transforms
    ref.listenManual(cameraStateProvider, (previous, next) {
      _applyCameraTransform(next);
    });

    // Initialize camera state for the current level
    _initializeCameraForLevel();

    // Center camera
    camera.viewport.size = size;
  }

  void _initializeCameraForLevel() {
    if (_currentLevelData == null) return;

    final cameraNotifier = ref.read(cameraStateProvider.notifier);

    // Update zoom bounds based on screen and grid size
    cameraNotifier.updateZoomBounds(
      screenWidth: size.x,
      screenHeight: size.y,
      gridCols: _currentLevelData!.gridWidth,
      gridRows: _currentLevelData!.gridHeight,
      cellSize: cellSize,
    );

    // Start animation from full-board view to 1.0x
    cameraNotifier.animateToDefaultZoom(
      screenWidth: size.x,
      screenHeight: size.y,
      gridCols: _currentLevelData!.gridWidth,
      gridRows: _currentLevelData!.gridHeight,
      cellSize: cellSize,
    );
  }

  void _applyCameraTransform(CameraState cameraState) {
    // Apply zoom and pan to grid
    if (grid.isMounted) {
      grid.applyCameraTransform(
        zoom: cameraState.zoom,
        panOffset: Vector2(cameraState.panOffset.x, cameraState.panOffset.y),
        screenWidth: size.x,
        screenHeight: size.y,
      );
    }

    // Apply to projection lines
    if (projectionLines.isMounted) {
      projectionLines.applyCameraTransform(
        zoom: cameraState.zoom,
        panOffset: Vector2(cameraState.panOffset.x, cameraState.panOffset.y),
        screenWidth: size.x,
        screenHeight: size.y,
      );
    }
  }

  void _updateProjectionLinesVisibility() {
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

  void _createLevelComponents() {
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
      onTapEffect: (position) {
        // Create and add tap effect at the tapped position
        final tapEffect = TapEffectComponent(
          tapPosition: position,
          color: _tapEffectColor,
          maxRadius: 15.0, // Reduced to prevent large effects
          duration: 0.4,
        );
        grid.add(tapEffect);
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

  Future<void> _loadCurrentLevel() async {
    // If this is a lesson, use the pre-loaded lesson data
    if (_currentLessonData != null) {
      debugPrint('GardenGame: Loading lesson ${_currentLessonData!.id}');
      _convertLessonToLevelData(_currentLessonData!);
      return;
    }

    final debugSelected = ref.read(debugSelectedLevelProvider);
    final gameProgress = ref.read(gameProgressProvider);
    final levelNumber = debugSelected ?? gameProgress.currentLevel;

    if (debugSelected != null) {
      debugPrint(
          'GardenGame: Debug selected level $debugSelected — loading temporarily without changing saved progress');
    }

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

      // Log level start analytics (skip for debug play sessions)
      if (!ref.read(debugPlayModeProvider)) {
        ref.read(analyticsServiceProvider).logLevelStart(_currentLevelData!.id);
      }

      debugPrint('Loaded level $levelNumber: ${_currentLevelData!.name}');
    } catch (e, stackTrace) {
      debugPrint('Error loading level $levelNumber: $e');
      debugPrint('Stack trace: $stackTrace');

      // Determine if this error indicates all levels are completed
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
            'GardenGame: All levels completed! Setting game as completed.');
        ref.read(gameCompletedProvider.notifier).setCompleted(true);
      } else {
        // Level should exist but failed to load - critical error
        debugPrint(
          'GardenGame: CRITICAL ERROR - Level $levelNumber should exist but failed to load!',
        );
        ref.read(gameOverProvider.notifier).setGameOver(true);
      }
      return;
    }
  }

  /// Converts lesson data to level data for rendering
  void _convertLessonToLevelData(LessonData lesson) {
    // Convert lesson vines to level vines
    final vines = lesson.vines.map((lessonVine) {
      return VineData(
        id: lessonVine.id,
        headDirection: lessonVine.headDirection,
        orderedPath: lessonVine.orderedPath,
      );
    }).toList();

    // Create level data from lesson
    _currentLevelData = LevelData(
      id: lesson.id,
      name: 'Lesson ${lesson.id}',
      difficulty: 'tutorial',
      gridWidth: lesson.gridWidth,
      gridHeight: lesson.gridHeight,
      vines: vines,
      maxMoves: 999, // Unlimited moves for lessons
      minMoves: 0,
      complexity: 'tutorial',
      grace: 3, // Use standard grace for tutorial so GameHeader displays hearts
      mask: MaskData(mode: 'show-all', points: []),
    );

    // Update providers
    ref.read(currentLevelProvider.notifier).setLevel(_currentLevelData);
    ref.read(gameCompletedProvider.notifier).setCompleted(false);
    ref.read(levelTotalTapsProvider.notifier).reset();
    ref.read(levelWrongTapsProvider.notifier).reset();
    ref.read(levelCompleteProvider.notifier).setComplete(false);

    debugPrint('Converted lesson ${lesson.id} to level data');
  }

  Future<void> _setLevelDataOnGrid() async {
    if (_currentLevelData == null) return;

    // Reset vine states for this level to ensure completion detection works
    ref.read(vineStatesProvider.notifier).resetForLevel(_currentLevelData!);

    // Get current vine states from the provider after reset
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

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);

    // Trigger haptic feedback on tap if enabled
    final hapticsEnabled = ref.watch(hapticsEnabledProvider);
    if (hapticsEnabled) {
      HapticFeedback.lightImpact();
    }

    // Handle taps outside the grid (for play area but not on grid cells)
    // Grid and cells handle their own taps, so this only catches taps in empty space
    final tapPos = event.canvasPosition;

    // Check if tap is outside the grid bounds
    final gridBounds = grid.toRect();
    final isOutsideGrid = !gridBounds.contains(tapPos.toOffset());

    if (isOutsideGrid) {
      // Create tap effect at canvas position
      final tapEffect = TapEffectComponent(
        tapPosition: tapPos,
        color: _tapEffectColor,
        maxRadius: 15.0, // Reduced to prevent large effects
        duration: 0.4,
      );
      add(tapEffect);
    }
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

    await _loadCurrentLevel();

    if (_currentLevelData != null) {
      _createLevelComponents();

      // Reset vine states for the new level
      ref.read(vineStatesProvider.notifier).resetForLevel(_currentLevelData!);
      // Reset grace for the new level
      ref.read(gameInstanceProvider.notifier).resetGrace();

      await _setLevelDataOnGrid();

      // Reset projection lines visibility
      ref.read(projectionLinesVisibleProvider.notifier).setVisible(false);

      // Re-initialize camera for the new level
      _initializeCameraForLevel();
    }
  }
}
