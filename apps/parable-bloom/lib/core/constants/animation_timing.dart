/// Centralized timing values for gameplay and camera animations.
class AnimationTiming {
  static const double cameraTransitionSeconds = 0.8;

  /// Legacy blocked-wiggle step. Successful clears use [vineCruiseSecondsPerCell].
  static const double vineStepSeconds = 0.05;
  static const double vineBloomSeconds = 0.5;

  /// On-screen cruise for a clear that does not empty the board.
  /// About 260 px/s at the 42px lane pitch — slow enough to read, fast
  /// enough that a chain of taps still feels responsive.
  static const double vineCruiseSecondsPerCell = 0.16;

  /// Cruise for the vine that empties the board. The final exit is the
  /// ending beat, so it lingers longer than a mid-level clear.
  static const double vineLastCruiseSecondsPerCell = 0.24;

  /// Cells of gentle deceleration as the head crosses the board edge.
  static const double vineEdgeSettleCells = 1.5;

  /// Upper bound on one clear, met by speeding the off-screen tail only.
  /// The approach to the edge always keeps the cruise above.
  static const double vineClearCapSeconds = 2.8;

  /// Tap ripple ring lifespan.
  static const double tapEffectSeconds = 0.4;

  /// Pond-ripple celebration. Matches [levelCompleteReadHold] so the rings
  /// finish as the encouraging line finishes, not on the next board.
  static const double pondRippleSeconds = 3.2;

  /// Impact ripple lifespan for celebration fireworks.
  static const double fireworkRippleSeconds = 1.2;

  /// Celebration fireworks coordinator lifespan (total launch span).
  static const double celebrationSpanSeconds = 1.6;

  /// Firework travel time range (base + random span).
  static const double fireworkTravelBaseSeconds = 0.30;
  static const double fireworkTravelSpanSeconds = 0.30;

  /// Latest a firework ripple can still be on screen, measured from spawn.
  /// Launch times fill the first 80% of [celebrationSpanSeconds].
  static double get fireworksLifetimeSeconds =>
      celebrationSpanSeconds * 0.8 +
      fireworkTravelBaseSeconds +
      fireworkTravelSpanSeconds +
      fireworkRippleSeconds;

  /// Pause so the player registers the camera move before auto-clearing.
  static const Duration autoClearPause = Duration(milliseconds: 200);

  /// Empty garden between the last vine leaving and the win card.
  static const Duration levelCompleteBreath = Duration(milliseconds: 350);

  /// Card fade in. The read hold below starts after this finishes.
  static const Duration levelCompleteFadeIn = Duration(milliseconds: 400);

  /// Card fade out. The next board is already underneath.
  static const Duration levelCompleteFadeOut = Duration(milliseconds: 450);

  /// How long the encouraging line stays fully visible. Pond ripples and
  /// fireworks are budgeted to finish inside this hold.
  static const Duration levelCompleteReadHold = Duration(milliseconds: 3200);

  static double get levelCompleteReadHoldSeconds =>
      levelCompleteReadHold.inMilliseconds / 1000;

  /// Scrim behind the win card. Light enough that the cleared garden and
  /// the celebration still read around the parchment.
  static const double levelCompleteScrimOpacity = 0.45;

  /// Tutorial guide pulse cycle and blocked-tap indicator timeout.
  static const Duration guidePulse = Duration(milliseconds: 1500);
  static const Duration blockedTapDisplay = Duration(milliseconds: 1500);

  /// Camera animation tick. Timer-driven at ~60Hz; Flame itself still
  /// renders at the display refresh rate (90/120Hz), and applyCameraFrame is
  /// allocation-free per tick so interpolation stays smooth on ProMotion.
  static const Duration cameraTick = Duration(milliseconds: 16);

  const AnimationTiming._();
}

/// Polls until no vine is animating, or until the caller is no longer alive.
///
/// The win card and the lesson advance wait on this so a slow exit is not
/// covered up. A short poll keeps the wait cancellable when the player
/// leaves, without a provider subscription to close.
Future<void> waitUntilVinesSettled({
  required bool Function() isAlive,
  required bool Function() isAnimating,
}) async {
  while (isAlive()) {
    try {
      if (!isAnimating()) return;
    } on StateError {
      return;
    }
    await Future.delayed(const Duration(milliseconds: 40));
  }
}
