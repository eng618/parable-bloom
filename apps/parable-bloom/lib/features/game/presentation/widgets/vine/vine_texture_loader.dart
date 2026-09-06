import 'dart:ui' as ui;

import 'package:flame/cache.dart';

/// Race-free loader for the three vine textures.
///
/// Previously each [VineComponent] lazy-loaded static images in its own
/// `onLoad`, so N concurrent vines could double-load the same texture and
/// failures were silent. One loader per game shares a single in-flight
/// future across all vines; textures live as long as the game.
class VineTextureLoader {
  ui.Image? classic;
  ui.Image? blossom;
  ui.Image? ethereal;

  Future<void>? _inflight;

  bool get isLoaded => classic != null;

  Future<void> load(Images images) {
    return _inflight ??= Future.wait([
      images.load('classic_vine_texture.png'),
      images.load('blossom_vine_texture.png'),
      images.load('ethereal_vine_texture.png'),
    ]).then((loaded) {
      classic = loaded[0];
      blossom = loaded[1];
      ethereal = loaded[2];
    });
  }
}
