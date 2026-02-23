import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A visual component that displays a pulse ring effect at a tap location.
/// The ring expands and fades out over a short duration.
/// Renders with very high priority to appear on top of all game elements.
class TapEffectComponent extends PositionComponent {
  final Vector2 tapPosition;
  final Color color;
  final double maxRadius;
  final double duration;

  double _elapsed = 0.0;
  final List<({double angle, double speed, double size})> _sparkles = [];

  TapEffectComponent({
    required this.tapPosition,
    this.color = Colors.white,
    this.maxRadius = 15.0,
    this.duration = 0.4,
  }) : super(
          position: tapPosition,
          anchor: Anchor.center,
          priority: 10000,
        ) {
    // Generate random sparkle data
    final random = math.Random();
    for (int i = 0; i < 6; i++) {
      _sparkles.add((
        angle: random.nextDouble() * math.pi * 2,
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
    final paint = Paint()
      ..color = color.withValues(alpha: opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset.zero, currentRadius, paint);

    // Draw inner filled circle that quickly fades
    if (progress < 0.3) {
      final innerOpacity = (1.0 - progress / 0.3).clamp(0.0, 1.0);
      final innerPaint = Paint()
        ..color = color.withValues(alpha: innerOpacity * 0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset.zero, currentRadius * 0.5, innerPaint);
    }

    // Draw radiating sparkles
    for (final sparkle in _sparkles) {
      final distance = progress * sparkle.speed;
      final sparkleX = math.cos(sparkle.angle) * distance;
      final sparkleY = math.sin(sparkle.angle) * distance;

      final sparklePaint = Paint()
        ..color = color.withValues(alpha: opacity * 0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(sparkleX, sparkleY), sparkle.size, sparklePaint);
    }
  }

  @override
  int get priority => 10000; // Explicitly set high priority for rendering order
}
