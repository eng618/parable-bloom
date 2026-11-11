import 'dart:async';

import 'package:flutter/foundation.dart' show BindingBase, kIsWeb;

import 'garden_audio_engine.dart';
import 'logger_service.dart';
import 'soloud_garden_audio_engine.dart';

/// Looping garden music.
///
/// Playback commands are queued so a load cannot finish after the listener
/// has turned music off, and an interrupted load is retried instead of
/// sticking until the next settings toggle. On web the first gesture is
/// remembered even when it arrives while [background.mp3] is still loading.
///
/// App lifecycle should call [setSuspended], not [setEnabled]. [setEnabled]
/// is the user's music preference. Suspending pauses the voice in place.
/// The clip stays loaded, so resume does not seek and does not start a
/// second loop.
///
/// [GardenAudioEngine.play] is not awaited for the length of the loop. It
/// returns the voice immediately.
class BackgroundAudioController {
  BackgroundAudioController({
    GardenAudioEngine? engine,
    bool? isWeb,
  })  : _engine = engine,
        _isWeb = isWeb ?? kIsWeb;

  static const String assetPath = 'assets/audio/background.mp3';

  final GardenAudioEngine? _engine;
  final bool _isWeb;

  GardenAudioEngine? _resolved;
  GardenAudioClip? _clip;
  GardenAudioVoice? _voice;
  bool _voicePaused = false;
  bool _enabled = false;
  bool _suspended = false;
  bool _loaded = false;
  bool _loadFailed = false;
  bool _userInteracted = false;
  bool _interactionQueued = false;
  Future<void> _tail = Future<void>.value();

  /// User preference. Does not release the clip.
  Future<void> setEnabled(bool enabled) {
    _enabled = enabled;
    if (enabled) {
      _loadFailed = false;
    }
    return _enqueue(() async {
      if (!_enabled || _suspended) {
        _pauseVoice();
        return;
      }
      await _startIfAllowed();
    });
  }

  /// Pause while the app is backgrounded. The preference in [setEnabled]
  /// stays as the user left it.
  Future<void> setSuspended(bool suspended) {
    _suspended = suspended;
    return _enqueue(() async {
      if (_suspended || !_enabled) {
        _pauseVoice();
        return;
      }
      await _startIfAllowed();
    });
  }

  /// Web autoplay unlock. Safe to call before the asset has loaded, and
  /// again if the browser later rejects [play].
  Future<void> notifyUserInteraction() {
    _userInteracted = true;
    if (_voice != null && _enabled && !_suspended) {
      return Future<void>.value();
    }
    if (_interactionQueued) return Future<void>.value();
    _interactionQueued = true;
    return _enqueue(() async {
      _interactionQueued = false;
      await _startIfAllowed();
    });
  }

  Future<void> dispose() {
    _enabled = false;
    _suspended = true;
    return _enqueue(() async {
      final engine = _activeEngine();
      final voice = _voice;
      final clip = _clip;
      _voice = null;
      _clip = null;
      _voicePaused = false;
      _loaded = false;
      if (engine == null) return;
      if (voice != null) {
        await engine.stop(voice);
      }
      if (clip != null) {
        await engine.disposeClip(clip);
      }
    });
  }

  GardenAudioEngine? _activeEngine() {
    if (_engine != null) return _engine;
    if (BindingBase.debugBindingType() == null) return null;
    return _resolved ??= SoloudGardenAudioEngine();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final done = Completer<void>();
    _tail.whenComplete(() async {
      try {
        await action();
        if (!done.isCompleted) done.complete();
      } catch (error, stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      }
    });
    _tail = done.future;
    return done.future;
  }

  Future<void> _startIfAllowed() async {
    if (!_enabled || _suspended) return;
    if (_isWeb && !_userInteracted) {
      await _ensureLoaded();
      return;
    }
    await _ensureLoaded();
    if (!_loaded || !_enabled || _suspended) return;
    if (_isWeb && !_userInteracted) return;

    final engine = _activeEngine();
    final clip = _clip;
    if (engine == null || clip == null) return;

    final existing = _voice;
    if (existing != null) {
      if (!_voicePaused) return;
      try {
        engine.resume(existing);
        _voicePaused = false;
      } catch (error, stack) {
        LoggerService.warn(
          'Background audio resume failed',
          error: error,
          stackTrace: stack,
          tag: 'BackgroundAudioController',
        );
      }
      return;
    }

    try {
      _voice = engine.play(
        clip,
        volume: 1,
        looping: true,
        protect: true,
      );
      _voicePaused = false;
    } on GardenAudioPlayRejected {
      _voice = null;
      if (_isWeb) {
        // The browser can reject play until a later gesture.
        _userInteracted = false;
      }
      LoggerService.debug(
        'Background audio play rejected',
        tag: 'BackgroundAudioController',
      );
    } catch (error, stack) {
      _voice = null;
      if (_isWeb) {
        _userInteracted = false;
      }
      LoggerService.warn(
        'Background audio play failed',
        error: error,
        stackTrace: stack,
        tag: 'BackgroundAudioController',
      );
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded || _loadFailed) return;
    final engine = _activeEngine();
    if (engine == null) {
      _loadFailed = true;
      return;
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        _clip = await engine.load(assetPath, stream: true);
        _loaded = true;
        return;
      } on GardenAudioLoadInterrupted {
        // A newer load cancelled this one. Try once more, then wait for
        // the next play request to call here again.
      } on GardenAudioEngineUnavailable {
        _loadFailed = true;
        LoggerService.warn(
          'Background audio engine unavailable',
          tag: 'BackgroundAudioController',
        );
        return;
      } catch (e, stack) {
        _loadFailed = true;
        LoggerService.error(
          'Failed to load background audio asset',
          error: e,
          stackTrace: stack,
          tag: 'BackgroundAudioController',
        );
        return;
      }
    }
    LoggerService.debug(
      'Background audio load interrupted',
      tag: 'BackgroundAudioController',
    );
  }

  void _pauseVoice() {
    final engine = _activeEngine();
    final voice = _voice;
    if (engine == null || voice == null || _voicePaused) return;
    try {
      engine.pause(voice);
      _voicePaused = true;
    } catch (e, stack) {
      LoggerService.warn(
        'Background audio pause failed',
        error: e,
        stackTrace: stack,
        tag: 'BackgroundAudioController',
      );
    }
  }
}
