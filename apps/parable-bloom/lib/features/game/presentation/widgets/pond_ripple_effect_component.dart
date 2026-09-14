import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:parable_bloom/core/constants/animation_timing.dart';

/// A subtle pond ripple celebration effect.
/// Renders concentric rings that expand and fade with slight staggering.
class PondRippleEffectComponent extends PositionComponent {
  final int ringCount;
  final double maxRadius;
  final double duration; // total animation duration in seconds
  final List<Color> colors;

  double _elapsed = 0.0;

  /// Reused paint: one allocation per component instead of one per ring per
  /// frame.
  final Paint _paint = Paint()..style = PaintingStyle.stroke;

  /// Centered effect; set [position] to the ripple origin and [anchor] to center.
  PondRippleEffectComponent({
    required Vector2 center,
    required this.maxRadius,
    this.ringCount = 4,
    this.duration = AnimationTiming.pondRippleSeconds,
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

      _paint
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = stroke;

      canvas.drawCircle(Offset.zero, radius, _paint);
    }
  }

  double _easeOutCubic(double t) {
    final p = t - 1.0;
    return p * p * p + 1.0;
  }
}
