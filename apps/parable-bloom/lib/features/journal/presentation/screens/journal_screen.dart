import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../game/application/providers/progress_providers.dart";
import "../../../game/domain/entities/game_progress.dart";
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
  final String? initialPassageId;

  const JournalScreen({super.key, this.initialPassageId});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  bool _loggedOpen = false;
  bool _deepLinkHandled = false;
  late final ScrollController _scrollController;

  /// Maps unlocked passage ids to their [GlobalKey] so deep-link scrolling
  /// can locate each entry's [BuildContext] by id. All unlocked passages get
  /// a key up front so off-screen entries are still addressable.
  final Map<String, GlobalKey> _entryKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(analyticsServiceProvider).logScreenView("Journal");
      unawaited(ref.read(sfxControllerProvider).playMenuOpen());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openEntry(BuildContext context, JournalPassage passage) {
    unawaited(ref.read(sfxControllerProvider).playMenuOpen());
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JournalEntrySheet(passage: passage),
    ).whenComplete(() {
      if (!mounted) return;
      unawaited(ref.read(sfxControllerProvider).playMenuClose());
    });
  }

  /// Find a passage by id (preferred), falling back to reference so parable
  /// unlocks — which only carry a reference string — can deep-link too.
  JournalPassage? _findPassage(List<JournalTheme> themes, String id) {
    for (final theme in themes) {
      for (final passage in theme.passages) {
        if (passage.id == id) return passage;
      }
    }
    for (final theme in themes) {
      for (final passage in theme.passages) {
        if (passage.reference == id) return passage;
      }
    }
    return null;
  }

  /// Scrolls the journal so the entry comes into view, then opens its
  /// reading sheet. Falls back to opening the sheet directly if the entry
  /// context isn't available yet.
  Future<void> _scrollAndOpenEntry(
    List<JournalTheme> themes,
    bool Function(JournalPassage passage) isUnlocked,
  ) async {
    final passage = _findPassage(themes, widget.initialPassageId!);
    if (passage == null || !isUnlocked(passage)) return;

    final key = _entryKeys[passage.id];
    if (key == null || key.currentContext == null) {
      // Entry hasn't rendered yet — open the sheet without scrolling.
      if (!mounted) return;
      _openEntry(context, passage);
      return;
    }

    await Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
    );
    if (!mounted) return;
    _openEntry(context, passage);
  }

  @override
  Widget build(BuildContext context) {
    final themesAsync = ref.watch(journalThemesProvider);
    // Unlock fields only. Unrelated GameProgress writes (currentLevel, notes)
    // do not rebuild the list. A finished tutorial opens the starter passage
    // even when the stored id is the module scripture (`seed_starter`) rather
    // than the journal passage (`growth_seed_word`).
    final unlock = ref.watch(gameProgressProvider.select(
      (p) => (
        ids: p.unlockedScriptureIds,
        lessons: p.completedLessons,
        levels: p.completedLevels,
        tutorialFinished: p.tutorialFinished,
      ),
    ));
    bool isUnlocked(JournalPassage passage) => GameProgress.passageIsUnlocked(
          unlockedIds: unlock.ids,
          completedLessons: unlock.lessons,
          completedLevels: unlock.levels,
          tutorialFinished: unlock.tutorialFinished,
          passageId: passage.id,
          triggerLevel: passage.triggerLevel,
        );
    final preferred = ref.watch(preferredTranslationProvider).toUpperCase();
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        unawaited(ref.read(sfxControllerProvider).playMenuClose());
      },
      child: Scaffold(
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
                        unlockedCount: themes
                            .expand((t) => t.passages)
                            .where(isUnlocked)
                            .length,
                      );
                });
              }

              // Pre-populate entry keys for every unlocked passage so deep-link
              // scrolling can resolve each entry's BuildContext by id.
              for (final theme in themes) {
                for (final passage in theme.passages) {
                  if (isUnlocked(passage)) {
                    _entryKeys.putIfAbsent(passage.id, () => GlobalKey());
                  }
                }
              }

              // Deep link: scroll the entry into view, then open its sheet.
              if (widget.initialPassageId != null && !_deepLinkHandled) {
                _deepLinkHandled = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _scrollAndOpenEntry(themes, isUnlocked);
                });
              }

              final totalUnlocked =
                  themes.expand((t) => t.passages).where(isUnlocked).length;
              final totalPassages =
                  themes.fold<int>(0, (sum, t) => sum + t.passages.length);

              return SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
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
                    ),
                    const SizedBox(height: 16),
                    ...themes.asMap().entries.map((entry) {
                      final theme = entry.value;
                      final unlockedCount =
                          theme.passages.where(isUnlocked).length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ChapterDivider(
                            theme: theme,
                            unlockedCount: unlockedCount,
                          ),
                          const SizedBox(height: 8),
                          ...theme.passages.asMap().entries.map((passageEntry) {
                            final passage = passageEntry.value;
                            if (isUnlocked(passage)) {
                              return ScrapbookEntry(
                                key: _entryKeys[passage.id],
                                passage: passage,
                                translationCode: preferred,
                                index: passageEntry.key,
                                onTap: () => _openEntry(context, passage),
                              );
                            }
                            return SealedEnvelope(passage: passage);
                          }),
                          const SizedBox(height: 20),
                        ],
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
