import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/infrastructure_providers.dart';
import '../../../core/providers/settings_providers.dart';
import '../data/appearance_catalog.dart';
import '../domain/appearance_pack.dart';
import '../domain/vine_skin.dart';

/// Bundled packs. Falls back to the built-in garden pack while loading.
final appearanceCatalogProvider =
    FutureProvider<AppearanceCatalog>((ref) async {
  return AppearanceCatalog.load(rootBundle);
});

/// Clock used to match a season window. Tests override the function.
final appearanceClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

/// Hive selection: `auto`, `garden`, or a pack id.
final appearanceSelectionProvider =
    NotifierProvider<AppearanceSelectionNotifier, String>(
  AppearanceSelectionNotifier.new,
);

class AppearanceSelectionNotifier extends Notifier<String> {
  static const _key = 'appearancePack';

  @override
  String build() {
    final box = ref.watch(hiveBoxProvider);
    final value = box.get(_key, defaultValue: AppearancePack.autoSelection);
    if (value is! String || value.isEmpty) return AppearancePack.autoSelection;
    return value;
  }

  Future<void> setSelection(String selection) async {
    final next = selection.isEmpty ? AppearancePack.autoSelection : selection;
    state = next;
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setAppearancePack(next);
  }
}

/// The pack to paint. `auto` follows the local date.
final resolvedAppearancePackProvider = Provider<AppearancePack>((ref) {
  final catalog = ref.watch(appearanceCatalogProvider).maybeWhen(
        data: (catalog) => catalog,
        orElse: () => AppearanceCatalog.fallback,
      );
  final selection = ref.watch(appearanceSelectionProvider);
  final now = ref.watch(appearanceClockProvider)();
  return catalog.resolve(selection, now);
});

/// Per-pack vine skin ids. A Christmas choice does not replace the garden one.
final vineSkinByPackProvider =
    NotifierProvider<VineSkinByPackNotifier, Map<String, String>>(
  VineSkinByPackNotifier.new,
);

class VineSkinByPackNotifier extends Notifier<Map<String, String>> {
  static const _key = 'vineSkinByPack';

  @override
  Map<String, String> build() {
    final box = ref.watch(hiveBoxProvider);
    final raw = box.get(_key);
    if (raw is Map && raw.isNotEmpty) {
      return {
        for (final entry in raw.entries)
          entry.key.toString(): entry.value.toString(),
      };
    }
    final legacy = box.get('vineStyle');
    if (legacy is String && legacy.isNotEmpty) {
      return {
        AppearancePack.gardenId: VineSkin.idFromLegacyStyle(legacy),
      };
    }
    return const {};
  }

  Future<void> setSkin(String packId, String skinId) async {
    final next = {...state, packId: skinId};
    state = next;
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setVineSkinForPack(packId, skinId);
  }
}

/// Skin the player picked for the active pack, before the texture gate.
final activeVineSkinProvider = Provider<VineSkin>((ref) {
  final pack = ref.watch(resolvedAppearancePackProvider);
  final byPack = ref.watch(vineSkinByPackProvider);
  return pack.skinOrDefault(byPack[pack.id]);
});

/// Skin the board draws.
///
/// `vineTexturedSkins` (default off) is the play-pass gate. While it is off,
/// a textured choice stays saved and the board draws the pack's flat stroke.
final renderedVineSkinProvider = Provider<VineSkin>((ref) {
  final skin = ref.watch(activeVineSkinProvider);
  final textured = ref.watch(vineTexturedSkinsEnabledProvider);
  if (textured || skin.flat) return skin;
  return ref.watch(resolvedAppearancePackProvider).flatSkin;
});
