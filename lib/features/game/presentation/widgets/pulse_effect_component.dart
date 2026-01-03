import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A tiny pulse effect that appears at tap location.
/// Shows a brief expanding ring effect.
class PulseEffectComponent extends PositionComponent {
  static const double _maxRadius = 30.0; // Slightly larger for visibility
  static const double _duration = 0.4; // Slightly longer duration (400ms)
  static const double _lineWidth = 3.0; // Thicker line for visibility

  double _elapsed = 0.0;
  final Color _color;

  PulseEffectComponent({
    required Vector2 position,
    Color? color,
  })  : _color = color ?? Colors.white.withValues(alpha: 0.8),
        super(
          position: position,
          size: Vector2.all(_maxRadius * 2),
          anchor: Anchor.center,
          priority: 100, // High priority to render above other components
        );

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    // Remove component after animation completes
    if (_elapsed >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Calculate animation progress (0.0 to 1.0)
    final progress = (_elapsed / _duration).clamp(0.0, 1.0);

    // Ease out cubic for smooth deceleration
    final easedProgress = 1.0 - (1.0 - progress) * (1.0 - progress) * (1.0 - progress);

    // Radius expands from 0 to maxRadius
    final radius = _maxRadius * easedProgress;

    // Fade out as it expands
    final alpha = (1.0 - progress) * _color.a;

    final paint = Paint()
      ..color = _color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _lineWidth;

    // Draw ring at center (component is anchored at center)
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      radius,
      paint,
    );
  }
}
