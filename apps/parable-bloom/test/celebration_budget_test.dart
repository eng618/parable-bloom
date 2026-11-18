import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/core/constants/animation_timing.dart';

void main() {
  test('the win-card hold covers pond ripples and fireworks', () {
    final holdMs = AnimationTiming.levelCompleteReadHold.inMilliseconds;
    expect(
      holdMs,
      greaterThanOrEqualTo(
        (AnimationTiming.pondRippleSeconds * 1000).round(),
      ),
    );
    expect(
      holdMs,
      greaterThanOrEqualTo(
        (AnimationTiming.fireworksLifetimeSeconds * 1000).round(),
      ),
    );
    expect(
      AnimationTiming.vineLastCruiseSecondsPerCell,
      greaterThan(AnimationTiming.vineCruiseSecondsPerCell),
    );
    expect(AnimationTiming.vineClearCapSeconds, greaterThan(1));
  });
}
