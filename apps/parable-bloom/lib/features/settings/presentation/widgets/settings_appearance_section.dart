import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/settings_providers.dart';
import '../../../appearance/application/appearance_providers.dart';
import '../../../appearance/data/appearance_catalog.dart';
import '../../../appearance/domain/appearance_pack.dart';
import '../../../appearance/presentation/widgets/vine_skin_control.dart';

/// Brightness, season, and vine skin.
class SettingsAppearanceSection extends ConsumerWidget {
  const SettingsAppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final season = ref.watch(appearanceSelectionProvider);
    final resolvedSeason = ref.watch(resolvedAppearancePackProvider);
    final catalog = ref.watch(appearanceCatalogProvider).maybeWhen(
          data: (value) => value,
          orElse: () => AppearanceCatalog.fallback,
        );
    final vineSkin = ref.watch(renderedVineSkinProvider);

    return Column(
      children: [
        ListTile(
          leading: Icon(_themeIcon(themeMode)),
          title: const Text('Theme'),
          subtitle: Text(_themeLabel(themeMode)),
          onTap: () => _showThemeDialog(context, ref, themeMode),
        ),
        ListTile(
          leading: const Icon(Icons.event_repeat),
          title: const Text('Season'),
          subtitle: Text(_seasonSubtitle(season, resolvedSeason)),
          onTap: () => _showSeasonDialog(context, ref, season, catalog),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    vineSkinIcon(vineSkin),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vine Style',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          vineSkinSubtitle(vineSkin),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SizedBox(
                width: double.infinity,
                child: VineSkinControl(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

IconData _themeIcon(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return Icons.light_mode;
    case AppThemeMode.dark:
      return Icons.dark_mode;
    case AppThemeMode.system:
      return Icons.settings_brightness;
  }
}

String _themeLabel(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return 'Light';
    case AppThemeMode.dark:
      return 'Dark';
    case AppThemeMode.system:
      return 'System';
  }
}

String _seasonSubtitle(String selection, AppearancePack resolved) {
  if (selection == AppearancePack.autoSelection) {
    if (resolved.id == AppearancePack.gardenId) return 'Automatic';
    return 'Automatic · ${resolved.name}';
  }
  return resolved.name;
}

void _showSeasonDialog(
  BuildContext context,
  WidgetRef ref,
  String currentSelection,
  AppearanceCatalog catalog,
) {
  final choices = <(String, String)>[
    (AppearancePack.autoSelection, 'Automatic'),
    for (final pack in catalog.packs) (pack.id, pack.name),
  ];
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Choose Season'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: choices.map((choice) {
          final (id, label) = choice;
          final isSelected = id == currentSelection;
          return ListTile(
            title: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(dialogContext).colorScheme.primary
                    : null,
              ),
            ),
            trailing: isSelected
                ? Icon(
                    Icons.check,
                    color: Theme.of(dialogContext).colorScheme.primary,
                  )
                : null,
            onTap: () {
              ref.read(appearanceSelectionProvider.notifier).setSelection(id);
              Navigator.of(dialogContext).pop();
            },
          );
        }).toList(),
      ),
    ),
  );
}

void _showThemeDialog(
  BuildContext context,
  WidgetRef ref,
  AppThemeMode currentMode,
) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Choose Theme'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: AppThemeMode.values.map((mode) {
          final isSelected = mode == currentMode;
          return ListTile(
            leading: Icon(
              _themeIcon(mode),
              color: isSelected
                  ? Theme.of(dialogContext).colorScheme.primary
                  : null,
            ),
            title: Text(
              _themeLabel(mode),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(dialogContext).colorScheme.primary
                    : null,
              ),
            ),
            trailing: isSelected
                ? Icon(
                    Icons.check,
                    color: Theme.of(dialogContext).colorScheme.primary,
                  )
                : null,
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(mode);
              Navigator.of(dialogContext).pop();
            },
          );
        }).toList(),
      ),
    ),
  );
}
