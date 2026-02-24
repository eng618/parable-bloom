import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:flame/sprite.dart';

import '../../../../core/vine_color_palette.dart';
import '../../../../providers/game_providers.dart';
import 'garden_game.dart';
import 'grid_component.dart';

class VineComponent extends PositionComponent with ParentIsA<GridComponent> {
  final VineData vineData;
  final double cellSize;

  static SpriteSheet? _classicSpriteSheet;
  static SpriteSheet? _trellisSpriteSheet;

  bool _isAnimating = false;
  bool _willClearAfterAnimation =
      false; // Whether this vine should be cleared when animation completes

  // Track current visual positions during animation (separate from vineData.path)
  List<Map<String, int>> _currentVisualPositions = [];

  // Animation state
  int _currentAnimationStep = 0;
  int _totalAnimationSteps = 0;
  double _animationTimer = 0.0;
  double _stepDuration =
      0.05; // seconds per step - smoother animation with slightly slower pace

  // History-based animation (snake-like movement)
  List<List<Map<String, int>>> _positionHistory = [];
  bool _isBlockedAnimation = false;

  // Bloom effect after clearing
  bool _isShowingBloomEffect = false;
  double _bloomEffectTimer = 0.0;
  final double _bloomEffectDuration =
      0.5; // seconds - reduced for faster level completion
  Offset? _bloomEffectPosition; // Where to show the bloom effect

  // Track if we've already notified parent of clearing
  final bool _alreadyNotifiedCleared = false;


  VineComponent({required this.vineData, required this.cellSize}) {
    // Initialize visual positions directly from vine data (pure x,y coordinates)
    _currentVisualPositions = List<Map<String, int>>.from(
      vineData.orderedPath.map((cell) => Map<String, int>.from(cell)),
    );
  }

  @override
  Future<void> onLoad() async {
    // Initial position is zero within GridComponent coordinate space
    position = Vector2.zero();
    size = parent.size;

    final game = parent.parent as GardenGame;
    if (_classicSpriteSheet == null) {
      final image = await game.images.load('vine_spritesheet.png');
      _classicSpriteSheet = SpriteSheet(
        image: image,
        srcSize: Vector2(128, 128),
      );
    }

    if (_trellisSpriteSheet == null) {
      try {
        final image = await game.images.load('trellis_vines_spritesheet.png');
        _trellisSpriteSheet = SpriteSheet(
          image: image,
          srcSize: Vector2(128, 128),
        );
      } catch (e) {
        debugPrint('Failed to load trellis_vines_spritesheet.png: $e. Falling back to classic.');
        _trellisSpriteSheet = _classicSpriteSheet;
      }
    }

    // Visual positions are already initialized in constructor
    // This is just for logging

    debugPrint('VineComponent loaded for vine ${vineData.id}');
    debugPrint(
      'Vine ordered path: ${vineData.orderedPath.map((p) => "(${p['x']},${p['y']})").join(' -> ')}',
    );
    debugPrint('Head direction: ${vineData.headDirection}');
    debugPrint('Calculated direction: ${_calculateVineDirection()}');
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final vineState = parent.getCurrentVineState(vineData.id);
    if (vineState == null) return;

    final level = parent.getCurrentLevelData();
    if (level == null) return;

    final isBlocked = vineState.isBlocked;
    final isAttempted = vineState.hasBeenAttempted;

    final seedColor = VineColorPalette.resolve(vineData.vineColor);
    final calmColor = _deriveCalmVariant(seedColor, vineData.id);
    final baseColor = VineComponent.computeRenderColor(
      calmColor,
      isAttempted,
      (parent.parent).vineAttemptedColor,
    );

    final useWithered = isBlocked && isAttempted;
    final visualHeight = level.gridHeight;

    for (int i = 0; i < _currentVisualPositions.length; i++) {
      final cell = _currentVisualPositions[i];
      final x = cell['x'] as int;
      final y = cell['y'] as int;

      final visualY = visualHeight - 1 - y;

      final center = Offset(
        x * cellSize + cellSize / 2,
        visualY * cellSize + cellSize / 2,
      );

      _drawSegmentSprite(canvas, i, center, baseColor, useWithered);
    }

    if (_isShowingBloomEffect && _bloomEffectPosition != null) {
      _drawBloomEffect(canvas);
    }
  }

  void _drawSegmentSprite(
    Canvas canvas,
    int index,
    Offset center,
    Color tintColor,
    bool isWithered,
  ) {
    if (_currentVisualPositions.isEmpty) return;

    final isHead = index == 0;
    final isTail = index == _currentVisualPositions.length - 1;

    final game = parent.parent as GardenGame;
    final useSimpleVines = game.useSimpleVines;
    final row = isWithered ? 1 : 0;
    int col = 0;
    double rotation = 0;

    // Give priority to trellis spritesheet's pre-rotated columns
    if (isHead) {
      final String dir = _calculateVineDirection() ?? 'up';
      switch (dir) {
        case 'up':
          rotation = 0;
          col = 0;
          break;
        case 'down':
          if (useSimpleVines) {
            rotation = math.pi;
            col = 0; // Classic usually just has one head rotated? No, let's check.
          } else {
            rotation = 0;
            col = 1;
          }
          break;
        case 'left':
          if (useSimpleVines) {
            rotation = -math.pi / 2;
            col = 0;
          } else {
            rotation = 0;
            col = 2;
          }
          break;
        case 'right':
          if (useSimpleVines) {
            rotation = math.pi / 2;
            col = 0;
          } else {
            rotation = 0;
            col = 3;
          }
          break;
      }
    } else if (isTail && index > 0) {
      col = 6;
      final prev = _currentVisualPositions[index - 1];
      final curr = _currentVisualPositions[index];
      final dx = curr['x']! - prev['x']!;
      final dy = curr['y']! - prev['y']!; // Grid coordinates (dy > 0 is down)

      if (dx > 0) {
        rotation = math.pi / 2;
      } else if (dx < 0) {
        rotation = -math.pi / 2;
      } else if (dy > 0) {
        rotation = math.pi; // Tail moving DOWN (so tail is at bottom)
      } else if (dy < 0) {
        rotation = 0; // Tail moving UP
      }
    } else {
      // Body segment (straight or corner)
      final prev = _currentVisualPositions[index - 1];
      final curr = _currentVisualPositions[index];
      final next = _currentVisualPositions[index + 1];

      final dx1 = curr['x']! - prev['x']!;
      final dy1 = curr['y']! - prev['y']!;
      final dx2 = next['x']! - curr['x']!;
      final dy2 = next['y']! - curr['y']!;

      if (dx1 == dx2 && dy1 == dy2) {
        // Straight component
        col = 4;
        if (dx1 != 0) {
          rotation = math.pi / 2;
        } else {
          rotation = 0;
        }
      } else {
        // Corner component
        col = 5;
        final hasUp = (dy1 < 0 || dy2 < 0);
        final hasDown = (dy1 > 0 || dy2 > 0);
        final hasLeft = (dx1 < 0 || dx2 < 0);
        final hasRight = (dx1 > 0 || dx2 > 0);

        if (hasUp && hasRight) {
          rotation = 0;
        } else if (hasRight && hasDown) {
          rotation = math.pi / 2;
        } else if (hasDown && hasLeft) {
          rotation = math.pi;
        } else if (hasLeft && hasUp) {
          rotation = -math.pi / 2;
        }
      }
    }

    final spriteSheet = useSimpleVines ? _classicSpriteSheet : _trellisSpriteSheet;
    if (spriteSheet == null) return; // Check after selecting which sheet to use
    final sprite = spriteSheet.getSprite(row, col);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Apply color tint ONLY to classic vine sprites
    final paint = useSimpleVines
        ? (Paint()..colorFilter = ColorFilter.mode(tintColor, BlendMode.modulate))
        : Paint();

    // Provide scaled size to fill cell
    // Depending on the tile margin, might need scale factor
    final scaleFactor = 1.0; 
    sprite.render(
      canvas,
      size: Vector2(cellSize * scaleFactor, cellSize * scaleFactor),
      position: Vector2(-cellSize * scaleFactor / 2, -cellSize * scaleFactor / 2),
      overridePaint: paint,
    );

    canvas.restore();
  }

  String? _calculateVineDirection() {
    // Direction comes directly from the level data, not calculated from positions
    return vineData.headDirection;
  }

  void slideOut() {
    if (_isAnimating) return;
    _isAnimating = true;

    // Initialize history-based animation
    _positionHistory = [];
    _currentAnimationStep = 0;
    _isBlockedAnimation = false;
    _animationTimer = 0.0;

    final rawDistance = _calculateMovementDistance();
    final canClear = rawDistance > 0;
    // For blocked vines, rawDistance is negative, abs() gives distance to blocker
    // We animate TO the blocker (not past it), so use the full distance
    final distanceToBlocker = rawDistance.abs();
    final maxForwardSteps = distanceToBlocker;

    if (canClear) {
      // Vine can reach edge - calculate steps needed to exit completely off-screen
      // Add extra steps to ensure vine moves well beyond the visible area
      const int extraOffScreenSteps = 6; // Ensure vine is far off-screen
      _totalAnimationSteps =
          maxForwardSteps + vineData.orderedPath.length + extraOffScreenSteps;
      _willClearAfterAnimation = true;

      // Set animation state to animatingClear - this removes it from blocking calculations
      // but allows the animation to continue and complete properly
      parent.setVineAnimationState(
        vineData.id,
        VineAnimationState.animatingClear,
      );

      _logDebug(
        'Starting CLEAR animation: vineId=${vineData.id}, '
        'maxForwardSteps=$maxForwardSteps, totalSteps=$_totalAnimationSteps, '
        'headPos=(${_currentVisualPositions[0]['x']},${_currentVisualPositions[0]['y']}), '
        'direction=${vineData.headDirection}',
      );
    } else {
      // Vine is blocked - move forward to the blocking cell, then reverse
      _totalAnimationSteps = maxForwardSteps * 2;
      _willClearAfterAnimation = false;

      // Set animation state to animatingBlocked
      parent.setVineAnimationState(
        vineData.id,
        VineAnimationState.animatingBlocked,
      );

      _logDebug(
        'Starting BLOCKED animation: vineId=${vineData.id}, '
        'maxForwardSteps=$maxForwardSteps (to blocker cell), totalSteps=$_totalAnimationSteps, '
        'headPos=(${_currentVisualPositions[0]['x']},${_currentVisualPositions[0]['y']}), '
        'direction=${vineData.headDirection}',
      );
    }
  }

  // Update zoom level for rendering adjustments
  void updateZoom(double zoom) {
    // Zoom updates are handled via parent scale transform
    // This method kept for API compatibility
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!_isAnimating) return;

    _animationTimer += dt;

    if (_animationTimer >= _stepDuration) {
      _animationTimer = 0.0;

      if (_isBlockedAnimation) {
        // Animate backwards through history
        final historyIndex =
            _positionHistory.length - 1 - _currentAnimationStep;
        if (historyIndex >= 0) {
          // Set vine positions to historical state
          _currentVisualPositions = List<Map<String, int>>.from(
            _positionHistory[historyIndex].map(
              (pos) => Map<String, int>.from(pos),
            ),
          );
        }

        _currentAnimationStep++;

        if (_currentAnimationStep >= _positionHistory.length) {
          // Finished reverse animation - return to normal state
          _positionHistory.clear();
          _isAnimating = false;
          _isBlockedAnimation = false;

          // Reset animation state to normal
          parent.setVineAnimationState(vineData.id, VineAnimationState.normal);
        }
        return;
      }

      // Normal forward movement (history-based snake animation)
      final rawDistance = _calculateMovementDistance();
      final canClear = rawDistance > 0;
      final maxForwardDistance = rawDistance.abs();

      if (_currentAnimationStep < maxForwardDistance) {
        // Check if we've reached the blocker position for a blocked vine
        if (_currentAnimationStep + 1 >= maxForwardDistance && !canClear) {
          // About to reach the blocker cell - mark as attempted before the final forward step
          _logDebug(
            'Marking vine attempted before reaching blocker: vineId=${vineData.id}, '
            'step=$_currentAnimationStep, maxDistance=$maxForwardDistance',
          );
          parent.markVineAttempted(vineData.id);
        }

        // Save current positions to history
        _positionHistory.add(
          List<Map<String, int>>.from(
            _currentVisualPositions.map((pos) => Map<String, int>.from(pos)),
          ),
        );

        // Move head based on direction
        final headIndex = 0;
        final headPos = _currentVisualPositions[headIndex];
        var newHeadX = headPos['x'] as int;
        var newHeadY = headPos['y'] as int;

        switch (vineData.headDirection) {
          case 'right':
            newHeadX += 1;
            break;
          case 'left':
            newHeadX -= 1;
            break;
          case 'up':
            newHeadY += 1; // Up increases y
            break;
          case 'down':
            newHeadY -= 1; // Down decreases y
            break;
        }

        // Update each following segment to previous segment's old position
        var prevX = headPos['x'] as int;
        var prevY = headPos['y'] as int;

        for (int i = 1; i < _currentVisualPositions.length; i++) {
          final tempX = _currentVisualPositions[i]['x'] as int;
          final tempY = _currentVisualPositions[i]['y'] as int;

          _currentVisualPositions[i]['x'] = prevX;
          _currentVisualPositions[i]['y'] = prevY;

          prevX = tempX;
          prevY = tempY;
        }

        // Move head to new position
        _currentVisualPositions[headIndex]['x'] = newHeadX;
        _currentVisualPositions[headIndex]['y'] = newHeadY;

        _currentAnimationStep++;

        // Check if we've completed the forward animation for a blocked vine
        if (_currentAnimationStep >= maxForwardDistance && !canClear) {
          // Reached the blocker cell - start reverse animation
          _logDebug(
            'Reached blocker cell, starting reverse: vineId=${vineData.id}, '
            'step=$_currentAnimationStep, maxDistance=$maxForwardDistance, '
            'headPos=(${_currentVisualPositions[0]['x']},${_currentVisualPositions[0]['y']})',
          );
          _isBlockedAnimation = true;
          _currentAnimationStep = 0;
          return;
        }
      } else if (_willClearAfterAnimation) {
        // Continue moving off screen for clearing vines
        // Save current positions to history
        _positionHistory.add(
          List<Map<String, int>>.from(
            _currentVisualPositions.map((pos) => Map<String, int>.from(pos)),
          ),
        );

        // Move head further in direction
        final headIndex = 0;
        final headPos = _currentVisualPositions[headIndex];
        var newHeadX = headPos['x'] as int;
        var newHeadY = headPos['y'] as int;

        switch (vineData.headDirection) {
          case 'right':
            newHeadX += 1;
            break;
          case 'left':
            newHeadX -= 1;
            break;
          case 'up':
            newHeadY += 1; // Up increases y
            break;
          case 'down':
            newHeadY -= 1; // Down decreases y
            break;
        }

        // Update each following segment to previous segment's old position
        var prevX = headPos['x'] as int;
        var prevY = headPos['y'] as int;

        for (int i = 1; i < _currentVisualPositions.length; i++) {
          final tempX = _currentVisualPositions[i]['x'] as int;
          final tempY = _currentVisualPositions[i]['y'] as int;

          _currentVisualPositions[i]['x'] = prevX;
          _currentVisualPositions[i]['y'] = prevY;

          prevX = tempX;
          prevY = tempY;
        }

        // Move head to new position
        _currentVisualPositions[headIndex]['x'] = newHeadX;
        _currentVisualPositions[headIndex]['y'] = newHeadY;

        _currentAnimationStep++;

        // Check vine position relative to visible grid bounds
        // Use `_hasExitedVisibleGrid()` to detect when the vine head has left
        // the visible grid area so we can start the bloom immediately.
        final isHeadExitedVisibleGrid = _hasExitedVisibleGrid();
        final isFullyOffScreen = _isFullyOffScreen();

        // Start bloom effect as soon as vine head leaves the visible grid
        if (isHeadExitedVisibleGrid && !_isShowingBloomEffect) {
          _logDebug(
            'Head exited visible grid: vineId=${vineData.id}, '
            'starting bloom effect',
          );
          _startBloomEffect();
        }

        // Update bloom effect continuously while vine is animating off-screen
        if (_isShowingBloomEffect) {
          _updateBloomEffect(dt);

          // Continue bloom effect while vine animates, but check for completion when fully off-screen
          if (isFullyOffScreen && _bloomEffectTimer >= _bloomEffectDuration) {
            // Bloom effect finished and vine is fully off-screen - remove vine
            _logDebug(
              'Fully off-screen and bloom complete: vineId=${vineData.id}, '
              'calling _finishAnimation()',
            );
            _finishAnimation();
          }
        } else if (_currentAnimationStep >= _totalAnimationSteps) {
          // Fallback: if animation times out, still show effect
          _startBloomEffect();
        }
      }
    }
  }

  int _calculateMovementDistance() {
    // Get distance from solver service - this tells us how far we can move before being blocked
    // Use the active IDs that exclude animatingClear vines (they don't block others)
    final activeIds = parent.getActiveVineIds();
    final solver = parent.getLevelSolverService();

    return solver.getDistanceToBlocker(
      parent.getCurrentLevelData()!,
      vineData.id,
      activeIds,
    );
  }

  // Check if all vine segments have exited the visible grid area (no margin)
  bool _hasExitedVisibleGrid() {
    final level = parent.getCurrentLevelData();
    if (level == null) return true;
    final gridCols = level.gridWidth;
    final gridRows = level.gridHeight;

    // If no visual positions, consider it exited
    if (_currentVisualPositions.isEmpty) return true;

    // Only check the head position: we want the bloom to start as soon as
    // the head has left the visible grid area.
    final headPos = _currentVisualPositions[0];
    final x = headPos['x'] as int;
    final y = headPos['y'] as int;

    // Head is outside visible grid when it's <0 or >= cols/rows
    return x < 0 || x >= gridCols || y < 0 || y >= gridRows;
  }

  // Check if all vine segments are fully off-screen (with margin)
  bool _isFullyOffScreen() {
    final level = parent.getCurrentLevelData();
    if (level == null) return true;
    final gridCols = level.gridWidth;
    final gridRows = level.gridHeight;
    const int offScreenMargin =
        3; // Extra cells to ensure vine is fully off-screen

    // Check if any segment is still visible on screen (with margin)
    for (final pos in _currentVisualPositions) {
      final x = pos['x'] as int;
      final y = pos['y'] as int;

      // If any segment is still within extended bounds (includes margin)
      if (x >= -offScreenMargin &&
          x < gridCols + offScreenMargin &&
          y >= -offScreenMargin &&
          y < gridRows + offScreenMargin) {
        return false; // Still visible with margin
      }
    }

    return true; // All segments are fully off-screen
  }

  void slideBump(int distanceInCells) {
    if (_isAnimating) return;
    _isAnimating = true;

    // Initialize bump animation state
    _currentAnimationStep = 0;
    _totalAnimationSteps = distanceInCells * 2; // forward + backward
    _animationTimer = 0.0;
    _stepDuration = 0.05; // faster for bump animation
    // Note: slideBump not implemented with history-based animation yet
  }

  void _startBloomEffect() {
    _isShowingBloomEffect = true;
    _bloomEffectTimer = 0.0;

    // Calculate bloom position at the grid edge where the vine exited.
    // The bloom should appear at the boundary edge, clamped to valid grid coordinates.
    if (_currentVisualPositions.isNotEmpty) {
      final level = parent.getCurrentLevelData();
      if (level == null) return;

      final headPos = _currentVisualPositions[0]; // Head is at index 0
      final headX = headPos['x'] as int;
      final headY = headPos['y'] as int;

      // Determine bloom position at the grid boundary (perpendicular axis clamped to grid)
      int bloomX = headX;
      int bloomY = headY;

      switch (vineData.headDirection) {
        case 'right':
          // Head exited right edge - bloom at right boundary
          bloomX = level.gridWidth - 1;
          // Clamp Y to valid grid range
          bloomY = headY.clamp(0, level.gridHeight - 1);
          break;
        case 'left':
          // Head exited left edge - bloom at left boundary
          bloomX = 0;
          // Clamp Y to valid grid range
          bloomY = headY.clamp(0, level.gridHeight - 1);
          break;
        case 'up':
          // Head exited top edge - bloom at top boundary
          bloomY = level.gridHeight - 1;
          // Clamp X to valid grid range
          bloomX = headX.clamp(0, level.gridWidth - 1);
          break;
        case 'down':
          // Head exited bottom edge - bloom at bottom boundary
          bloomY = 0;
          // Clamp X to valid grid range
          bloomX = headX.clamp(0, level.gridWidth - 1);
          break;
      }

      // Transform to visual coordinates (y=0 at bottom)
      final visualHeight = level.gridHeight;
      final visualY = visualHeight - 1 - bloomY;

      // Position the bloom effect at the grid edge exit point
      _bloomEffectPosition = Offset(
        bloomX * cellSize + cellSize / 2,
        visualY * cellSize + cellSize / 2,
      );

      debugPrint(
        'Bloom effect started at grid edge: head($headX,$headY) -> bloom($bloomX,$bloomY)',
      );
    }
  }

  void _updateBloomEffect(double dt) {
    _bloomEffectTimer += dt;

    // Bloom effect continues while vine animates - no early termination
  }

  void _finishAnimation() {
    // Clean up animation state
    _isAnimating = false;
    _isShowingBloomEffect = false;
    _bloomEffectPosition = null;
    _positionHistory.clear();
    _currentAnimationStep = 0;
    _totalAnimationSteps = 0;
    _animationTimer = 0.0;

    // Set animation state to cleared - this properly marks the vine as cleared
    parent.setVineAnimationState(vineData.id, VineAnimationState.cleared);

    _logDebug(
      'Animation finished: vineId=${vineData.id}, '
      'state=cleared, notifying parent and removing component',
    );

    // Notify parent of clearing (only once)
    if (!_alreadyNotifiedCleared) {
      parent.notifyVineCleared(vineData.id);
    }

    // Remove the vine component from the scene
    removeFromParent();
  }

  /// Helper method for conditional debug logging
  void _logDebug(String message) {
    // Check if debug logging is enabled via the provider
    final debugEnabled = parent.parent.ref.read(
      debugVineAnimationLoggingProvider,
    );
    if (debugEnabled) {
      debugPrint('VineComponent: $message');
    }
  }

  void _drawBloomEffect(Canvas canvas) {
    if (_bloomEffectPosition == null) return;

    final progress = _bloomEffectTimer / _bloomEffectDuration;
    final center = _bloomEffectPosition!;

    final seedColor = VineColorPalette.resolve(vineData.vineColor);
    final calmColor = _deriveCalmVariant(seedColor, vineData.id);

    // Respect the render color (including blocked/attempted state) for bloom visuals
    final vineState = parent.getCurrentVineState(vineData.id);
    final renderColor = VineComponent.computeRenderColor(
      calmColor,
      vineState?.hasBeenAttempted ?? false,
      (parent.parent).vineAttemptedColor,
    );

    // Create expanding sparkle rings
    final sparkleColors = [
      renderColor.withValues(alpha: (1.0 - progress) * 0.8),
      renderColor.withValues(alpha: (1.0 - progress) * 0.6),
      renderColor.withValues(alpha: (1.0 - progress) * 0.4),
    ];

    final maxRadius = cellSize * 2.0;
    final ringCount = 3;

    for (int i = 0; i < ringCount; i++) {
      final ringProgress = (progress + i * 0.2) % 1.0; // Staggered timing
      final radius = ringProgress * maxRadius;

      if (radius > 0) {
        final paint = Paint()
          ..color = sparkleColors[i % sparkleColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * (1.0 - ringProgress); // Thinner as they expand

        canvas.drawCircle(center, radius, paint);
      }
    }

    // Add central glow
    final glowRadius = progress * cellSize * 0.8;
    if (glowRadius > 0) {
      final glowPaint = Paint()
        ..color = renderColor.withValues(alpha: (1.0 - progress) * 0.5)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, glowRadius, glowPaint);
    }

    // Add sparkle particles
    final particleCount = 8;
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final distance = progress * cellSize * 1.5;
      final particleX = center.dx + distance * math.cos(angle);
      final particleY = center.dy + distance * math.sin(angle);

      final particlePaint = Paint()
        ..color = renderColor.withValues(alpha: (1.0 - progress) * 0.9)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(particleX, particleY), 2.0, particlePaint);
    }

    // Add extra "dust" particles that move further
    final dustCount = 6;
    for (int i = 0; i < dustCount; i++) {
      final angle = (i / dustCount) * 2 * math.pi + (progress * 0.5);
      final distance = progress * cellSize * 2.5;
      final x = center.dx + distance * math.cos(angle);
      final y = center.dy + distance * math.sin(angle);

      final dustPaint = Paint()
        ..color = renderColor.withValues(alpha: (1.0 - progress) * 0.4)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 1.0, dustPaint);
    }
  }

  static Color _deriveCalmVariant(Color base, String seed) {
    // Deterministic per-vine variation without high-contrast colors.
    // We keep saturation muted and only nudge lightness slightly.
    final hash = _fnv1a32(seed);
    final bucket = hash % 7; // 0..6
    final lightnessDelta = (bucket - 3) * 0.02; // -0.06..+0.06

    final hsl = HSLColor.fromColor(base);
    final adjusted = hsl
        .withSaturation((hsl.saturation * 0.85).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0));
    return adjusted.toColor();
  }

  static int _fnv1a32(String input) {
    const int fnvOffset = 0x811C9DC5;
    const int fnvPrime = 0x01000193;

    var hash = fnvOffset;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Compute the color used for rendering a vine based on its calm color and
  /// current state. This is made public and static so it can be tested in
  /// isolation.
  static Color computeRenderColor(
    Color calmColor,
    bool isAttempted,
    Color attemptedColor,
  ) {
    // Simplified rule: if the vine has been attempted at any time, use the
    // attempted/error color for the rest of the level. This keeps the logic
    // straightforward and avoids additional persistent flags.
    if (isAttempted) {
      return attemptedColor;
    }

    return calmColor;
  }
}
