import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/settings_providers.dart';
import '../../../../core/services/logger_service.dart';
import '../../../game/application/providers/gameplay_state_providers.dart';
import '../../../game/application/providers/module_providers.dart';
import '../../../game/domain/entities/level_data.dart';

/// Debug-only settings: coordinates, animation logs, skins, level picker.
class SettingsDebugSection extends ConsumerWidget {
  const SettingsDebugSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCoordinates = ref.watch(debugShowGridCoordinatesProvider);
    final loggingEnabled = ref.watch(debugVineAnimationLoggingProvider);
    final texturedSkins = ref.watch(vineTexturedSkinsEnabledProvider);
    final selected = ref.watch(debugSelectedLevelProvider);
    final subtitle =
        selected == null ? 'No level selected' : 'Selected: $selected';

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(
            Icons.grid_on,
            color: showCoordinates
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
          ),
          title: const Text('Show Grid Coordinates'),
          subtitle: const Text('Display coordinate labels on grid cells'),
          value: showCoordinates,
          onChanged: (value) async {
            await ref
                .read(debugShowGridCoordinatesProvider.notifier)
                .setShowCoordinates(value);
          },
        ),
        SwitchListTile(
          secondary: Icon(
            Icons.animation,
            color: loggingEnabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
          ),
          title: const Text('Vine Animation Logging'),
          subtitle: const Text('Log vine animation details to console'),
          value: loggingEnabled,
          onChanged: (value) async {
            await ref
                .read(debugVineAnimationLoggingProvider.notifier)
                .setEnabled(value);
          },
        ),
        SwitchListTile(
          secondary: Icon(
            Icons.texture,
            color: texturedSkins
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
          ),
          title: const Text('Textured Vine Skins'),
          subtitle: const Text(
            'Show classic/blossom/ethereal vine textures (debug only)',
          ),
          value: texturedSkins,
          onChanged: (value) async {
            await ref
                .read(vineTexturedSkinsEnabledProvider.notifier)
                .setEnabled(value);
          },
        ),
        ListTile(
          leading: Icon(
            Icons.gamepad,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('Play Any Level (Debug)'),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            try {
              final modules = await ref.read(modulesProvider.future);
              SchedulerBinding.instance.addPostFrameCallback((_) {
                _showDebugLevelPickerDialog(context, ref, modules);
              });
            } catch (error, stackTrace) {
              LoggerService.error(
                'Unable to open debug level picker due to module load failure',
                tag: 'SettingsScreen',
                error: error,
                stackTrace: stackTrace,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to load levels. Please try again.'),
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }
}

void _showDebugLevelPickerDialog(
  BuildContext context,
  WidgetRef ref,
  List<ModuleData> modules,
) {
  final safeContext = context;

  if (modules.isEmpty) {
    ScaffoldMessenger.of(safeContext).showSnackBar(
      const SnackBar(content: Text('No levels available')),
    );
    return;
  }

  String? selected = ref.read(debugSelectedLevelProvider);

  // Preselect the module containing the current selection, else the first.
  ModuleData selectedModule = modules.first;
  for (final m in modules) {
    if (selected != null && m.containsLevel(selected)) {
      selectedModule = m;
      break;
    }
  }
  if (selected != null && !selectedModule.containsLevel(selected)) {
    selected = null;
  }

  showDialog(
    context: safeContext,
    builder: (dialogContext) {
      return StatefulBuilder(builder: (ctx, setState) {
        final moduleLevels = selectedModule.allLevels;
        return AlertDialog(
          title: const Text('Debug: Select Level to Play'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                isDense: true,
                initialValue: selectedModule.id,
                items: modules
                    .map((m) => DropdownMenuItem<int>(
                          value: m.id,
                          child: Text(
                              'Module ${m.id} — ${m.name} (${m.levelCount})'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedModule = modules.firstWhere(
                      (m) => m.id == value,
                      orElse: () => modules.first,
                    );
                    // Reset level selection when switching modules.
                    selected = null;
                  });
                },
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Module',
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, String>>(
                // Reload labels whenever the module changes.
                key: ValueKey(selectedModule.id),
                future: _loadLabels(moduleLevels, ref),
                builder: (labelCtx, snapshot) {
                  final labels = snapshot.data ?? {};
                  return DropdownButtonFormField<String>(
                    isDense: true,
                    initialValue: selected,
                    items: moduleLevels
                        .map((lvl) => DropdownMenuItem<String>(
                              value: lvl,
                              child: Text(labels[lvl] ?? lvl),
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
                  );
                },
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
                            // go_router (MaterialApp.router) has no named
                            // Navigator routes; pushNamed('/game') crashes.
                            GoRouter.of(dialogContext).go('/game');
                          },
                    child: const Text('Play'),
                  ),
                ],
              ),
            ],
          ),
        );
      });
    },
  );
}

Future<Map<String, String>> _loadLabels(
  List<String> levels,
  WidgetRef ref,
) async {
  final labels = <String, String>{};
  final futures = levels.indexed.map((entry) async {
    final (i, lvl) = entry;
    final index = i + 1;
    try {
      final levelData = await ref.read(levelDataProvider(lvl).future);
      final difficulty = levelData.difficulty;
      final name = lvl.endsWith('challenge')
          ? '★ Challenge ($lvl) — $difficulty'
          : 'Level $index ($lvl) — $difficulty';
      return MapEntry(lvl, name);
    } catch (_) {
      return MapEntry(lvl, lvl);
    }
  });

  final results = await Future.wait(futures);
  for (final result in results) {
    labels[result.key] = result.value;
  }
  return labels;
}
