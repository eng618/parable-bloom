import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';

import '../../../../core/game_board_layout.dart';
import '../../../../features/game/domain/entities/level_data.dart';
import '../../../../core/providers/settings_providers.dart' show VineStyle;
import '../../../../core/services/logger_service.dart';
import '../../../tutorial/domain/entities/lesson_data.dart';
import '../../application/providers/camera_providers.dart' show CameraState;
import 'grid_component.dart';
import 'projection_lines_component.dart';
import 'tap_effect_component.dart';

class GardenGameCallbacks {
  final void Function(GardenGame game) onGameLoaded;
  final void Function() onGameRemoved;
  final void Function(String vineId) onVineCleared;
  final void Function(String vineId, VineAnimationState state)
      onVineAnimationStateChanged;
  final void Function(String vineId) onVineAttempted;
  final void Function(int count) onTapIncrement;
  final void Function() onTapOutsideGrid;

  // Settings/State Getters
  final bool Function() getUseSimpleVines;
  final bool Function() getHapticsEnabled;

  GardenGameCallbacks({
    required this.onGameLoaded,
    required this.onGameRemoved,
    required this.onVineCleared,
    required this.onVineAnimationStateChanged,
    required this.onVineAttempted,
    required this.onTapIncrement,
    required this.onTapOutsideGrid,
    required this.getUseSimpleVines,
    required this.getHapticsEnabled,
  });
}

class GardenGame extends FlameGame with TapCallbacks {
  static const double cellSize = GameBoardLayout.cellSize;

  late GridComponent grid;
  late ProjectionLinesComponent projectionLines;
  final GardenGameCallbacks callbacks;

  bool _isGridInitialized = false;
  bool get isGridInitialized => _isGridInitialized;
  LevelData? _currentLevelData;
  LessonData? _currentLessonData;
  SpriteComponent? _gameBackground;
  Sprite? _bgDaySprite;
  Sprite? _bgNightSprite;

  // Theme colors - updated dynamically from app theme
  late Color _backgroundColor;
  late Color _tapEffectColor;
  late Color _vineAttemptedColor;

  GardenGame({required this.callbacks}) {
    LoggerService.debug('Constructor called - creating new instance',
        tag: 'GardenGame');
    // Initialize with default theme colors - will be updated by game screen
    _backgroundColor = const Color(0xFF1A2E3F); // Default dark background
    _tapEffectColor = const Color(0xFFE6E1E5); // Default light for dark theme
    _vineAttemptedColor = const Color(0xFFFFFFFF);
  }

  /// Factory constructor for loading a lesson
  factory GardenGame.fromLesson(LessonData lessonData,
      {required GardenGameCallbacks callbacks}) {
    final game = GardenGame(callbacks: callbacks);
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
    LoggerService.debug(
      'updateThemeColors: bg=$backgroundColor, surface=$surfaceColor, grid=$gridColor, tap=$tapEffectColor, vineAttempted=$vineAttemptedColor',
      tag: 'GardenGame',
    );
    _backgroundColor = backgroundColor;
    if (tapEffectColor != null) {
      _tapEffectColor = tapEffectColor;
    }
    if (vineAttemptedColor != null) {
      _vineAttemptedColor = vineAttemptedColor;
    }

    _backgroundColor = backgroundColor;

    if (_gameBackground != null) {
      final isDark = _backgroundColor.computeLuminance() < 0.5;
      _gameBackground!.sprite = isDark ? _bgNightSprite : _bgDaySprite;
    }

    _updateBackgroundOpacity();
  }

  void _updateBackgroundOpacity([bool? isSimpleVines]) {
    if (_gameBackground != null) {
      final simple = isSimpleVines ?? useSimpleVines;
      if (simple) {
        _gameBackground!.setOpacity(0.0);
      } else {
        _gameBackground!.setOpacity(1.0); // Full opacity for new assets
      }
    }
  }

  void _updateBackgroundSize() {
    if (_gameBackground != null && _gameBackground!.sprite != null) {
      final spriteSize = _gameBackground!.sprite!.srcSize;

      // Scale to match window height exactly
      final scale = size.y / spriteSize.y;

      _gameBackground!.size = spriteSize * scale;
      _gameBackground!.position = Vector2(
        (size.x - _gameBackground!.size.x) / 2,
        0, // Align to top
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

  /// Expose whether simple vines are enabled
  bool get useSimpleVines => callbacks.getUseSimpleVines();

  @override
  Future<void> onLoad() async {
    LoggerService.debug('onLoad called', tag: 'GardenGame');
    images.prefix = 'assets/art/';
    await super.onLoad();

    // Load parable background artwork
    try {
      _bgDaySprite = await loadSprite('bg_day_new.png');
      _bgNightSprite = await loadSprite('bg_night_new.png');

      final isDark = _backgroundColor.computeLuminance() < 0.5;

      _gameBackground = SpriteComponent(
        sprite: isDark ? _bgNightSprite : _bgDaySprite,
        priority: -2,
      );
      add(_gameBackground!);
      _updateBackgroundSize();
      _updateBackgroundOpacity();
    } catch (e, stack) {
      LoggerService.error('Failed to load background sprite',
          error: e, stackTrace: stack, tag: 'GardenGame');
    }

    // Create grid and background components
    _createLevelComponents();

    // Center camera
    camera.viewport.size = size;

    // Trigger game loaded callback to let the Flutter layer initialize the level
    callbacks.onGameLoaded(this);
  }

  void applyCameraTransform(CameraState cameraState) {
    // Apply zoom and pan to grid
    if (_isGridInitialized && grid.isMounted) {
      grid.applyCameraTransform(
        zoom: cameraState.zoom,
        panOffset: Vector2(cameraState.panOffset.x, cameraState.panOffset.y),
        screenWidth: size.x,
        screenHeight: size.y,
      );
    }

    // Apply to projection lines
    if (_isGridInitialized && projectionLines.isMounted) {
      projectionLines.applyCameraTransform(
        zoom: cameraState.zoom,
        panOffset: Vector2(cameraState.panOffset.x, cameraState.panOffset.y),
        screenWidth: size.x,
        screenHeight: size.y,
      );
    }
  }

  void updateProjectionLinesVisibility({
    required bool visible,
    required Set<String> hintedVines,
    required bool isAnimating,
  }) {
    if (_isGridInitialized && projectionLines.isMounted) {
      projectionLines
          .setVisible((visible || hintedVines.isNotEmpty) && !isAnimating);
    }
  }

  void _createLevelComponents() {
    // Interactive grid
    grid = GridComponent(
      cellSize: cellSize,
      onVineCleared: callbacks.onVineCleared,
      onVineTap: (vineId) {
        // Called when user taps a vine (after checking if it's valid)
      },
      onVineAnimationStateChanged: callbacks.onVineAnimationStateChanged,
      onVineAttempted: callbacks.onVineAttempted,
      onTapIncrement: callbacks.onTapIncrement,
      onTapEffect: (position) {
        final tapEffect = TapEffectComponent(
          tapPosition: position,
          color: _tapEffectColor,
          maxRadius: 30.0,
          duration: 0.4,
        );
        grid.add(tapEffect);
      },
    );
    add(grid);

    // Projection lines component (rendered above grid)
    projectionLines = ProjectionLinesComponent(cellSize: cellSize);
    add(projectionLines);

    _isGridInitialized = true;
  }

  /// Start or load a level with the given level data and current states
  void startLevel(LevelData levelData, Map<String, VineState> vineStates) {
    _currentLevelData = levelData;

    // Set level data on grid
    grid.setLevelData(levelData, vineStates);

    // Set level data on projection lines
    projectionLines.setLevelData(levelData);

    _updateBackgroundSize();
    _updateBackgroundOpacity();
  }

  /// Start or load a lesson with the given lesson data
  void startLesson(LessonData lesson) {
    _currentLessonData = lesson;
    final levelData = _convertLessonToLevelData(lesson);

    // For lessons, vine states start fresh (all uncompleted)
    final Map<String, VineState> vineStates = {};
    for (final vine in levelData.vines) {
      vineStates[vine.id] = VineState(
        isCompleted: false,
        animationState: VineAnimationState.idle,
        isAttempted: false,
      );
    }

    startLevel(levelData, vineStates);
  }

  /// Converts lesson data to level data for rendering
  LevelData _convertLessonToLevelData(LessonData lesson) {
    final vines = lesson.vines.map((lessonVine) {
      return VineData(
        id: lessonVine.id,
        headDirection: lessonVine.headDirection,
        orderedPath: lessonVine.orderedPath,
      );
    }).toList();

    return LevelData(
      id: lesson.id.toString(),
      name: 'Lesson ${lesson.id}',
      difficulty: 'tutorial',
      gridWidth: lesson.gridWidth,
      gridHeight: lesson.gridHeight,
      vines: vines,
      maxMoves: 999,
      minMoves: 0,
      complexity: 'tutorial',
      grace: 3,
      mask: MaskData(mode: 'show-all', points: []),
    );
  }

  /// Update vine states dynamically when they change in the app state
  void updateVineStates(Map<String, VineState> vineStates) {
    if (_currentLevelData != null && _isGridInitialized) {
      grid.setLevelData(_currentLevelData!, vineStates);
      if (projectionLines.isMounted) {
        projectionLines.update(0);
      }
    }
  }

  /// Update simple vines setting dynamically
  void updateSimpleVines(bool useSimple) {
    _updateBackgroundOpacity(useSimple);
  }

  @override
  Color backgroundColor() => _backgroundColor;

  /// Converts a grid coordinate (x, y) to global screenspace position.
  /// y=0 is at the bottom of the grid.
  Offset getCellScreenPosition(int x, int y) {
    if (_currentLevelData == null || !_isGridInitialized || !grid.isMounted) {
      return Offset.zero;
    }
    final rows = _currentLevelData!.gridHeight;
    final visualRow = rows - 1 - y;
    final localX = GameBoardLayout.cellCenterX(x);
    final localY = GameBoardLayout.cellCenterY(visualRow);

    final zoom = grid.scale.x;
    final gridPos = grid.position;

    return Offset(
      gridPos.x + (localX * zoom),
      gridPos.y + (localY * zoom),
    );
  }

  @override
  void onRemove() {
    callbacks.onGameRemoved();
    super.onRemove();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);

    // Trigger haptic feedback on tap if enabled
    if (callbacks.getHapticsEnabled()) {
      HapticFeedback.lightImpact();
    }

    final tapPos = event.canvasPosition;

    // Check if tap is outside the grid bounds
    final gridBounds = grid.toRect();
    final isOutsideGrid = !gridBounds.contains(tapPos.toOffset());

    if (isOutsideGrid) {
      callbacks.onTapOutsideGrid();

      // Create tap effect at canvas position
      final tapEffect = TapEffectComponent(
        tapPosition: tapPos,
        color: _tapEffectColor,
        maxRadius: 30.0,
        duration: 0.4,
      );
      add(tapEffect);
    }
  }
}
