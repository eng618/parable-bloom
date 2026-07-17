import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/animation_timing.dart';
import '../../../../core/game_board_layout.dart';
import '../../../../core/vine_color_palette.dart';
import '../../../../features/game/domain/entities/level_data.dart';
import '../../../../providers/settings_providers.dart';
import '../../../../services/logger_service.dart';
import '../../application/providers/gameplay_state_providers.dart';
import 'grid_component.dart';

class VineComponent extends PositionComponent with ParentIsA<GridComponent> {
  final VineData vineData;
  final double cellSize;

  static ui.Image? _classicTextureImage;
  static ui.Image? _blossomTextureImage;
  static ui.Image? _etherealTextureImage;

  bool _isAnimating = false;
  bool _willClearAfterAnimation =
      false; // Whether this vine should be cleared when animation completes

  // Track current visual positions during animation (separate from vineData.path)
  List<Map<String, int>> _currentVisualPositions = [];

  // Animation state
  int _currentAnimationStep = 0;
  int _totalAnimationSteps = 0;
  int _maxForwardStepsThisRun = 0;
  bool _canClearThisRun = false;
  double _animationTimer = 0.0;
  double _stepDuration = AnimationTiming.vineStepSeconds;

  // History-based animation (snake-like movement)
  List<List<Map<String, int>>> _positionHistory = [];
  bool _isBlockedAnimation = false;

  // Bloom effect after clearing
  bool _isShowingBloomEffect = false;
  double _bloomEffectTimer = 0.0;
  final double _bloomEffectDuration = AnimationTiming.vineBloomSeconds;
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

    final game = parent.parent;

    _classicTextureImage ??= await game.images.load('classic_vine_texture.png');
    _blossomTextureImage ??= await game.images.load('blossom_vine_texture.png');
    _etherealTextureImage ??=
        await game.images.load('ethereal_vine_texture.png');

    // Visual positions are already initialized in constructor
    // This is just for logging

    LoggerService.debug('VineComponent loaded',
        tag: 'VineComponent',
        metadata: {
          'vine_id': vineData.id,
          'head_direction': vineData.headDirection,
          'calculated_direction': _calculateVineDirection(),
        });
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final vineState = parent.getCurrentVineState(vineData.id);
    if (vineState == null) return;
    if (vineState.isCleared &&
        vineState.animationState != VineAnimationState.animatingClear) {
      return;
    }

    final level = parent.getCurrentLevelData();
    if (level == null) return;

    if (_currentVisualPositions.isEmpty) return;

    final isAttempted = vineState.hasBeenAttempted;
    final seedColor = VineColorPalette.resolve(vineData.vineColor);
    final calmColor = _deriveCalmVariant(seedColor, vineData.id);
    final baseColor = VineComponent.computeRenderColor(
      calmColor,
      isAttempted,
      parent.parent.vineAttemptedColor,
    );

    final visualHeight = level.gridHeight;
    final game = parent.parent;
    final vineStyle = game.ref.read(vineStyleProvider);
    final useSimpleVines = vineStyle == VineStyle.simple;

    // Swap live and blocked appearance for premium/stylized vines:
    // Live state modulates with pure white (fully bright and vibrant in both light/dark modes),
    // and blocked state modulates with calmColor.
    Color drawColor = baseColor;
    if (!useSimpleVines) {
      drawColor = isAttempted ? calmColor : const Color(0xFFFFFFFF);
    }

    // Build lists of segment centers
    final List<Offset> points = [];
    for (final cell in _currentVisualPositions) {
      final x = cell['x'] as int;
      final y = cell['y'] as int;
      final visualY = visualHeight - 1 - y;
      points.add(Offset(
        GameBoardLayout.cellCenterX(x),
        GameBoardLayout.cellCenterY(visualY),
      ));
    }

    // Set line thickness (sleek thinner profile)
    final double strokeWidth = useSimpleVines ? 14.0 : 16.0;

    // Create continuous path from tail to head
    final path = Path();
    path.moveTo(points.last.dx, points.last.dy);
    for (int i = points.length - 2; i >= 0; i--) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Setup base Paint
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Get texture image for shaders
    ui.Image? texture;
    if (vineStyle == VineStyle.classic) {
      texture = _classicTextureImage;
    } else if (vineStyle == VineStyle.blossom) {
      texture = _blossomTextureImage;
    } else if (vineStyle == VineStyle.ethereal) {
      texture = _etherealTextureImage;
    }

    if (useSimpleVines || texture == null) {
      paint.color = drawColor;
    } else {
      // Identity 4x4 matrix for ImageShader
      final matrix = Float64List(16)
        ..[0] = 1.0
        ..[5] = 1.0
        ..[10] = 1.0
        ..[15] = 1.0;
      // High-resolution texture scale mapping
      const double textureScale = 0.25;
      matrix[0] = textureScale;
      matrix[5] = textureScale;

      paint.shader = ImageShader(
        texture,
        TileMode.repeated,
        TileMode.repeated,
        matrix,
      );
      paint.colorFilter = ColorFilter.mode(
        drawColor,
        BlendMode.modulate,
      );
    }

    // 1. Draw outer glow for Ethereal Bioluminescent
    if (vineStyle == VineStyle.ethereal) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6.0
        ..color =
            const Color(0xFF00E5FF).withValues(alpha: 0.35) // Cyber cyan glow
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawPath(path, glowPaint);
    }

    // 2. Draw main branch/arrow path
    canvas.drawPath(path, paint);

    // 3. Draw Organic Foliage & Details (Classic, Blossom, Ethereal)
    if (!useSimpleVines) {
      for (int i = 0; i < points.length; i++) {
        // Skip details directly on head
        if (i == 0) continue;

        // Calculate direction along the branch segment to grow foliage organically
        final nextPoint = points[i - 1];
        final dx = nextPoint.dx - points[i].dx;
        final dy = nextPoint.dy - points[i].dy;
        final double baseAngle = math.atan2(dy, dx);

        if (vineStyle == VineStyle.classic) {
          final leafPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = drawColor;
          if (texture != null) {
            leafPaint.shader = paint.shader;
            leafPaint.colorFilter = paint.colorFilter;
          }

          final double leafSize = strokeWidth * 0.95;

          // Draw left leaf
          canvas.save();
          canvas.translate(points[i].dx, points[i].dy);
          canvas.rotate(baseAngle + math.pi / 4.0);
          canvas.drawPath(_createLeafPath(leafSize), leafPaint);
          canvas.restore();

          // Draw right leaf
          canvas.save();
          canvas.translate(points[i].dx, points[i].dy);
          canvas.rotate(baseAngle - math.pi / 4.0);
          canvas.drawPath(_createLeafPath(leafSize), leafPaint);
          canvas.restore();
        } else if (vineStyle == VineStyle.blossom) {
          _drawCherryBlossom(canvas, points[i], strokeWidth * 1.15, drawColor);
        } else if (vineStyle == VineStyle.ethereal) {
          final leafPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = const Color(0xFF00E5FF)
            ..colorFilter = ColorFilter.mode(drawColor, BlendMode.modulate);

          final leafGlow = Paint()
            ..style = PaintingStyle.fill
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

          final double leafSize = strokeWidth * 0.95;

          // Draw glowing left leaf
          canvas.save();
          canvas.translate(points[i].dx, points[i].dy);
          canvas.rotate(baseAngle + math.pi / 4.0);
          canvas.drawPath(_createLeafPath(leafSize), leafGlow);
          canvas.drawPath(_createLeafPath(leafSize), leafPaint);
          canvas.restore();

          // Draw glowing right leaf
          canvas.save();
          canvas.translate(points[i].dx, points[i].dy);
          canvas.rotate(baseAngle - math.pi / 4.0);
          canvas.drawPath(_createLeafPath(leafSize), leafGlow);
          canvas.drawPath(_createLeafPath(leafSize), leafPaint);
          canvas.restore();
        }
      }
    }

    // 4. Draw sleek, rounded Arrow Head at the very tip (points.first)
    final head = points.first;
    final String dir = _calculateVineDirection() ?? 'up';
    final double arrowSize = strokeWidth * 1.45;
    final headPath = Path();

    if (dir == 'up') {
      headPath.moveTo(head.dx, head.dy - arrowSize * 0.85);
      headPath.lineTo(head.dx - arrowSize * 0.72, head.dy + arrowSize * 0.22);
      headPath.lineTo(head.dx + arrowSize * 0.72, head.dy + arrowSize * 0.22);
      headPath.close();
    } else if (dir == 'down') {
      headPath.moveTo(head.dx, head.dy + arrowSize * 0.85);
      headPath.lineTo(head.dx - arrowSize * 0.72, head.dy - arrowSize * 0.22);
      headPath.lineTo(head.dx + arrowSize * 0.72, head.dy - arrowSize * 0.22);
      headPath.close();
    } else if (dir == 'left') {
      headPath.moveTo(head.dx - arrowSize * 0.85, head.dy);
      headPath.lineTo(head.dx + arrowSize * 0.22, head.dy - arrowSize * 0.72);
      headPath.lineTo(head.dx + arrowSize * 0.22, head.dy + arrowSize * 0.72);
      headPath.close();
    } else if (dir == 'right') {
      headPath.moveTo(head.dx + arrowSize * 0.85, head.dy);
      headPath.lineTo(head.dx - arrowSize * 0.22, head.dy - arrowSize * 0.72);
      headPath.lineTo(head.dx - arrowSize * 0.22, head.dy + arrowSize * 0.72);
      headPath.close();
    }

    final headPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = drawColor;

    if (useSimpleVines || texture == null) {
      headPaint.color = drawColor;
    } else {
      headPaint.shader = paint.shader;
      headPaint.colorFilter = paint.colorFilter;
    }

    canvas.drawPath(headPath, headPaint);

    if (_isShowingBloomEffect && _bloomEffectPosition != null) {
      _drawBloomEffect(canvas);
    }
  }

  Path _createLeafPath(double size) {
    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size * 0.5, -size * 0.32, size, 0);
    path.quadraticBezierTo(size * 0.5, size * 0.32, 0, 0);
    path.close();
    return path;
  }

  void _drawCherryBlossom(
      Canvas canvas, Offset center, double size, Color baseColor) {
    final petalPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFC2D8); // Soft pink petals
    final centerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFDB4D); // Bright yellow center

    petalPaint.colorFilter = ColorFilter.mode(baseColor, BlendMode.modulate);
    centerPaint.colorFilter = ColorFilter.mode(baseColor, BlendMode.modulate);

    final double petalRadius = size * 0.44;
    for (int i = 0; i < 5; i++) {
      final double angle = i * 2 * math.pi / 5;
      final px = center.dx + petalRadius * math.cos(angle);
      final py = center.dy + petalRadius * math.sin(angle);
      canvas.drawCircle(Offset(px, py), size * 0.34, petalPaint);
    }
    canvas.drawCircle(center, size * 0.22, centerPaint);
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
    _canClearThisRun = rawDistance > 0;
    // For blocked vines, rawDistance is negative, abs() gives distance to blocker
    // We animate TO the blocker (not past it), so use the full distance
    _maxForwardStepsThisRun = rawDistance.abs();

    if (_canClearThisRun) {
      // Vine can reach edge - calculate steps needed to exit completely off-screen
      // Add extra steps to ensure vine moves well beyond the visible area
      const int extraOffScreenSteps = 6; // Ensure vine is far off-screen
      _totalAnimationSteps = _maxForwardStepsThisRun +
          vineData.orderedPath.length +
          extraOffScreenSteps;
      _willClearAfterAnimation = true;

      // Set animation state to animatingClear - this removes it from blocking calculations
      // but allows the animation to continue and complete properly
      parent.setVineAnimationState(
        vineData.id,
        VineAnimationState.animatingClear,
      );

      _logDebug(
        'Starting CLEAR animation: vineId=${vineData.id}, '
        'maxForwardSteps=$_maxForwardStepsThisRun, totalSteps=$_totalAnimationSteps, '
        'headPos=(${_currentVisualPositions[0]['x']},${_currentVisualPositions[0]['y']}), '
        'direction=${vineData.headDirection}',
      );
    } else {
      // Vine is blocked - move forward to the blocking cell, then reverse
      _totalAnimationSteps = _maxForwardStepsThisRun * 2;
      _willClearAfterAnimation = false;

      // Set animation state to animatingBlocked
      parent.setVineAnimationState(
        vineData.id,
        VineAnimationState.animatingBlocked,
      );

      _logDebug(
        'Starting BLOCKED animation: vineId=${vineData.id}, '
        'maxForwardSteps=$_maxForwardStepsThisRun (to blocker cell), totalSteps=$_totalAnimationSteps, '
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

    // Update bloom effect continuously on every frame, independent of the grid stepping frequency
    if (_isShowingBloomEffect) {
      _updateBloomEffect(dt);

      // Check for completion when fully off-screen
      final isFullyOffScreen = _isFullyOffScreen();
      if (isFullyOffScreen && _bloomEffectTimer >= _bloomEffectDuration) {
        _logDebug(
          'Fully off-screen and bloom complete: vineId=${vineData.id}, '
          'calling _finishAnimation()',
        );
        _finishAnimation();
        return; // Don't run stepping code if finished
      }
    }

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
          _maxForwardStepsThisRun = 0;
          _canClearThisRun = false;

          // Reset animation state to normal
          parent.setVineAnimationState(vineData.id, VineAnimationState.normal);
        }
        return;
      }

      if (_currentAnimationStep < _maxForwardStepsThisRun) {
        // Check if we've reached the blocker position for a blocked vine
        if (_currentAnimationStep + 1 >= _maxForwardStepsThisRun &&
            !_canClearThisRun) {
          // About to reach the blocker cell - mark as attempted before the final forward step
          _logDebug(
            'Marking vine attempted before reaching blocker: vineId=${vineData.id}, '
            'step=$_currentAnimationStep, maxDistance=$_maxForwardStepsThisRun',
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
        if (_currentAnimationStep >= _maxForwardStepsThisRun &&
            !_canClearThisRun) {
          // Reached the blocker cell - start reverse animation
          _logDebug(
            'Reached blocker cell, starting reverse: vineId=${vineData.id}, '
            'step=$_currentAnimationStep, maxDistance=$_maxForwardStepsThisRun, '
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

        if (!_isShowingBloomEffect &&
            _currentAnimationStep >= _totalAnimationSteps) {
          // Fallback: if animation times out, still show effect
          _logDebug(
            'Animation steps timeout fallback: vineId=${vineData.id}, '
            'starting bloom effect',
          );
          _startBloomEffect();
        }
      } else if (!_canClearThisRun) {
        // Safety net for blocked runs: if we somehow reach this branch without
        // entering reverse mode, transition to reverse to avoid getting stuck.
        _isBlockedAnimation = true;
        _currentAnimationStep = 0;
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
    _stepDuration = AnimationTiming.vineStepSeconds;
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
        GameBoardLayout.cellCenterX(bloomX),
        GameBoardLayout.cellCenterY(visualY),
      );

      LoggerService.debug(
        'Bloom effect started at grid edge',
        tag: 'VineComponent',
        metadata: {
          'vine_id': vineData.id,
          'head_x': headX,
          'head_y': headY,
          'bloom_x': bloomX,
          'bloom_y': bloomY,
        },
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
    _maxForwardStepsThisRun = 0;
    _canClearThisRun = false;
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
      LoggerService.debug(message,
          tag: 'VineComponent', metadata: {'vine_id': vineData.id});
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
    final isAttempted = vineState?.hasBeenAttempted ?? false;
    final baseColor = VineComponent.computeRenderColor(
      calmColor,
      isAttempted,
      (parent.parent).vineAttemptedColor,
    );

    Color renderColor = baseColor;
    final vineStyle = parent.parent.ref.read(vineStyleProvider);
    final useSimpleVines = vineStyle == VineStyle.simple;
    if (!useSimpleVines) {
      renderColor = isAttempted ? calmColor : const Color(0xFFFFFFFF);
    }

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
