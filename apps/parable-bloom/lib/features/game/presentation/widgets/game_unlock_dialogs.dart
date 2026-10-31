import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/settings_providers.dart';
import '../../../../core/services/logger_service.dart';
import '../../../journal/application/providers/journal_providers.dart';
import '../../domain/entities/level_data.dart';

/// Scripture and parable dialogs shown when a level clear unlocks content.

Future<void> showScriptureUnlockedDialog(
  BuildContext context,
  WidgetRef ref,
  ModuleScripture scripture,
  ModuleData module, {
  required VoidCallback onHome,
  required VoidCallback onViewJournal,
  required VoidCallback onContinue,
}) async {
  if (!context.mounted) return;

  ref.read(analyticsServiceProvider).logParableViewed(scripture.id);

  // Single-version UX: always render the user's preferred translation.
  final preferred = ref.read(preferredTranslationProvider);

  String resolvedText = '';
  String displayCitation = scripture.reference;
  String translationCode = preferred.toUpperCase();
  bool didFallback = false;
  bool requiresDownload = false;
  String themeName = module.name;
  String? reflectionPrompt;

  try {
    final themes = await ref.read(journalThemesProvider.future);
    for (final theme in themes) {
      for (final passage in theme.passages) {
        if (passage.id == scripture.id ||
            passage.reference == scripture.reference) {
          themeName = theme.name;
          if (passage.reflectionPrompts.isNotEmpty) {
            reflectionPrompt = passage.reflectionPrompts.first;
          }
          break;
        }
      }
    }
  } catch (_) {}

  try {
    final result = await ref.read(scriptureServiceProvider).loadScripture(
          scripture.reference,
          preferredTranslationId: preferred,
        );

    resolvedText = result['text'] ?? '';
    translationCode = result['translation'] ?? preferred.toUpperCase();
    displayCitation = '${scripture.reference} ($translationCode)';
    didFallback = result['didFallback'] == 'true';
    requiresDownload = result['requiresDownload'] == 'true';
  } catch (e, stack) {
    LoggerService.error(
      'Error loading scripture for unlocked dialog',
      error: e,
      stackTrace: stack,
      tag: 'GameScreen',
    );
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final cs = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        backgroundColor: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.spa, color: cs.primary, size: 28),
            const SizedBox(width: 8),
            Text(
              scripture.type == 'starter'
                  ? 'Starter Scripture!'
                  : 'Scripture Collected!',
              style: TextStyle(
                color: cs.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                scripture.title,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (resolvedText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Text(
                    resolvedText,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  context.push('/settings');
                },
                child: Text(
                  displayCitation,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (didFallback && requiresDownload) ...[
                const SizedBox(height: 8),
                Text(
                  'Needs internet once to download $translationCode, then works offline. Showing fallback for now.',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (reflectionPrompt != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: cs.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.help_outline, size: 16, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reflectionPrompt,
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Added to your Journal under $themeName.',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onHome();
            },
            child: const Text('HOME'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onViewJournal();
            },
            child: const Text('VIEW JOURNAL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onContinue();
            },
            child: const Text('CONTINUE'),
          ),
        ],
      );
    },
  );
}

Future<void> showParableUnlockedDialog(
  BuildContext context,
  WidgetRef ref,
  ModuleData module, {
  required VoidCallback onHome,
  required void Function(String? scriptureReference) onViewJournal,
  required VoidCallback onContinue,
}) async {
  if (!context.mounted) return;

  ref.read(analyticsServiceProvider).logParableViewed(module.id.toString());

  final parable = module.parable;
  final title = (parable['title'] as String?)?.trim();
  final scripture = (parable['scripture'] as String?)?.trim();
  final reflection = (parable['reflection'] as String?)?.trim();

  String resolvedText = (parable['content'] as String?)?.trim() ?? '';
  String displayCitation = scripture ?? '';

  if (scripture != null && scripture.isNotEmpty) {
    try {
      final preferred = ref.read(preferredTranslationProvider);

      final result = await ref.read(scriptureServiceProvider).loadScripture(
            scripture,
            preferredTranslationId: preferred,
          );

      resolvedText = result['text'] ?? resolvedText;
      final translationCode = result['translation'] ?? preferred.toUpperCase();
      displayCitation = '$scripture ($translationCode)';
    } catch (e, stack) {
      LoggerService.error(
        'Error loading scripture for unlocked parable dialog',
        error: e,
        stackTrace: stack,
        tag: 'GameScreen',
      );
    }
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final cs = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        backgroundColor: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title?.isNotEmpty == true ? title! : 'Parable Unlocked',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book, size: 48),
              const SizedBox(height: 12),
              if (module.unlockMessage.trim().isNotEmpty)
                Text(
                  module.unlockMessage,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              if (displayCitation.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  displayCitation,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (resolvedText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  resolvedText,
                  style: TextStyle(color: cs.onSurface, fontSize: 14),
                  textAlign: TextAlign.left,
                ),
              ],
              if (reflection?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  reflection!,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  textAlign: TextAlign.left,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onHome();
            },
            child: const Text('HOME'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onViewJournal(scripture);
            },
            child: const Text('GO TO JOURNAL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onContinue();
            },
            child: const Text('CONTINUE'),
          ),
        ],
      );
    },
  );
}
