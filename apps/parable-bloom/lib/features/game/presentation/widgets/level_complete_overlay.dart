import 'package:material_ui/material_ui.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/constants/animation_timing.dart';
import '../../../../core/widgets/garden_leaf_divider.dart';
import '../../../appearance/domain/appearance_slot.dart';
import '../../../appearance/presentation/widgets/themed_asset.dart';
import 'garden_encouraging_message.dart';

/// Full-screen "Level Complete" celebration overlay content.
///
/// Pure presentation: the owning screen owns visibility timing, analytics,
/// and the congratulatory message. [onContinue] is the call to action and
/// skips the rest of the hold. [onHome] stays a quiet control so players
/// can leave without Pause → Home.
///
/// Visual language matches Home: parchment panel, botanical ornaments,
/// forest/moss serif titles — not Material celebration chrome.
class LevelCompleteOverlay extends StatelessWidget {
  const LevelCompleteOverlay({
    super.key,
    required this.message,
    this.onContinue,
    this.onHome,
  });

  final String message;

  /// When set, shows the primary Continue action. Skips the remaining hold.
  final VoidCallback? onContinue;

  /// When set, shows a quiet Home control during the celebration beat.
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final pack = AppearanceScope.of(context);
    final frameSlot =
        isDark ? AppearanceSlot.homeFrameDark : AppearanceSlot.homeFrameLight;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Soft soil/parchment scrim so the garden still peeks through.
        Positioned.fill(
          child: ColoredBox(
            color: theme.scaffoldBackgroundColor.withValues(
              alpha: AnimationTiming.levelCompleteScrimOpacity,
            ),
          ),
        ),
        // Faint botanical frame (same assets as Home).
        Positioned.fill(
          child: Opacity(
            opacity: isDark ? 0.35 : 0.55,
            child: ThemedAsset(
              slot: frameSlot,
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
                        child: const ThemedAsset(
                          slot: AppearanceSlot.homeGrain,
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
                            child: const ThemedAsset(
                              slot: AppearanceSlot.ornamentSprig,
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
                          GardenLeafDivider(
                            asset: pack.asset(AppearanceSlot.ornamentDivider),
                          ),
                          const SizedBox(height: 16),
                          GardenEncouragingMessage(message: message),
                          if (onContinue != null) ...[
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: onContinue,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text(
                                'Continue',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontFamily: AppTheme.displayFontFamily,
                                  fontFamilyFallback:
                                      AppTheme.displayFontFallback,
                                ),
                              ),
                            ),
                          ],
                          if (onHome != null) ...[
                            SizedBox(height: onContinue != null ? 4 : 24),
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
