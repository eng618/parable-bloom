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
    // Extended palette for level variety
    "moss_green": Color(0xFF4A7C59),
    "sunset_orange": Color(0xFFE87461),
    "golden_yellow": Color(0xFFFFD700),
    "royal_purple": Color(0xFF7851A9),
    "sky_blue": Color(0xFF87CEEB),
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
