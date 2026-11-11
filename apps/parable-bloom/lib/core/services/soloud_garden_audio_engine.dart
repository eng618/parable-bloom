import 'package:flutter_soloud/flutter_soloud.dart';

import 'garden_audio_engine.dart';
import 'logger_service.dart';

/// [flutter_soloud] adapter. One process-wide engine, many voices.
///
/// Android attributes stay [AndroidAAudioAttributes.unmanaged] so
/// [GardenAudioSession] keeps `USAGE_GAME`. The default (`mediaMusic`)
/// would replace that on init.
class SoloudGardenAudioEngine implements GardenAudioEngine {
  SoloudGardenAudioEngine({SoLoud? soloud})
      : _soloud = soloud ?? SoLoud.instance;

  static Future<void>? _starting;

  final SoLoud _soloud;
  final Map<GardenAudioClip, AudioSource> _sources = {};
  final Map<GardenAudioVoice, SoundHandle> _handles = {};

  /// Safe to call more than once. A failed attempt is not cached.
  ///
  /// Call this after [GardenAudioSession.ensureConfigured] and before any
  /// controller loads a clip. Screenshot mode skips it.
  static Future<void> ensureInitialized() {
    final existing = _starting;
    if (existing != null) return existing;
    final run = _init();
    _starting = run;
    return run;
  }

  static Future<void> _init() async {
    try {
      if (SoLoud.instance.isInitialized) return;
      await SoLoud.instance.init(
        sampleRate: 44100,
        channels: Channels.stereo,
        lowLatency: true,
        androidAAudioAttributes: AndroidAAudioAttributes.unmanaged,
      );
    } catch (error, stack) {
      _starting = null;
      LoggerService.warn(
        'SoLoud init failed',
        error: error,
        stackTrace: stack,
        tag: 'SoloudGardenAudioEngine',
      );
    }
  }

  @override
  Future<GardenAudioClip> load(
    String assetPath, {
    required bool stream,
  }) async {
    if (!_soloud.isInitialized) {
      throw const GardenAudioEngineUnavailable();
    }
    try {
      final source = await _soloud.loadAsset(
        assetPath,
        mode: stream ? LoadMode.disk : LoadMode.memory,
      );
      final clip = GardenAudioClip();
      _sources[clip] = source;
      return clip;
    } on SoLoudNotInitializedException {
      throw const GardenAudioEngineUnavailable();
    }
  }

  @override
  GardenAudioVoice play(
    GardenAudioClip clip, {
    required double volume,
    required bool looping,
    bool protect = false,
  }) {
    final source = _sources[clip];
    if (source == null || !_soloud.isInitialized) {
      throw const GardenAudioPlayRejected();
    }
    final handle = _soloud.play(
      source,
      volume: volume,
      looping: looping,
    );
    if (!_soloud.getIsValidVoiceHandle(handle)) {
      throw const GardenAudioPlayRejected();
    }
    if (protect) {
      _soloud.setProtectVoice(handle, true);
    }
    final voice = GardenAudioVoice();
    _handles[voice] = handle;
    return voice;
  }

  @override
  void setVolume(GardenAudioVoice voice, double volume) {
    final handle = _liveHandle(voice);
    if (handle == null) return;
    _soloud.setVolume(handle, volume);
  }

  @override
  void pause(GardenAudioVoice voice) {
    final handle = _liveHandle(voice);
    if (handle == null) return;
    _soloud.setPause(handle, true);
  }

  @override
  void resume(GardenAudioVoice voice) {
    final handle = _liveHandle(voice);
    if (handle == null) return;
    _soloud.setPause(handle, false);
  }

  @override
  Future<void> stop(GardenAudioVoice voice) async {
    final handle = _handles.remove(voice);
    if (handle == null || !_soloud.isInitialized) return;
    if (!_soloud.getIsValidVoiceHandle(handle)) return;
    try {
      await _soloud.stop(handle);
    } on SoLoudException {
      // The voice ended between the validity check and the native stop.
    }
  }

  @override
  Future<void> disposeClip(GardenAudioClip clip) async {
    final source = _sources.remove(clip);
    if (source == null || !_soloud.isInitialized) return;
    try {
      await _soloud.disposeSource(source);
    } on SoLoudException {
      // Already disposed, or the engine shut down during teardown.
    }
  }

  SoundHandle? _liveHandle(GardenAudioVoice voice) {
    final handle = _handles[voice];
    if (handle == null || !_soloud.isInitialized) return null;
    if (!_soloud.getIsValidVoiceHandle(handle)) {
      _handles.remove(voice);
      return null;
    }
    return handle;
  }
}
