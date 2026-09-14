import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:parable_bloom/core/constants/animation_timing.dart';

/// A visual component that displays a pulse ring effect at a tap location.
/// The ring expands and fades out over a short duration.
/// Renders with very high priority to appear on top of all game elements.
class TapEffectComponent extends PositionComponent {
  final Vector2 tapPosition;
  final Color color;
  final double maxRadius;
  final double duration;

  double _elapsed = 0.0;
  final List<({double dx, double dy, double speed, double size})> _sparkles =
      [];

  // Shared RNG + paints: avoids per-tap Random() and per-frame Paint() churn
  // on the most frequent effect (stacks on rapid taps).
  static final math.Random _sharedRandom = math.Random();
  final Paint _ringPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  TapEffectComponent({
    required this.tapPosition,
    this.color = Colors.white,
    this.maxRadius = 15.0,
    this.duration = AnimationTiming.tapEffectSeconds,
  }) : super(
          position: tapPosition,
          anchor: Anchor.center,
          priority: 10000,
        ) {
    // Generate random sparkle data with precomputed unit vectors so render()
    // does no trig.
    final random = _sharedRandom;
    for (int i = 0; i < 6; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      _sparkles.add((
        dx: math.cos(angle),
        dy: math.sin(angle),
        speed: 15.0 + random.nextDouble() * 25.0,
        size: 1.0 + random.nextDouble() * 1.5,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    // Remove component when animation is complete
    if (_elapsed >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_elapsed >= duration) return;

    // Calculate progress (0.0 to 1.0), clamped to prevent oversized effects
    final progress = (_elapsed / duration).clamp(0.0, 1.0);

    // Expand radius from 0 to maxRadius
    final currentRadius = maxRadius * progress;

    // Fade out opacity (1.0 to 0.0)
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    // Draw outer ring
    _ringPaint
      ..color = color.withValues(alpha: opacity * 0.6)
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset.zero, currentRadius, _ringPaint);

    // Draw inner filled circle that quickly fades
    if (progress < 0.3) {
      final innerOpacity = (1.0 - progress / 0.3).clamp(0.0, 1.0);
      _fillPaint.color = color.withValues(alpha: innerOpacity * 0.3);

      canvas.drawCircle(Offset.zero, currentRadius * 0.5, _fillPaint);
    }

    // Draw radiating sparkles (no trig: unit vectors precomputed)
    _fillPaint.color = color.withValues(alpha: opacity * 0.8);
    for (final sparkle in _sparkles) {
      final distance = progress * sparkle.speed;
      final sparkleX = sparkle.dx * distance;
      final sparkleY = sparkle.dy * distance;

      canvas.drawCircle(Offset(sparkleX, sparkleY), sparkle.size, _fillPaint);
    }
  }

  @override
  int get priority => 10000; // Explicitly set high priority for rendering order
}
