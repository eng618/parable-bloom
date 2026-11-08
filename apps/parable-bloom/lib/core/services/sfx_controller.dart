import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'asset_audio_player.dart';
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

/// Lightweight multi-player SFX mixer. One player per cue so SFX can
/// overlap (slide + rustle, bloom over music) without cutting ambient audio.
///
/// Plays of the same cue are queued and only the latest one runs, so a
/// retrigger during seek does not cancel itself into silence. A load that
/// [just_audio] interrupts is retried on the next play.
///
/// Pure unit tests without [WidgetsFlutterBinding] no-op instead of asserting
/// on the binary messenger, unless a [playerFactory] is injected.
class SfxController {
  SfxController({
    AssetAudioPlayer Function()? playerFactory,
  })  : _playerFactory = playerFactory ?? JustAudioAssetPlayer.new,
        _platformPlayers = playerFactory == null;

  final AssetAudioPlayer Function() _playerFactory;
  final bool _platformPlayers;
  final Map<GameSfx, AssetAudioPlayer> _players = {};
  final Map<GameSfx, Future<void>> _playTails = {};
  final Map<GameSfx, int> _playGeneration = {};
  final Set<GameSfx> _unrecoverable = {};
  bool _enabled = true;
  bool _unavailable = false;
  double _volume = 0.72;

  static const Map<GameSfx, String> _assets = {
    GameSfx.vineSlideStart: 'assets/audio/sfx/vines/vine_slide_start.mp3',
    GameSfx.vineRustle: 'assets/audio/sfx/vines/vine_rustle.mp3',
    GameSfx.vineBloom: 'assets/audio/sfx/vines/vine_bloom.mp3',
    GameSfx.vineBloomLong: 'assets/audio/sfx/vines/vine_bloom_long.mp3',
    GameSfx.vineBlocked: 'assets/audio/sfx/vines/vine_blocked.mp3',
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
    if (_unavailable) return;
    if (_players.length == _assets.length) return;

    // No Flutter binding → no platform channels (pure unit tests).
    if (_platformPlayers && BindingBase.debugBindingType() == null) {
      _unavailable = true;
      return;
    }

    for (final entry in _assets.entries) {
      if (_players.containsKey(entry.key) ||
          _unrecoverable.contains(entry.key)) {
        continue;
      }
      final player = _playerFactory();
      try {
        await player.loadAsset(entry.value);
        await player.setVolume(_volume);
        if (entry.key == GameSfx.vineRustle) {
          await player.setLooping(true);
        }
        _players[entry.key] = player;
      } on PlayerInterruptedException {
        await _disposeQuietly(player);
        LoggerService.debug(
          'SFX load interrupted: ${entry.key.name}',
          tag: 'SfxController',
        );
      } catch (e, stack) {
        await _disposeQuietly(player);
        _unrecoverable.add(entry.key);
        _logSfxIssue('Failed to load SFX ${entry.key.name}', e, stack);
      }
    }
  }

  Future<void> play(
    GameSfx sfx, {
    double? volumeScale,
  }) {
    if (!_enabled || _unavailable || _unrecoverable.contains(sfx)) {
      return Future<void>.value();
    }
    final generation = (_playGeneration[sfx] ?? 0) + 1;
    _playGeneration[sfx] = generation;
    final previous = _playTails[sfx] ?? Future<void>.value();
    final done = Completer<void>();
    previous.whenComplete(() async {
      try {
        await _playLatest(sfx, generation, volumeScale);
        if (!done.isCompleted) done.complete();
      } catch (error, stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      }
    });
    _playTails[sfx] = done.future;
    return done.future;
  }

  Future<void> _playLatest(
    GameSfx sfx,
    int generation,
    double? volumeScale,
  ) async {
    if (!_enabled || _playGeneration[sfx] != generation) return;
    await ensureLoaded();
    if (!_enabled || _unavailable || _playGeneration[sfx] != generation) {
      return;
    }
    final player = _players[sfx];
    if (player == null) return;
    try {
      final scale = (volumeScale ?? 1.0).clamp(0.0, 1.0);
      await player.setVolume(_volume * scale);
      if (_playGeneration[sfx] != generation) return;
      await player.seekToStart();
      if (_playGeneration[sfx] != generation) return;
      await player.play();
    } catch (e, stack) {
      _logSfxIssue('SFX play failed: ${sfx.name}', e, stack);
    }
  }

  Future<void> stop(GameSfx sfx) async {
    final player = _players[sfx];
    if (player == null) return;
    try {
      await player.stop();
    } catch (e, stack) {
      _logSfxIssue('SFX stop failed: ${sfx.name}', e, stack);
    }
  }

  Future<void> stopAll() async {
    for (final entry in _players.entries) {
      try {
        await entry.value.stop();
      } catch (e, stack) {
        _logSfxIssue('SFX stopAll failed: ${entry.key.name}', e, stack);
      }
    }
  }

  /// Slide start + light looping rustle while a vine moves.
  Future<void> playVineSlide() async {
    await play(GameSfx.vineSlideStart, volumeScale: 0.9);
    // Keep continuous rustle very quiet under the soft whoosh.
    await play(GameSfx.vineRustle, volumeScale: 0.35);
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

  /// A newer load cancelling this one is normal (navigation, cue overlap).
  /// just_audio reports that as [PlayerInterruptedException]
  /// ("Loading interrupted").
  void _logSfxIssue(String message, Object error, StackTrace stack) {
    if (error is PlayerInterruptedException) {
      LoggerService.debug(message, tag: 'SfxController');
      return;
    }
    LoggerService.warn(
      message,
      error: error,
      stackTrace: stack,
      tag: 'SfxController',
    );
  }

  Future<void> dispose() async {
    for (final player in _players.values) {
      await _disposeQuietly(player);
    }
    _players.clear();
    _playTails.clear();
  }

  Future<void> _disposeQuietly(AssetAudioPlayer player) async {
    try {
      await player.dispose();
    } catch (e, stack) {
      _logSfxIssue('SFX dispose failed', e, stack);
    }
  }
}
