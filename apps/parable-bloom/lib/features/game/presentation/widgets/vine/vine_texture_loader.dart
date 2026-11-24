import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter/services.dart';

import 'package:parable_bloom/core/services/logger_service.dart';

/// Race-free loader for vine trellis strips, keyed by Flutter asset path.
///
/// One loader per game shares a single in-flight future per asset. Keys under
/// `assets/art/` use the Flame image cache. Any other key is decoded from the
/// asset bundle, so a season strip can live under `assets/themes/`.
class VineTextureLoader {
  static const artPrefix = 'assets/art/';

  final Map<String, ui.Image> _byAsset = {};
  final Map<String, Future<ui.Image>> _inflight = {};

  /// True once at least one strip has decoded.
  bool get isLoaded => _byAsset.isNotEmpty;

  /// The decoded strip for [assetKey], or null while it is still loading.
  ui.Image? imageFor(String? assetKey) {
    if (assetKey == null || assetKey.isEmpty) return null;
    return _byAsset[assetKey];
  }

  /// Decodes each missing key. Keys already cached or in flight are joined.
  Future<void> ensureLoaded(Images images, Iterable<String> assetKeys) {
    final pending = <Future<ui.Image>>[];
    for (final key in assetKeys) {
      if (key.isEmpty || _byAsset.containsKey(key)) continue;
      pending.add(_inflight.putIfAbsent(key, () => _load(images, key)));
    }
    if (pending.isEmpty) return Future<void>.value();
    return Future.wait(pending).then((_) {});
  }

  Future<ui.Image> _load(Images images, String assetKey) async {
    try {
      final image = await _decode(images, assetKey);
      _byAsset[assetKey] = image;
      return image;
    } catch (e, stack) {
      LoggerService.warn(
        'Vine texture failed to load',
        tag: 'VineTexture',
        error: e,
        stackTrace: stack,
        metadata: {'asset': assetKey},
      );
      rethrow;
    } finally {
      _inflight.remove(assetKey);
    }
  }

  Future<ui.Image> _decode(Images images, String assetKey) async {
    if (assetKey.startsWith(artPrefix)) {
      images.prefix = artPrefix;
      return images.load(assetKey.substring(artPrefix.length));
    }
    final data = await rootBundle.load(assetKey);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }
}
