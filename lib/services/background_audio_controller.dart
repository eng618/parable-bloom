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
      await _player.setAsset("assets/audio/background.mp3");
      await _player.setLoopMode(LoopMode.one);
      _loaded = true;
    }

    try {
      await _player.play();
    } catch (_) {
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
