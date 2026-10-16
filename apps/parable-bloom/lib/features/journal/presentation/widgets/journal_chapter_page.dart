import "package:flutter/material.dart";

import "../../domain/entities/journal_theme.dart";
import "journal_paper.dart";

/// Chapter opener spread: theme art, description, ink-fill progress,
/// and a scrapbook bloom index that jumps to a passage page.
class JournalChapterPage extends StatelessWidget {
  const JournalChapterPage({
    super.key,
    required this.theme,
    required this.unlockedCount,
    required this.onSelectPassage,
    required this.runningHeader,
    required this.pageLabel,
    required this.themeIcon,
  });

  final JournalTheme theme;
  final int unlockedCount;
  final ValueChanged<int> onSelectPassage;
  final String runningHeader;
  final String pageLabel;
  final IconData themeIcon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final total = theme.passages.length;
    final pct = total > 0 ? unlockedCount / total : 0.0;
    final complete = unlockedCount == total && total > 0;

    return JournalPaper(
      runningHeader: runningHeader,
      pageLabel: pageLabel,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                JournalWaxSeal(
                  icon: themeIcon,
                  sealed: unlockedCount == 0,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Chapter",
                        style: textTheme.labelMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        theme.name,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: "Georgia",
                          fontFamilyFallback: const ["Serif"],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (theme.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                theme.description,
                style: textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              "$unlockedCount / $total Collected",
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  complete ? cs.primary : cs.secondary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            PressedBloomRow(total: total, unlocked: unlockedCount),
            const SizedBox(height: 12),
            // Washi-tape index of passages.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(total, (i) {
                final passage = theme.passages[i];
                return ActionChip(
                  label: Text(
                    passage.title.isEmpty ? "Page ${i + 1}" : passage.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  avatar: Icon(
                    Icons.local_florist,
                    size: 14,
                    color: cs.primary,
                  ),
                  onPressed: () => onSelectPassage(i),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
