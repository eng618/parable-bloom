import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/game_providers.dart';

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
            const SizedBox(height: 12),
            _buildThemeRow(context, ref, themeMode),

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
                  icon: Icons.replay_rounded,
                  label: 'Restart',
                  onTap: onRestart,
                  isPrimary: true,
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

  Widget _buildThemeRow(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode currentMode,
  ) {
    IconData icon;
    String label;

    switch (currentMode) {
      case AppThemeMode.light:
        icon = Icons.light_mode;
        label = 'Light';
        break;
      case AppThemeMode.dark:
        icon = Icons.dark_mode;
        label = 'Dark';
        break;
      case AppThemeMode.system:
        icon = Icons.brightness_auto;
        label = 'System';
        break;
    }

    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Theme: $label',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          splashColor: Colors.transparent,
          onPressed: () {
            // Cycle through themes
            final nextMode = AppThemeMode
                .values[(currentMode.index + 1) % AppThemeMode.values.length];
            ref.read(themeModeProvider.notifier).setThemeMode(nextMode);
          },
        ),
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
