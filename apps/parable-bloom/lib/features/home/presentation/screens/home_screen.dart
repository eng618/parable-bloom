import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game/application/providers/module_providers.dart';
import '../../../game/application/providers/progress_providers.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/widgets/constrained_page.dart';
import '../../../../core/widgets/garden_loading_view.dart';
import '../../../game/domain/entities/game_progress.dart';
import '../../application/providers/habit_providers.dart';
import '../widgets/welcome_back_messages.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _precached = false;
  bool _habitOpenRecorded = false;
  String? _welcomeBackLine;

  static const _homeAssets = [
    'assets/art/home/cross_wood.png',
    'assets/art/home/frame_light.png',
    'assets/art/home/frame_dark.png',
    'assets/art/home/parchment.png',
    'assets/art/cross.png',
    'assets/art/bg_day.png',
    'assets/art/bg_night.png',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logScreenView('Home');
      _recordHabitOpen();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      for (final asset in _homeAssets) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  void _recordHabitOpen() {
    if (!mounted || _habitOpenRecorded) return;
    _habitOpenRecorded = true;

    final habit = ref.read(habitSessionProvider.notifier);
    final daysSinceLast = habit.recordOpen();
    if (daysSinceLast != null) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logHabitDayReturn(daysSinceLast: daysSinceLast),
      );
    }

    final habitState = ref.read(habitSessionProvider);
    if (habitState.isReturningDay) {
      setState(() {
        _welcomeBackLine = pickWelcomeBackMessage();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Select only the fields the build reads, so unrelated GameProgress
    // writes (scripture unlocks, journal notes, Hive reloads) don't rebuild
    // this screen.
    final (tutorialCompleted, currentLevelId, completedLevels) = ref.watch(
      gameProgressProvider.select(
        (p) => (p.tutorialCompleted, p.currentLevel, p.completedLevels),
      ),
    );
    final modulesAsync = ref.watch(modulesProvider);
    final isReturningDay = ref.watch(
      habitSessionProvider.select((s) => s.isReturningDay),
    );

    final welcomeLine =
        isReturningDay ? (_welcomeBackLine ?? pickWelcomeBackMessage()) : null;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final frameAsset = isDark
        ? 'assets/art/home/frame_dark.png'
        : 'assets/art/home/frame_light.png';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Soft parchment grain (light) / dim grain (dark)
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.12 : 0.28,
              child: Image.asset(
                'assets/art/home/parchment.png',
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
          ),
          Positioned.fill(
            child: Image.asset(
              frameAsset,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          SafeArea(
            child: ConstrainedPage(
              maxWidth: 600,
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Parable Bloom',
                    style: theme.textTheme.displayMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          letterSpacing: -0.5,
                        ) ??
                        TextStyle(
                          fontFamily: AppTheme.displayFontFamily,
                          fontFamilyFallback: AppTheme.displayFontFallback,
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (welcomeLine != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      welcomeLine,
                      style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                            fontFamily: AppTheme.displayFontFamily,
                            fontFamilyFallback: AppTheme.displayFontFallback,
                            height: 1.4,
                          ) ??
                          TextStyle(
                            color: cs.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                            fontFamily: AppTheme.displayFontFamily,
                            fontFamilyFallback: AppTheme.displayFontFallback,
                            height: 1.4,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: _HomeCrossArtwork(isDark: isDark),
                      ),
                    ),
                  ),
                  modulesAsync.when(
                    data: (modules) {
                      final playlist =
                          modules.expand((m) => m.allLevels).toList();
                      final allLevelsCompleted = playlist.isNotEmpty &&
                          playlist.every(completedLevels.contains);
                      // Display the first uncompleted level, not the persisted
                      // pointer: the pointer goes stale when new cloud levels
                      // ship (indexOf == -1 wrongly rendered "Play Level 1").
                      final displayId = GameProgress.firstUncompletedInPlaylist(
                            playlist,
                            completedLevels,
                          ) ??
                          (playlist.contains(currentLevelId)
                              ? currentLevelId
                              : null);
                      final nextLevelIdx =
                          displayId == null ? -1 : playlist.indexOf(displayId);
                      final levelDisplayNumber =
                          nextLevelIdx != -1 ? nextLevelIdx + 1 : 1;

                      if (allLevelsCompleted) {
                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: null,
                                style: ElevatedButton.styleFrom(
                                  disabledBackgroundColor:
                                      cs.surfaceContainerHighest,
                                  disabledForegroundColor: cs.onSurfaceVariant,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  'All Levels Complete',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'More levels coming soon!',
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      }

                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _playNextLevel(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            tutorialCompleted
                                ? 'Play Level $levelDisplayNumber'
                                : 'Start Tutorial',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              fontFamily: AppTheme.displayFontFamily,
                              fontFamilyFallback: AppTheme.displayFontFallback,
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () =>
                        const GardenLoadingView(message: "Loading garden…"),
                    error: (error, __) => Column(
                      children: [
                        Text(
                          'Failed to load levels. Please try again.',
                          style: TextStyle(color: cs.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => ref.invalidate(modulesProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openSettings(),
                          icon: const Icon(Icons.settings_outlined, size: 20),
                          label: const Text('Settings'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.primary,
                            backgroundColor: cs.surface.withValues(alpha: 0.72),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(color: cs.outline),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openJournal(),
                          icon: const Icon(Icons.menu_book_outlined, size: 20),
                          label: const Text('Journal'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.primary,
                            backgroundColor: cs.surface.withValues(alpha: 0.72),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(color: cs.outline),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _playNextLevel() async {
    final gameProgress = ref.read(gameProgressProvider);

    if (!gameProgress.tutorialCompleted) {
      context.go('/tutorial');
      return;
    }
    // Persist any stale-pointer heal before entering the game so the
    // resolved level survives refreshes even if the load below races it.
    await ref.read(gameProgressProvider.notifier).resolveLevelToLoad();
    if (!mounted) return;
    context.go('/game');
  }

  void _openSettings() {
    context.push('/settings');
  }

  void _openJournal() {
    context.push('/journal');
  }
}

/// Wooden cross with a soft multiply ground shadow so light and dark both read
/// cleanly (the PNG keeps original silhouette AA; the old white matte plate is
/// stripped from the asset).
class _HomeCrossArtwork extends StatelessWidget {
  const _HomeCrossArtwork({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CrossGroundShadowPainter(isDark: isDark),
      child: Image.asset(
        'assets/art/home/cross_wood.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Wooden cross',
      ),
    );
  }
}

/// Soft elliptical contact shadow under the cross, multiplied into the Home
/// backdrop so it darkens cream and night soil instead of painting a white matte.
class _CrossGroundShadowPainter extends CustomPainter {
  const _CrossGroundShadowPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    // Anchor near the foot of the contained cross image.
    final center = Offset(size.width * 0.52, size.height * 0.90);
    final radii = Offset(size.width * 0.28, size.height * 0.045);
    final rect = Rect.fromCenter(
      center: center,
      width: radii.dx * 2,
      height: radii.dy * 2,
    );

    final paint = Paint()
      ..blendMode = BlendMode.multiply
      ..color = Color.fromRGBO(18, 14, 10, isDark ? 0.72 : 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _CrossGroundShadowPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
