import "package:flutter/material.dart";

/// Parchment page wrapper shared by chapter + passage pages.
///
/// Gives the paper-journal feel: warm paper, spine shadow on the bound
/// edge, stacked page edges on the fore-edge, running header + folio.
class JournalPaper extends StatelessWidget {
  const JournalPaper({
    super.key,
    required this.child,
    this.runningHeader = "",
    this.pageLabel = "",
    this.bindLeft = true,
  });

  final Widget child;
  final String runningHeader;
  final String pageLabel;
  final bool bindLeft;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Paper + ink: warm parchment by day, "night journal" by night.
    final paper = isDark ? const Color(0xFF33475C) : const Color(0xFFFDFBF4);
    final paperEdge =
        isDark ? const Color(0xFF2A3C4F) : const Color(0xFFEFE6D2);
    final ink = isDark ? const Color(0xFFF2EAD8) : cs.onSurface;
    final faintInk = (isDark ? Colors.white70 : cs.onSurfaceVariant);

    return Container(
      decoration: BoxDecoration(
        color: paperEdge,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Fore-edge page stack on the outer edge.
      padding: EdgeInsets.only(
        left: bindLeft ? 0 : 5,
        right: bindLeft ? 5 : 0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (bindLeft) _SpineShadow(left: true),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (runningHeader.isNotEmpty || pageLabel.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              runningHeader,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: faintInk,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            pageLabel,
                            style: textTheme.labelSmall?.copyWith(
                              color: faintInk,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    if (runningHeader.isNotEmpty || pageLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 10),
                        child: Container(
                          height: 1,
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: ink),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!bindLeft) _SpineShadow(left: false),
          ],
        ),
      ),
    );
  }
}

class _SpineShadow extends StatelessWidget {
  const _SpineShadow({required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(left ? 8 : 0),
          right: Radius.circular(left ? 0 : 8),
        ),
        gradient: LinearGradient(
          begin: left ? Alignment.centerLeft : Alignment.centerRight,
          end: left ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            Colors.black.withValues(alpha: 0.22),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

/// Wax-seal achievement mark for completed chapters / unlocked pages.
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

/// Scrapbook bloom row: filled blooms = unlocked, outlines = still pressed.
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
