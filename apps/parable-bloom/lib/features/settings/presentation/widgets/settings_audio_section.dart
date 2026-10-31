import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/settings_providers.dart';

/// Background music and haptic toggles.
class SettingsAudioSection extends ConsumerWidget {
  const SettingsAudioSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundAudioEnabled = ref.watch(backgroundAudioEnabledProvider);
    final hapticsEnabled = ref.watch(hapticsEnabledProvider);

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(
            backgroundAudioEnabled ? Icons.music_note : Icons.music_off,
            color: backgroundAudioEnabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          title: const Text('Background Audio'),
          subtitle: const Text('Play background music on a loop'),
          value: backgroundAudioEnabled,
          onChanged: (value) async {
            await ref
                .read(backgroundAudioEnabledProvider.notifier)
                .setEnabled(value);
          },
        ),
        SwitchListTile(
          secondary: Icon(
            hapticsEnabled ? Icons.vibration : Icons.smartphone,
            color: hapticsEnabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          title: const Text('Haptic Feedback'),
          subtitle: const Text('Vibrate on game events'),
          value: hapticsEnabled,
          onChanged: (value) async {
            await ref.read(hapticsEnabledProvider.notifier).setEnabled(value);
          },
        ),
      ],
    );
  }
}
