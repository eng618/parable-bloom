import "package:flutter/material.dart";

import "../../domain/entities/journal_theme.dart";
import "../screens/journal_screen.dart" show themeIconFor;
import "journal_chapter_page.dart";
import "journal_passage_page.dart";

/// Flat book model: each theme contributes a chapter page + one page
/// per passage. The view renders 1-up on phones, 2-up spreads on wide
/// screens (tablet/web) with swipe + spine shadow (no curl physics).
class JournalBookEntry {
  const JournalBookEntry.chapter(this.theme)
      : passage = null,
        passageIndex = -1;

  const JournalBookEntry.passage(
    this.theme,
    this.passage,
    this.passageIndex,
  );

  final JournalTheme theme;
  final JournalPassage? passage;
  final int passageIndex;

  bool get isChapter => passage == null;
}

List<JournalBookEntry> buildJournalBook(List<JournalTheme> themes) {
  final entries = <JournalBookEntry>[];
  for (final theme in themes) {
    entries.add(JournalBookEntry.chapter(theme));
    for (var i = 0; i < theme.passages.length; i++) {
      entries.add(JournalBookEntry.passage(theme, theme.passages[i], i));
    }
  }
  return entries;
}

class JournalBookView extends StatefulWidget {
  const JournalBookView({
    super.key,
    required this.entries,
    required this.isUnlocked,
    required this.preferredTranslation,
    required this.noteFor,
    required this.showTeaser,
    required this.onSaveNote,
    required this.onPageChanged,
    this.initialPage = 0,
  });

  final List<JournalBookEntry> entries;
  final bool Function(String passageId) isUnlocked;
  final String preferredTranslation;
  final String Function(String passageId) noteFor;
  final bool showTeaser;
  final Future<void> Function(String passageId, String note) onSaveNote;
  final ValueChanged<int> onPageChanged;
  final int initialPage;

  /// Wide breakpoint for two-page spreads (tablet landscape / web).
  static const double spreadBreakpoint = 720;

  @override
  State<JournalBookView> createState() => _JournalBookViewState();
}

class _JournalBookViewState extends State<JournalBookView> {
  late PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage
        .clamp(0, widget.entries.isEmpty ? 0 : widget.entries.length - 1);
    _controller = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void jumpToEntry(int entryIndex) {
    final spread = _isSpread(context);
    final sheet = spread ? entryIndex ~/ 2 : entryIndex;
    _controller.animateToPage(
      sheet,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  bool _isSpread(BuildContext context) =>
      MediaQuery.widthOf(context) >= JournalBookView.spreadBreakpoint;

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();
    final spread = _isSpread(context);
    final sheetCount =
        spread ? (widget.entries.length / 2).ceil() : widget.entries.length;

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: sheetCount,
            onPageChanged: (sheet) {
              final entry = spread
                  ? (sheet * 2).clamp(0, widget.entries.length - 1)
                  : sheet;
              setState(() => _page = entry);
              widget.onPageChanged(entry);
            },
            itemBuilder: (context, sheet) {
              if (!spread) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _entryPage(entryIndex: sheet, bindLeft: true),
                );
              }
              final left = sheet * 2;
              final right = left + 1;
              return Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _entryPage(entryIndex: left, bindLeft: false),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: right < widget.entries.length
                          ? _entryPage(entryIndex: right, bindLeft: true)
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _Footer(
          entryIndex: _page,
          total: widget.entries.length,
          sheetCount: sheetCount,
          spread: spread,
          onPrev: () => _controller.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
          onNext: () => _controller.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
        ),
      ],
    );
  }

  Widget _entryPage({required int entryIndex, required bool bindLeft}) {
    final entry = widget.entries[entryIndex];
    final pageLabel = "p. ${entryIndex + 1} of ${widget.entries.length}";
    if (entry.isChapter) {
      final unlocked =
          entry.theme.passages.where((p) => widget.isUnlocked(p.id)).length;
      return JournalChapterPage(
        theme: entry.theme,
        unlockedCount: unlocked,
        runningHeader: entry.theme.name,
        pageLabel: pageLabel,
        themeIcon: themeIconFor(entry.theme.icon),
        onSelectPassage: (i) {
          // Chapter + i + 1 => entry index of that passage.
          final target = entryIndex + 1 + i;
          jumpToEntry(target);
        },
      );
    }
    final passage = entry.passage!;
    return JournalPassagePage(
      passage: passage,
      theme: entry.theme,
      isUnlocked: widget.isUnlocked(passage.id),
      preferredTranslation: widget.preferredTranslation,
      initialNote: widget.noteFor(passage.id),
      runningHeader: entry.theme.name,
      pageLabel: pageLabel,
      showTeaser: widget.showTeaser,
      bindLeft: bindLeft,
      onSaveNote: (note) => widget.onSaveNote(passage.id, note),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.entryIndex,
    required this.total,
    required this.sheetCount,
    required this.spread,
    required this.onPrev,
    required this.onNext,
  });

  final int entryIndex;
  final int total;
  final int sheetCount;
  final bool spread;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sheet = spread ? entryIndex ~/ 2 : entryIndex;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: "Previous page",
          onPressed: sheet > 0 ? onPrev : null,
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(sheetCount.clamp(0, 9), (i) {
              final active = i == sheet;
              return Container(
                width: active ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active ? cs.primary : cs.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
            const SizedBox(width: 8),
            Text(
              "${entryIndex + 1} / $total",
              style: textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        IconButton(
          tooltip: "Next page",
          onPressed: sheet < sheetCount - 1 ? onNext : null,
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
        ),
      ],
    );
  }
}
