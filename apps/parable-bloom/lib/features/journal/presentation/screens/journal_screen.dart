import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../game/application/providers/progress_providers.dart";
import "../../../../core/providers/service_providers.dart";
import "../../../../core/providers/settings_providers.dart";
import "../../../../core/widgets/constrained_page.dart";
import "../../../../core/widgets/garden_loading_view.dart";
import "../../application/providers/journal_providers.dart";
import "../../domain/entities/journal_theme.dart";
import "../widgets/journal_entry_sheet.dart";
import "../widgets/journal_scrapbook.dart";

/// Vertically scrolling scrapbook journal: kraft chapter dividers, taped-in
/// entry cards, and sealed envelopes for locked passages. Locked entries
/// are fully sealed — no title or reference, just the lock and the unlock.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  bool _loggedOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logScreenView("Journal");
    });
  }

  void _openEntry(BuildContext context, JournalPassage passage) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JournalEntrySheet(passage: passage),
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
      body: ConstrainedPage(
        child: themesAsync.when(
          loading: () => const GardenLoadingView(message: "Opening journal…"),
          error: (error, _) => Center(child: Text("Error: $error")),
          data: (themes) {
            if (themes.isEmpty) {
              return Center(
                child: Semantics(
                  label: "No journal entries yet",
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("No blooms yet", style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        "Complete levels to unlock scripture and parables.",
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!_loggedOpen) {
              _loggedOpen = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(analyticsServiceProvider).logJournalOpened(
                      initialTab: "All",
                      unlockedCount: progress.unlockedScriptureIds.length,
                    );
              });
            }

            final totalUnlocked = themes
                .expand((t) => t.passages)
                .where((p) => progress.unlockedScriptureIds.contains(p.id))
                .length;
            final totalPassages =
                themes.fold<int>(0, (sum, t) => sum + t.passages.length);

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: themes.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          color: cs.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "A growing collection · $totalUnlocked / $totalPassages Collected",
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final theme = themes[index - 1];
                final unlockedCount = theme.passages
                    .where((p) => progress.unlockedScriptureIds.contains(p.id))
                    .length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ChapterDivider(
                      theme: theme,
                      unlockedCount: unlockedCount,
                    ),
                    ...theme.passages.asMap().entries.map((entry) {
                      final passage = entry.value;
                      final isUnlocked =
                          progress.unlockedScriptureIds.contains(passage.id);
                      if (isUnlocked) {
                        return ScrapbookEntry(
                          passage: passage,
                          translationCode: preferred,
                          index: entry.key,
                          onTap: () => _openEntry(context, passage),
                        );
                      }
                      return SealedEnvelope(passage: passage);
                    }),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
