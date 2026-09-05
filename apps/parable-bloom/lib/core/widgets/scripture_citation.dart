import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';

/// Tappable `Reference (ABBR)` citation that opens the attribution sheet.
class ScriptureCitation extends ConsumerWidget {
  final String reference;
  final String translationCode;
  final TextStyle? style;

  const ScriptureCitation({
    super.key,
    required this.reference,
    required this.translationCode,
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => showScriptureAttribution(context, ref, translationCode),
      child: Text(
        '$reference ($translationCode)',
        style: (style ??
                Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ))
            ?.copyWith(
          decoration: TextDecoration.underline,
          decorationColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

Future<void> showScriptureAttribution(
    BuildContext context, WidgetRef ref, String translationCode) async {
  final service = ref.read(scriptureServiceProvider);
  await service.initialize();
  final meta = service.getMetadata(translationCode.toLowerCase());
  if (!context.mounted) return;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      final textTheme = Theme.of(sheetContext).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meta == null
                  ? 'Bible Translation ($translationCode)'
                  : '${meta['name']} (${meta['abbreviation']})',
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              (meta?['copyrightNotice'] as String?) ??
                  'Scripture text shown in $translationCode.',
              style: textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (meta != null && (meta['publisher'] as String?) != null) ...[
              const SizedBox(height: 8),
              Text('Publisher: ${meta['publisher']}',
                  style: textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
            if (meta != null && (meta['infoUrl'] as String?) != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  await Clipboard.setData(
                      ClipboardData(text: meta['infoUrl'] as String));
                },
                child: Text(
                  meta['infoUrl'] as String,
                  style: textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Text('Tap to copy license link',
                  style: textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      );
    },
  );
}
