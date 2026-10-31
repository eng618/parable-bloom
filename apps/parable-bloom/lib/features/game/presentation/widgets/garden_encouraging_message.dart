import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';

/// Garden-language encouraging line for in-game HUD moments.
///
/// Serif italic muted ink (welcome-back / parchment grammar). Optional small
/// leaf-pair flanks keep the line tied to botanical ornaments without neon
/// chrome or Material celebration icons.
class GardenEncouragingMessage extends StatelessWidget {
  const GardenEncouragingMessage({
    super.key,
    required this.message,
    this.showLeafFlanks = true,
    this.textAlign = TextAlign.center,
  });

  final String message;
  final bool showLeafFlanks;
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

    final text = Text(
      message,
      style: style,
      textAlign: textAlign,
    );

    if (!showLeafFlanks) return text;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _LeafAccent(color: cs.secondary),
        const SizedBox(width: 10),
        Expanded(child: text),
        const SizedBox(width: 10),
        _LeafAccent(color: cs.secondary, mirror: true),
      ],
    );
  }
}

class _LeafAccent extends StatelessWidget {
  const _LeafAccent({required this.color, this.mirror = false});

  final Color color;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final leaf = Image.asset(
      'assets/art/ornaments/leaf_pair.png',
      height: 14,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      excludeFromSemantics: true,
    );
    if (!mirror) return leaf;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
      child: leaf,
    );
  }
}
