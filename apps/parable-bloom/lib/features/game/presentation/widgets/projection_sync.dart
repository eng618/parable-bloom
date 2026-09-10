import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/gameplay_state_providers.dart';
import 'garden_game.dart';

/// Single implementation of the projection-lines sync previously
/// copy-pasted in `_updateProjectionLinesVisibility` on both the game and
/// tutorial screens: suppress transient modes during animations, then
/// forward the settled filter state to Flame.
void syncProjectionLines(WidgetRef ref, GardenGame? game) {
  if (game == null) return;
  final notifier = ref.read(projectionModeProvider.notifier);
  final isAnimating = ref.read(anyVineAnimatingProvider);
  notifier.suppressDuringAnimation(isAnimating);
  final mode = ref.read(projectionModeProvider);
  game.updateProjectionLinesVisibility(
    visible: mode.showAll,
    hintedVines: mode.hintedVineIds,
    isAnimating: isAnimating,
  );
}
