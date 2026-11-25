import 'package:flame/cache.dart';

import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_skin.dart';

/// Race-free loader for modular vine-arrow skin themes.
///
/// Classic is loaded eagerly with the existing [VineTextureLoader] textures.
/// Future themes register the same filenames under `skins/<id>/`.
class VineSkinLoader {
  VineSkinTheme? classic;

  Future<void>? _inflight;

  bool get isClassicLoaded => classic != null;

  Future<void> load(Images images) {
    return _inflight ??= Future.wait([
      images.load(ClassicVineSkinPaths.shaft),
      images.load(ClassicVineSkinPaths.wrapLive),
      images.load(ClassicVineSkinPaths.wrapWithered),
      images.load(ClassicVineSkinPaths.endsAtlas),
    ]).then((loaded) {
      classic = VineSkinTheme(
        id: 'classic',
        shaft: loaded[0],
        wrapLive: loaded[1],
        wrapWithered: loaded[2],
        endsAtlas: loaded[3],
      );
    });
  }
}
