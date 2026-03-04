import "../services/logger_service.dart";
import "package:just_audio/just_audio.dart";

class BackgroundAudioController {
  final AudioPlayer _player;
  bool _enabled = false;
  bool _loaded = false;

  BackgroundAudioController({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;

    if (!_enabled) {
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

    try {
      await _player.play();
    } catch (e, stack) {
      // Autoplay is often blocked on web until user interaction
      LoggerService.warn("Background audio play failed (likely autoplay block)",
          error: e, stackTrace: stack, tag: 'BackgroundAudioController');
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
