import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/core/services/garden_audio_engine.dart';
import 'package:parable_bloom/core/services/sfx_controller.dart';

void main() {
  test('GameSfx pack covers required gameplay cues', () {
    expect(
        GameSfx.values.map((e) => e.name).toSet(),
        containsAll([
          'vineSlideStart',
          'vineRustle',
          'vineBloom',
          'vineBloomLong',
          'vineBlocked',
          'graceLoss',
          'levelComplete',
          'levelSwell',
          'uiTap',
          'uiMenuOpen',
          'uiMenuClose',
          'uiConfirm',
          'uiCancel',
        ]));
  });

  test('organized cues load the soft UI and foliage files into memory',
      () async {
    final engine = _FakeSfxEngine();
    final controller = SfxController(engine: engine);

    await controller.play(GameSfx.uiMenuOpen);
    expect(engine.loads, contains('assets/audio/sfx/ui/ui_menu_open.wav'));
    expect(engine.loads, contains('assets/audio/sfx/ui/ui_menu_close.wav'));
    expect(engine.loads, contains('assets/audio/sfx/ui/ui_clicked_in.wav'));
    expect(engine.loads, contains('assets/audio/sfx/ui/ui_confirm.wav'));
    expect(engine.loads, contains('assets/audio/sfx/ui/ui_cancel.wav'));
    expect(
        engine.loads, contains('assets/audio/sfx/vines/vine_slide_start.mp3'));
    expect(
      engine.loads,
      contains('assets/audio/sfx/vines/vine_foliage_rustle_01.wav'),
    );
    expect(
      engine.loads,
      contains('assets/audio/sfx/vines/vine_foliage_rustle_02.wav'),
    );
    expect(engine.loads, contains('assets/audio/sfx/vines/vine_bloom.mp3'));
    expect(engine.loads, contains('assets/audio/sfx/vines/vine_blocked.mp3'));
    expect(engine.loads, contains('assets/audio/sfx/grace_loss.mp3'));
    expect(engine.loads, contains('assets/audio/sfx/level_complete.mp3'));
    expect(engine.loads, isNot(contains('assets/audio/sfx/ui_tap.mp3')));
    expect(engine.loads,
        isNot(contains('assets/audio/sfx/vines/vine_rustle.mp3')));
    expect(engine.streams, everyElement(isFalse));
    await controller.dispose();
  });

  test('disabled controller skips play without throwing', () async {
    final controller = SfxController();
    await controller.setEnabled(false);
    await controller.play(GameSfx.uiTap);
    await controller.playVineSlide();
    await controller.playBloom(vineLength: 6);
    await controller.playBlocked();
    await controller.dispose();
  });

  test('play no-ops without Flutter binding (pure unit tests)', () async {
    final controller = SfxController();
    await controller.play(GameSfx.graceLoss);
    await controller.playVineSlide();
    await controller.dispose();
  });

  test('an interrupted SFX load is retried on the next play', () async {
    final engine = _FakeSfxEngine()..failNextLoad = true;
    final controller = SfxController(engine: engine);

    await controller.play(GameSfx.uiTap);
    expect(engine.plays, 1);
    final loadsAfterFirstPlay = engine.loads.length;

    await controller.play(GameSfx.uiTap);
    expect(engine.loads.length, loadsAfterFirstPlay + 1);
    expect(engine.plays, 2);
    await controller.dispose();
  });

  test('a second tap overlaps the first cue', () async {
    final engine = _FakeSfxEngine();
    final controller = SfxController(engine: engine);

    final first = controller.play(GameSfx.uiTap);
    final second = controller.play(GameSfx.uiTap);
    await first;
    await second;

    expect(engine.plays, 2);
    expect(engine.stops, 0);
    await controller.dispose();
  });

  test('a retriggered rustle replaces the looping voice', () async {
    final engine = _FakeSfxEngine();
    final controller = SfxController(engine: engine);

    await controller.play(GameSfx.vineRustle);
    await controller.play(GameSfx.vineRustle);

    expect(engine.plays, 2);
    expect(engine.loopingPlays, 2);
    expect(engine.stops, 1);
    await controller.dispose();
  });

  test('overlapping ensureLoaded loads each cue once', () async {
    final gate = Completer<void>();
    final engine = _FakeSfxEngine(onLoad: () => gate.future);
    final controller = SfxController(engine: engine);

    final first = controller.ensureLoaded();
    final second = controller.ensureLoaded();
    expect(second, same(first));
    expect(engine.loads, isNotEmpty);
    gate.complete();
    await first;

    expect(engine.loads.length, GameSfx.values.length);
    await controller.dispose();
  });

  test('a playing cue does not block stop or another play', () async {
    final engine = _FakeSfxEngine();
    final controller = SfxController(engine: engine);

    await controller.play(GameSfx.uiTap);
    await controller.stop(GameSfx.uiTap);
    expect(engine.stops, 1);

    await controller.play(GameSfx.uiTap);
    expect(engine.plays, 2);
    await controller.dispose();
  });

  test('suspended controller does not play', () async {
    final engine = _FakeSfxEngine();
    final controller = SfxController(engine: engine);

    await controller.setSuspended(true);
    await controller.play(GameSfx.uiTap);
    expect(engine.plays, 0);

    await controller.setSuspended(false);
    await controller.play(GameSfx.uiTap);
    expect(engine.plays, 1);
    await controller.dispose();
  });
}

class _FakeSfxEngine implements GardenAudioEngine {
  _FakeSfxEngine({this.onLoad});

  final Future<void> Function()? onLoad;
  final List<String> loads = [];
  final List<bool> streams = [];
  int plays = 0;
  int stops = 0;
  int loopingPlays = 0;
  bool failNextLoad = false;

  @override
  Future<GardenAudioClip> load(
    String assetPath, {
    required bool stream,
  }) async {
    loads.add(assetPath);
    streams.add(stream);
    final pending = onLoad;
    if (pending != null) await pending();
    if (failNextLoad) {
      failNextLoad = false;
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
    plays++;
    if (looping) loopingPlays++;
    return GardenAudioVoice();
  }

  @override
  void setVolume(GardenAudioVoice voice, double volume) {}

  @override
  void pause(GardenAudioVoice voice) {}

  @override
  void resume(GardenAudioVoice voice) {}

  @override
  Future<void> stop(GardenAudioVoice voice) async {
    stops++;
  }

  @override
  Future<void> disposeClip(GardenAudioClip clip) async {}
}
