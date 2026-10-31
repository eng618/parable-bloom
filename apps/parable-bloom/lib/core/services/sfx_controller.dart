import 'package:just_audio/just_audio.dart';

import 'logger_service.dart';

/// Gameplay / UI sound effects that sit on top of ambient music.
enum GameSfx {
  vineSlideStart,
  vineRustle,
  vineBloom,
  vineBloomLong,
  vineBlocked,
  graceLoss,
  levelComplete,
  uiTap,
}

/// Lightweight multi-player SFX mixer. One [AudioPlayer] per cue so SFX can
/// overlap (slide + rustle, bloom over music) without cutting ambient audio.
class SfxController {
  SfxController({
    AudioPlayer Function()? playerFactory,
  }) : _playerFactory = playerFactory ?? AudioPlayer.new;

  final AudioPlayer Function() _playerFactory;
  final Map<GameSfx, AudioPlayer> _players = {};
  bool _enabled = true;
  bool _loaded = false;
  double _volume = 0.85;

  static const Map<GameSfx, String> _assets = {
    GameSfx.vineSlideStart: 'assets/audio/sfx/vine_slide_start.mp3',
    GameSfx.vineRustle: 'assets/audio/sfx/vine_rustle.mp3',
    GameSfx.vineBloom: 'assets/audio/sfx/vine_bloom.mp3',
    GameSfx.vineBloomLong: 'assets/audio/sfx/vine_bloom_long.mp3',
    GameSfx.vineBlocked: 'assets/audio/sfx/vine_blocked.mp3',
    GameSfx.graceLoss: 'assets/audio/sfx/grace_loss.mp3',
    GameSfx.levelComplete: 'assets/audio/sfx/level_complete.mp3',
    GameSfx.uiTap: 'assets/audio/sfx/ui_tap.mp3',
  };

  bool get enabled => _enabled;

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (!enabled) {
      await stopAll();
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    for (final player in _players.values) {
      await player.setVolume(_volume);
    }
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    for (final entry in _assets.entries) {
      try {
        final player = _playerFactory();
        await player.setAsset(entry.value);
        await player.setVolume(_volume);
        if (entry.key == GameSfx.vineRustle) {
          await player.setLoopMode(LoopMode.one);
        }
        _players[entry.key] = player;
      } catch (e, stack) {
        LoggerService.warn(
          'Failed to load SFX ${entry.key.name}',
          error: e,
          stackTrace: stack,
          tag: 'SfxController',
        );
      }
    }
    _loaded = true;
  }

  Future<void> play(
    GameSfx sfx, {
    double? volumeScale,
  }) async {
    if (!_enabled) return;
    await ensureLoaded();
    final player = _players[sfx];
    if (player == null) return;
    try {
      final scale = (volumeScale ?? 1.0).clamp(0.0, 1.0);
      await player.setVolume(_volume * scale);
      await player.seek(Duration.zero);
      await player.play();
    } catch (e, stack) {
      LoggerService.warn(
        'SFX play failed: ${sfx.name}',
        error: e,
        stackTrace: stack,
        tag: 'SfxController',
      );
    }
  }

  Future<void> stop(GameSfx sfx) async {
    final player = _players[sfx];
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {}
  }

  Future<void> stopAll() async {
    for (final player in _players.values) {
      try {
        await player.stop();
      } catch (_) {}
    }
  }

  /// Slide start + light looping rustle while a vine moves.
  Future<void> playVineSlide() async {
    await play(GameSfx.vineSlideStart);
    await play(GameSfx.vineRustle, volumeScale: 0.55);
  }

  Future<void> stopVineMotion() async {
    await stop(GameSfx.vineRustle);
  }

  /// Successful clear/bloom; longer vines get the warmer flourish.
  Future<void> playBloom({int vineLength = 1}) async {
    await stopVineMotion();
    if (vineLength >= 5) {
      await play(GameSfx.vineBloomLong);
    } else {
      await play(GameSfx.vineBloom);
    }
  }

  Future<void> playBlocked() async {
    await stopVineMotion();
    await play(GameSfx.vineBlocked);
  }

  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
    _loaded = false;
  }
}
