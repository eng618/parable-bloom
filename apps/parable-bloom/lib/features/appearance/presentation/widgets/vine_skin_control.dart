import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/providers/settings_providers.dart';
import '../../application/appearance_providers.dart';
import '../../domain/vine_skin.dart';

/// Segmented picker for the active pack's vine skins.
///
/// Textured skins stay hidden while [vineTexturedSkinsEnabledProvider] is
/// off. The saved skin is unchanged; the board draws the flat stroke.
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
    final textured = ref.watch(vineTexturedSkinsEnabledProvider);
    final rendered = ref.watch(renderedVineSkinProvider);
    final skins = pack.skinsForPicker(textured: textured);
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
  return switch (skin.id) {
    'trellis' => 'Wood trellis with leaves wrapped around it',
    'blossom' => 'Blossoms along the trellis',
    'ethereal' => 'Soft glow around the trellis',
    _ => switch (skin.foliage) {
        VineFoliage.leaves => 'Wood trellis with leaves',
        VineFoliage.blossom => 'Blossoms along the trellis',
        VineFoliage.glow => 'Soft glow around the trellis',
        VineFoliage.none => 'Crisp stroke',
      },
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
    VineFoliage.none =>
      outlined ? Icons.park_outlined : Icons.park,
  };
}
