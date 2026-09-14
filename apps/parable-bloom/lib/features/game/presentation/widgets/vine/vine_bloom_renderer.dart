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

  // Reused across frames: avoids ~18 Paint() allocs per clearing vine per
  // frame. Color/width are overwritten each draw.
  final Paint _ringPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  // Precomputed unit vectors for sparkles/dust: no per-frame cos/sin.
  static const int _sparkleCount = 6;
  static final List<double> _sparkleCos = List<double>.generate(
    _sparkleCount,
    (i) => math.cos((i / _sparkleCount) * 2 * math.pi),
  );
  static final List<double> _sparkleSin = List<double>.generate(
    _sparkleCount,
    (i) => math.sin((i / _sparkleCount) * 2 * math.pi),
  );
  static const int _dustCount = 4;
  static final List<double> _dustCos = List<double>.generate(
    _dustCount,
    (i) => math.cos((i / _dustCount) * 2 * math.pi),
  );
  static final List<double> _dustSin = List<double>.generate(
    _dustCount,
    (i) => math.sin((i / _dustCount) * 2 * math.pi),
  );

  void startBloomEffect({
    required VineData vineData,
    required LevelData level,
    required List<Map<String, int>> visualPositions,
  }) {
    isShowingBloomEffect = true;
    bloomEffectTimer = 0.0;

    if (visualPositions.isNotEmpty) {
      final headPos = visualPositions[0];
      final headX = headPos['x'] ?? 0;
      final headY = headPos['y'] ?? 0;

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
    // Clamp once: withValues asserts 0..1 and progress can exceed 1 on the
    // final frame before reset.
    final fade = (1.0 - progress).clamp(0.0, 1.0);

    // Create expanding sparkle rings (2 instead of 3: halves stroke overdraw)
    final maxRadius = cellSize * 2.0;
    const ringCount = 2;

    for (int i = 0; i < ringCount; i++) {
      final ringProgress = (progress + i * 0.33) % 1.0;
      final radius = ringProgress * maxRadius;

      if (radius > 0) {
        _ringPaint
          ..color = renderColor.withValues(
            alpha: fade * (0.8 - i * 0.2),
          )
          ..strokeWidth = 3.0 * (1.0 - ringProgress);
        canvas.drawCircle(center, radius, _ringPaint);
      }
    }

    // Add central glow
    final glowRadius = progress * cellSize * 0.8;
    if (glowRadius > 0) {
      _fillPaint.color = renderColor.withValues(alpha: fade * 0.5);
      canvas.drawCircle(center, glowRadius, _fillPaint);
    }

    // Add sparkle particles (precomputed directions, shared paint)
    for (int i = 0; i < _sparkleCount; i++) {
      final distance = progress * cellSize * 1.5;
      final particleX = center.dx + distance * _sparkleCos[i];
      final particleY = center.dy + distance * _sparkleSin[i];

      _fillPaint.color = renderColor.withValues(alpha: fade * 0.9);
      canvas.drawCircle(Offset(particleX, particleY), 2.0, _fillPaint);
    }

    // Add extra dust particles
    for (int i = 0; i < _dustCount; i++) {
      final distance = progress * cellSize * 2.5;
      final x = center.dx + distance * _dustCos[i];
      final y = center.dy + distance * _dustSin[i];

      _fillPaint.color = renderColor.withValues(alpha: fade * 0.4);
      canvas.drawCircle(Offset(x, y), 1.0, _fillPaint);
    }
  }
}
