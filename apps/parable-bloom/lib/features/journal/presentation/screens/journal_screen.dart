import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../game/application/providers/progress_providers.dart";
import "../../../../core/providers/service_providers.dart";
import "../../../../core/providers/settings_providers.dart";
import "../../../../core/widgets/scripture_citation.dart";
import "../../domain/entities/journal_theme.dart";
import "../../application/providers/journal_providers.dart";

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
      final progress = ref.read(gameProgressProvider);
      ref.read(analyticsServiceProvider).logJournalOpened(
            initialTab: 'All',
            unlockedCount: progress.unlockedScriptureIds.length,
          );
    });
  }

  IconData _themeIcon(String iconKey) {
    switch (iconKey) {
      case 'spa':
        return Icons.spa;
      case 'psychology':
        return Icons.psychology;
      case 'hourglass_empty':
        return Icons.hourglass_empty;
      case 'favorite':
        return Icons.favorite;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'shield':
        return Icons.shield;
      default:
        return Icons.menu_book;
    }
  }

  String _formatTriggerText(String triggerLevel) {
    if (triggerLevel.isEmpty) return 'Complete Milestone to Unlock';
    if (triggerLevel == 'lesson_10' ||
        triggerLevel == 'lesson_5' ||
        triggerLevel == 'lesson_1') {
      return 'Unlocks after Tutorial';
    }
    if (triggerLevel == 'lvl_seed_challenge') {
      return 'Unlocks at Seedling Challenge';
    }
    if (triggerLevel == 'lvl_sprout_challenge') {
      return 'Unlocks at Sprout Challenge';
    }
    if (triggerLevel == 'lvl_blossom_challenge') {
      return 'Unlocks at Blossom Challenge';
    }
    if (triggerLevel == 'lvl_flourish_challenge') {
      return 'Unlocks at Flourish Challenge';
    }
    if (triggerLevel == 'lvl_harvest_challenge') {
      return 'Unlocks at Harvest Challenge';
    }

    // Numbered levels
    if (triggerLevel.startsWith('lvl_seed_')) {
      final numStr = triggerLevel.replaceAll('lvl_seed_', '');
      final n = int.tryParse(numStr);
      if (n != null) return 'Unlocks at Level $n';
    }
    if (triggerLevel.startsWith('lvl_sprout_')) {
      final numStr = triggerLevel.replaceAll('lvl_sprout_', '');
      final n = int.tryParse(numStr);
      if (n != null) return 'Unlocks at Level ${n + 21}';
    }
    if (triggerLevel.startsWith('lvl_blossom_')) {
      final numStr = triggerLevel.replaceAll('lvl_blossom_', '');
      final n = int.tryParse(numStr);
      if (n != null) return 'Unlocks at Level ${n + 42}';
    }
    if (triggerLevel.startsWith('lvl_flourish_')) {
      final numStr = triggerLevel.replaceAll('lvl_flourish_', '');
      final n = int.tryParse(numStr);
      if (n != null) return 'Unlocks at Level ${n + 63}';
    }
    if (triggerLevel.startsWith('lvl_harvest_')) {
      final numStr = triggerLevel.replaceAll('lvl_harvest_', '');
      final n = int.tryParse(numStr);
      if (n != null) return 'Unlocks at Level ${n + 84}';
    }

    return 'Unlocks at Level $triggerLevel';
  }

  void _showDetailsSheet(
    BuildContext context,
    JournalPassage passage,
    JournalTheme theme,
  ) {
    final preferred = ref.read(preferredTranslationProvider).toUpperCase();
    final analytics = ref.read(analyticsServiceProvider);
    analytics.logScriptureRead(
      scriptureId: passage.id,
      reference: passage.reference,
      translation: preferred,
    );
    if (passage.type == 'parable') {
      analytics.logParableViewed(passage.id, source: 'journal_browse');
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _ScriptureReflectionSheet(
          passage: passage,
          theme: theme,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themesAsync = ref.watch(journalThemesProvider);
    final progress = ref.watch(gameProgressProvider);
    final preferred = ref.watch(preferredTranslationProvider).toUpperCase();
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Journal"),
        backgroundColor: cs.surfaceContainerHighest,
      ),
      body: themesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text("Error: $error")),
        data: (themes) {
          if (themes.isEmpty) {
            return const Center(
              child: Text("No biblical themes loaded."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: themes.length,
            itemBuilder: (context, index) {
              final theme = themes[index];
              final totalCount = theme.passages.length;
              final unlockedCount = theme.passages
                  .where((p) => progress.unlockedScriptureIds.contains(p.id))
                  .length;
              final progressPct =
                  totalCount > 0 ? unlockedCount / totalCount : 0.0;
              final isAllUnlocked =
                  unlockedCount == totalCount && totalCount > 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isAllUnlocked
                        ? cs.primary.withValues(alpha: 0.5)
                        : cs.outlineVariant.withValues(alpha: 0.4),
                    width: isAllUnlocked ? 2 : 1,
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
                                Row(
                                  children: [
                                    Icon(
                                      _themeIcon(theme.icon),
                                      color: cs.primary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        theme.name,
                                        style: textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (theme.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    theme.description,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isAllUnlocked
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$unlockedCount / $totalCount Collected',
                              style: textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isAllUnlocked
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
                            isAllUnlocked ? cs.primary : cs.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: theme.passages.map((passage) {
                          final isUnlocked = progress.unlockedScriptureIds
                              .contains(passage.id);

                          if (isUnlocked) {
                            return Card(
                              elevation: 0,
                              color: cs.surfaceContainerLow,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color:
                                      cs.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: cs.primaryContainer,
                                  child: Icon(
                                    passage.type == 'parable'
                                        ? Icons.menu_book
                                        : (passage.type == 'starter'
                                            ? Icons.star
                                            : Icons.spa),
                                    color: cs.onPrimaryContainer,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  passage.title,
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  '${passage.reference} ($preferred)',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                ),
                                onTap: () => _showDetailsSheet(
                                  context,
                                  passage,
                                  theme,
                                ),
                              ),
                            );
                          } else {
                            // Locked card placeholder
                            return Card(
                              elevation: 0,
                              color: cs.surfaceContainerLowest
                                  .withValues(alpha: 0.5),
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color:
                                      cs.outlineVariant.withValues(alpha: 0.1),
                                ),
                              ),
                              child: ListTile(
                                enabled: false,
                                leading: CircleAvatar(
                                  backgroundColor: cs.surfaceContainerHighest
                                      .withValues(alpha: 0.6),
                                  child: Icon(
                                    Icons.lock_outline,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.4),
                                    size: 18,
                                  ),
                                ),
                                title: Text(
                                  'Locked Scripture',
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                subtitle: Text(
                                  _formatTriggerText(passage.triggerLevel),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.3),
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

class _ScriptureReflectionSheet extends ConsumerStatefulWidget {
  final JournalPassage passage;
  final JournalTheme theme;

  const _ScriptureReflectionSheet({
    required this.passage,
    required this.theme,
  });

  @override
  ConsumerState<_ScriptureReflectionSheet> createState() =>
      _ScriptureReflectionSheetState();
}

class _ScriptureReflectionSheetState
    extends ConsumerState<_ScriptureReflectionSheet> {
  late TextEditingController _notesController;
  bool _isNotesSaved = false;

  @override
  void initState() {
    super.initState();
    final progress = ref.read(gameProgressProvider);
    final initialNote = progress.journalNotes[widget.passage.id] ?? '';
    _notesController = TextEditingController(text: initialNote);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    await ref
        .read(gameProgressProvider.notifier)
        .saveJournalNote(widget.passage.id, _notesController.text);
    if (mounted) {
      setState(() {
        _isNotesSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reflection note saved.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
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
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    widget.passage.type == 'parable'
                        ? Icons.menu_book
                        : (widget.passage.type == 'starter'
                            ? Icons.star
                            : Icons.spa),
                    color: cs.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.passage.title,
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
                widget.theme.name,
                style: textTheme.labelLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, String>>(
                future: ref.read(scriptureServiceProvider).loadScripture(
                      widget.passage.reference,
                      preferredTranslationId:
                          ref.read(preferredTranslationProvider),
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
                      widget.passage.defaultContent ??
                      'Scripture text not found.';
                  final code = data?['translation'] ?? 'NET';
                  final didFallback = data?['didFallback'] == 'true';
                  final requiresDownload = data?['requiresDownload'] == 'true';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (didFallback && requiresDownload)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'This translation needs internet once to download, then works offline. Showing $code for now.',
                            style: textTheme.bodySmall
                                ?.copyWith(color: cs.onSecondaryContainer),
                          ),
                        ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text,
                              style: textTheme.bodyLarge?.copyWith(
                                height: 1.6,
                                fontStyle: FontStyle.italic,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: ScriptureCitation(
                                reference: widget.passage.reference,
                                translationCode: code,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (widget.passage.reflectionPrompts.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Guided Reflection',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                ...widget.passage.reflectionPrompts.asMap().entries.map((e) {
                  final idx = e.key + 1;
                  final prompt = e.value;
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$idx',
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            prompt,
                            style: textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Personal Reflection Notes',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  if (_isNotesSaved)
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: cs.primary, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Saved',
                          style: textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Write your thoughts, prayers, or reflections here...',
                  hintStyle: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                ),
                onChanged: (_) {
                  if (_isNotesSaved) {
                    setState(() {
                      _isNotesSaved = false;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _saveNotes,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save Notes'),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
