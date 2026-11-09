import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';

import 'asset_audio_player.dart';
import 'logger_service.dart';

/// Looping garden music.
///
/// Playback commands are queued so a load cannot finish after the listener
/// has turned music off, and an interrupted load is retried instead of
/// sticking until the next settings toggle. On web the first gesture is
/// remembered even when it arrives while [background.mp3] is still loading.
///
/// App lifecycle should call [setSuspended], not [setEnabled]. [setEnabled]
/// is the user's music preference. Suspending pauses the decoder in place;
/// [AudioPlayer.stop] would release it and force another load on resume.
///
/// [AssetAudioPlayer.play] is not awaited. On Android, just_audio completes
/// that future only when playback ends or someone pauses, and a loop never
/// ends. Waiting would leave [setSuspended] stuck behind it, so the loop
/// keeps playing after the app leaves the screen.
class BackgroundAudioController {
  BackgroundAudioController({
    AssetAudioPlayer? player,
    bool? isWeb,
  })  : _player = player ?? JustAudioAssetPlayer(),
        _isWeb = isWeb ?? kIsWeb;

  static const String assetPath = 'assets/audio/background.mp3';

  final AssetAudioPlayer _player;
  final bool _isWeb;

  bool _enabled = false;
  bool _suspended = false;
  bool _loaded = false;
  bool _loadFailed = false;
  bool _userInteracted = false;
  bool _playbackStarted = false;
  bool _interactionQueued = false;
  int _playGeneration = 0;
  Future<void> _tail = Future<void>.value();

  /// User preference. Does not release the decoder.
  Future<void> setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      _playbackStarted = false;
    } else {
      _loadFailed = false;
    }
    return _enqueue(() async {
      if (!_enabled) {
        await _safePause();
        return;
      }
      await _startIfAllowed();
    });
  }

  /// Pause while the app is backgrounded. The preference in [setEnabled]
  /// stays as the user left it.
  Future<void> setSuspended(bool suspended) {
    _suspended = suspended;
    if (suspended) {
      // Drop the in-flight start so a late play error cannot clear a
      // later resume, and cannot mark the loop as running while paused.
      _playbackStarted = false;
      _playGeneration++;
    }
    return _enqueue(() async {
      if (_suspended) {
        await _safePause();
        return;
      }
      await _startIfAllowed();
    });
  }

  /// Web autoplay unlock. Safe to call before the asset has loaded, and
  /// again if the browser later rejects [play].
  Future<void> notifyUserInteraction() {
    _userInteracted = true;
    if (_playbackStarted && _enabled && !_suspended) {
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
    _playbackStarted = false;
    _playGeneration++;
    return _enqueue(_player.dispose);
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
    if (!_enabled || _suspended || _playbackStarted) return;
    if (_isWeb && !_userInteracted) {
      await _ensureLoaded();
      return;
    }
    await _ensureLoaded();
    if (!_loaded || !_enabled || _suspended || _playbackStarted) return;
    if (_isWeb && !_userInteracted) return;

    final generation = ++_playGeneration;
    _playbackStarted = true;
    unawaited(
      _player.play().then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          if (generation != _playGeneration) return;
          _playbackStarted = false;
          if (error is PlayerInterruptedException) {
            LoggerService.debug(
              'Background audio play interrupted',
              tag: 'BackgroundAudioController',
            );
            return;
          }
          if (_isWeb) {
            // The browser can reject play until a later gesture.
            _userInteracted = false;
          }
          LoggerService.warn(
            'Background audio play failed',
            error: error,
            stackTrace: stack,
            tag: 'BackgroundAudioController',
          );
        },
      ),
    );
  }

  Future<void> _ensureLoaded() async {
    if (_loaded || _loadFailed) return;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _player.loadAsset(assetPath);
        await _player.setLooping(true);
        _loaded = true;
        return;
      } on PlayerInterruptedException {
        // A newer load cancelled this one. Try once more, then wait for
        // the next play request to call here again.
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

  Future<void> _safePause() async {
    try {
      await _player.pause();
    } on PlayerInterruptedException {
      LoggerService.debug(
        'Background audio pause interrupted',
        tag: 'BackgroundAudioController',
      );
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
