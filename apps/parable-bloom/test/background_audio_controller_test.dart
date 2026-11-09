import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parable_bloom/core/services/asset_audio_player.dart';
import 'package:parable_bloom/core/services/background_audio_controller.dart';

void main() {
  test('web gesture during load still starts the loop', () async {
    final gate = _Gate();
    final player = _FakePlayer(onLoad: (_) => gate.wait());
    final controller = BackgroundAudioController(player: player, isWeb: true);

    final enabling = controller.setEnabled(true);
    await gate.entered;
    final interaction = controller.notifyUserInteraction();
    gate.release();
    await enabling;
    await interaction;

    expect(player.loads, [BackgroundAudioController.assetPath]);
    expect(player.plays, 1);
    await controller.dispose();
  });

  test('web does not play until a gesture', () async {
    final player = _FakePlayer();
    final controller = BackgroundAudioController(player: player, isWeb: true);

    await controller.setEnabled(true);
    expect(player.plays, 0);
    expect(player.loads, [BackgroundAudioController.assetPath]);

    await controller.notifyUserInteraction();
    expect(player.plays, 1);
    await controller.dispose();
  });

  test('turning music off during load does not start playback', () async {
    final gate = _Gate();
    final player = _FakePlayer(onLoad: (_) => gate.wait());
    final controller = BackgroundAudioController(player: player, isWeb: false);

    final enabling = controller.setEnabled(true);
    await gate.entered;
    final disabling = controller.setEnabled(false);
    gate.release();
    await enabling;
    await disabling;

    expect(player.plays, 0);
    expect(player.pauses, greaterThan(0));
    await controller.dispose();
  });

  test('interrupted load is retried and then plays', () async {
    final player = _FakePlayer()..failLoadOnce = true;
    final controller = BackgroundAudioController(player: player, isWeb: false);

    await controller.setEnabled(true);

    expect(player.loads, [
      BackgroundAudioController.assetPath,
      BackgroundAudioController.assetPath,
    ]);
    expect(player.plays, 1);
    await controller.dispose();
  });

  test('backgrounding pauses and resume continues without a new gesture',
      () async {
    final player = _FakePlayer();
    final controller = BackgroundAudioController(player: player, isWeb: false);

    await controller.setEnabled(true);
    await controller.setSuspended(true);
    await controller.setSuspended(false);

    expect(player.plays, 2);
    expect(player.pauses, greaterThan(0));
    await controller.dispose();
  });

  test('suspend pauses even when play never completes', () async {
    final player = _FakePlayer()..hangPlay = true;
    final controller = BackgroundAudioController(player: player, isWeb: false);

    await controller.setEnabled(true);
    expect(player.plays, 1);

    await controller.setSuspended(true);
    expect(player.pauses, greaterThan(0));

    await controller.setSuspended(false);
    expect(player.plays, 2);
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

class _FakePlayer implements AssetAudioPlayer {
  _FakePlayer({Future<void> Function(_FakePlayer player)? onLoad})
      : _onLoad = onLoad;

  final Future<void> Function(_FakePlayer player)? _onLoad;
  final List<String> loads = [];
  int plays = 0;
  int pauses = 0;
  bool failLoadOnce = false;
  bool hangPlay = false;

  @override
  Future<void> loadAsset(String assetPath) async {
    loads.add(assetPath);
    final onLoad = _onLoad;
    if (onLoad != null) await onLoad(this);
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
  Future<void> seekToStart() async {}

  @override
  Future<void> play() {
    plays++;
    if (hangPlay) return Completer<void>().future;
    return Future<void>.value();
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
