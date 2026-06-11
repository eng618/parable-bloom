import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/settings_providers.dart';

class PauseMenuDialog extends ConsumerWidget {
  final VoidCallback onRestart;
  final VoidCallback onHome;

  const PauseMenuDialog({
    super.key,
    required this.onRestart,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final audioEnabled = ref.watch(backgroundAudioEnabledProvider);
    final hapticsEnabled = ref.watch(hapticsEnabledProvider);
    final vineStyle = ref.watch(vineStyleProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Paused',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 24),

            // Settings Toggles
            _buildSettingRow(
              context,
              icon: audioEnabled ? Icons.music_note : Icons.music_off,
              label: 'Music',
              value: audioEnabled,
              onChanged: (val) => ref
                  .read(backgroundAudioEnabledProvider.notifier)
                  .setEnabled(val),
            ),
            const SizedBox(height: 12),
            _buildSettingRow(
              context,
              icon: hapticsEnabled ? Icons.vibration : Icons.smartphone,
              label: 'Haptics',
              value: hapticsEnabled,
              onChanged: (val) =>
                  ref.read(hapticsEnabledProvider.notifier).setEnabled(val),
            ),
            const SizedBox(height: 16),
            Text(
              'Vine Style',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<VineStyle>(
                segments: const [
                  ButtonSegment(
                    value: VineStyle.classic,
                    icon: Icon(Icons.park_outlined),
                    tooltip: 'Classic Style',
                  ),
                  ButtonSegment(
                    value: VineStyle.blossom,
                    icon: Icon(Icons.local_florist_outlined),
                    tooltip: 'Cherry Blossom',
                  ),
                  ButtonSegment(
                    value: VineStyle.ethereal,
                    icon: Icon(Icons.star_outline),
                    tooltip: 'Ethereal Magic',
                  ),
                  ButtonSegment(
                    value: VineStyle.simple,
                    icon: Icon(Icons.grid_view_outlined),
                    tooltip: 'Simple Shapes',
                  ),
                ],
                selected: {vineStyle},
                onSelectionChanged: (Set<VineStyle> newSelection) {
                  ref
                      .read(vineStyleProvider.notifier)
                      .setStyle(newSelection.first);
                },
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.comfortable,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Theme',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<AppThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: AppThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    tooltip: 'Light Mode',
                  ),
                  ButtonSegment(
                    value: AppThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    tooltip: 'System Default',
                  ),
                  ButtonSegment(
                    value: AppThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    tooltip: 'Dark Mode',
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (Set<AppThemeMode> newSelection) {
                  ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(newSelection.first);
                },
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.comfortable,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  context,
                  icon: Icons.home_rounded,
                  label: 'Home',
                  onTap: onHome,
                  isPrimary: false,
                ),
                _buildActionButton(
                  context,
                  icon: Icons.play_arrow_rounded,
                  label: 'Resume',
                  onTap: () => Navigator.of(context).pop(),
                  isPrimary: true,
                ),
                _buildActionButton(
                  context,
                  icon: Icons.replay_rounded,
                  label: 'Restart',
                  onTap: onRestart,
                  isPrimary: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 16),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor =
        isPrimary ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final fgColor = isPrimary ? colorScheme.onPrimary : colorScheme.onSurface;

    return Column(
      children: [
        Material(
          color: bgColor,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Icon(icon, color: fgColor, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
