import "package:flutter/material.dart";

import "app_theme.dart";

class VineColorPalette {
  static const String defaultKey = "default";

  /// Central palette for vine colors.
  ///
  /// Levels should set `vine_color` to one of these keys.
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

    return colors[trimmed] ?? colors[defaultKey]!;
  }

  static bool isKnownKey(String key) => colors.containsKey(key);

}
