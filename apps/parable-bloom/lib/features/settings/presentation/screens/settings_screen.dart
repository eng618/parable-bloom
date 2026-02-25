import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/game_providers.dart';
import '../../../../providers/tutorial_providers.dart';
import '../../../../screens/home_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/auth_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final backgroundAudioEnabled = ref.watch(backgroundAudioEnabledProvider);
    final hapticsEnabled = ref.watch(hapticsEnabledProvider);
    final useSimpleVines = ref.watch(useSimpleVinesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader(context, 'Account'),
          _buildAccountTile(context, ref),
          const Divider(),
          _buildSectionHeader(context, 'Appearance'),
          _buildThemeTile(context, ref, themeMode),
          _buildBoardZoomTile(context, ref),
          SwitchListTile(
            secondary: Icon(
              useSimpleVines ? Icons.grid_view : Icons.park,
              color: useSimpleVines
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            title: const Text('Classic Vines'),
            subtitle: const Text('Use simple vine assets (visually impaired mode)'),
            value: useSimpleVines,
            onChanged: (value) async {
              await ref.read(useSimpleVinesProvider.notifier).setEnabled(value);
            },
          ),
          const Divider(),
          _buildSectionHeader(context, 'Audio & Haptics'),
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
          const Divider(),
          _buildSectionHeader(context, 'Data & Sync'),
          _buildCloudSyncTile(context, ref),
          _buildRedoTutorialTile(context, ref),
          const Divider(),
          _buildSectionHeader(context, 'About'),
          _buildVersionTile(context, ref),
          const Divider(),
          if (kDebugMode || ref.watch(debugUiEnabledForTestsProvider)) ...[
            _buildSectionHeader(context, 'Debug'),
            _buildDebugGridCoordinatesTile(context, ref),
            _buildDebugVineAnimationLoggingTile(context, ref),
            _buildDebugLevelPickerTile(context, ref),
            const Divider(),
          ],
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

  Widget _buildAccountTile(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserProvider);

    return userAsync.when(
      data: (user) {
        final isAnonymous = user?.isAnonymous ?? true;
        final email = user?.email;
        final subtitle = isAnonymous
            ? 'Guest Account (Not Synced)'
            : 'Signed in as ${email ?? "User"}';

        return ListTile(
          leading: Icon(
            isAnonymous ? Icons.account_circle_outlined : Icons.account_circle,
            color: isAnonymous ? null : Theme.of(context).colorScheme.primary,
          ),
          title: Text(isAnonymous ? 'Sign In / Sign Up' : 'Account Status'),
          subtitle: Text(subtitle),
          trailing: isAnonymous
              ? const Icon(Icons.chevron_right)
              : IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await ref.read(authServiceProvider).signOut();
                  },
                ),
          onTap: isAnonymous
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AuthScreen(),
                    ),
                  );
                }
              : null, // Disable tap if already signed in, logic is in logout button
        );
      },
      loading: () => const ListTile(
        leading: CircularProgressIndicator(),
        title: Text('Account'),
      ),
      error: (e, s) => ListTile(
        leading: const Icon(Icons.error),
        title: const Text('Account Error'),
        subtitle: Text(e.toString()),
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

  Widget _buildBoardZoomTile(BuildContext context, WidgetRef ref) {
    final zoomAsync = ref.watch(boardZoomScaleProvider);
    
    return zoomAsync.when(
      data: (zoom) => ListTile(
        leading: Icon(
          Icons.zoom_in,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Board Default Zoom'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adjust how close the camera starts'),
            Slider(
              value: zoom,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: '${zoom.toStringAsFixed(1)}x',
              onChanged: (value) async {
                await ref.read(boardZoomScaleProvider.notifier).setScale(value);
              },
            ),
          ],
        ),
      ),
      loading: () => const ListTile(
        leading: Icon(Icons.zoom_in),
        title: Text('Board Default Zoom'),
        subtitle: LinearProgressIndicator(),
      ),
      error: (e, s) => ListTile(
        leading: const Icon(Icons.error),
        title: const Text('Board Default Zoom Error'),
        subtitle: Text(e.toString()),
      ),
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

  Widget _buildVersionTile(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);

    return versionAsync.when(
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
    );
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

  Widget _buildRedoTutorialTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.replay),
      title: const Text('Redo Tutorial'),
      subtitle: const Text('Restart the tutorial levels'),
      onTap: () => _showRedoTutorialDialog(context, ref),
    );
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

  Widget _buildDebugGridCoordinatesTile(BuildContext context, WidgetRef ref) {
    final showCoordinates = ref.watch(debugShowGridCoordinatesProvider);

    return SwitchListTile(
      secondary: Icon(
        Icons.grid_on,
        color: showCoordinates
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      title: const Text('Show Grid Coordinates'),
      subtitle: const Text('Display coordinate labels on grid cells'),
      value: showCoordinates,
      onChanged: (value) async {
        await ref
            .read(debugShowGridCoordinatesProvider.notifier)
            .setShowCoordinates(value);
      },
    );
  }

  Widget _buildDebugVineAnimationLoggingTile(
    BuildContext context,
    WidgetRef ref,
  ) {
    final loggingEnabled = ref.watch(debugVineAnimationLoggingProvider);

    return SwitchListTile(
      secondary: Icon(
        Icons.animation,
        color: loggingEnabled
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      title: const Text('Vine Animation Logging'),
      subtitle: const Text('Log vine animation details to console'),
      value: loggingEnabled,
      onChanged: (value) async {
        await ref
            .read(debugVineAnimationLoggingProvider.notifier)
            .setEnabled(value);
      },
    );
  }

  Widget _buildDebugLevelPickerTile(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(debugSelectedLevelProvider);
    final subtitle =
        selected == null ? 'No level selected' : 'Selected: Level $selected';

    return ListTile(
      leading: Icon(
        Icons.gamepad,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text('Play Any Level (Debug)'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final modules = await ref.read(modulesProvider.future);
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _showDebugLevelPickerDialog(context, ref, modules);
        });
      },
    );
  }

  void _showDebugLevelPickerDialog(
      BuildContext context, WidgetRef ref, List<dynamic> modules) {
    final safeContext = context;

    // Fetch modules and build level list
    final levels = <int>[];
    for (final m in modules) {
      for (int i = m.startLevel; i <= m.endLevel; i++) {
        levels.add(i);
      }
    }

    if (levels.isEmpty) {
      ScaffoldMessenger.of(safeContext).showSnackBar(
        const SnackBar(content: Text('No levels available')),
      );
      return;
    }

    int? selected = ref.read(debugSelectedLevelProvider);

    showDialog(
      context: safeContext,
      builder: (dialogContext) {
        return FutureBuilder<Map<int, String>>(
          future: _loadLabels(levels),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                title: const Text('Debug: Select Level to Play'),
                content: const CircularProgressIndicator(),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            }
            final labels = snapshot.data ?? {};
            return AlertDialog(
              title: const Text('Debug: Select Level to Play'),
              content: StatefulBuilder(builder: (ctx, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      isDense: true,
                      initialValue: selected,
                      items: levels
                          .map((lvl) => DropdownMenuItem<int>(
                                value: lvl,
                                child: Text(labels[lvl] ?? 'Level $lvl'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selected = value;
                        });
                        // Persist selection immediately in the debug provider so the Play
                        // button reflects the choice and other code can react sooner.
                        if (value != null) {
                          ref
                              .read(debugSelectedLevelProvider.notifier)
                              .setLevel(value);
                        }
                      },
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Level',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: selected == null
                              ? null
                              : () {
                                  ref
                                      .read(debugSelectedLevelProvider.notifier)
                                      .setLevel(selected);
                                  Navigator.of(dialogContext).pop();
                                  Navigator.of(dialogContext)
                                      .pushNamed('/game');
                                },
                          child: const Text('Play'),
                        ),
                      ],
                    ),
                  ],
                );
              }),
            );
          },
        );
      },
    );
  }

  Future<Map<int, String>> _loadLabels(List<int> levels) async {
    final labels = <int, String>{};
    for (final lvl in levels) {
      try {
        final jsonStr =
            await rootBundle.loadString('assets/levels/level_$lvl.json');
        final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
        final difficulty = (jsonMap['difficulty'] ?? 'Unknown').toString();
        labels[lvl] = 'Level $lvl — $difficulty';
      } catch (_) {
        labels[lvl] = 'Level $lvl';
      }
    }
    return labels;
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
      // 1. Clear Firebase data first
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

      // 3. Close the loading dialog immediately (before invalidating providers)
      debugPrint('ResetData: Attempting to close loading dialog...');
      try {
        if (loadingContext != null && loadingContext.mounted) {
          Navigator.of(loadingContext).pop();
          debugPrint('ResetData: Loading dialog closed');
        }
      } catch (dialogError) {
        debugPrint('ResetData: Error closing dialog: $dialogError');
      }

      // 4. Check context before continuing
      if (!originalContext.mounted) {
        debugPrint('ResetData: Original context not mounted, aborting');
        return;
      }

      // 5. Navigate to home immediately (before invalidating UI providers)
      debugPrint('ResetData: Navigating to home screen...');
      try {
        await Navigator.of(originalContext).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
        debugPrint('ResetData: Navigation completed');
      } catch (navError) {
        debugPrint('ResetData: Navigation error: $navError');
        return;
      }

      // 6. NOW invalidate only essential progress/level providers
      // (after navigation is complete)
      // These providers will rebuild with cleared data when HomeScreen loads
      debugPrint('ResetData: Invalidating progress providers...');
      ref.invalidate(gameProgressProvider);

      debugPrint('ResetData: Reset completed successfully');
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

  Future<void> _performRedoTutorial(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop(); // Close dialog

    // Only reset the in-memory tutorial progress state - don't persist changes
    // This allows replaying the tutorial without affecting main game progress
    ref.read(tutorialProgressProvider.notifier).resetForReplay();

    // Invalidate current level to force reload
    ref.invalidate(currentLevelProvider);

    // Navigate directly to tutorial flow
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).pushNamed('/tutorial');
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
