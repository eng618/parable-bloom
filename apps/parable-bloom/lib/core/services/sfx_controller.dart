import 'dart:async';

import 'package:flutter/foundation.dart';

import 'garden_audio_engine.dart';
import 'logger_service.dart';
import 'soloud_garden_audio_engine.dart';

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

/// Sound effects mixed as voices of clips loaded once.
///
/// One-shot cues overlap, including a second tap of the same cue. The
/// foliage rustle is the only loop: a new play stops the previous voice
/// so the loops do not stack.
///
/// [GardenAudioEngine.play] returns the voice immediately, so a cue that
/// is still audible does not block the next one.
///
/// Pure unit tests without [WidgetsFlutterBinding] no-op instead of
/// touching the engine, unless an [engine] is injected.
class SfxController {
  SfxController({
    GardenAudioEngine? engine,
  }) : _engine = engine;

  final GardenAudioEngine? _engine;
  GardenAudioEngine? _resolved;
  final Map<GameSfx, GardenAudioClip> _clips = {};
  final Map<GameSfx, List<GardenAudioVoice>> _voices = {};
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

  /// Stop cues while the app is backgrounded. The preference in [setEnabled]
  /// stays as the user left it. The looping foliage rustle stops here so it
  /// does not keep playing after the garden leaves the screen.
  Future<void> setSuspended(bool suspended) async {
    _suspended = suspended;
    if (suspended) {
      await stopAll();
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    final engine = _engineForPlay();
    if (engine == null) return;
    for (final entry in _voices.entries) {
      final gain = _gain(entry.key, null);
      for (final voice in entry.value) {
        engine.setVolume(voice, gain);
      }
    }
  }

  Future<void> ensureLoaded() {
    if (_unavailable ||
        _clips.length + _unrecoverable.length == _assets.length) {
      return Future<void>.value();
    }
    return _loadTail ??= _loadAll().whenComplete(() {
      _loadTail = null;
    });
  }

  Future<void> _loadAll() async {
    final engine = _engineForPlay();
    if (engine == null) {
      _unavailable = true;
      return;
    }

    for (final entry in _assets.entries) {
      if (_unavailable) return;
      if (_clips.containsKey(entry.key) || _unrecoverable.contains(entry.key)) {
        continue;
      }
      try {
        _clips[entry.key] = await engine.load(entry.value, stream: false);
      } on GardenAudioLoadInterrupted {
        LoggerService.debug(
          'SFX load interrupted: ${entry.key.name}',
          tag: 'SfxController',
        );
      } on GardenAudioEngineUnavailable {
        _unavailable = true;
        LoggerService.warn(
          'SFX engine unavailable',
          tag: 'SfxController',
        );
        return;
      } catch (e, stack) {
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
    // Stop and suspend bump the generation. A second tap of the same
    // one-shot must not, or the first voice is cancelled before it starts.
    final generation = _generation(sfx);
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
    if (!_enabled || _suspended || _generation(sfx) != generation) return;
    await ensureLoaded();
    if (!_enabled ||
        _suspended ||
        _unavailable ||
        _generation(sfx) != generation) {
      return;
    }
    final clip = _clips[sfx];
    final engine = _engineForPlay();
    if (clip == null || engine == null) return;
    if (_looping.contains(sfx)) {
      await _stopVoices(sfx);
      if (!_enabled || _suspended || _generation(sfx) != generation) {
        return;
      }
    }
    try {
      final voice = engine.play(
        clip,
        volume: _gain(sfx, volumeScale),
        looping: _looping.contains(sfx),
      );
      if (_generation(sfx) != generation || _suspended || !_enabled) {
        await engine.stop(voice);
        return;
      }
      (_voices[sfx] ??= <GardenAudioVoice>[]).add(voice);
    } on GardenAudioPlayRejected {
      LoggerService.debug(
        'SFX play rejected: ${sfx.name}',
        tag: 'SfxController',
      );
    } catch (e, stack) {
      _logSfxIssue('SFX play failed: ${sfx.name}', e, stack);
    }
  }

  Future<void> stop(GameSfx sfx) async {
    _playGeneration[sfx] = (_playGeneration[sfx] ?? 0) + 1;
    await _stopVoices(sfx);
  }

  Future<void> stopAll() async {
    for (final sfx in _assets.keys) {
      _playGeneration[sfx] = (_playGeneration[sfx] ?? 0) + 1;
    }
    for (final sfx in _voices.keys.toList()) {
      await _stopVoices(sfx);
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

  Future<void> dispose() async {
    await stopAll();
    final engine = _engineForPlay();
    final clips = List<GardenAudioClip>.of(_clips.values);
    _clips.clear();
    _voices.clear();
    _playTails.clear();
    if (engine == null) return;
    for (final clip in clips) {
      await engine.disposeClip(clip);
    }
  }

  int _generation(GameSfx sfx) => _playGeneration[sfx] ?? 0;

  double _gain(GameSfx sfx, double? volumeScale) {
    final scale = (volumeScale ?? _defaultScales[sfx] ?? 1.0).clamp(0.0, 1.0);
    return _volume * scale;
  }

  GardenAudioEngine? _engineForPlay() {
    if (_engine != null) return _engine;
    if (_unavailable) return _resolved;
    if (BindingBase.debugBindingType() == null) return null;
    return _resolved ??= SoloudGardenAudioEngine();
  }

  Future<void> _stopVoices(GameSfx sfx) async {
    final voices = _voices.remove(sfx);
    if (voices == null || voices.isEmpty) return;
    final engine = _engineForPlay();
    if (engine == null) return;
    for (final voice in voices) {
      try {
        await engine.stop(voice);
      } catch (e, stack) {
        _logSfxIssue('SFX stop failed: ${sfx.name}', e, stack);
      }
    }
  }

  void _logSfxIssue(String message, Object error, StackTrace stack) {
    if (error is GardenAudioLoadInterrupted ||
        error is GardenAudioPlayRejected) {
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
}
