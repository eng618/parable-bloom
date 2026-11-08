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
          'uiTap',
        ]));
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
}

class _FakeSfxPlayer implements AssetAudioPlayer {
  _FakeSfxPlayer({this.onSeek});

  final Future<void> Function()? onSeek;
  final Completer<void> _seekStarted = Completer<void>();
  final List<String> loads = [];
  int plays = 0;
  bool failLoadOnce = false;

  Future<void> get seekStarted => _seekStarted.future;

  @override
  Future<void> loadAsset(String assetPath) async {
    loads.add(assetPath);
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
  Future<void> play() async {
    plays++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
