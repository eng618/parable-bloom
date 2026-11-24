import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/appearance_providers.dart';
import '../../domain/vine_skin.dart';

/// Segmented picker for the active pack's vine skins.
class VineSkinControl extends ConsumerWidget {
  const VineSkinControl({
    super.key,
    this.showLabels = true,
  });

  /// Settings shows a name on each segment. The pause menu keeps icons.
  final bool showLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pack = ref.watch(resolvedAppearancePackProvider);
    final rendered = ref.watch(renderedVineSkinProvider);
    final skins = pack.skinsForPicker();
    final selected = skins.any((skin) => skin.id == rendered.id)
        ? rendered.id
        : skins.first.id;

    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: [
        for (final skin in skins)
          ButtonSegment<String>(
            value: skin.id,
            icon: Icon(vineSkinIcon(skin, outlined: !showLabels)),
            label: showLabels ? Text(skin.label) : null,
            tooltip: skin.label,
          ),
      ],
      selected: {selected},
      onSelectionChanged: (selection) {
        ref
            .read(vineSkinByPackProvider.notifier)
            .setSkin(pack.id, selection.first);
      },
      style: SegmentedButton.styleFrom(
        visualDensity:
            showLabels ? VisualDensity.standard : VisualDensity.comfortable,
      ),
    );
  }
}

/// Short line under the settings heading.
String vineSkinSubtitle(VineSkin skin) {
  if (skin.flat) {
    return 'Crisp stroke. Easier to read on a busy board.';
  }
  return switch (skin.foliage) {
    VineFoliage.leaves => 'Wood trellis with a vine winding through the leaves',
    VineFoliage.blossom => 'Wood trellis with a vine of small cherry blossoms',
    VineFoliage.glow => 'A soft mist winding along a bright core',
    VineFoliage.needles => 'Wood trellis with an evergreen vine',
    VineFoliage.none => 'Crisp stroke',
  };
}

IconData vineSkinIcon(VineSkin skin, {bool outlined = false}) {
  if (skin.flat) {
    return outlined ? Icons.grid_view_outlined : Icons.grid_view;
  }
  return switch (skin.foliage) {
    VineFoliage.blossom =>
      outlined ? Icons.local_florist_outlined : Icons.local_florist,
    VineFoliage.glow => outlined ? Icons.star_outline : Icons.star,
    VineFoliage.leaves ||
    VineFoliage.needles ||
    VineFoliage.none =>
      outlined ? Icons.park_outlined : Icons.park,
  };
}
