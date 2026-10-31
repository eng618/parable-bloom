import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game/application/providers/module_providers.dart';
import '../../../game/application/providers/progress_providers.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/widgets/constrained_page.dart';
import '../../../../core/widgets/garden_loading_view.dart';
import '../../../game/domain/entities/game_progress.dart';
import '../../application/providers/habit_providers.dart';
import '../widgets/session_close_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _precached = false;
  bool _habitOpenRecorded = false;
  bool _sessionCloseScheduled = false;
  bool _sessionCloseVisible = false;
  Timer? _sessionCloseTimer;
  String? _welcomeBackLine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logScreenView('Home');
      _recordHabitOpenAndMaybeScheduleClose();
    });
  }

  @override
  void dispose() {
    _sessionCloseTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      for (final asset in const [
        'assets/art/cross.png',
        'assets/art/bg_day.png',
        'assets/art/bg_night.png',
      ]) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  void _recordHabitOpenAndMaybeScheduleClose() {
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

    _scheduleSessionCloseIfNeeded();
  }

  void _scheduleSessionCloseIfNeeded() {
    if (_sessionCloseScheduled || _sessionCloseVisible) return;
    final habit = ref.read(habitSessionProvider.notifier);
    if (!habit.shouldShowSessionClose()) return;

    _sessionCloseScheduled = true;
    _sessionCloseTimer?.cancel();
    // Brief grace so an immediate Play tap is treated as a continuous session.
    _sessionCloseTimer = Timer(kSessionClosePlayGrace, () {
      if (!mounted) return;
      _showSessionCloseIfStillEligible();
    });
  }

  Future<void> _showSessionCloseIfStillEligible() async {
    if (!mounted || _sessionCloseVisible) return;
    final habit = ref.read(habitSessionProvider.notifier);
    if (!habit.shouldShowSessionClose()) return;

    // Home may sit under Journal after scripture "VIEW JOURNAL" (go `/` then
    // push). Wait until Home is the top route so we never cover reading.
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) {
      _sessionCloseTimer?.cancel();
      _sessionCloseTimer = Timer(kSessionClosePlayGrace, () {
        if (!mounted) return;
        _showSessionCloseIfStillEligible();
      });
      return;
    }

    final habitState = ref.read(habitSessionProvider);
    final hadScripture = habitState.hadScriptureUnlockToday;
    final scriptureId = habitState.scriptureIdToday;

    habit.markSessionCloseShown();
    _sessionCloseVisible = true;

    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logHabitSessionCloseShown(hadScriptureUnlockToday: hadScripture),
    );

    final action = await showSessionCloseSheet(
      context,
      hadScriptureUnlock: hadScripture,
    );

    if (!mounted) return;
    _sessionCloseVisible = false;

    final resolved = action ?? SessionCloseAction.dismiss;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logHabitSessionCloseAction(resolved.name),
    );

    if (resolved == SessionCloseAction.journal) {
      if (scriptureId != null && scriptureId.isNotEmpty) {
        context.push('/journal?entry=${Uri.encodeComponent(scriptureId)}');
      } else {
        context.push('/journal');
      }
    }
  }

  void _cancelPendingSessionClose() {
    _sessionCloseTimer?.cancel();
    _sessionCloseTimer = null;
    _sessionCloseScheduled = false;
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

    // When returning from game/journal with a pending close, (re)schedule.
    ref.listen(habitSessionProvider, (prev, next) {
      if (next.completedLevelToday && !next.sessionCloseShownToday) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scheduleSessionCloseIfNeeded();
        });
      }
    });

    final welcomeLine =
        isReturningDay ? (_welcomeBackLine ?? pickWelcomeBackMessage()) : null;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: ConstrainedPage(
          maxWidth: 600,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Parable Bloom',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              if (welcomeLine != null) ...[
                const SizedBox(height: 12),
                Text(
                  welcomeLine,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 48),
              Expanded(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/art/cross.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              modulesAsync.when(
                data: (modules) {
                  final playlist = modules.expand((m) => m.allLevels).toList();
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
                        ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            disabledBackgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            disabledForegroundColor:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'All Levels Complete',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'More levels coming soon!',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  }

                  return ElevatedButton(
                    onPressed: () => _playNextLevel(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      tutorialCompleted
                          ? 'Play Level $levelDisplayNumber'
                          : 'Start Tutorial',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(modulesProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _openSettings(),
                icon: const Icon(Icons.settings),
                label: const Text('Settings'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openJournal(),
                icon: const Icon(Icons.menu_book),
                label: const Text('Journal'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playNextLevel() async {
    // Treat a quick Play tap as continuous play — skip today's close invite.
    _cancelPendingSessionClose();

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
