import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import '../../../core/services/logger_service.dart';
import '../domain/appearance_pack.dart';
import '../domain/appearance_slot.dart';
import '../domain/vine_skin.dart';

/// One manifest the catalog tried to read.
class AppearanceManifest {
  const AppearanceManifest({required this.directory, required this.json});

  /// Directory that holds `pack.json`, such as `assets/themes/garden`.
  final String directory;

  final Map<String, dynamic> json;
}

/// Loaded appearance packs. [garden] is always present.
class AppearanceCatalog {
  const AppearanceCatalog({
    required this.garden,
    this.seasons = const [],
  });

  static const schemaVersion = 1;

  /// Used before the asset bundle loads, and when every manifest fails.
  static const fallback = AppearanceCatalog(garden: AppearancePack.garden);

  final AppearancePack garden;
  final List<AppearancePack> seasons;

  List<AppearancePack> get packs => [garden, ...seasons];

  /// Resolves a Hive selection (`auto`, `garden`, or a pack id) at [now].
  AppearancePack resolve(String selection, DateTime now) {
    if (selection != AppearancePack.autoSelection) {
      if (selection == garden.id) return garden;
      for (final season in seasons) {
        if (season.id == selection) return season;
      }
      return garden;
    }
    for (final season in seasons) {
      final window = season.window;
      if (window != null && window.contains(now)) return season;
    }
    return garden;
  }

  /// Reads every `assets/themes/*/pack.json` from [bundle].
  static Future<AppearanceCatalog> load(AssetBundle bundle) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      final keys = manifest
          .listAssets()
          .where(
            (key) =>
                key.startsWith('assets/themes/') && key.endsWith('/pack.json'),
          )
          .toList()
        ..sort();
      final documents = <AppearanceManifest>[];
      for (final key in keys) {
        final raw = await bundle.loadString(key);
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          _logOnce(key, 'Appearance manifest $key is not a JSON object.');
          continue;
        }
        final directory = key.substring(0, key.length - '/pack.json'.length);
        documents.add(
          AppearanceManifest(
            directory: directory,
            json: Map<String, dynamic>.from(decoded),
          ),
        );
      }
      return parseDocuments(documents);
    } catch (error, stack) {
      _logOnce(
        'load',
        'Appearance catalogs failed to load. Staying on the garden pack.',
      );
      LoggerService.warn(
        'Appearance catalog load failed.',
        tag: 'AppearanceCatalog',
        error: error,
        stackTrace: stack,
      );
      return fallback;
    }
  }

  /// Builds a catalog from parsed manifests.
  ///
  /// Unknown schemas, failed contrast, and overlapping windows are dropped.
  /// The garden pack falls back to [AppearancePack.garden] when its manifest
  /// is missing or invalid. Seasons merge onto that garden, so a holiday can
  /// omit any slot it does not replace.
  static AppearanceCatalog parseDocuments(List<AppearanceManifest> documents) {
    AppearancePack? parsedGarden;
    final seasons = <AppearancePack>[];

    for (final document in documents) {
      final parsed = _parsePack(document);
      if (parsed == null) continue;
      if (parsed.id == AppearancePack.gardenId) {
        parsedGarden = parsed;
      } else {
        seasons.add(parsed);
      }
    }

    final garden = parsedGarden ?? AppearancePack.garden;
    final accepted = <AppearancePack>[];
    for (final season in seasons) {
      final merged = _mergeOntoGarden(garden, season);
      if (!_passesContrast(merged)) {
        _logOnce(
          'contrast:${merged.id}',
          'Appearance pack ${merged.id} failed contrast. It stays on garden.',
        );
        continue;
      }
      accepted.add(merged);
    }
    accepted.sort((a, b) => a.id.compareTo(b.id));
    final withoutOverlap = _dropOverlaps(accepted);
    return AppearanceCatalog(garden: garden, seasons: withoutOverlap);
  }

  static AppearancePack _mergeOntoGarden(
    AppearancePack garden,
    AppearancePack season,
  ) {
    return AppearancePack(
      id: season.id,
      name: season.name,
      window: season.window,
      lightColors: season.lightColors,
      darkColors: season.darkColors,
      assets: {...garden.assets, ...season.assets},
      vineSkins: season.vineSkins.isEmpty ? garden.vineSkins : season.vineSkins,
      defaultVineSkinId: season.vineSkins.isEmpty
          ? garden.defaultVineSkinId
          : season.defaultVineSkinId,
    );
  }

  static List<AppearancePack> _dropOverlaps(List<AppearancePack> seasons) {
    final kept = <AppearancePack>[];
    for (final season in seasons) {
      final window = season.window;
      if (window == null) {
        kept.add(season);
        continue;
      }
      AppearancePack? clash;
      for (final existing in kept) {
        final other = existing.window;
        if (other != null && window.overlaps(other)) {
          clash = existing;
          break;
        }
      }
      if (clash != null) {
        _logOnce(
          'overlap:${season.id}',
          'Appearance windows overlap: ${clash.id} and ${season.id}. '
              'Dropped ${season.id}.',
        );
        continue;
      }
      kept.add(season);
    }
    return kept;
  }

  static bool _passesContrast(AppearancePack pack) {
    const minimum = 3.0;
    bool roleOk(Color? primary, Brightness brightness) {
      if (primary == null) return true;
      final theme = brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme;
      final scaffold = AppTheme.getContrastRatio(
        primary,
        theme.scaffoldBackgroundColor,
      );
      final surface = AppTheme.getContrastRatio(
        primary,
        theme.colorScheme.surface,
      );
      final onPrimary = AppTheme.getContrastRatio(
        primary,
        theme.colorScheme.onPrimary,
      );
      return scaffold >= minimum && surface >= minimum && onPrimary >= minimum;
    }

    return roleOk(pack.lightColors.primary, Brightness.light) &&
        roleOk(pack.darkColors.primary, Brightness.dark);
  }

  static AppearancePack? _parsePack(AppearanceManifest document) {
    final json = document.json;
    final schema = json['schema'];
    if (schema != schemaVersion) {
      _logOnce(
        'schema:${document.directory}',
        'Appearance manifest ${document.directory} uses schema $schema. '
            'This build reads schema $schemaVersion.',
      );
      return null;
    }
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || id == AppearancePack.autoSelection) {
      _logOnce(
        'id:${document.directory}',
        'Appearance manifest ${document.directory} has no usable id.',
      );
      return null;
    }
    if (name is! String || name.isEmpty) {
      _logOnce(
        'name:$id',
        'Appearance pack $id has no name.',
      );
      return null;
    }

    final assets = _parseAssets(document.directory, json['assets']);
    if (id == AppearancePack.gardenId) {
      for (final slot in AppearanceSlot.required) {
        if (!assets.containsKey(slot)) {
          _logOnce(
            'garden-slot:${slot.key}',
            'Garden appearance pack is missing ${slot.key}.',
          );
          return null;
        }
      }
    }

    final window = _parseWindow(id, json['window']);
    if (json['window'] != null && window == null) return null;

    final colors = json['colors'];
    final colorMap = colors is Map ? colors : const {};
    final authoredSkins = _parseSkins(document.directory, json['vineSkins']);
    final skins = authoredSkins.isEmpty && id == AppearancePack.gardenId
        ? AppearancePack.garden.vineSkins
        : authoredSkins;
    final defaultSkin = json['defaultVineSkin'];
    final defaultVineSkinId = defaultSkin is String && defaultSkin.isNotEmpty
        ? defaultSkin
        : (skins.isEmpty
            ? AppearancePack.garden.defaultVineSkinId
            : skins.first.id);

    if (skins.isNotEmpty &&
        !skins.any((skin) => skin.id == defaultVineSkinId)) {
      _logOnce(
        'skin:$id',
        'Appearance pack $id default vine skin $defaultVineSkinId is missing.',
      );
      return null;
    }

    return AppearancePack(
      id: id,
      name: name,
      window: window,
      lightColors: _parseRoles(colorMap['light']),
      darkColors: _parseRoles(colorMap['dark']),
      assets: assets,
      vineSkins: skins,
      defaultVineSkinId: defaultVineSkinId,
    );
  }

  static Map<AppearanceSlot, String> _parseAssets(
    String directory,
    Object? raw,
  ) {
    if (raw is! Map) return const {};
    final assets = <AppearanceSlot, String>{};
    for (final entry in raw.entries) {
      final slot = AppearanceSlot.byKey(entry.key.toString());
      final value = entry.value;
      if (slot == null || value is! String || value.isEmpty) continue;
      assets[slot] = value.startsWith('assets/') ? value : '$directory/$value';
    }
    return assets;
  }

  static AppearanceWindow? _parseWindow(String id, Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) {
      _logOnce('window:$id',
          'Appearance pack $id has a window that is not an object.');
      return null;
    }
    final from = _parseMonthDay(raw['from']);
    final until = _parseMonthDay(raw['until']);
    if (from == null || until == null) {
      _logOnce('window:$id', 'Appearance pack $id has an invalid window.');
      return null;
    }
    return AppearanceWindow(
      fromMonth: from.$1,
      fromDay: from.$2,
      untilMonth: until.$1,
      untilDay: until.$2,
    );
  }

  static (int, int)? _parseMonthDay(Object? raw) {
    if (raw is! String) return null;
    final parts = raw.split('-');
    if (parts.length != 2) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    if (month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return (month, day);
  }

  static AppearanceColorRoles _parseRoles(Object? raw) {
    if (raw is! Map) return AppearanceColorRoles.empty;
    return AppearanceColorRoles(
      primary: _parseColor(raw['primary']),
      secondary: _parseColor(raw['secondary']),
      tertiary: _parseColor(raw['tertiary']),
    );
  }

  static Color? _parseColor(Object? raw) {
    if (raw is! String) return null;
    var hex = raw.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  static List<VineSkin> _parseSkins(String directory, Object? raw) {
    if (raw is! List) return const [];
    final skins = <VineSkin>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final id = item['id'];
      final label = item['label'];
      final foliage = VineFoliage.parse(item['foliage'] as String?);
      if (id is! String || id.isEmpty || label is! String || label.isEmpty) {
        continue;
      }
      if (foliage == null) continue;
      final flat = item['flat'] == true;
      final texture = item['texture'];
      String? textureAsset;
      if (!flat && texture is String && texture.isNotEmpty) {
        textureAsset =
            texture.startsWith('assets/') ? texture : '$directory/$texture';
      }
      if (!flat && textureAsset == null) continue;
      skins.add(
        VineSkin(
          id: id,
          label: label,
          flat: flat,
          textureAsset: flat ? null : textureAsset,
          foliage: flat ? VineFoliage.none : foliage,
          accent: _parseColor(item['accent']) ?? VineSkin.defaultAccent,
        ),
      );
    }
    return skins;
  }

  static final Set<String> _logged = {};

  static void _logOnce(String key, String message) {
    if (!_logged.add(key)) return;
    LoggerService.warn(message, tag: 'AppearanceCatalog');
  }
}
