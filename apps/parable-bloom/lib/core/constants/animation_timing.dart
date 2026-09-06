/// Centralized timing values for gameplay and camera animations.
class AnimationTiming {
  static const double cameraTransitionSeconds = 0.8;
  static const double vineStepSeconds = 0.05;
  static const double vineBloomSeconds = 0.5;

  /// Tap ripple ring lifespan.
  static const double tapEffectSeconds = 0.4;

  /// Celebration pond-ripple lifespan.
  static const double pondRippleSeconds = 2.0;

  /// Impact ripple lifespan for celebration fireworks.
  static const double fireworkRippleSeconds = 1.6;

  /// Firework travel time range (base + random span).
  static const double fireworkTravelBaseSeconds = 0.35;
  static const double fireworkTravelSpanSeconds = 0.45;

  /// Pause so the player registers the camera move before auto-clearing.
  static const Duration autoClearPause = Duration(milliseconds: 200);

  /// Beat before the level-complete overlay appears.
  static const Duration levelCompleteDelay = Duration(seconds: 2);

  /// Tutorial guide pulse cycle and blocked-tap indicator timeout.
  static const Duration guidePulse = Duration(milliseconds: 1500);
  static const Duration blockedTapDisplay = Duration(milliseconds: 1500);

  /// Camera animation tick (drives 60fps interpolation).
  static const Duration cameraTick = Duration(milliseconds: 16);

  const AnimationTiming._();
}
