/// A clip loaded once and played as one or more voices.
///
/// Identity matters. The SoLoud adapter stores the native source on this
/// instance. Tests construct an empty clip.
final class GardenAudioClip {
  GardenAudioClip();
}

/// One playing instance of a [GardenAudioClip].
final class GardenAudioVoice {
  GardenAudioVoice();
}

/// The engine was not initialized. Controllers treat audio as unavailable.
class GardenAudioEngineUnavailable implements Exception {
  const GardenAudioEngineUnavailable();

  @override
  String toString() => 'GardenAudioEngineUnavailable';
}

/// A load was cancelled by a newer one. The next play retries it.
class GardenAudioLoadInterrupted implements Exception {
  const GardenAudioLoadInterrupted();

  @override
  String toString() => 'GardenAudioLoadInterrupted';
}

/// [GardenAudioEngine.play] returned without a voice.
///
/// On web this is how a missing user gesture shows up. The music controller
/// forgets the gesture so a later tap can try again.
class GardenAudioPlayRejected implements Exception {
  const GardenAudioPlayRejected();

  @override
  String toString() => 'GardenAudioPlayRejected';
}

/// Mixer operations the music loop and the sound-effect cues share.
///
/// [play] returns as soon as the voice exists. It does not wait for the
/// clip to finish. Production code uses `SoloudGardenAudioEngine`.
abstract class GardenAudioEngine {
  /// [stream] keeps a long file on disk. Short cues use memory.
  Future<GardenAudioClip> load(String assetPath, {required bool stream});

  /// Starts a voice. A rejected play throws [GardenAudioPlayRejected].
  GardenAudioVoice play(
    GardenAudioClip clip, {
    required double volume,
    required bool looping,
    bool protect = false,
  });

  void setVolume(GardenAudioVoice voice, double volume);

  void pause(GardenAudioVoice voice);

  void resume(GardenAudioVoice voice);

  Future<void> stop(GardenAudioVoice voice);

  Future<void> disposeClip(GardenAudioClip clip);
}
