import 'package:flutter/foundation.dart' show kIsWeb;

import "../services/logger_service.dart";
import "package:just_audio/just_audio.dart";

class BackgroundAudioController {
  final AudioPlayer _player;
  bool _enabled = false;
  bool _loaded = false;
  // On web, autoplay is blocked until first user interaction.
  bool _awaitingInteraction = false;

  BackgroundAudioController({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;

    if (!_enabled) {
      _awaitingInteraction = false;
      await _player.stop();
      return;
    }

    if (!_loaded) {
      try {
        await _player.setAsset("assets/audio/background.mp3");
        await _player.setLoopMode(LoopMode.one);
        _loaded = true;
      } catch (e, stack) {
        LoggerService.error("Failed to load background audio asset",
            error: e, stackTrace: stack, tag: 'BackgroundAudioController');
        return;
      }
    }

    // On web, defer play until the user first interacts with the page.
    if (kIsWeb) {
      _awaitingInteraction = true;
      return;
    }

    try {
      await _player.play();
    } catch (e, stack) {
      LoggerService.warn("Background audio play failed",
          error: e, stackTrace: stack, tag: 'BackgroundAudioController');
    }
  }

  /// Called on the first pointer-down event on web.
  /// Starts playback if audio was enabled but held back by autoplay policy.
  Future<void> notifyUserInteraction() async {
    if (!_awaitingInteraction || !_enabled) return;
    _awaitingInteraction = false;
    try {
      await _player.play();
    } catch (e, stack) {
      LoggerService.warn("Background audio play failed after interaction",
          error: e, stackTrace: stack, tag: 'BackgroundAudioController');
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
