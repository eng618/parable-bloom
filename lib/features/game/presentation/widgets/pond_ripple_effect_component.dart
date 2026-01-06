import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A subtle pond ripple celebration effect.
/// Renders concentric rings that expand and fade with slight staggering.
class PondRippleEffectComponent extends PositionComponent {
  final int ringCount;
  final double maxRadius;
  final double duration; // total animation duration in seconds
  final List<Color> colors;

  double _elapsed = 0.0;

  /// Centered effect; set [position] to the ripple origin and [anchor] to center.
  PondRippleEffectComponent({
    required Vector2 center,
    required this.maxRadius,
    this.ringCount = 4,
    this.duration = 2.0,
    this.colors = const [],
  }) : super(
          position: center,
          anchor: Anchor.center,
          priority: 9000, // above grid, below tap effects
        );

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_elapsed >= duration) return;

    // Stagger rings uniformly across duration
    final double ringInterval = duration / ringCount;

    for (int i = 0; i < ringCount; i++) {
      final double startTime = i * ringInterval * 0.5; // slight overlap
      final double t =
          ((_elapsed - startTime) / (duration - startTime)).clamp(0.0, 1.0);
      if (t <= 0) continue; // not started yet

      // Ease-out for radius and alpha
      final double eased = _easeOutCubic(t);
      final double radius = maxRadius * eased;

      // Stroke thins from 3.0 to 0.5
      final double stroke = 3.0 - 2.5 * eased;
      // Alpha fades from 0.7 to 0.0
      final double alpha = (0.7 * (1.0 - eased)).clamp(0.0, 0.7);

      final Color color =
          (colors.isNotEmpty) ? colors[i % colors.length] : Colors.white;

      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;

      canvas.drawCircle(Offset.zero, radius, paint);
    }
  }

  double _easeOutCubic(double t) {
    final p = t - 1.0;
    return p * p * p + 1.0;
  }
}
