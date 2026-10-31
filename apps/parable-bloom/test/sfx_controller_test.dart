import 'package:flutter_test/flutter_test.dart';
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
}
