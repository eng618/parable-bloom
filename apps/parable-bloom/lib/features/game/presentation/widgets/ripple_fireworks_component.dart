import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'pond_ripple_effect_component.dart';
import 'package:parable_bloom/core/constants/animation_timing.dart';

/// Spawns a set of subtle "fireworks" that travel from the bottom
/// toward random points and create small pond ripple effects on impact.
class RippleFireworksComponent extends Component with HasGameReference {
  final int count;
  final double duration; // total span of launches (seconds)
  final double minRippleRadius;
  final double maxRippleRadius;
  final List<Color> colors;
  final double paddingRatio; // avoid edges (0.0 - 0.3 recommended)

  double _elapsed = 0.0;
  final math.Random _rng = math.Random();

  late final List<_ScheduledFirework> _schedule;
  int _nextLaunchIndex = 0;
  int _launchedCount = 0;

  RippleFireworksComponent({
    this.count = 8,
    this.duration = 2.0,
    this.minRippleRadius = 28.0,
    this.maxRippleRadius = 60.0,
    this.colors = const [],
    this.paddingRatio = 0.12,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final size = game.size;
    final padX = size.x * paddingRatio;
    final padY = size.y * paddingRatio;

    _schedule = List.generate(count, (i) {
      // Random target within padded area
      final tx = _rng.nextDouble() * (size.x - 2 * padX) + padX;
      final ty = _rng.nextDouble() * (size.y - 2 * padY) + padY;

      // Launch time staggered across duration
      final launch = _rng.nextDouble() * (duration * 0.8);
      // Travel time subtle and quick
      final travel = AnimationTiming.fireworkTravelBaseSeconds +
          _rng.nextDouble() * AnimationTiming.fireworkTravelSpanSeconds;

      // Start slightly below the screen toward the target x
      final sx = tx + (_rng.nextDouble() * 30 - 15); // small x variance
      final sy = size.y + 10.0; // just below bottom

      final radius = minRippleRadius +
          _rng.nextDouble() * (maxRippleRadius - minRippleRadius);

      return _ScheduledFirework(
        launchTime: launch,
        travelTime: travel,
        start: Vector2(sx, sy),
        target: Vector2(tx, ty),
        rippleRadius: radius,
      );
    })
      ..sort((a, b) => a.launchTime.compareTo(b.launchTime));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    // Launch any due fireworks: schedule is sorted by launchTime, so walk
    // forward with an index instead of `.where().toList()` + closure churn
    // every frame.
    while (_nextLaunchIndex < _schedule.length &&
        _elapsed >= _schedule[_nextLaunchIndex].launchTime) {
      final f = _schedule[_nextLaunchIndex];
      _nextLaunchIndex++;
      if (!f.launched) {
        f.launched = true;
        _launchedCount++;
        final projectile = _FireworkProjectile(
          start: f.start,
          target: f.target,
          travelTime: f.travelTime,
          color: colors.isEmpty
              ? Colors.white
              : colors[_rng.nextInt(colors.length)],
          onImpact: (impactAt) {
            // Spawn ripple at impact
            game.add(
              PondRippleEffectComponent(
                center: impactAt,
                maxRadius: f.rippleRadius,
                ringCount: 3,
                duration: AnimationTiming.fireworkRippleSeconds,
                colors: colors,
              ),
            );
          },
        );
        game.add(projectile);
      }
    }

    // Remove this coordinator once all have launched and enough time has passed
    if (_launchedCount >= _schedule.length && _elapsed > duration + 1.0) {
      removeFromParent();
    }
  }
}

class _ScheduledFirework {
  final double launchTime;
  final double travelTime;
  final Vector2 start;
  final Vector2 target;
  final double rippleRadius;
  bool launched = false;

  _ScheduledFirework({
    required this.launchTime,
    required this.travelTime,
    required this.start,
    required this.target,
    required this.rippleRadius,
  });
}

class _FireworkProjectile extends PositionComponent {
  final Vector2 start;
  final Vector2 target;
  final double travelTime;
  final Color color;
  final void Function(Vector2 impactAt) onImpact;

  double _elapsed = 0.0;
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  _FireworkProjectile({
    required this.start,
    required this.target,
    required this.travelTime,
    required this.color,
    required this.onImpact,
  }) : super(position: start.clone(), anchor: Anchor.center, priority: 9500) {
    _paint.color = color.withValues(alpha: 0.7);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    final t = (_elapsed / travelTime).clamp(0.0, 1.0);
    final eased = _easeOutCubic(t);
    // Mutate in place: avoids a Vector2() alloc per projectile per frame.
    position.setValues(
      start.x + (target.x - start.x) * eased,
      start.y + (target.y - start.y) * eased,
    );

    if (t >= 1.0) {
      onImpact(target.clone());
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Tiny, subtle dot (shared paint, no per-frame alloc)
    canvas.drawCircle(Offset.zero, 2.0, _paint);
  }

  double _easeOutCubic(double t) {
    final p = t - 1.0;
    return p * p * p + 1.0;
  }
}
