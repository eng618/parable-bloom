import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parable_bloom/core/services/asset_audio_player.dart';
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

  test('organized cues load the soft UI and foliage files', () async {
    final created = <_FakeSfxPlayer>[];
    final controller = SfxController(playerFactory: () {
      final player = _FakeSfxPlayer();
      created.add(player);
      return player;
    });

    await controller.play(GameSfx.uiMenuOpen);
    final paths = created.expand((player) => player.loads).toSet();
    expect(paths, contains('assets/audio/sfx/ui/ui_menu_open.wav'));
    expect(paths, contains('assets/audio/sfx/ui/ui_menu_close.wav'));
    expect(paths, contains('assets/audio/sfx/ui/ui_clicked_in.wav'));
    expect(paths, contains('assets/audio/sfx/ui/ui_confirm.wav'));
    expect(paths, contains('assets/audio/sfx/ui/ui_cancel.wav'));
    expect(paths, contains('assets/audio/sfx/vines/vine_slide_start.mp3'));
    expect(
        paths, contains('assets/audio/sfx/vines/vine_foliage_rustle_01.wav'));
    expect(
        paths, contains('assets/audio/sfx/vines/vine_foliage_rustle_02.wav'));
    expect(paths, contains('assets/audio/sfx/vines/vine_bloom.mp3'));
    expect(paths, contains('assets/audio/sfx/vines/vine_blocked.mp3'));
    expect(paths, contains('assets/audio/sfx/grace_loss.mp3'));
    expect(paths, contains('assets/audio/sfx/level_complete.mp3'));
    expect(paths, isNot(contains('assets/audio/sfx/ui_tap.mp3')));
    expect(paths, isNot(contains('assets/audio/sfx/vines/vine_rustle.mp3')));
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
    var failNextLoad = true;
    final created = <_FakeSfxPlayer>[];
    final controller = SfxController(playerFactory: () {
      final player = _FakeSfxPlayer();
      created.add(player);
      if (failNextLoad) {
        player.failLoadOnce = true;
        failNextLoad = false;
      }
      return player;
    });

    await controller.play(GameSfx.uiTap);
    expect(created.fold<int>(0, (sum, player) => sum + player.plays), 1);
    final createdAfterFirstPlay = created.length;

    await controller.play(GameSfx.uiTap);
    expect(created.length, createdAfterFirstPlay + 1);
    await controller.dispose();
  });

  test('a retrigger during seek plays the cue once', () async {
    final gate = Completer<void>();
    final player = _FakeSfxPlayer(onSeek: () => gate.future);
    final controller = SfxController(playerFactory: () => player);

    final first = controller.play(GameSfx.uiTap);
    await player.seekStarted;
    final second = controller.play(GameSfx.uiTap);
    gate.complete();
    await first;
    await second;

    expect(player.plays, 1);
    await controller.dispose();
  });

  test('overlapping ensureLoaded uses one player per cue', () async {
    final created = <_FakeSfxPlayer>[];
    final gate = Completer<void>();
    final controller = SfxController(playerFactory: () {
      final player = _FakeSfxPlayer(onLoad: () => gate.future);
      created.add(player);
      return player;
    });

    final first = controller.ensureLoaded();
    final second = controller.ensureLoaded();
    expect(second, same(first));
    expect(created, isNotEmpty);
    gate.complete();
    await first;

    expect(created.length, GameSfx.values.length);
    await controller.dispose();
  });

  test('a play that never finishes does not block stop or another play',
      () async {
    final created = <_FakeSfxPlayer>[];
    final controller = SfxController(playerFactory: () {
      final player = _FakeSfxPlayer()..hangPlay = true;
      created.add(player);
      return player;
    });

    await controller.play(GameSfx.uiTap);
    await controller.stop(GameSfx.uiTap);
    final played = created.singleWhere((player) => player.plays > 0);
    expect(played.stops, 1);

    await controller.play(GameSfx.uiTap);
    expect(played.plays, 2);
    await controller.dispose();
  });

  test('suspended controller does not play', () async {
    final player = _FakeSfxPlayer();
    final controller = SfxController(playerFactory: () => player);

    await controller.setSuspended(true);
    await controller.play(GameSfx.uiTap);
    expect(player.plays, 0);

    await controller.setSuspended(false);
    await controller.play(GameSfx.uiTap);
    expect(player.plays, 1);
    await controller.dispose();
  });
}

class _FakeSfxPlayer implements AssetAudioPlayer {
  _FakeSfxPlayer({this.onSeek, this.onLoad});

  final Future<void> Function()? onSeek;
  final Future<void> Function()? onLoad;
  final Completer<void> _seekStarted = Completer<void>();
  final List<String> loads = [];
  int plays = 0;
  int stops = 0;
  bool failLoadOnce = false;
  bool hangPlay = false;

  Future<void> get seekStarted => _seekStarted.future;

  @override
  Future<void> loadAsset(String assetPath) async {
    loads.add(assetPath);
    final onLoad = this.onLoad;
    if (onLoad != null) await onLoad();
    if (failLoadOnce) {
      failLoadOnce = false;
      throw PlayerInterruptedException('Loading interrupted');
    }
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  Future<void> seekToStart() async {
    if (!_seekStarted.isCompleted) _seekStarted.complete();
    final onSeek = this.onSeek;
    if (onSeek != null) await onSeek();
  }

  @override
  Future<void> play() {
    plays++;
    if (hangPlay) return Completer<void>().future;
    return Future<void>.value();
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}
}
