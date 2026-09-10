import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/constants/animation_timing.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/entities/lesson_data.dart';
import '../../../game/application/providers/camera_providers.dart';
import '../../../game/application/providers/gameplay_state_providers.dart';
import '../../../game/application/providers/solver_providers.dart';
import '../../application/providers/tutorial_providers.dart';
import '../../../game/presentation/widgets/garden_game.dart';
import '../../../game/presentation/widgets/celebration_effects.dart';
import '../../../game/presentation/widgets/level_complete_overlay.dart';
import '../../../game/presentation/widgets/game_event_sink.dart';
import '../../../game/presentation/widgets/projection_sync.dart';
import '../../../game/presentation/widgets/game_header.dart';
import '../../../game/presentation/widgets/pause_menu_dialog.dart';
import '../widgets/tutorial_guide_overlay.dart';
import '../../../game/application/providers/progress_providers.dart';
import '../../../game/application/providers/module_providers.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/settings_providers.dart';
import '../../../game/application/providers/counter_providers.dart';
import '../../../game/domain/entities/level_data.dart';
import '../../../journal/application/providers/journal_providers.dart';

/// Tutorial flow screen that matches the regular game experience.
/// Shows the game with GameHeader (pause, grace) and a simple instruction overlay.
class TutorialFlowScreen extends ConsumerStatefulWidget {
  const TutorialFlowScreen({super.key});

  @override
  ConsumerState<TutorialFlowScreen> createState() => _TutorialFlowScreenState();
}

class _TutorialFlowScreenState extends ConsumerState<TutorialFlowScreen> {
  GardenGame? _game;
  bool _isLevelCompleteOverlayVisible = false;
  String _currentCongratulationMessage = '';

  @override
  void initState() {
    super.initState();
    _subscribeToProviders();
  }

  /// Provider subscriptions live here — not in [build] — so they are
  /// registered once instead of re-subscribed on every rebuild.
  /// Uses [listenManual]: [ref.listen] asserts a build context and throws
  /// when called from [initState]; manual subscriptions are closed
  /// automatically on unmount.
  void _subscribeToProviders() {
    // Listen for level completion
    ref.listenManual<bool>(levelCompleteProvider, (previous, next) {
      LoggerService.debug('levelCompleteProvider changed $previous -> $next',
          tag: 'TutorialFlowScreen');
      if (next && (previous == null || !previous)) {
        _showLevelCompleteOverlay();
      }
    });

    // Listen for game completion (all vines cleared)
    ref.listenManual<bool>(gameCompletedProvider, (previous, next) {
      LoggerService.debug('gameCompletedProvider changed $previous -> $next',
          tag: 'TutorialFlowScreen');
      if (next && (previous == null || !previous)) {
        _showLevelCompleteOverlay();
      }
    });

    // Forward projection-line state (Show All + long-press hint) to Flame.
    // Single subscription: ProjectionMode carries both atomically.
    ref.listenManual<ProjectionMode>(projectionModeProvider, (previous, next) {
      if (previous != next) syncProjectionLines(ref, _game);
    });
    ref.listenManual<bool>(anyVineAnimatingProvider, (previous, next) {
      if (previous != next) syncProjectionLines(ref, _game);
    });

    // Forward vine-style changes (the game otherwise stays on classic).
    ref.listenManual<VineStyle>(vineStyleProvider, (previous, next) {
      if (previous != next) _game?.updateVineStyle(next);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Theme sync runs here so it re-fires on brightness/theme changes —
    // not on every build.
    _syncThemeColors();
  }

  void _syncThemeColors() {
    if (_game == null) return;
    final extension = Theme.of(context).extension<AppThemeExtension>()!;
    _game!.updateThemeColors(
      AppTheme.getGameBackground(Theme.of(context).brightness),
      AppTheme.getGameSurface(Theme.of(context).brightness),
      AppTheme.getGridBackground(Theme.of(context).brightness),
      tapEffectColor: extension.tapEffect,
      vineAttemptedColor: extension.vineAttempted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tutorialProgress = ref.watch(tutorialProgressProvider);
    final currentLesson = tutorialProgress.currentLesson;

    // Validate lesson number
    if (currentLesson < 1 || currentLesson > LessonData.totalLessons) {
      return Scaffold(
        body: Center(
          child: Text('Invalid lesson: $currentLesson'),
        ),
      );
    }

    return ref.watch(lessonProvider(currentLesson)).when(
          data: (lesson) {
            // Create or recreate game when lesson changes
            if (_game == null || _game!.currentLessonId != lesson.id) {
              final levelData = lesson.toLevelData();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ref.read(currentLevelProvider.notifier).setLevel(levelData);
                  ref
                      .read(vineStatesProvider.notifier)
                      .resetForLevel(levelData);
                  ref.read(levelCompleteProvider.notifier).setComplete(false);
                  ref.read(gameCompletedProvider.notifier).setCompleted(false);
                }
              });

              _game = GardenGame.fromLesson(
                lesson,
                solver: ref.read(levelSolverServiceProvider),
                sink: _TutorialFlowEventSink(this, lesson),
              );
            }

            return Scaffold(
              backgroundColor: colorScheme.surface,
              floatingActionButton: _buildProjectionLinesFAB(),
              body: Stack(
                children: [
                  // Game widget
                  _buildGameWidgetWithGestures(),

                  // Game header with pause button and grace display
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: GameHeader(onPause: _showPauseMenu),
                    ),
                  ),

                  // Lesson progress indicator
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 56),
                        child: _buildLessonProgressIndicator(currentLesson),
                      ),
                    ),
                  ),

                  // Redesigned progressive tap-based tutorial overlay
                  const TutorialGuideOverlay(),

                  // Level complete overlay
                  if (_isLevelCompleteOverlayVisible)
                    _buildLevelCompleteOverlay(),
                ],
              ),
            );
          },
          loading: () => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => Scaffold(
            body: Center(
              child: Text('Error loading lesson: $error'),
            ),
          ),
        );
  }

  Widget _buildGameWidgetWithGestures() {
    // No pan/zoom handling here by design: lesson grids are small enough to
    // fit on screen (auto-framed on load), and without a camera-state
    // listener the gesture writes never reached Flame anyway. Taps are
    // handled by Flame's own TapCallbacks inside GameWidget.
    return GameWidget<GardenGame>(
      game: _game!,
      loadingBuilder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildProjectionLinesFAB() {
    return FloatingActionButton(
      onPressed: () {
        ref.read(projectionModeProvider.notifier).toggleAll();
      },
      tooltip: 'Toggle projection lines',
      child: const Icon(Icons.tag),
    );
  }

  Widget _buildLessonProgressIndicator(int currentLesson) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(LessonData.totalLessons, (index) {
        final lessonNum = index + 1;
        final isCompleted = lessonNum < currentLesson;
        final isCurrent = lessonNum == currentLesson;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: isCurrent ? 12 : 8,
            height: isCurrent ? 12 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? Theme.of(context).colorScheme.primary
                  : isCurrent
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
              border: isCurrent
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
          ),
        );
      }),
    );
  }

  void _showPauseMenu() {
    showDialog(
      context: context,
      builder: (context) => PauseMenuDialog(
        onRestart: () {
          if (context.canPop()) context.pop(); // Close dialog
          _restartLesson();
        },
        onHome: () {
          if (context.canPop()) context.pop(); // Close dialog
          context.go('/');
        },
      ),
    );
  }

  void _restartLesson() {
    ref.read(levelCompleteProvider.notifier).setComplete(false);
    ref.read(gameCompletedProvider.notifier).setCompleted(false);
    ref.read(gameInstanceProvider.notifier).resetGrace();

    final tutorialProgress = ref.read(tutorialProgressProvider);
    final currentLesson = tutorialProgress.currentLesson;
    ref.read(lessonProvider(currentLesson)).whenData((lesson) {
      if (_game != null) {
        _game!.startLesson(lesson);
        final cameraNotifier = ref.read(cameraStateProvider.notifier);
        cameraNotifier.animateToDefaultZoom(
          screenWidth: _game!.size.x,
          screenHeight: _game!.size.y,
          gridCols: lesson.gridWidth,
          gridRows: lesson.gridHeight,
        );
      }
    });

    setState(() {
      _isLevelCompleteOverlayVisible = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lesson restarted')),
    );
  }

  void _showLevelCompleteOverlay() async {
    if (_isLevelCompleteOverlayVisible) return;

    _currentCongratulationMessage = pickCongratulationMessage();

    setState(() {
      _isLevelCompleteOverlayVisible = true;
    });

    // Celebration FX, centered on the board.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_game != null) {
        spawnCelebrationEffect(
          game: _game!,
          effect: ref.read(celebrationEffectProvider),
          isDark: Theme.of(context).brightness == Brightness.dark,
        );
      }
    });

    // Wait for 2 seconds then advance to next lesson
    await Future.delayed(AnimationTiming.levelCompleteDelay);

    if (!mounted) return;

    setState(() {
      _isLevelCompleteOverlayVisible = false;
    });

    // Get current lesson before advancing
    final beforeLesson = ref.read(tutorialProgressProvider).currentLesson;

    final prevUnlockedScriptures =
        ref.read(gameProgressProvider).unlockedScriptureIds;

    // Advance to next lesson
    await ref
        .read(tutorialProgressProvider.notifier)
        .completeLesson(beforeLesson);

    // Reset completion flags
    ref.read(levelCompleteProvider.notifier).setComplete(false);
    ref.read(gameCompletedProvider.notifier).setCompleted(false);

    final postProgress = ref.read(gameProgressProvider);
    ModuleScripture? unlockedScripture;
    ModuleData? completedModule;

    try {
      final modules = await ref.read(modulesProvider.future);
      for (final m in modules) {
        for (final s in m.scriptures) {
          if (!prevUnlockedScriptures.contains(s.id) &&
              postProgress.unlockedScriptureIds.contains(s.id)) {
            unlockedScripture = s;
            completedModule = m;
            break;
          }
        }
      }

      if (unlockedScripture == null) {
        final themes = await ref.read(journalThemesProvider.future);
        for (final theme in themes) {
          for (final passage in theme.passages) {
            if (!prevUnlockedScriptures.contains(passage.id) &&
                postProgress.unlockedScriptureIds.contains(passage.id)) {
              unlockedScripture = ModuleScripture(
                id: passage.id,
                triggerLevel: passage.triggerLevel,
                reference: passage.reference,
                title: passage.title,
                type: passage.type,
              );
              completedModule = ModuleData(
                id: 1,
                name: theme.name,
                themeSeed: 'forest',
                levels: const [],
                challengeLevel: '',
                parable: const {},
                unlockMessage: '',
                scriptures: const [],
              );
              break;
            }
          }
        }
      }
    } catch (e) {
      LoggerService.error(
          'Failed to look up unlocked scripture in tutorial completion',
          error: e);
    }

    if (unlockedScripture != null && completedModule != null) {
      await _showScriptureUnlockedDialog(unlockedScripture, completedModule);
      return;
    }

    // If no scripture is unlocked, but we completed all lessons, pop now!
    final after = ref.read(tutorialProgressProvider);
    if (after.allLessonsCompleted) {
      if (mounted) {
        LoggerService.info('All lessons completed - returning to home',
            tag: 'TutorialFlowScreen');
        context.go('/');
      }
      return;
    }

    // Check if we advanced to a new lesson
    if (after.currentLesson != beforeLesson) {
      // Reset for new lesson
      setState(() {
        _game = null; // Will be recreated in build
      });
    }
  }

  Future<void> _showScriptureUnlockedDialog(
    ModuleScripture scripture,
    ModuleData module,
  ) async {
    if (!mounted) return;

    final preferred = ref.read(preferredTranslationProvider);

    String resolvedText = '';
    String displayCitation = scripture.reference;
    String themeName = module.name;
    String? reflectionPrompt;

    try {
      final themes = await ref.read(journalThemesProvider.future);
      for (final theme in themes) {
        for (final passage in theme.passages) {
          if (passage.id == scripture.id ||
              passage.reference == scripture.reference) {
            themeName = theme.name;
            if (passage.reflectionPrompts.isNotEmpty) {
              reflectionPrompt = passage.reflectionPrompts.first;
            }
            break;
          }
        }
      }
    } catch (_) {}

    try {
      final result = await ref.read(scriptureServiceProvider).loadScripture(
            scripture.reference,
            preferredTranslationId: preferred,
          );

      resolvedText = result['text'] ?? '';
      final code = result['translation'] ?? preferred.toUpperCase();
      displayCitation = '${scripture.reference} ($code)';
    } catch (e, stack) {
      LoggerService.error(
        'Error loading scripture for unlocked dialog',
        error: e,
        stackTrace: stack,
        tag: 'TutorialFlowScreen',
      );
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.spa, color: cs.primary, size: 28),
              const SizedBox(width: 8),
              Text(
                scripture.type == 'starter'
                    ? 'Starter Scripture!'
                    : 'Scripture Collected!',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  scripture.title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (resolvedText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Text(
                      resolvedText,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  displayCitation,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (reflectionPrompt != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: cs.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.help_outline, size: 16, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reflectionPrompt,
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Added to your Journal under $themeName.',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go('/');
                context.push('/journal');
              },
              child: const Text('VIEW JOURNAL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go('/');
              },
              child: const Text('CONTINUE'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLevelCompleteOverlay() {
    // Shared widget (same as the game screen, including the title the
    // old inline version was missing).
    return LevelCompleteOverlay(message: _currentCongratulationMessage);
  }
}

/// [GameEventSink] bridging the Flame engine to [_TutorialFlowState].
///
/// Carries the [LessonData] the game was created for, since lesson setup
/// (level reset, camera framing) needs it on every [onGameLoaded].
class _TutorialFlowEventSink implements GameEventSink {
  _TutorialFlowEventSink(this._state, this._lesson);

  final _TutorialFlowScreenState _state;
  final LessonData _lesson;

  WidgetRef get _ref => _state.ref;
  bool get _mounted => _state.mounted;

  @override
  void onGameLoaded(GardenGame game) {
    if (!_mounted) return;
    _ref.read(gameInstanceProvider.notifier).setGame(game);
    final levelData = _lesson.toLevelData();
    _ref.read(currentLevelProvider.notifier).setLevel(levelData);
    _ref.read(vineStatesProvider.notifier).resetForLevel(levelData);
    _ref.read(levelCompleteProvider.notifier).setComplete(false);
    _ref.read(gameCompletedProvider.notifier).setCompleted(false);

    game.startLesson(_lesson);

    final cameraNotifier = _ref.read(cameraStateProvider.notifier);
    cameraNotifier.updateZoomBounds(
      screenWidth: game.size.x,
      screenHeight: game.size.y,
      gridCols: _lesson.gridWidth,
      gridRows: _lesson.gridHeight,
    );
    cameraNotifier.animateToDefaultZoom(
      screenWidth: game.size.x,
      screenHeight: game.size.y,
      gridCols: _lesson.gridWidth,
      gridRows: _lesson.gridHeight,
    );
    game.applyCameraTransform(_ref.read(cameraStateProvider));
  }

  @override
  void onGameRemoved() {
    if (!_mounted) return;
    if (_ref.read(gameInstanceProvider) == _state._game) {
      _ref.read(gameInstanceProvider.notifier).setGame(null);
    }
  }

  @override
  void onVineCleared(String vineId) {
    if (!_mounted) return;
    _ref.read(vineStatesProvider.notifier).clearVine(vineId);
  }

  @override
  void onVineAnimationStateChanged(String vineId, VineAnimationState state) {
    if (!_mounted) return;
    _ref.read(vineStatesProvider.notifier).setAnimationState(vineId, state);
  }

  @override
  void onVineAttempted(String vineId) {
    if (!_mounted) return;
    _ref.read(vineStatesProvider.notifier).markAttempted(vineId);
  }

  @override
  void onTapIncrement(int count) {
    if (!_mounted) return;
    _ref.read(levelTotalTapsProvider.notifier).add(count);
  }

  @override
  void onTapOutsideGrid() {
    if (!_mounted) return;
    _ref.read(projectionModeProvider.notifier).clearHints();
  }

  @override
  void onBlockedTap(BlockedTapState state) {
    if (!_mounted) return;
    _ref.read(blockedTapProvider.notifier).setBlockedTap(state);
  }

  @override
  Future<void> onEnsureVineVisible(VineData vine) async {
    if (!_mounted) return;
    await _ref.read(cameraStateProvider.notifier).ensureVineVisible(vine);
  }

  @override
  void onHintVine(String vineId) {
    if (!_mounted) return;
    _ref.read(projectionModeProvider.notifier).hint(vineId);
  }

  @override
  void onClearHints() {
    if (!_mounted) return;
    _ref.read(projectionModeProvider.notifier).clearHints();
  }

  @override
  bool get useSimpleVines =>
      _mounted ? _ref.read(useSimpleVinesProvider) : false;

  @override
  bool get hapticsEnabled =>
      _mounted ? _ref.read(hapticsEnabledProvider) : false;

  @override
  bool get isAnyAnimating =>
      _mounted ? _ref.read(anyVineAnimatingProvider) : false;

  @override
  bool get debugShowGridCoordinates =>
      _mounted ? _ref.read(debugShowGridCoordinatesProvider) : false;

  @override
  bool get debugVineAnimationLogging =>
      _mounted ? _ref.read(debugVineAnimationLoggingProvider) : false;
}
