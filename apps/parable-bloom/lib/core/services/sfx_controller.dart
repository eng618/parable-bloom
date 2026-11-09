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
  levelSwell,
  uiTap,
  uiMenuOpen,
  uiMenuClose,
  uiConfirm,
  uiCancel,
}

/// Lightweight multi-player SFX mixer. One player per cue so SFX can
/// overlap (slide + rustle, bloom over music) without cutting ambient audio.
///
/// Plays of the same cue are queued and only the latest one runs, so a
/// retrigger during seek does not cancel itself into silence. A load that
/// [just_audio] interrupts is retried on the next play.
///
/// [AssetAudioPlayer.play] is not awaited. On Android that future stays
/// pending until the cue ends or the player is paused, and the looping
/// foliage rustle never ends. Waiting would freeze later plays of that cue.
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
  bool _suspended = false;
  bool _unavailable = false;
  double _volume = 0.72;
  Future<void>? _loadTail;

  static const Map<GameSfx, String> _assets = {
    GameSfx.vineSlideStart: 'assets/audio/sfx/vines/vine_slide_start.mp3',
    GameSfx.vineRustle: 'assets/audio/sfx/vines/vine_foliage_rustle_01.wav',
    GameSfx.vineBloom: 'assets/audio/sfx/vines/vine_bloom.mp3',
    GameSfx.vineBloomLong: 'assets/audio/sfx/vines/vine_bloom_long.mp3',
    GameSfx.vineBlocked: 'assets/audio/sfx/vines/vine_blocked.mp3',
    GameSfx.graceLoss: 'assets/audio/sfx/grace_loss.mp3',
    GameSfx.levelComplete: 'assets/audio/sfx/level_complete.mp3',
    GameSfx.levelSwell: 'assets/audio/sfx/vines/vine_foliage_rustle_02.wav',
    GameSfx.uiTap: 'assets/audio/sfx/ui/ui_clicked_in.wav',
    GameSfx.uiMenuOpen: 'assets/audio/sfx/ui/ui_menu_open.wav',
    GameSfx.uiMenuClose: 'assets/audio/sfx/ui/ui_menu_close.wav',
    GameSfx.uiConfirm: 'assets/audio/sfx/ui/ui_confirm.wav',
    GameSfx.uiCancel: 'assets/audio/sfx/ui/ui_cancel.wav',
  };

  /// Per-cue gain under the master SFX volume. UI stays quieter than vines.
  static const Map<GameSfx, double> _defaultScales = {
    GameSfx.vineSlideStart: 0.82,
    GameSfx.vineRustle: 0.2,
    GameSfx.vineBloom: 0.7,
    GameSfx.vineBloomLong: 0.7,
    GameSfx.vineBlocked: 0.55,
    GameSfx.graceLoss: 0.58,
    GameSfx.levelComplete: 0.66,
    GameSfx.levelSwell: 0.16,
    GameSfx.uiTap: 0.38,
    GameSfx.uiMenuOpen: 0.5,
    GameSfx.uiMenuClose: 0.46,
    GameSfx.uiConfirm: 0.42,
    GameSfx.uiCancel: 0.38,
  };

  static const Set<GameSfx> _looping = {GameSfx.vineRustle};

  bool get enabled => _enabled;

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (!enabled) {
      await stopAll();
    }
  }

  /// Pause cues while the app is backgrounded. The preference in [setEnabled]
  /// stays as the user left it. The looping foliage rustle is stopped here
  /// so it does not keep playing after the garden leaves the screen.
  Future<void> setSuspended(bool suspended) async {
    _suspended = suspended;
    if (suspended) {
      await stopAll();
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    for (final player in _players.values) {
      await player.setVolume(_volume);
    }
  }

  Future<void> ensureLoaded() {
    if (_unavailable || _players.length == _assets.length) {
      return Future<void>.value();
    }
    return _loadTail ??= _loadAll().whenComplete(() {
      _loadTail = null;
    });
  }

  Future<void> _loadAll() async {
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
        await player.setVolume(_volume * (_defaultScales[entry.key] ?? 1.0));
        if (_looping.contains(entry.key)) {
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
    if (!_enabled ||
        _suspended ||
        _unavailable ||
        _unrecoverable.contains(sfx)) {
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
    if (!_enabled || _suspended || _playGeneration[sfx] != generation) return;
    await ensureLoaded();
    if (!_enabled ||
        _suspended ||
        _unavailable ||
        _playGeneration[sfx] != generation) {
      return;
    }
    final player = _players[sfx];
    if (player == null) return;
    try {
      final scale = (volumeScale ?? _defaultScales[sfx] ?? 1.0).clamp(0.0, 1.0);
      await player.setVolume(_volume * scale);
      if (_playGeneration[sfx] != generation || _suspended) return;
      await player.seekToStart();
      if (_playGeneration[sfx] != generation || _suspended) return;
      unawaited(
        player.play().then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            _logSfxIssue('SFX play failed: ${sfx.name}', error, stack);
          },
        ),
      );
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

  /// Slide start plus a quiet looping foliage rustle while a vine moves.
  Future<void> playVineSlide() async {
    await Future.wait([
      play(GameSfx.vineSlideStart),
      play(GameSfx.vineRustle),
    ]);
  }

  Future<void> playMenuOpen() => play(GameSfx.uiMenuOpen);

  Future<void> playMenuClose() => play(GameSfx.uiMenuClose);

  Future<void> playConfirm() => play(GameSfx.uiConfirm);

  Future<void> playCancel() => play(GameSfx.uiCancel);

  /// Existing clear chime with a short, quiet foliage swell underneath.
  Future<void> playLevelComplete() async {
    await Future.wait([
      play(GameSfx.levelComplete),
      play(GameSfx.levelSwell),
    ]);
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
