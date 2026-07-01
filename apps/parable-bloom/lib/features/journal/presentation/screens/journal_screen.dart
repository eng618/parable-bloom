import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../game/application/providers/module_providers.dart";
import "../../../game/application/providers/progress_providers.dart";
import "../../../../providers/service_providers.dart";
import "../../../game/domain/entities/level_data.dart";
import "../../../game/domain/entities/game_progress.dart";

class JournalItem {
  final String id;
  final String title;
  final String reference;
  final String triggerText;
  final String type; // 'starter' | 'supporting' | 'parable'
  final bool isUnlocked;
  final String? savedTranslationId;
  final String? defaultContent;
  final String? reflection;

  JournalItem({
    required this.id,
    required this.title,
    required this.reference,
    required this.triggerText,
    required this.type,
    required this.isUnlocked,
    this.savedTranslationId,
    this.defaultContent,
    this.reflection,
  });
}

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logScreenView('Journal');
    });
  }

  List<JournalItem> _buildJournalItems(
    ModuleData module,
    GameProgress progress,
    List<ModuleData> modules,
  ) {
    final items = <JournalItem>[];

    // 1. Add scriptures (starter & supporting)
    for (final s in module.scriptures) {
      final unlocked = progress.unlockedScriptureIds.contains(s.id);
      String triggerLabel = 'Unlocks at Level 5';
      if (s.type == 'starter') {
        triggerLabel = 'Unlocks after Tutorial';
      } else {
        final parts = s.triggerLevel.split('_');
        if (parts.isNotEmpty) {
          final numStr = parts.last;
          final levelNum = int.tryParse(numStr);
          if (levelNum != null) {
            triggerLabel = 'Unlocks at Level $levelNum';
          }
        }
      }

      items.add(JournalItem(
        id: s.id,
        title: s.title,
        reference: s.reference,
        triggerText: triggerLabel,
        type: s.type,
        isUnlocked: unlocked,
        savedTranslationId: progress.unlockedTranslations[s.id],
      ));
    }

    // 2. Add main parable
    final parableUnlocked = progress.isModuleCompleted(module.id, modules);
    final parable = module.parable;
    items.add(JournalItem(
      id: 'parable_${module.id}',
      title: (parable['title'] as String?)?.trim() ?? 'The Parable',
      reference: (parable['scripture'] as String?)?.trim() ?? '',
      triggerText: 'Complete Module to Unlock',
      type: 'parable',
      isUnlocked: parableUnlocked,
      savedTranslationId: progress.unlockedTranslations[module.id.toString()],
      defaultContent: (parable['content'] as String?)?.trim(),
      reflection: (parable['reflection'] as String?)?.trim(),
    ));

    return items;
  }

  void _showDetailsSheet(
      BuildContext context, JournalItem item, String moduleName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        final textTheme = Theme.of(sheetContext).textTheme;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            builder: (scrollContext, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        item.type == 'parable'
                            ? Icons.menu_book
                            : (item.type == 'starter' ? Icons.star : Icons.spa),
                        color: cs.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    moduleName,
                    style: textTheme.labelLarge?.copyWith(
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<Map<String, String>>(
                    future: ref.read(scriptureServiceProvider).loadScripture(
                          item.reference,
                          translationId: item.savedTranslationId,
                        ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final data = snapshot.data;
                      final text = data?['text'] ??
                          item.defaultContent ??
                          'Scripture text not found.';
                      final translationCode = data?['translation'] ?? 'KJV';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text,
                                  style: textTheme.bodyLarge?.copyWith(
                                    height: 1.5,
                                    fontStyle: FontStyle.italic,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    '— ${item.reference} ($translationCode)',
                                    style: textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (item.reflection != null &&
                      item.reflection!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Reflection',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary.withOpacity(0.2)),
                      ),
                      child: Text(
                        item.reflection!,
                        style: textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(modulesProvider);
    final progress = ref.watch(gameProgressProvider);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Journal"),
        backgroundColor: cs.surfaceContainerHighest,
      ),
      body: modulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text("Error: $error")),
        data: (modules) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final module = modules[index];
              final items = _buildJournalItems(module, progress, modules);
              final unlockedCount = items.where((i) => i.isUnlocked).length;
              final totalCount = items.length;
              final progressPct =
                  totalCount > 0 ? unlockedCount / totalCount : 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: unlockedCount == totalCount
                        ? cs.primary.withOpacity(0.5)
                        : cs.outlineVariant.withOpacity(0.4),
                    width: unlockedCount == totalCount ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  module.name,
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Thematic Set',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: unlockedCount == totalCount
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$unlockedCount / $totalCount Collected',
                              style: textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: unlockedCount == totalCount
                                    ? cs.onPrimaryContainer
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressPct,
                          minHeight: 6,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            unlockedCount == totalCount
                                ? cs.primary
                                : cs.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: items.map((item) {
                          if (item.isUnlocked) {
                            return Card(
                              elevation: 0,
                              color: cs.surfaceContainerLow,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                    color: cs.outlineVariant.withOpacity(0.3)),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: cs.primaryContainer,
                                  child: Icon(
                                    item.type == 'parable'
                                        ? Icons.menu_book
                                        : (item.type == 'starter'
                                            ? Icons.star
                                            : Icons.spa),
                                    color: cs.onPrimaryContainer,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  item.title,
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  '${item.reference} (${(item.savedTranslationId ?? 'kjv').toUpperCase()})',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios,
                                    size: 14),
                                onTap: () => _showDetailsSheet(
                                    context, item, module.name),
                              ),
                            );
                          } else {
                            // Locked card placeholder
                            return Card(
                              elevation: 0,
                              color: cs.surfaceContainerLowest.withOpacity(0.5),
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                    color: cs.outlineVariant.withOpacity(0.1)),
                              ),
                              child: ListTile(
                                enabled: false,
                                leading: CircleAvatar(
                                  backgroundColor: cs.surfaceContainerHighest
                                      .withOpacity(0.6),
                                  child: Icon(
                                    Icons.lock_outline,
                                    color: cs.onSurfaceVariant.withOpacity(0.4),
                                    size: 18,
                                  ),
                                ),
                                title: Text(
                                  'Locked Scripture',
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurfaceVariant.withOpacity(0.4),
                                  ),
                                ),
                                subtitle: Text(
                                  item.triggerText,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant.withOpacity(0.3),
                                  ),
                                ),
                              ),
                            );
                          }
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
