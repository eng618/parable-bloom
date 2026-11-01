import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/settings_providers.dart';
import '../../../../core/services/sfx_controller.dart';

/// Shared SFX dispatch used by [GameEventSink] implementations so game and
/// tutorial screens stay in sync without duplicated play calls.
void dispatchVineSlideStarted(ProviderContainer container) {
  unawaited(container.read(sfxControllerProvider).playVineSlide());
}

void dispatchVineSlideEnded(
  ProviderContainer container, {
  required bool cleared,
  required int vineLength,
}) {
  final sfx = container.read(sfxControllerProvider);
  if (cleared) {
    unawaited(sfx.playBloom(vineLength: vineLength));
  } else {
    unawaited(sfx.playBlocked());
  }
}

void dispatchUiTap(ProviderContainer container) {
  unawaited(container.read(sfxControllerProvider).play(GameSfx.uiTap));
}
