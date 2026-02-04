import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';

import '../../../../core/app_theme.dart';
import '../../../../providers/game_providers.dart';
import '../../../../providers/tutorial_providers.dart';
import '../../../game/presentation/widgets/garden_game.dart';
import '../../../game/presentation/widgets/game_header.dart';
import '../../../game/presentation/widgets/pause_menu_dialog.dart';
import '../widgets/tutorial_overlay.dart';

/// Tutorial flow screen that matches the regular game experience.
/// Shows the game with GameHeader (pause, grace) and a simple instruction overlay.
class TutorialFlowScreen extends ConsumerStatefulWidget {
  const TutorialFlowScreen({super.key});

  @override
  ConsumerState<TutorialFlowScreen> createState() => _TutorialFlowScreenState();
}

class _TutorialFlowScreenState extends ConsumerState<TutorialFlowScreen> {
  GardenGame? _game;
  bool _showInstructionOverlay = true;
  bool _isLevelCompleteOverlayVisible = false;
  String _currentCongratulationMessage = '';

  // Congratulatory messages (same as GameScreen)
  static const List<String> _congratulationMessages = [
    'Well done, good and faithful servant!',
    'Blessed are you!',
    'Your faith has made you well!',
    'The Lord is with you!',
    'Rejoice in the Lord!',
    'Grace upon grace!',
    'In His strength!',
    'Abundant life!',
    'Fruitful harvest!',
    'Seeds of faith!',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tutorialProgress = ref.watch(tutorialProgressProvider);
    final currentLesson = tutorialProgress.currentLesson;

    // Update game theme colors when theme changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_game != null) {
        final extension = Theme.of(context).extension<AppThemeExtension>()!;
        final gameBackground = AppTheme.getGameBackground(
          Theme.of(context).brightness,
        );
        final gameSurface = AppTheme.getGameSurface(
          Theme.of(context).brightness,
        );
        final gridBackground = AppTheme.getGridBackground(
          Theme.of(context).brightness,
        );

        _game!.updateThemeColors(
          gameBackground,
          gameSurface,
          gridBackground,
          tapEffectColor: extension.tapEffect,
          vineAttemptedColor: extension.vineAttempted,
        );
      }
    });

    // Listen for level completion
    ref.listen<bool>(levelCompleteProvider, (previous, next) {
      debugPrint(
          'TutorialFlowScreen: levelCompleteProvider changed $previous -> $next');
      if (next && (previous == null || !previous)) {
        _showLevelCompleteOverlay();
      }
    });

    // Listen for game completion (all vines cleared)
    ref.listen<bool>(gameCompletedProvider, (previous, next) {
      debugPrint(
          'TutorialFlowScreen: gameCompletedProvider changed $previous -> $next');
      if (next && (previous == null || !previous)) {
        _showLevelCompleteOverlay();
      }
    });

    // If all lessons completed, navigate to main game
    if (tutorialProgress.allLessonsCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint(
              'TutorialFlowScreen: All lessons completed - returning to home');
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Validate lesson number
    if (currentLesson < 1 || currentLesson > 5) {
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
              _game = GardenGame.fromLesson(lesson, ref: ref);
              // Show instruction overlay for new lesson
              _showInstructionOverlay = true;
            }

            return Scaffold(
              backgroundColor: colorScheme.surface,
              body: Stack(
                children: [
                  // Game widget
                  GameWidget<GardenGame>(
                    game: _game!,
                    loadingBuilder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  ),

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

                  // Tutorial instruction overlay
                  if (_showInstructionOverlay)
                    TutorialOverlay(
                      instruction: lesson.objective,
                      onDismiss: () {
                        if (mounted) {
                          setState(() => _showInstructionOverlay = false);
                        }
                      },
                    ),

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

  Widget _buildLessonProgressIndicator(int currentLesson) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
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
          Navigator.of(context).pop(); // Close dialog
          _restartLesson();
        },
        onHome: () {
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }

  void _restartLesson() {
    ref.read(levelCompleteProvider.notifier).setComplete(false);
    ref.read(gameCompletedProvider.notifier).setCompleted(false);
    ref.read(gameInstanceProvider.notifier).resetGrace();
    _game?.reloadLevel();
    setState(() {
      _showInstructionOverlay = true;
      _isLevelCompleteOverlayVisible = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lesson restarted')),
    );
  }

  void _showLevelCompleteOverlay() async {
    // Select a random congratulatory message
    final randomIndex =
        DateTime.now().millisecondsSinceEpoch % _congratulationMessages.length;
    _currentCongratulationMessage = _congratulationMessages[randomIndex];

    setState(() {
      _isLevelCompleteOverlayVisible = true;
    });

    // Wait for 2 seconds then advance to next lesson
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isLevelCompleteOverlayVisible = false;
    });

    // Get current lesson before advancing
    final beforeLesson = ref.read(tutorialProgressProvider).currentLesson;

    // Advance to next lesson
    await ref
        .read(tutorialProgressProvider.notifier)
        .completeLesson(beforeLesson);

    // Reset completion flags
    ref.read(levelCompleteProvider.notifier).setComplete(false);
    ref.read(gameCompletedProvider.notifier).setCompleted(false);

    // Check if we advanced to a new lesson
    final after = ref.read(tutorialProgressProvider);

    if (!after.allLessonsCompleted && after.currentLesson != beforeLesson) {
      // Reset for new lesson
      setState(() {
        _game = null; // Will be recreated in build
        _showInstructionOverlay = true;
      });
    }
  }

  Widget _buildLevelCompleteOverlay() {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentCongratulationMessage,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Theme.of(context)
                            .colorScheme
                            .shadow
                            .withValues(alpha: 0.6),
                        offset: const Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Icon(
                  Icons.celebration,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 72,
                  shadows: [
                    Shadow(
                      blurRadius: 8.0,
                      color: Theme.of(context)
                          .colorScheme
                          .shadow
                          .withValues(alpha: 0.4),
                      offset: const Offset(1.5, 1.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
