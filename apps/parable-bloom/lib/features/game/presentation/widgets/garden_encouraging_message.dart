import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';

/// Garden-language encouraging line for main-game HUD moments.
///
/// Full-width italic serif muted ink (welcome-back / parchment grammar).
/// Side leaf embroideries are intentionally omitted — they crushed long lines
/// into mid-word wraps; botanical framing stays on the leaf divider above.
class GardenEncouragingMessage extends StatelessWidget {
  const GardenEncouragingMessage({
    super.key,
    required this.message,
    this.textAlign = TextAlign.center,
  });

  final String message;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final style = theme.textTheme.titleLarge?.copyWith(
          color: cs.onSurfaceVariant,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w500,
          fontFamily: AppTheme.displayFontFamily,
          fontFamilyFallback: AppTheme.displayFontFallback,
          height: 1.35,
        ) ??
        TextStyle(
          color: cs.onSurfaceVariant,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w500,
          fontFamily: AppTheme.displayFontFamily,
          fontFamilyFallback: AppTheme.displayFontFallback,
          fontSize: 22,
          height: 1.35,
        );

    return Text(
      message,
      style: style,
      textAlign: textAlign,
    );
  }
}
