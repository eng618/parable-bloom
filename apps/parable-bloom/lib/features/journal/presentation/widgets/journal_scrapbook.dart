import "package:flutter/material.dart";

import "../../domain/entities/journal_theme.dart";
import "journal_unlock_text.dart";

/// Public icon mapping for journal themes.
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

/// Translucent washi-tape strip pasted across the top of a scrapbook card.
/// Colors cycle through a muted palette by index so the page feels
/// hand-assembled without extra assets.
class WashiTape extends StatelessWidget {
  const WashiTape({super.key, required this.index});

  final int index;

  static const _palette = [
    Color(0xFF9DBEAA), // sage
    Color(0xFF9AB6D3), // dusty blue
    Color(0xFFD3A894), // clay
    Color(0xFFC9B48A), // straw
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[index % _palette.length];
    return Transform.rotate(
      angle: (index.isEven ? -1 : 1) * 0.06,
      child: Container(
        width: 96,
        height: 24,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.75),
          border: Border(
            left: BorderSide(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1,
            ),
            right: BorderSide(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Wax-seal achievement mark for chapters and envelopes.
class JournalWaxSeal extends StatelessWidget {
  const JournalWaxSeal({
    super.key,
    this.icon = Icons.spa,
    this.size = 40,
    this.sealed = false,
  });

  final IconData icon;
  final double size;
  final bool sealed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = sealed ? cs.onSurfaceVariant : cs.primary;
    return Semantics(
      label: sealed ? "Sealed" : "Unlocked seal",
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: sealed
              ? cs.surfaceContainerHighest.withValues(alpha: 0.7)
              : base.withValues(alpha: 0.9),
          border: Border.all(
            color: sealed ? cs.outlineVariant : base.withValues(alpha: 0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          sealed ? Icons.lock_outline : icon,
          size: size * 0.5,
          color: sealed ? cs.onSurfaceVariant : cs.onPrimary,
        ),
      ),
    );
  }
}

/// Scrapbook bloom index: filled blooms = unlocked, outlines = still to press.
class PressedBloomRow extends StatelessWidget {
  const PressedBloomRow({
    super.key,
    required this.total,
    required this.unlocked,
  });

  final int total;
  final int unlocked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (total <= 0) return const SizedBox.shrink();
    return Semantics(
      label: "$unlocked of $total pressed",
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: List.generate(total, (i) {
          final filled = i < unlocked;
          return Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? cs.primaryContainer : Colors.transparent,
              border: Border.all(
                color: filled ? cs.primary : cs.outlineVariant,
                width: 1.5,
              ),
            ),
            child: Icon(
              filled ? Icons.local_florist : Icons.circle_outlined,
              size: 14,
              color: filled ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          );
        }),
      ),
    );
  }
}

Color _paperColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF33475C)
      : const Color(0xFFFDFBF4);
}

Color _kraftColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF3E5366)
      : const Color(0xFFEFE0C3);
}

/// Kraft-paper chapter divider: seal, title, progress, bloom index.
class ChapterDivider extends StatelessWidget {
  const ChapterDivider({
    super.key,
    required this.theme,
    required this.unlockedCount,
  });

  final JournalTheme theme;
  final int unlockedCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final total = theme.passages.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20, bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kraftColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              JournalWaxSeal(
                icon: themeIconFor(theme.icon),
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
              Text(
                "$unlockedCount / $total",
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
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
          const SizedBox(height: 10),
          PressedBloomRow(total: total, unlocked: unlockedCount),
        ],
      ),
    );
  }
}

/// Taped-in scrapbook card for an unlocked passage. Tapping opens the
/// reading sheet.
class ScrapbookEntry extends StatelessWidget {
  const ScrapbookEntry({
    super.key,
    required this.passage,
    required this.translationCode,
    required this.index,
    required this.onTap,
  });

  final JournalPassage passage;
  final String translationCode;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Transform.rotate(
        angle: (index.isEven ? -1 : 1) * 0.008,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: _paperColor(context),
                borderRadius: BorderRadius.circular(4),
                border: Border(
                  left: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                    child: Row(
                      children: [
                        Icon(
                          passage.type == "parable"
                              ? Icons.menu_book
                              : (passage.type == "starter"
                                  ? Icons.star
                                  : Icons.spa),
                          color: cs.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                passage.title,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "Georgia",
                                  fontFamilyFallback: const ["Serif"],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${passage.reference} ($translationCode)",
                                style: textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(top: 0, child: WashiTape(index: index)),
          ],
        ),
      ),
    );
  }
}

/// Brown-paper envelope for a locked passage. Fully sealed: no title, no
/// reference — just the lock and how to earn it.
class SealedEnvelope extends StatelessWidget {
  const SealedEnvelope({super.key, required this.passage});

  final JournalPassage passage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kraftColor(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          JournalWaxSeal(sealed: true, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Locked Scripture",
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatJournalTriggerText(passage.triggerLevel),
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
