import 'package:flame/components.dart';

/// Marker for win-ceremony visuals (ripples, fireworks, their projectiles).
///
/// The next board drops every component with this mixin so a celebration
/// cannot keep drawing after the level changes.
mixin CelebrationVisual on Component {}
