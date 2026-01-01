import "package:flutter/material.dart";

import "app_theme.dart";

class VineColorPalette {
  static const String defaultKey = "default";

  /// Central palette for vine colors.
  ///
  /// Levels should set `vine_color` to one of these keys.
  ///
  /// Backward-compat: if `vine_color` is a hex string (e.g. `#RRGGBB` or
  /// `#AARRGGBB`), it will be parsed and used directly.
  static const Map<String, Color> colors = {
    defaultKey: AppTheme.vineGreen,
    "primary": AppTheme.primarySeed,
    "secondary": AppTheme.secondarySeed,
    "tertiary": AppTheme.tertiarySeed,
  };

  static Color resolve(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return colors[defaultKey]!;
    }

    final hex = _tryParseHexColor(trimmed);
    if (hex != null) return hex;

    return colors[trimmed] ?? colors[defaultKey]!;
  }

  static bool isKnownKey(String key) => colors.containsKey(key);

  static Color? _tryParseHexColor(String value) {
    var hex = value;
    if (hex.startsWith("#")) hex = hex.substring(1);

    if (hex.length == 6) {
      hex = "FF$hex";
    }

    if (hex.length != 8) return null;

    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;

    return Color(parsed);
  }
}
