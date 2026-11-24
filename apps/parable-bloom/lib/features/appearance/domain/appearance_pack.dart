import 'package:material_ui/material_ui.dart';

import 'appearance_slot.dart';
import 'vine_skin.dart';

/// Month-day window, recurring every year in local time.
///
/// Both ends are inclusive. A window that starts in December and ends in
/// January wraps the new year.
class AppearanceWindow {
  const AppearanceWindow({
    required this.fromMonth,
    required this.fromDay,
    required this.untilMonth,
    required this.untilDay,
  });

  final int fromMonth;
  final int fromDay;
  final int untilMonth;
  final int untilDay;

  bool contains(DateTime local) {
    final today = local.month * 100 + local.day;
    final start = fromMonth * 100 + fromDay;
    final end = untilMonth * 100 + untilDay;
    if (start <= end) {
      return today >= start && today <= end;
    }
    return today >= start || today <= end;
  }

  /// Inclusive ranges in month-day space (`1201` is 1 Dec). A wrapping
  /// window is two ranges.
  List<(int, int)> get spans {
    final start = fromMonth * 100 + fromDay;
    final end = untilMonth * 100 + untilDay;
    if (start <= end) return [(start, end)];
    return [(start, 1231), (101, end)];
  }

  bool overlaps(AppearanceWindow other) {
    for (final a in spans) {
      for (final b in other.spans) {
        if (a.$1 <= b.$2 && b.$1 <= a.$2) return true;
      }
    }
    return false;
  }

  @override
  bool operator ==(Object other) {
    return other is AppearanceWindow &&
        other.fromMonth == fromMonth &&
        other.fromDay == fromDay &&
        other.untilMonth == untilMonth &&
        other.untilDay == untilDay;
  }

  @override
  int get hashCode => Object.hash(fromMonth, fromDay, untilMonth, untilDay);
}

/// Optional primary, secondary, and tertiary overrides for one brightness.
///
/// Null keeps the garden role. Surfaces, ink, error, and blocked-vine colors
/// are not fields here.
class AppearanceColorRoles {
  const AppearanceColorRoles({this.primary, this.secondary, this.tertiary});

  static const empty = AppearanceColorRoles();

  final Color? primary;
  final Color? secondary;
  final Color? tertiary;

  bool get isEmpty => primary == null && secondary == null && tertiary == null;

  @override
  bool operator ==(Object other) {
    return other is AppearanceColorRoles &&
        other.primary == primary &&
        other.secondary == secondary &&
        other.tertiary == tertiary;
  }

  @override
  int get hashCode => Object.hash(primary, secondary, tertiary);
}

/// Bundled season: art slots, a small palette delta, and vine skins.
///
/// This is not a biblical theme and not the light/dark setting. [garden] is
/// the fallback for every missing slot.
class AppearancePack {
  const AppearancePack({
    required this.id,
    required this.name,
    required this.assets,
    required this.vineSkins,
    required this.defaultVineSkinId,
    this.window,
    this.lightColors = AppearanceColorRoles.empty,
    this.darkColors = AppearanceColorRoles.empty,
  });

  static const gardenId = 'garden';

  /// Selection value that follows [window] on the device clock.
  static const autoSelection = 'auto';

  final String id;
  final String name;
  final AppearanceWindow? window;
  final AppearanceColorRoles lightColors;
  final AppearanceColorRoles darkColors;
  final Map<AppearanceSlot, String> assets;
  final List<VineSkin> vineSkins;
  final String defaultVineSkinId;

  /// Today's garden. Asset keys match the screens this pack replaces.
  static const garden = AppearancePack(
    id: gardenId,
    name: 'Garden',
    assets: {
      AppearanceSlot.homeGrain: 'assets/art/home/parchment.png',
      AppearanceSlot.homeFrameLight: 'assets/art/home/frame_light.png',
      AppearanceSlot.homeFrameDark: 'assets/art/home/frame_dark.png',
      AppearanceSlot.homeHero: 'assets/art/home/cross_wood.png',
      AppearanceSlot.ornamentSprig: 'assets/art/ornaments/leaf_sprig.png',
      AppearanceSlot.ornamentDivider: 'assets/art/ornaments/leaf_pair.png',
      AppearanceSlot.boardDay: 'assets/art/bg_day_new.png',
      AppearanceSlot.boardNight: 'assets/art/bg_night_new.png',
    },
    vineSkins: [
      VineSkin(
        id: 'trellis',
        label: 'Trellis',
        foliage: VineFoliage.leaves,
        accent: Color(0xFFF3E2B8),
        rail: Color(0xFF6B4A2E),
        core: Color(0xFFC4A574),
        arrow: Color(0xFFF3E2B8),
      ),
      VineSkin(
        id: 'blossom',
        label: 'Blossom',
        foliage: VineFoliage.blossom,
        accent: Color(0xFFDE7FA4),
        rail: Color(0xFF8D5A4A),
        core: Color(0xFFE0C2A4),
        arrow: Color(0xFFF3E2B8),
      ),
      VineSkin(
        id: 'ethereal',
        label: 'Ethereal',
        foliage: VineFoliage.glow,
        accent: Color(0xFF74F4FF),
        rail: Color(0x66D5F4F6),
        arrow: Color(0xFF74F4FF),
      ),
      VineSkin(
        id: 'flat',
        label: 'Flat',
        flat: true,
        foliage: VineFoliage.none,
        accent: VineSkin.defaultAccent,
      ),
    ],
    defaultVineSkinId: 'trellis',
  );

  AppearanceColorRoles colorsFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkColors : lightColors;
  }

  /// Asset key for [slot].
  ///
  /// A dark [brightness] uses [AppearanceSlot.homeHeroDark] when the pack
  /// has one, then the light hero. Any other missing key falls back to
  /// [garden]. Frame slots stay explicit: pass light or dark yourself.
  String asset(AppearanceSlot slot, {Brightness? brightness}) {
    var resolved = slot;
    if (brightness == Brightness.dark && slot == AppearanceSlot.homeHero) {
      final darkHero = assets[AppearanceSlot.homeHeroDark] ??
          AppearancePack.garden.assets[AppearanceSlot.homeHeroDark];
      if (darkHero != null) return darkHero;
    }
    final value = assets[resolved] ?? AppearancePack.garden.assets[resolved];
    if (value != null) return value;
    return AppearancePack.garden.assets[slot] ??
        AppearancePack.garden.assets[AppearanceSlot.homeHero]!;
  }

  /// Grain, both frames, and the hero images Home paints.
  List<String> get homePrecacheAssets {
    final paths = <String>[
      asset(AppearanceSlot.homeGrain),
      asset(AppearanceSlot.homeFrameLight),
      asset(AppearanceSlot.homeFrameDark),
      asset(AppearanceSlot.homeHero),
    ];
    final darkHero = assets[AppearanceSlot.homeHeroDark];
    if (darkHero != null) paths.add(darkHero);
    return paths;
  }

  VineSkin skinOrDefault(String? skinId) {
    if (skinId != null) {
      for (final skin in vineSkins) {
        if (skin.id == skinId) return skin;
      }
    }
    for (final skin in vineSkins) {
      if (skin.id == defaultVineSkinId) return skin;
    }
    return vineSkins.first;
  }

  /// Flat stroke for this pack, or a synthetic one when the pack has none.
  VineSkin get flatSkin {
    for (final skin in vineSkins) {
      if (skin.flat) return skin;
    }
    return const VineSkin(
      id: 'flat',
      label: 'Flat',
      flat: true,
      foliage: VineFoliage.none,
    );
  }

  /// Trellis strips this pack paints. Flat skins are omitted.
  Iterable<String> get vineTextureAssets sync* {
    for (final skin in vineSkins) {
      final asset = skin.textureAsset;
      if (skin.flat || asset == null || asset.isEmpty) continue;
      yield asset;
    }
  }

  /// Skins the settings control offers. Flat stays in the list.
  List<VineSkin> skinsForPicker() => vineSkins;

  @override
  bool operator ==(Object other) {
    return other is AppearancePack &&
        other.id == id &&
        other.name == name &&
        other.window == window &&
        other.lightColors == lightColors &&
        other.darkColors == darkColors &&
        other.defaultVineSkinId == defaultVineSkinId &&
        _mapEquals(other.assets, assets) &&
        _listEquals(other.vineSkins, vineSkins);
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        window,
        lightColors,
        darkColors,
        defaultVineSkinId,
        Object.hashAll(
          AppearanceSlot.values.map((slot) => assets[slot]),
        ),
        Object.hashAll(vineSkins),
      );
}

bool _mapEquals(
  Map<AppearanceSlot, String> a,
  Map<AppearanceSlot, String> b,
) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

bool _listEquals(List<VineSkin> a, List<VineSkin> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
