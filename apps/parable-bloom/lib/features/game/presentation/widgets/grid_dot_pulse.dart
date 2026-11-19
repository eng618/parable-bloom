import 'dart:math' as math;

import 'package:parable_bloom/core/constants/animation_timing.dart';

/// One scale throb for a grid dot a clearing vine has just uncovered.
///
/// The resting dot is only a few pixels, and a zoomed-out board makes it
/// smaller still, so the peak is twice the resting radius. It grows and
/// settles once, then stays still.
class GridDotPulse {
  const GridDotPulse._();

  static const double duration = AnimationTiming.gridDotPulseSeconds;

  /// Added to 1 at the middle of the throb. Peak scale is `1 + amplitude`.
  static const double amplitude = 1.0;

  /// Scale at [elapsed] seconds after the throb starts.
  ///
  /// Returns 1 before the start and once the throb has finished.
  static double scaleAt(double elapsed) {
    if (elapsed <= 0 || elapsed >= duration) return 1;
    final t = elapsed / duration;
    return 1 + amplitude * math.sin(math.pi * t);
  }
}
