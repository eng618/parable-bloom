import 'package:material_ui/material_ui.dart';

/// Thin rule with a centered leaf-pair ornament (level-complete / garden HUD).
class GardenLeafDivider extends StatelessWidget {
  const GardenLeafDivider({
    super.key,
    this.height = 18,
    this.asset = 'assets/art/ornaments/leaf_pair.png',
  });

  final double height;

  /// Ornament painted between the rules. Defaults to the garden leaf pair.
  final String asset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outline.withValues(alpha: 0.45))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Image.asset(
            asset,
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
