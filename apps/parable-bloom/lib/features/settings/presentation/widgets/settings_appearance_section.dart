import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/settings_providers.dart';

/// Theme, default board zoom, and vine style.
class SettingsAppearanceSection extends ConsumerWidget {
  const SettingsAppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final vineStyle = ref.watch(vineStyleProvider);
    final texturedSkinsEnabled = ref.watch(vineTexturedSkinsEnabledProvider);

    return Column(
      children: [
        ListTile(
          leading: Icon(_themeIcon(themeMode)),
          title: const Text('Theme'),
          subtitle: Text(_themeLabel(themeMode)),
          onTap: () => _showThemeDialog(context, ref, themeMode),
        ),
        _BoardZoomTile(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _vineStyleIcon(vineStyle),
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
                          _vineStyleSubtitle(vineStyle),
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
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<VineStyle>(
                  showSelectedIcon: false,
                  segments: <ButtonSegment<VineStyle>>[
                    if (texturedSkinsEnabled)
                      const ButtonSegment<VineStyle>(
                        value: VineStyle.classic,
                        icon: Icon(Icons.park),
                        label: Text('Classic'),
                      ),
                    if (texturedSkinsEnabled)
                      const ButtonSegment<VineStyle>(
                        value: VineStyle.blossom,
                        icon: Icon(Icons.local_florist),
                        label: Text('Blossom'),
                      ),
                    if (texturedSkinsEnabled)
                      const ButtonSegment<VineStyle>(
                        value: VineStyle.ethereal,
                        icon: Icon(Icons.star),
                        label: Text('Ethereal'),
                      ),
                    const ButtonSegment<VineStyle>(
                      value: VineStyle.simple,
                      icon: Icon(Icons.grid_view),
                      label: Text('Simple'),
                    ),
                  ],
                  selected: <VineStyle>{vineStyle},
                  onSelectionChanged: (Set<VineStyle> newSelection) async {
                    await ref
                        .read(vineStyleProvider.notifier)
                        .setStyle(newSelection.first);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BoardZoomTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoomAsync = ref.watch(boardZoomScaleProvider);

    return zoomAsync.when(
      data: (zoom) => ListTile(
        leading: Icon(
          Icons.zoom_in,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Board Default Zoom'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adjust how close the camera starts'),
            Slider(
              value: zoom,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: '${zoom.toStringAsFixed(1)}x',
              onChanged: (value) async {
                await ref.read(boardZoomScaleProvider.notifier).setScale(value);
              },
            ),
          ],
        ),
      ),
      loading: () => const ListTile(
        leading: Icon(Icons.zoom_in),
        title: Text('Board Default Zoom'),
        subtitle: LinearProgressIndicator(),
      ),
      error: (e, s) => ListTile(
        leading: const Icon(Icons.error),
        title: const Text('Board Default Zoom Error'),
        subtitle: Text(e.toString()),
      ),
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

IconData _vineStyleIcon(VineStyle style) {
  switch (style) {
    case VineStyle.classic:
      return Icons.park;
    case VineStyle.blossom:
      return Icons.local_florist;
    case VineStyle.ethereal:
      return Icons.star;
    case VineStyle.simple:
      return Icons.grid_view;
  }
}

String _vineStyleSubtitle(VineStyle style) {
  switch (style) {
    case VineStyle.classic:
      return 'Detailed wood branches with green leaves';
    case VineStyle.blossom:
      return 'Cherry blossom branches with pink flowers';
    case VineStyle.ethereal:
      return 'Glowing bioluminescent purple-blue magic vines';
    case VineStyle.simple:
      return 'High-contrast geometric shapes (accessibility)';
  }
}
