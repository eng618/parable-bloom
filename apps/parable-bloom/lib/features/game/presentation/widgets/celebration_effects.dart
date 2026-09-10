import 'package:flame/components.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/constants/animation_timing.dart';
import '../../application/providers/gameplay_state_providers.dart';
import 'garden_game.dart';
import 'pond_ripple_effect_component.dart';
import 'ripple_fireworks_component.dart';

/// Shared congratulatory messages (previously copy-pasted per screen).
const List<String> kCongratulationMessages = [
  'Well done, good and faithful servant!',
  'Blessed are you in Christ!',
  'Your faith is bearing fruit!',
  'The Lord is with you always!',
  'Rejoice in the Lord!',
  'Grace upon grace!',
  'In His strength alone!',
  'Abundant life in Christ!',
  'A fruitful harvest awaits!',
  'Seeds of faith growing deep!',
  'Abide in His love!',
  'He makes your path straight!',
  'The joy of the Lord is your strength!',
  'Walk by faith, not by sight!',
  'Rooted and built up in Him!',
];

/// Time-based pick so consecutive completions vary the message.
String pickCongratulationMessage([List<String> messages = kCongratulationMessages]) {
  return messages[DateTime.now().millisecondsSinceEpoch % messages.length];
}

/// Spawns the selected celebration FX centered on [game].
/// Shared by the game and tutorial screens (previously literal-identical
/// switch statements in both).
void spawnCelebrationEffect({
  required GardenGame game,
  required CelebrationEffect effect,
  required bool isDark,
}) {
  final animationColors =
      isDark ? [AppTheme.secondarySeed] : [AppTheme.primarySeed];
  final center = Vector2(game.size.x / 2, game.size.y / 2);
  switch (effect) {
    case CelebrationEffect.pondRipples:
      game.add(
        PondRippleEffectComponent(
          center: center,
          maxRadius: (game.size.y * 0.45),
          ringCount: 4,
          duration: AnimationTiming.pondRippleSeconds,
          colors: animationColors,
        ),
      );
      break;
    case CelebrationEffect.rippleFireworks:
      game.add(
        RippleFireworksComponent(
          count: 8,
          duration: AnimationTiming.celebrationSpanSeconds,
          minRippleRadius: 30,
          maxRippleRadius: 64,
          colors: animationColors,
          paddingRatio: 0.12,
        ),
      );
      break;
  }
}
