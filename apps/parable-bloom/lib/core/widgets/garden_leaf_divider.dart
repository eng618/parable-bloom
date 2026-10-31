import 'package:flutter/material.dart';

/// Thin rule with a centered leaf-pair ornament (level-complete / garden HUD).
class GardenLeafDivider extends StatelessWidget {
  const GardenLeafDivider({super.key, this.height = 18});

  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.45))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Image.asset(
            'assets/art/ornaments/leaf_pair.png',
            height: height,
            color: cs.secondary,
            colorBlendMode: BlendMode.srcIn,
            excludeFromSemantics: true,
          ),
        ),
        Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.45))),
      ],
    );
  }
}
