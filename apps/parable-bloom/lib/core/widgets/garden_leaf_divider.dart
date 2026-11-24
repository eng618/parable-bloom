import 'package:material_ui/material_ui.dart';

/// Full-width ornament between the level-complete title and the message.
///
/// The asset is a wide rule (ornament, gap, ornament). It is drawn at the
/// card's width in its own colors. A fixed height would shrink that whole
/// rule into the middle of the card.
class GardenLeafDivider extends StatelessWidget {
  const GardenLeafDivider({
    super.key,
    this.asset = 'assets/art/ornaments/leaf_pair.png',
  });

  /// Ornament spanning the row. Defaults to the garden leaf pair.
  final String asset;

  @override
  Widget build(BuildContext context) {
    final rule = Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : null;
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              right: 0,
              child: Divider(color: rule, thickness: 1.25),
            ),
            Image.asset(
              asset,
              width: width,
              fit: BoxFit.fitWidth,
              excludeFromSemantics: true,
            ),
          ],
        );
      },
    );
  }
}
