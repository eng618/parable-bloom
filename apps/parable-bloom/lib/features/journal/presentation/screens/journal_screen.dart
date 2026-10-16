import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../game/application/providers/progress_providers.dart";
import "../../../../core/providers/service_providers.dart";
import "../../../../core/providers/settings_providers.dart";
import "../../../../core/widgets/constrained_page.dart";
import "../../../../core/widgets/garden_loading_view.dart";
import "../../application/providers/journal_display_providers.dart";
import "../../application/providers/journal_providers.dart";
import "../widgets/journal_book_view.dart";

/// Public icon mapping, reused by chapter pages.
IconData themeIconFor(String iconKey) {
  switch (iconKey) {
    case "spa":
      return Icons.spa;
    case "psychology":
      return Icons.psychology;
    case "hourglass_empty":
      return Icons.hourglass_empty;
    case "favorite":
      return Icons.favorite;
    case "wb_sunny":
      return Icons.wb_sunny;
    case "shield":
      return Icons.shield;
    default:
      return Icons.menu_book;
  }
}

/// Paper-journal codex: cover TOC + swipeable pages (1-up on phones,
/// 2-up spread on tablet/web), achievements as wax seals + pressed blooms.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  int? _requestedPage;
  bool _loggedOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logScreenView("Journal");
    });
  }

  @override
  Widget build(BuildContext context) {
    final themesAsync = ref.watch(journalThemesProvider);
    final progress = ref.watch(gameProgressProvider);
    final preferred = ref.watch(preferredTranslationProvider).toUpperCase();
    final lockedStyle = ref.watch(journalLockedStyleProvider);
    final bookmark = ref.watch(journalBookmarkProvider);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Journal"),
        backgroundColor: cs.surfaceContainerHighest,
        actions: [
          // Configurable locked treatment for A/B testing.
          PopupMenuButton<JournalLockedStyle>(
            tooltip: "Locked page style",
            icon: Icon(
              lockedStyle == JournalLockedStyle.sealed
                  ? Icons.lock_outline
                  : Icons.visibility_outlined,
            ),
            onSelected: (style) =>
                ref.read(journalLockedStyleProvider.notifier).setStyle(style),
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                checked: lockedStyle == JournalLockedStyle.sealed,
                value: JournalLockedStyle.sealed,
                child: const Text("Sealed (hide title)"),
              ),
              CheckedPopupMenuItem(
                checked: lockedStyle == JournalLockedStyle.teaser,
                value: JournalLockedStyle.teaser,
                child: const Text("Teaser (show title)"),
              ),
            ],
          ),
        ],
      ),
      body: ConstrainedPage(
        maxWidth: 920,
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

            final entries = buildJournalBook(themes);
            final totalUnlocked = themes
                .expand((t) => t.passages)
                .where((p) => progress.unlockedScriptureIds.contains(p.id))
                .length;
            final totalPassages =
                themes.fold<int>(0, (sum, t) => sum + t.passages.length);
            final initialPage = (_requestedPage ?? bookmark).clamp(
              0,
              entries.isEmpty ? 0 : entries.length - 1,
            );

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  // Cover strip: collection progress + ribbon resume.
                  _CoverStrip(
                    unlocked: totalUnlocked,
                    total: totalPassages,
                    bookmark: bookmark,
                    entryCount: entries.length,
                    onResume: () => setState(() => _requestedPage = bookmark),
                  ),
                  const SizedBox(height: 8),
                  // Chapter index (table of contents).
                  _ChapterIndex(
                    themes: themes,
                    unlockedIds: progress.unlockedScriptureIds,
                    onSelect: (themeIndex) {
                      // Entry index = chapters + passages before it.
                      var target = 0;
                      for (var i = 0; i < themeIndex; i++) {
                        target += 1 + themes[i].passages.length;
                      }
                      setState(() => _requestedPage = target);
                    },
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: JournalBookView(
                      key: ValueKey(
                        "book-$initialPage-${lockedStyle.name}",
                      ),
                      entries: entries,
                      isUnlocked: (id) =>
                          progress.unlockedScriptureIds.contains(id),
                      preferredTranslation: preferred,
                      noteFor: (id) => progress.journalNotes[id] ?? "",
                      showTeaser: lockedStyle == JournalLockedStyle.teaser,
                      onSaveNote: (id, note) => ref
                          .read(gameProgressProvider.notifier)
                          .saveJournalNote(id, note),
                      onPageChanged: (entry) {
                        ref.read(journalBookmarkProvider.notifier).save(entry);
                      },
                      initialPage: initialPage,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CoverStrip extends StatelessWidget {
  const _CoverStrip({
    required this.unlocked,
    required this.total,
    required this.bookmark,
    required this.entryCount,
    required this.onResume,
  });

  final int unlocked;
  final int total;
  final int bookmark;
  final int entryCount;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book_outlined, color: cs.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "A growing collection · $unlocked / $total Collected",
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (bookmark > 0 && bookmark < entryCount)
            TextButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.bookmark, size: 16),
              label: Text("p. ${bookmark + 1}"),
            ),
        ],
      ),
    );
  }
}

class _ChapterIndex extends StatelessWidget {
  const _ChapterIndex({
    required this.themes,
    required this.unlockedIds,
    required this.onSelect,
  });

  final List themes;
  final Set<String> unlockedIds;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: themes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final theme = themes[i];
          final unlocked = (theme.passages as List)
              .where((p) => unlockedIds.contains((p).id))
              .length;
          final total = (theme.passages as List).length;
          return ActionChip(
            avatar: Icon(
              themeIconFor((theme.icon as String?) ?? "spa"),
              size: 14,
              color: cs.primary,
            ),
            label: Text("$unlocked/$total ${theme.name}"),
            onPressed: () => onSelect(i),
          );
        },
      ),
    );
  }
}
