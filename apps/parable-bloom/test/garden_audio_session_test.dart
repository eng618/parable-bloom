import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/core/services/garden_audio_session.dart';

void main() {
  test('session mixes the loop with cues and does not pause when ducked', () {
    expect(
      GardenAudioSession.configuration.androidAudioAttributes?.usage,
      AndroidAudioUsage.game,
    );
    expect(
      GardenAudioSession.configuration.androidAudioAttributes?.contentType,
      AndroidAudioContentType.music,
    );
    expect(
      GardenAudioSession.configuration.androidAudioFocusGainType,
      AndroidAudioFocusGainType.gain,
    );
    expect(
      GardenAudioSession.configuration.androidWillPauseWhenDucked,
      isFalse,
    );
    expect(
      GardenAudioSession.configuration.avAudioSessionCategory,
      AVAudioSessionCategory.playback,
    );
  });
}
