import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/widgets/garden_leaf_divider.dart';
import 'garden_encouraging_message.dart';

/// Full-screen "Level Complete" celebration overlay content.
///
/// Pure presentation: the owning screen owns visibility timing, analytics,
/// and the congratulatory message. [onHome] is optional so players can leave
/// intentionally without Pause → Home (session-close may then show on Home).
///
/// Visual language matches Home / session-close: parchment panel, botanical
/// ornaments, forest/moss serif titles — not Material celebration chrome.
class LevelCompleteOverlay extends StatelessWidget {
  const LevelCompleteOverlay({
    super.key,
    required this.message,
    this.onHome,
  });

  final String message;

  /// When set, shows a quiet Home control during the celebration beat.
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final frameAsset = isDark
        ? 'assets/art/home/frame_dark.png'
        : 'assets/art/home/frame_light.png';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Soft soil/parchment scrim so the garden still peeks through.
        Positioned.fill(
          child: ColoredBox(
            color: theme.scaffoldBackgroundColor.withValues(alpha: 0.72),
          ),
        ),
        // Faint botanical frame (same assets as Home).
        Positioned.fill(
          child: Opacity(
            opacity: isDark ? 0.35 : 0.55,
            child: Image.asset(
              frameAsset,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Material(
                color: cs.surface,
                elevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: isDark ? 0.08 : 0.22,
                        child: Image.asset(
                          'assets/art/home/parchment.png',
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/art/ornaments/leaf_sprig.png',
                              height: 56,
                              excludeFromSemantics: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Level Complete',
                            style: theme.textTheme.headlineMedium?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: AppTheme.displayFontFamily,
                                  fontFamilyFallback:
                                      AppTheme.displayFontFallback,
                                  height: 1.2,
                                ) ??
                                TextStyle(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: AppTheme.displayFontFamily,
                                  fontFamilyFallback:
                                      AppTheme.displayFontFallback,
                                  fontSize: 28,
                                  height: 1.2,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          const GardenLeafDivider(),
                          const SizedBox(height: 16),
                          GardenEncouragingMessage(message: message),
                          if (onHome != null) ...[
                            const SizedBox(height: 24),
                            TextButton.icon(
                              onPressed: onHome,
                              icon: Icon(
                                Icons.home_rounded,
                                color: cs.onSurfaceVariant,
                              ),
                              label: Text(
                                'Home',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: AppTheme.displayFontFamily,
                                  fontFamilyFallback:
                                      AppTheme.displayFontFallback,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
