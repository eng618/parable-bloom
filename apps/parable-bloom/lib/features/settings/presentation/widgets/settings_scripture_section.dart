import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/settings_providers.dart';

/// Preferred translation and scripture license notices.
class SettingsScriptureSection extends ConsumerWidget {
  const SettingsScriptureSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _PreferredTranslationTile(),
        ListTile(
          leading: Icon(Icons.copyright,
              color: Theme.of(context).colorScheme.primary),
          title: const Text('Scripture Attributions'),
          subtitle: const Text('Bible translation licenses & notices'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showAttributionsSheet(context, ref),
        ),
      ],
    );
  }
}

class _PreferredTranslationTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferred = ref.watch(preferredTranslationProvider);
    final activeAsync = ref.watch(activeTranslationsProvider);

    return activeAsync.when(
      data: (translations) {
        final meta = translations.firstWhere(
          (t) => (t['id'] as String).toLowerCase() == preferred,
          orElse: () => translations.isNotEmpty
              ? translations.first
              : {
                  'id': preferred,
                  'abbreviation': preferred.toUpperCase(),
                  'name': 'Bible'
                },
        );
        final abbr =
            (meta['abbreviation'] as String?) ?? preferred.toUpperCase();
        final name = (meta['name'] as String?) ?? 'Bible Translation';
        return ListTile(
          leading: Icon(Icons.menu_book,
              color: Theme.of(context).colorScheme.primary),
          title: const Text('Preferred Translation'),
          subtitle: Text('$name ($abbr) — applies everywhere instantly'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              _showTranslationPicker(context, ref, translations, preferred),
        );
      },
      loading: () => const ListTile(
        leading: Icon(Icons.menu_book),
        title: Text('Preferred Translation'),
        subtitle: Text('Loading…'),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.error),
        title: const Text('Preferred Translation'),
        subtitle: Text('Error: $e'),
      ),
    );
  }
}

Future<void> _showTranslationPicker(
  BuildContext context,
  WidgetRef ref,
  List<Map<String, dynamic>> translations,
  String current,
) async {
  final selected = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Preferred Translation'),
      content: SizedBox(
        width: double.maxFinite,
        child: RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.of(dialogContext).pop(v),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: translations.length,
            itemBuilder: (ctx, i) {
              final t = translations[i];
              final id = (t['id'] as String).toLowerCase();
              final abbr = t['abbreviation'] as String? ?? id.toUpperCase();
              final name = t['name'] as String? ?? id;
              final hint = t['readabilityHint'] as String? ?? '';
              final onDemand = t['onDemand'] == true;
              return RadioListTile<String>(
                value: id,
                title: Text('$name ($abbr)'),
                subtitle: Text(
                    onDemand ? '$hint • downloads once, then offline' : hint),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  if (selected == null || selected == current) return;
  await ref.read(preferredTranslationProvider.notifier).setPreferred(selected);
  // Background prefetch of on-demand texts so they work offline next time.
  try {
    final service = ref.read(scriptureServiceProvider);
    final refs = service.knownReferences;
    if (refs.isNotEmpty) {
      // Fire and forget.
      // ignore: unawaited_futures
      service.prefetchTranslations(refs, selected);
    }
  } catch (_) {}
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Preference saved — Journal and new unlocks now show (${selected.toUpperCase()})')),
    );
  }
}

Future<void> _showAttributionsSheet(BuildContext context, WidgetRef ref) async {
  final translations = await ref.read(activeTranslationsProvider.future);
  if (!context.mounted) return;
  showModalBottomSheet<void>(
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
          itemCount: translations.length + 1,
          itemBuilder: (c, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Scripture Attributions',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              );
            }
            final t = translations[index - 1];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t['name']} (${t['abbreviation']})',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text((t['copyrightNotice'] as String?) ?? '',
                        style: Theme.of(ctx).textTheme.bodySmall),
                    if ((t['infoUrl'] as String?) != null) ...[
                      const SizedBox(height: 6),
                      Text(t['infoUrl'] as String,
                          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.primary)),
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
