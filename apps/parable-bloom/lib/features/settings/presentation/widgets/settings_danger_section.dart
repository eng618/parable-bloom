import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/infrastructure_providers.dart';
import '../../../../core/providers/settings_providers.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/application/providers/auth_providers.dart';
import '../../../game/application/providers/counter_providers.dart';
import '../../../game/application/providers/gameplay_state_providers.dart';
import '../../../game/application/providers/progress_providers.dart';
import '../../../tutorial/application/providers/tutorial_providers.dart';

/// Reset-all-data and delete-account actions.
class SettingsDangerSection extends ConsumerWidget {
  const SettingsDangerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider).value;
    final showDeleteAccount = user != null && !user.isAnonymous;

    return Column(
      children: [
        ListTile(
          leading: Icon(
            Icons.delete_forever,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Reset All Data',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          subtitle: const Text('Delete all progress, settings, and cloud data'),
          onTap: () => _showResetDataDialog(context, ref),
        ),
        if (showDeleteAccount)
          ListTile(
            leading: Icon(
              Icons.person_remove,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete Account',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle:
                const Text('Permanently delete your account and cloud data'),
            onTap: () => _showDeleteAccountDialog(context, ref),
          ),
      ],
    );
  }
}

void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning,
            color: Theme.of(dialogContext).colorScheme.error,
          ),
          const SizedBox(width: 8),
          const Text('Delete Account'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This action cannot be undone. This will permanently delete your account, including all cloud data, settings, and progress associated with it.',
            style: Theme.of(dialogContext).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'You may be required to sign in again before deletion can complete.',
            style: Theme.of(
              dialogContext,
            ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            _performAccountDeletion(context, ref);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          child: const Text('Delete Account'),
        ),
      ],
    ),
  );
}

void _performAccountDeletion(BuildContext context, WidgetRef ref) async {
  BuildContext? loadingContext;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      loadingContext = ctx;
      return const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Deleting account...'),
          ],
        ),
      );
    },
  );

  try {
    // 1. Purge cloud progress and local progress while still authenticated
    await ref.read(gameProgressProvider.notifier).resetProgress();

    // 2. Delete the user account from Firebase Auth
    final authService = ref.read(authServiceProvider);
    await authService.deleteAccount();

    // Navigate back to the start or login screen when done
    if (loadingContext != null && loadingContext!.mounted) {
      Navigator.of(loadingContext!).pop();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account successfully deleted.')),
      );
      context.go('/auth');
    }
  } catch (e) {
    if (loadingContext != null && loadingContext!.mounted) {
      Navigator.of(loadingContext!).pop();
    }

    // Reauthentication might be required.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to delete account: $e\n\nYou may need to sign out and sign back in to verify your identity before deleting your account.'),
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }
}

void _showResetDataDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning,
            color: Theme.of(dialogContext).colorScheme.error,
          ),
          const SizedBox(width: 8),
          const Text('Reset All Data'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This action cannot be undone. This will permanently delete:',
            style: Theme.of(dialogContext).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _warningItem(dialogContext, 'Local game progress'),
          _warningItem(dialogContext, 'Module completion data'),
          _warningItem(dialogContext, 'Settings and preferences'),
          _warningItem(dialogContext, 'Cloud sync data'),
          const SizedBox(height: 16),
          Text(
            'The app will restart with a fresh installation.',
            style: Theme.of(
              dialogContext,
            ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          // Use the outer screen context (not the dialog's) so subsequent
          // navigation and dialogs operate on a mounted navigator.
          onPressed: () => _performDataReset(context, ref),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          child: const Text('Reset Everything'),
        ),
      ],
    ),
  );
}

Widget _warningItem(BuildContext context, String item) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(
          Icons.delete,
          size: 16,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(width: 8),
        Text(item, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

void _performDataReset(BuildContext context, WidgetRef ref) {
  // Close the confirmation dialog immediately (before any async work)
  if (context.canPop()) context.pop();

  // Show loading dialog and capture its context
  BuildContext? loadingContext;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      loadingContext = ctx;
      return const AlertDialog(
        title: Text('Resetting Data...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('This may take a moment...'),
          ],
        ),
      );
    },
  );

  // Perform async operations without awaiting, using .then() and .catchError()
  _performResetAsync(
    ref: ref,
    loadingContext: loadingContext,
    originalContext: context,
  );
}

Future<void> _performResetAsync({
  required WidgetRef ref,
  required BuildContext? loadingContext,
  required BuildContext originalContext,
}) async {
  try {
    // 1. Reset progress through the repository: reseeds local Hive with
    // initial progress AND deletes the real cloud progress doc
    // ({env}/{uid}/data/{progressDoc}). A previous revision deleted
    // `users/{uid}` (which never holds progress) and left cloud data
    // behind to resurrect local state on the next sync.
    LoggerService.info('Resetting game progress...', tag: 'ResetData');
    await ref.read(gameProgressProvider.notifier).resetProgress();
    LoggerService.info('Game progress reset', tag: 'ResetData');

    // 2. Clear remaining Hive data (settings, preferences, cached
    // registries, journal display state).
    LoggerService.info('Clearing Hive data...', tag: 'ResetData');
    final box = ref.read(hiveBoxProvider);
    await box.clear();
    LoggerService.info('Hive data cleared', tag: 'ResetData');

    // 3. Invalidate in-memory provider state BEFORE navigating: after
    // push/go the settings element is unmounted and its ref is disposed,
    // so any invalidate here would throw and be swallowed (this was the
    // "still on the same level" bug — only gameProgressProvider was
    // invalidated, after navigation, so it never ran).
    // NB: tutorialProgressProvider reads (not watches) gameProgress, so
    // it goes stale unless explicitly invalidated.
    LoggerService.debug('Invalidating providers...', tag: 'ResetData');
    ref.invalidate(gameProgressProvider);
    ref.invalidate(tutorialProgressProvider);
    ref.invalidate(currentLevelProvider);
    ref.invalidate(levelCompleteProvider);
    ref.invalidate(gameCompletedProvider);
    ref.invalidate(graceProvider);
    ref.invalidate(gameOverProvider);
    ref.invalidate(gameInstanceProvider);
    ref.invalidate(levelTotalTapsProvider);
    ref.invalidate(levelWrongTapsProvider);
    ref.invalidate(levelAttemptCountProvider);
    ref.invalidate(levelStartTimestampProvider);
    ref.invalidate(themeModeProvider);
    ref.invalidate(backgroundAudioEnabledProvider);
    ref.invalidate(hapticsEnabledProvider);
    ref.invalidate(vineStyleProvider);
    ref.invalidate(preferredTranslationProvider);
    LoggerService.info('Reset completed successfully', tag: 'ResetData');

    // 4. Close the loading dialog.
    try {
      if (loadingContext != null && loadingContext.mounted) {
        Navigator.of(loadingContext).pop();
        LoggerService.debug('Loading dialog closed', tag: 'ResetData');
      }
    } catch (dialogError, stack) {
      LoggerService.error('Error closing dialog',
          error: dialogError, stackTrace: stack, tag: 'ResetData');
    }

    // 5. Navigate home via go_router (the app's router). Do not use
    // Navigator.pushAndRemoveUntil: it stacks a non-router HomeScreen
    // above the router and leaves router location stale.
    if (!originalContext.mounted) {
      LoggerService.warn('Original context not mounted, aborting',
          tag: 'ResetData');
      return;
    }
    LoggerService.info('Navigating to home screen...', tag: 'ResetData');
    originalContext.go('/');
  } catch (e, stack) {
    LoggerService.error('Error during reset',
        error: e, stackTrace: stack, tag: 'ResetData');

    // Close loading dialog safely
    if (loadingContext != null &&
        loadingContext.mounted &&
        Navigator.canPop(loadingContext)) {
      Navigator.of(loadingContext).pop();
    }

    if (!originalContext.mounted) return;
    // Show error message
    ScaffoldMessenger.of(originalContext).showSnackBar(
      SnackBar(
        content: Text('Error resetting data: ${e.toString()}'),
        backgroundColor: Theme.of(originalContext).colorScheme.error,
      ),
    );
  }
}
