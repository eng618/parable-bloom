import 'package:flutter/material.dart';

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
  final title = hadScriptureUnlock
      ? kSessionCloseVerseTitle
      : kSessionCloseNoVerseTitle;
  final body = hadScriptureUnlock
      ? kSessionCloseVerseBody
      : kSessionCloseNoVerseBody;

  return showModalBottomSheet<SessionCloseAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(sheetContext).textTheme.titleLarge
                    ?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: Theme.of(sheetContext).textTheme.bodyLarge
                    ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (hadScriptureUnlock) ...[
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(sheetContext)
                          .pop(SessionCloseAction.journal),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'View Journal',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(SessionCloseAction.done),
                  child: Text(
                    'Done for now',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(SessionCloseAction.done),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Done for now',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
