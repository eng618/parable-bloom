import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:parable_bloom/core/constants/animation_timing.dart';
import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/core/services/logger_service.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';

class VineBloomRenderer {
  bool isShowingBloomEffect = false;
  double bloomEffectTimer = 0.0;
  final double bloomEffectDuration = AnimationTiming.vineBloomSeconds;
  Offset? bloomEffectPosition;

  void startBloomEffect({
    required VineData vineData,
    required LevelData level,
    required List<Map<String, int>> visualPositions,
  }) {
    isShowingBloomEffect = true;
    bloomEffectTimer = 0.0;

    if (visualPositions.isNotEmpty) {
      final headPos = visualPositions[0];
      final headX = headPos['x'] as int;
      final headY = headPos['y'] as int;

      int bloomX = headX;
      int bloomY = headY;

      switch (vineData.headDirection) {
        case 'right':
          bloomX = level.gridWidth - 1;
          bloomY = headY.clamp(0, level.gridHeight - 1);
          break;
        case 'left':
          bloomX = 0;
          bloomY = headY.clamp(0, level.gridHeight - 1);
          break;
        case 'up':
          bloomY = level.gridHeight - 1;
          bloomX = headX.clamp(0, level.gridWidth - 1);
          break;
        case 'down':
          bloomY = 0;
          bloomX = headX.clamp(0, level.gridWidth - 1);
          break;
      }

      final visualHeight = level.gridHeight;
      final visualY = visualHeight - 1 - bloomY;

      bloomEffectPosition = Offset(
        GameBoardLayout.cellCenterX(bloomX),
        GameBoardLayout.cellCenterY(visualY),
      );

      LoggerService.debug(
        'Bloom effect started at grid edge',
        tag: 'VineBloomRenderer',
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

  void update(double dt) {
    if (isShowingBloomEffect) {
      bloomEffectTimer += dt;
    }
  }

  void reset() {
    isShowingBloomEffect = false;
    bloomEffectTimer = 0.0;
    bloomEffectPosition = null;
  }

  void draw({
    required Canvas canvas,
    required Color renderColor,
    required double cellSize,
  }) {
    if (!isShowingBloomEffect || bloomEffectPosition == null) return;

    final progress = bloomEffectTimer / bloomEffectDuration;
    final center = bloomEffectPosition!;

    // Create expanding sparkle rings
    final sparkleColors = [
      renderColor.withValues(alpha: (1.0 - progress) * 0.8),
      renderColor.withValues(alpha: (1.0 - progress) * 0.6),
      renderColor.withValues(alpha: (1.0 - progress) * 0.4),
    ];

    final maxRadius = cellSize * 2.0;
    const ringCount = 3;

    for (int i = 0; i < ringCount; i++) {
      final ringProgress = (progress + i * 0.2) % 1.0;
      final radius = ringProgress * maxRadius;

      if (radius > 0) {
        final paint = Paint()
          ..color = sparkleColors[i % sparkleColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * (1.0 - ringProgress);

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
    const particleCount = 8;
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

    // Add extra dust particles
    const dustCount = 6;
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
}
