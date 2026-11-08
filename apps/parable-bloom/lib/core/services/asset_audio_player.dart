import 'package:just_audio/just_audio.dart';

/// The playback operations both the music loop and the SFX mixer need.
///
/// Production code uses [JustAudioAssetPlayer]. Tests supply a fake so the
/// controllers can be exercised without platform channels.
abstract class AssetAudioPlayer {
  Future<void> loadAsset(String assetPath);

  Future<void> setVolume(double volume);

  Future<void> setLooping(bool looping);

  Future<void> seekToStart();

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> dispose();
}

/// [just_audio] adapter. One instance owns one [AudioPlayer].
class JustAudioAssetPlayer implements AssetAudioPlayer {
  JustAudioAssetPlayer({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> loadAsset(String assetPath) {
    return _player.setAsset(assetPath);
  }

  @override
  Future<void> setVolume(double volume) {
    return _player.setVolume(volume);
  }

  @override
  Future<void> setLooping(bool looping) {
    return _player.setLoopMode(looping ? LoopMode.one : LoopMode.off);
  }

  @override
  Future<void> seekToStart() {
    return _player.seek(Duration.zero);
  }

  @override
  Future<void> play() {
    return _player.play();
  }

  @override
  Future<void> pause() {
    return _player.pause();
  }

  @override
  Future<void> stop() {
    return _player.stop();
  }

  @override
  Future<void> dispose() {
    return _player.dispose();
  }
}
