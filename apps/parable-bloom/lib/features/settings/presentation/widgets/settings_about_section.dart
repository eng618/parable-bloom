import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/settings_providers.dart';

/// Version row and third-party audio credits.
class SettingsAboutSection extends ConsumerWidget {
  const SettingsAboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);

    return Column(
      children: [
        versionAsync.when(
          data: (version) => ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: Text(version),
          ),
          loading: () => const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('Loading...'),
          ),
          error: (error, stack) => const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('Unknown'),
          ),
        ),
        ListTile(
          leading: Icon(Icons.library_music,
              color: Theme.of(context).colorScheme.primary),
          title: const Text('Audio credits'),
          subtitle: const Text('Music and sound effect licenses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            unawaited(ref.read(sfxControllerProvider).playMenuOpen());
            unawaited(
              _showAudioCreditsSheet(context).whenComplete(() {
                unawaited(ref.read(sfxControllerProvider).playMenuClose());
              }),
            );
          },
        ),
      ],
    );
  }
}

class _AudioCredit {
  const _AudioCredit({
    required this.title,
    required this.detail,
    this.sourceUrl,
  });

  final String title;
  final String detail;
  final String? sourceUrl;
}

const List<_AudioCredit> _audioCredits = [
  _AudioCredit(
    title: 'Background music',
    detail: 'ViraMiller. License: CC BY 4.0.',
    sourceUrl: 'https://freesound.org/people/ViraMiller/sounds/744064/',
  ),
  _AudioCredit(
    title: 'Original gameplay SFX',
    detail:
        'Slide, rustle, bloom, blocked, grace loss, level complete, and UI tap. Copyright © 2026 Eric Garcia (GVTech). All rights reserved.',
  ),
  _AudioCredit(
    title: 'Case Portman UI SFX (Free Sample Pack)',
    detail: 'Credit: “Case Portman Audio”',
    sourceUrl: 'https://caseportman.itch.io/cute-cozy-ui-sfx-free-sample-pack',
  ),
  _AudioCredit(
    title: 'Nature Sounds Pack by Antoinemax',
    detail: 'License: CC-BY 4.0. https://creativecommons.org/licenses/by/4.0/',
    sourceUrl: 'https://opengameart.org/content/nature-sounds-pack',
  ),
];

Future<void> _showAudioCreditsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView.builder(
          controller: controller,
          padding: const EdgeInsets.all(24),
          itemCount: _audioCredits.length + 1,
          itemBuilder: (c, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Audio credits',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              );
            }
            final credit = _audioCredits[index - 1];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      credit.title,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(credit.detail,
                        style: Theme.of(ctx).textTheme.bodySmall),
                    if (credit.sourceUrl != null) ...[
                      const SizedBox(height: 6),
                      SelectableText(
                        credit.sourceUrl!,
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.primary),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
