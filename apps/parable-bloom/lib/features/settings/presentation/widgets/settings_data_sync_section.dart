import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/settings_providers.dart';
import '../../../game/application/providers/gameplay_state_providers.dart';
import '../../../game/application/providers/progress_providers.dart';
import '../../../game/domain/entities/cloud_sync_state.dart';
import '../../../game/domain/entities/game_progress.dart';
import '../../../tutorial/application/providers/tutorial_providers.dart';

/// Cloud sync, telemetry, and tutorial replay.
class SettingsDataSyncSection extends ConsumerWidget {
  const SettingsDataSyncSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _CloudSyncTile(),
        _TelemetryTile(),
        ListTile(
          leading: const Icon(Icons.replay),
          title: const Text('Redo Tutorial'),
          subtitle: const Text('Restart the tutorial levels'),
          onTap: () => _showRedoTutorialDialog(context, ref),
        ),
      ],
    );
  }
}

class _CloudSyncTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncEnabledAsync = ref.watch(cloudSyncEnabledProvider);
    final availabilityAsync = ref.watch(cloudSyncAvailabilityProvider);
    final lastSyncAsync = ref.watch(lastSyncTimeProvider);

    return Column(
      children: [
        syncEnabledAsync.when(
          data: (isEnabled) => availabilityAsync.when(
            data: (availability) => SwitchListTile(
              secondary: Icon(
                isEnabled ? Icons.cloud_done : Icons.cloud_off,
                color: isEnabled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              title: const Text('Cloud Sync'),
              subtitle: Text(_syncSubtitleForAvailability(availability)),
              value: isEnabled,
              onChanged: (value) async {
                final notifier = ref.read(gameProgressProvider.notifier);
                if (value && !availability.isAvailable) {
                  await ref
                      .read(analyticsServiceProvider)
                      .logCloudSyncUnavailable(
                        source: 'settings_toggle',
                        reason: availability.reason.name,
                      );
                  if (!context.mounted) {
                    return;
                  }
                  await _showEnableSyncUnavailableDialog(
                    context,
                    availability,
                  );
                  return;
                }

                if (value) {
                  await notifier.enableCloudSync();
                  if (context.mounted) {
                    final conflict = await notifier.inspectSyncConflict();
                    if (conflict.requiresUserDecision && context.mounted) {
                      final resolution = await _showSyncConflictDialog(
                        context,
                        conflict,
                      );
                      if (resolution != null) {
                        await notifier.resolveSyncConflict(resolution);
                      }
                    }
                  }
                } else {
                  await notifier.disableCloudSync();
                }
                ref.invalidate(cloudSyncEnabledProvider);
                ref.invalidate(cloudSyncAvailabilityProvider);
              },
            ),
            loading: () => const ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Cloud Sync'),
              subtitle: Text('Loading account status...'),
            ),
            error: (error, stack) => ListTile(
              leading: const Icon(Icons.error, color: Colors.red),
              title: const Text('Cloud Sync'),
              subtitle: Text('Error: ${error.toString()}'),
            ),
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
        availabilityAsync.when(
          data: (availability) => syncEnabledAsync.maybeWhen(
            data: (isEnabled) {
              if (!isEnabled) return const SizedBox.shrink();

              final availabilityText =
                  _syncAvailabilityStatusText(availability);
              final availabilityColor = availability.isAvailable
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error;

              return Padding(
                padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      availability.isAvailable
                          ? Icons.check_circle
                          : Icons.error,
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
        lastSyncAsync.when(
          data: (lastSync) => syncEnabledAsync.maybeWhen(
            data: (isEnabled) {
              if (!isEnabled || lastSync == null) {
                return const SizedBox.shrink();
              }

              final timeAgo = _timeAgo(lastSync);
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
}

class _TelemetryTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetryEnabled = ref.watch(analyticsEnabledProvider);

    return SwitchListTile(
      secondary: Icon(
        telemetryEnabled ? Icons.analytics : Icons.analytics_outlined,
        color: telemetryEnabled
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      title: const Text('Anonymized Telemetry'),
      subtitle: const Text(
          'Help us improve gameplay by sharing anonymous usage statistics'),
      value: telemetryEnabled,
      onChanged: (value) async {
        await ref.read(analyticsEnabledProvider.notifier).setEnabled(value);
      },
    );
  }
}

String _syncSubtitleForAvailability(CloudSyncAvailability availability) {
  switch (availability.reason) {
    case CloudSyncAvailabilityReason.available:
      return 'Backup progress across devices';
    case CloudSyncAvailabilityReason.signedOut:
      return 'Sign in to enable cloud backup';
    case CloudSyncAvailabilityReason.anonymousAccount:
      return 'Create an account to sync your progress';
  }
}

String _syncAvailabilityStatusText(CloudSyncAvailability availability) {
  switch (availability.reason) {
    case CloudSyncAvailabilityReason.available:
      return 'Connected to your account';
    case CloudSyncAvailabilityReason.signedOut:
      return 'Unavailable: sign in to enable sync';
    case CloudSyncAvailabilityReason.anonymousAccount:
      return 'Unavailable: guest accounts cannot sync';
  }
}

Future<void> _showEnableSyncUnavailableDialog(
  BuildContext context,
  CloudSyncAvailability availability,
) async {
  final shouldOpenAuth = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cloud Sync Requires Account'),
      content: Text(
        availability.reason == CloudSyncAvailabilityReason.anonymousAccount
            ? 'You are currently playing as a guest. Create or sign in to an account to back up progress across devices.'
            : 'Sign in to your account to enable cloud sync and back up your progress.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sign In / Sign Up'),
        ),
      ],
    ),
  );

  if (shouldOpenAuth == true && context.mounted) {
    await context.push('/auth');
  }
}

String _progressSummary(GameProgress progress) {
  return 'Level ${progress.currentLevel} • ${progress.completedLevels.length} levels completed';
}

Future<SyncConflictResolution?> _showSyncConflictDialog(
  BuildContext context,
  SyncConflictState conflict,
) async {
  final cloudProgress = conflict.cloudProgress;
  if (cloudProgress == null) {
    return SyncConflictResolution.keepLocal;
  }

  return showDialog<SyncConflictResolution>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final localSummary = _progressSummary(conflict.localProgress);
      final cloudSummary = _progressSummary(cloudProgress);
      final title = conflict.type == SyncConflictType.localAhead
          ? 'Progress Found on This Device'
          : 'Choose Progress to Keep';

      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We found different progress locally and in the cloud. Choose which one should be kept and synced to all devices.',
            ),
            const SizedBox(height: 16),
            Text('This device: $localSummary'),
            const SizedBox(height: 8),
            Text('Cloud save: $cloudSummary'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              SyncConflictResolution.keepCloud,
            ),
            child: const Text('Use Cloud Save'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              SyncConflictResolution.keepLocal,
            ),
            child: const Text('Keep This Device'),
          ),
        ],
      );
    },
  );
}

String _timeAgo(DateTime dateTime) {
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

void _showRedoTutorialDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Redo Tutorial'),
      content: const Text(
        'This will reset your tutorial progress and allow you to play through the tutorial levels again. Your main game progress will not be affected.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _performRedoTutorial(context, ref),
          child: const Text('Redo Tutorial'),
        ),
      ],
    ),
  );
}

Future<void> _performRedoTutorial(BuildContext context, WidgetRef ref) async {
  if (context.canPop()) context.pop(); // Close dialog

  // Only reset the in-memory tutorial progress state - don't persist changes
  // This allows replaying the tutorial without affecting main game progress
  ref.read(tutorialProgressProvider.notifier).resetForReplay();

  // Invalidate current level to force reload
  ref.invalidate(currentLevelProvider);

  // Navigate directly to tutorial flow
  if (context.mounted) {
    context.go('/tutorial');
  }
}
