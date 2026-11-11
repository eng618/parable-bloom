import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/core/services/background_audio_controller.dart';
import 'package:parable_bloom/core/services/garden_audio_engine.dart';

void main() {
  test('web gesture during load still starts the loop', () async {
    final gate = _Gate();
    final engine = _FakeEngine(onLoad: () => gate.wait());
    final controller = BackgroundAudioController(engine: engine, isWeb: true);

    final enabling = controller.setEnabled(true);
    await gate.entered;
    final interaction = controller.notifyUserInteraction();
    gate.release();
    await enabling;
    await interaction;

    expect(engine.loads, [BackgroundAudioController.assetPath]);
    expect(engine.streams.single, isTrue);
    expect(engine.plays, 1);
    expect(engine.loopingPlays, 1);
    expect(engine.protectedPlays, 1);
    await controller.dispose();
  });

  test('web does not play until a gesture', () async {
    final engine = _FakeEngine();
    final controller = BackgroundAudioController(engine: engine, isWeb: true);

    await controller.setEnabled(true);
    expect(engine.plays, 0);
    expect(engine.loads, [BackgroundAudioController.assetPath]);

    await controller.notifyUserInteraction();
    expect(engine.plays, 1);
    await controller.dispose();
  });

  test('a rejected web play is retried on the next gesture', () async {
    final engine = _FakeEngine()..rejectNextPlay = true;
    final controller = BackgroundAudioController(engine: engine, isWeb: true);

    await controller.setEnabled(true);
    await controller.notifyUserInteraction();
    expect(engine.plays, 0);

    await controller.notifyUserInteraction();
    expect(engine.plays, 1);
    await controller.dispose();
  });

  test('turning music off during load does not start playback', () async {
    final gate = _Gate();
    final engine = _FakeEngine(onLoad: () => gate.wait());
    final controller = BackgroundAudioController(engine: engine, isWeb: false);

    final enabling = controller.setEnabled(true);
    await gate.entered;
    final disabling = controller.setEnabled(false);
    gate.release();
    await enabling;
    await disabling;

    expect(engine.plays, 0);
    await controller.dispose();
  });

  test('interrupted load is retried and then plays', () async {
    final engine = _FakeEngine()..failLoadOnce = true;
    final controller = BackgroundAudioController(engine: engine, isWeb: false);

    await controller.setEnabled(true);

    expect(engine.loads, [
      BackgroundAudioController.assetPath,
      BackgroundAudioController.assetPath,
    ]);
    expect(engine.plays, 1);
    await controller.dispose();
  });

  test('backgrounding pauses the same voice and resume does not reload',
      () async {
    final engine = _FakeEngine();
    final controller = BackgroundAudioController(engine: engine, isWeb: false);

    await controller.setEnabled(true);
    await controller.setSuspended(true);
    await controller.setSuspended(false);

    expect(engine.plays, 1);
    expect(engine.pauses, 1);
    expect(engine.resumes, 1);
    expect(engine.loads, [BackgroundAudioController.assetPath]);
    await controller.dispose();
  });

  test('enabling music twice does not start a second loop', () async {
    final engine = _FakeEngine();
    final controller = BackgroundAudioController(engine: engine, isWeb: false);

    await controller.setEnabled(true);
    await controller.setEnabled(true);

    expect(engine.plays, 1);
    expect(engine.pauses, 0);
    await controller.dispose();
  });
}

class _Gate {
  final Completer<void> _entered = Completer<void>();
  final Completer<void> _release = Completer<void>();

  Future<void> get entered => _entered.future;

  void release() {
    if (!_release.isCompleted) _release.complete();
  }

  Future<void> wait() {
    if (!_entered.isCompleted) _entered.complete();
    return _release.future;
  }
}

class _FakeEngine implements GardenAudioEngine {
  _FakeEngine({Future<void> Function()? onLoad}) : _onLoad = onLoad;

  final Future<void> Function()? _onLoad;
  final List<String> loads = [];
  final List<bool> streams = [];
  int plays = 0;
  int pauses = 0;
  int resumes = 0;
  int loopingPlays = 0;
  int protectedPlays = 0;
  bool failLoadOnce = false;
  bool rejectNextPlay = false;

  @override
  Future<GardenAudioClip> load(
    String assetPath, {
    required bool stream,
  }) async {
    loads.add(assetPath);
    streams.add(stream);
    final onLoad = _onLoad;
    if (onLoad != null) await onLoad();
    if (failLoadOnce) {
      failLoadOnce = false;
      throw const GardenAudioLoadInterrupted();
    }
    return GardenAudioClip();
  }

  @override
  GardenAudioVoice play(
    GardenAudioClip clip, {
    required double volume,
    required bool looping,
    bool protect = false,
  }) {
    if (rejectNextPlay) {
      rejectNextPlay = false;
      throw const GardenAudioPlayRejected();
    }
    plays++;
    if (looping) loopingPlays++;
    if (protect) protectedPlays++;
    return GardenAudioVoice();
  }

  @override
  void setVolume(GardenAudioVoice voice, double volume) {}

  @override
  void pause(GardenAudioVoice voice) {
    pauses++;
  }

  @override
  void resume(GardenAudioVoice voice) {
    resumes++;
  }

  @override
  Future<void> stop(GardenAudioVoice voice) async {}

  @override
  Future<void> disposeClip(GardenAudioClip clip) async {}
}
