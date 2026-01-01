import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/game_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final backgroundAudioEnabled = ref.watch(backgroundAudioEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader(context, 'Appearance'),
          _buildThemeTile(context, ref, themeMode),
          const Divider(),
          _buildSectionHeader(context, 'Audio'),
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
          const Divider(),
          _buildSectionHeader(context, 'Data & Sync'),
          _buildCloudSyncTile(context, ref),
          const Divider(),
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Danger Zone'),
          _buildResetDataTile(context, ref),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThemeTile(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode currentMode,
  ) {
    return ListTile(
      leading: Icon(_getThemeIcon(currentMode)),
      title: const Text('Theme'),
      subtitle: Text(_getThemeLabel(currentMode)),
      onTap: () => _showThemeDialog(context, ref, currentMode),
    );
  }

  IconData _getThemeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.settings_brightness;
    }
  }

  String _getThemeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }

  Widget _buildCloudSyncTile(BuildContext context, WidgetRef ref) {
    final syncEnabledAsync = ref.watch(cloudSyncEnabledProvider);
    final syncAvailableAsync = ref.watch(cloudSyncAvailableProvider);
    final lastSyncAsync = ref.watch(lastSyncTimeProvider);

    return Column(
      children: [
        // Main sync toggle
        syncEnabledAsync.when(
          data: (isEnabled) => SwitchListTile(
            secondary: Icon(
              isEnabled ? Icons.cloud_done : Icons.cloud_off,
              color: isEnabled
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            title: const Text('Cloud Sync'),
            subtitle: const Text('Backup progress across devices'),
            value: isEnabled,
            onChanged: (value) async {
              final notifier = ref.read(gameProgressProvider.notifier);
              if (value) {
                await notifier.enableCloudSync();
              } else {
                await notifier.disableCloudSync();
              }
              // Refresh the UI
              ref.invalidate(cloudSyncEnabledProvider);
            },
          ),
          loading: () => const ListTile(
            leading: CircularProgressIndicator(),
            title: Text('Cloud Sync'),
            subtitle: Text('Loading...'),
          ),
          error: (error, stack) => ListTile(
            leading: const Icon(Icons.error, color: Colors.red),
            title: const Text('Cloud Sync'),
            subtitle: Text('Error: ${error.toString()}'),
          ),
        ),

        // Sync status information
        syncAvailableAsync.when(
          data: (isAvailable) => syncEnabledAsync.maybeWhen(
            data: (isEnabled) {
              if (!isEnabled) return const SizedBox.shrink();

              final availabilityText = isAvailable
                  ? 'Available'
                  : 'Unavailable (check internet connection)';
              final availabilityColor = isAvailable
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error;

              return Padding(
                padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      isAvailable ? Icons.check_circle : Icons.error,
                      size: 16,
                      color: availabilityColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        availabilityText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: availabilityColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
        ),

        // Last sync time
        lastSyncAsync.when(
          data: (lastSync) => syncEnabledAsync.maybeWhen(
            data: (isEnabled) {
              if (!isEnabled || lastSync == null) {
                return const SizedBox.shrink();
              }

              final timeAgo = _getTimeAgo(lastSync);
              return Padding(
                padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Last synced $timeAgo',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'just now';
    }
  }

  Widget _buildResetDataTile(BuildContext context, WidgetRef ref) {
    return ListTile(
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
    );
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
            _buildWarningItem(dialogContext, 'Local game progress'),
            _buildWarningItem(dialogContext, 'Module completion data'),
            _buildWarningItem(dialogContext, 'Settings and preferences'),
            _buildWarningItem(dialogContext, 'Cloud sync data'),
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
            onPressed: () => _performDataReset(dialogContext, ref),
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

  Widget _buildWarningItem(BuildContext context, String item) {
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
    Navigator.of(context).pop();

    // Store service references before async operations
    final firestore = ref.read(firestoreProvider);
    final auth = ref.read(firebaseAuthProvider);
    final box = ref.read(hiveBoxProvider);

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
      firestore: firestore,
      auth: auth,
      box: box,
      ref: ref,
      loadingContext: loadingContext,
      originalContext: context,
    );
  }

  Future<void> _performResetAsync({
    required dynamic firestore,
    required dynamic auth,
    required dynamic box,
    required WidgetRef ref,
    required BuildContext? loadingContext,
    required BuildContext originalContext,
  }) async {
    try {
      // 1. Clear Firebase data
      debugPrint('ResetData: Clearing Firebase data...');
      final user = auth.currentUser;

      if (user != null) {
        // Clear user's cloud data
        final userDoc = firestore.collection('users').doc(user.uid);
        await userDoc.delete();
        debugPrint('ResetData: Firebase data cleared for user ${user.uid}');
      }

      // 2. Clear Hive data
      debugPrint('ResetData: Clearing Hive data...');
      await box.clear();
      debugPrint('ResetData: Hive data cleared');

      // 3. Invalidate all Riverpod providers to force fresh state
      debugPrint('ResetData: Invalidating providers...');
      ref.invalidate(gameProgressProvider);
      ref.invalidate(globalProgressProvider);
      ref.invalidate(currentLevelProvider);
      ref.invalidate(levelCompleteProvider);
      ref.invalidate(gameCompletedProvider);
      ref.invalidate(gameOverProvider);
      ref.invalidate(graceProvider);
      ref.invalidate(levelTotalTapsProvider);
      ref.invalidate(levelWrongTapsProvider);
      ref.invalidate(vineStatesProvider);
      ref.invalidate(themeModeProvider);

      // 4. Close the loading dialog safely
      if (loadingContext != null &&
          loadingContext.mounted &&
          Navigator.canPop(loadingContext)) {
        Navigator.of(loadingContext).pop();
      }

      if (!originalContext.mounted) return;

      // 5. Show success message and restart app
      debugPrint('ResetData: Showing success message...');
      ScaffoldMessenger.of(originalContext).showSnackBar(
        const SnackBar(
          content: Text('All data reset successfully. Restarting app...'),
          duration: Duration(seconds: 2),
        ),
      );

      // 6. Restart the app by navigating to home and clearing navigation stack
      debugPrint('ResetData: Restarting app...');
      await Future.delayed(const Duration(seconds: 2));

      if (!originalContext.mounted) return;
      Navigator.of(
        originalContext,
      ).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      debugPrint('ResetData: Error during reset: $e');

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

  void _showThemeDialog(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode currentMode,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            final isSelected = mode == currentMode;
            return ListTile(
              leading: Icon(
                _getThemeIcon(mode),
                color: isSelected
                    ? Theme.of(dialogContext).colorScheme.primary
                    : null,
              ),
              title: Text(
                _getThemeLabel(mode),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(dialogContext).colorScheme.primary
                      : null,
                ),
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode(mode);
                Navigator.of(dialogContext).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
