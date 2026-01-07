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

  TapEffectComponent({
    required this.tapPosition,
    this.color = Colors.white,
    this.maxRadius = 15.0, // Reduced default to prevent large effects
    this.duration = 0.4,
  }) : super(
          position: tapPosition,
          anchor: Anchor.center,
          priority:
              10000, // Render on top of everything with very high priority
        );

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
  }

  @override
  int get priority => 10000; // Explicitly set high priority for rendering order
}
