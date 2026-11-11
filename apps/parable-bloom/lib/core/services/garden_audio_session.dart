import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import 'logger_service.dart';

/// One audio session for the music loop and every sound effect.
///
/// Configured before `SoloudGardenAudioEngine.ensureInitialized`. SoLoud
/// is left unmanaged on Android so it does not replace this usage with
/// media playback. Exclusive media focus drops short cues.
class GardenAudioSession {
  GardenAudioSession._();

  static Future<void>? _configured;

  /// Game usage mixes the loop with cues. Playback on iOS matches the
  /// previous default so the silent switch still mutes the garden.
  static const AudioSessionConfiguration configuration =
      AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionMode: AVAudioSessionMode.defaultMode,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.music,
      usage: AndroidAudioUsage.game,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    androidWillPauseWhenDucked: false,
  );

  /// Safe to call more than once. A failed attempt is not cached.
  static Future<void> ensureConfigured() {
    final existing = _configured;
    if (existing != null) return existing;
    final run = _configure();
    _configured = run;
    return run;
  }

  static Future<void> _configure() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(configuration);
    } catch (error, stack) {
      _configured = null;
      LoggerService.warn(
        'Audio session configuration failed',
        error: error,
        stackTrace: stack,
        tag: 'GardenAudioSession',
      );
    }
  }

  /// Takes or releases audio focus. Playback also activates the session;
  /// releasing it on suspend is what lets the loop actually stop.
  static Future<void> setActive(bool active) async {
    if (kIsWeb) return;
    try {
      await ensureConfigured();
      final session = await AudioSession.instance;
      await session.setActive(active);
    } catch (error, stack) {
      LoggerService.warn(
        'Audio session setActive($active) failed',
        error: error,
        stackTrace: stack,
        tag: 'GardenAudioSession',
      );
    }
  }
}
