import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';

/// Calm session-close titles/bodies (no-verse path).
const String kSessionCloseNoVerseTitle = 'The garden rests.';
const String kSessionCloseNoVerseBody =
    'Come back tomorrow — another vine awaits.';

/// Calm session-close titles/bodies (verse unlocked this session/day).
const String kSessionCloseVerseTitle = 'A seed for tomorrow.';
const String kSessionCloseVerseBody = 'Rest with this verse when you return.';

/// Welcome-back lines under the Home brand title (prior calendar day).
const List<String> kWelcomeBackMessages = [
  'Welcome back. The garden missed your hands.',
  'Good to see you again.',
];

/// Time-based pick so consecutive returns vary the welcome line.
String pickWelcomeBackMessage([List<String> messages = kWelcomeBackMessages]) {
  if (messages.isEmpty) return '';
  return messages[DateTime.now().millisecondsSinceEpoch % messages.length];
}

/// Result of the session-close invite.
enum SessionCloseAction { done, journal, dismiss }

/// Soft end-of-session invite: goodbye, optional Journal when a verse is fresh.
Future<SessionCloseAction?> showSessionCloseSheet(
  BuildContext context, {
  required bool hadScriptureUnlock,
}) {
  final title =
      hadScriptureUnlock ? kSessionCloseVerseTitle : kSessionCloseNoVerseTitle;
  final body =
      hadScriptureUnlock ? kSessionCloseVerseBody : kSessionCloseNoVerseBody;

  return showModalBottomSheet<SessionCloseAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      final textTheme = Theme.of(sheetContext).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/art/ornaments/leaf_sprig.png',
                  height: 56,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTheme.displayFontFamily,
                  fontFamilyFallback: AppTheme.displayFontFallback,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                      child:
                          Divider(color: cs.outline.withValues(alpha: 0.45))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Image.asset(
                      'assets/art/ornaments/leaf_pair.png',
                      height: 18,
                      color: cs.secondary,
                      colorBlendMode: BlendMode.srcIn,
                      excludeFromSemantics: true,
                    ),
                  ),
                  Expanded(
                      child:
                          Divider(color: cs.outline.withValues(alpha: 0.45))),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                body,
                style: textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              if (hadScriptureUnlock) ...[
                ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext)
                      .pop(SessionCloseAction.journal),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'View Journal',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTheme.displayFontFamily,
                      fontFamilyFallback: AppTheme.displayFontFallback,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(SessionCloseAction.done),
                  child: Text(
                    'Done for now',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(SessionCloseAction.done),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.eco_outlined, size: 20),
                  label: const Text(
                    'Done for now',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTheme.displayFontFamily,
                      fontFamilyFallback: AppTheme.displayFontFallback,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  ).then((value) => value ?? SessionCloseAction.dismiss);
}
