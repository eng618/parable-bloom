import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';

import '../../../../providers/game_providers.dart';
import '../../../../providers/tutorial_providers.dart';
import '../../../game/presentation/widgets/garden_game.dart';
import '../widgets/lesson_preview_dialog.dart';
import '../widgets/lesson_completion_dialog.dart';

/// Wraps the game screen during lesson progression
/// Shows lesson preview before each lesson and handles auto-advancement
class TutorialFlowScreen extends ConsumerStatefulWidget {
  const TutorialFlowScreen({super.key});

  @override
  ConsumerState<TutorialFlowScreen> createState() => _TutorialFlowScreenState();
}

class _TutorialFlowScreenState extends ConsumerState<TutorialFlowScreen> {
  bool _showPreviewDialog = true;
  bool _showCompletionDialog = false;

  @override
  Widget build(BuildContext context) {
    final tutorialProgress = ref.watch(tutorialProgressProvider);
    final currentLesson = tutorialProgress.currentLesson;

    // Listen to level/game completion providers here (must be called from build)
    ref.listen<bool>(gameCompletedProvider, (previous, next) {
      debugPrint(
          'TutorialFlowScreen: gameCompletedProvider changed $previous -> $next');
      if (next && !_showCompletionDialog) {
        setState(() {
          _showPreviewDialog = false;
          _showCompletionDialog = true;
        });
      }
    });

    ref.listen<bool>(levelCompleteProvider, (previous, next) {
      debugPrint(
          'TutorialFlowScreen: levelCompleteProvider changed $previous -> $next');
      if (next && !_showCompletionDialog) {
        setState(() {
          _showPreviewDialog = false;
          _showCompletionDialog = true;
        });
      }
    });

    // If all lessons completed, navigate to main game
    if (tutorialProgress.allLessonsCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint(
              'TutorialFlowScreen: All lessons completed - navigating to home (/)');
          // Navigate to the app root (home). The app uses `home:` in MaterialApp, so the root route
          // is '/'. Using '/home' previously failed because no such named route exists.
          Navigator.of(context).pushReplacementNamed('/');
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show the current lesson
    if (currentLesson < 1 || currentLesson > 5) {
      return Scaffold(
        body: Center(
          child: Text('Invalid lesson: $currentLesson'),
        ),
      );
    }

    return ref.watch(lessonProvider(currentLesson)).when(
          data: (lesson) {
            return Stack(
              children: [
                // Game screen with lesson data
                Scaffold(
                  body: GameWidget(
                    game: GardenGame.fromLesson(lesson, ref: ref),
                  ),
                ),

                // Preview dialog before lesson starts
                if (_showPreviewDialog)
                  Dialog(
                    backgroundColor: Colors.transparent,
                    child: LessonPreviewDialog(
                      lesson: lesson,
                      onBegin: () {
                        setState(() => _showPreviewDialog = false);
                      },
                    ),
                  ),

                // Completion dialog after lesson completes
                if (_showCompletionDialog)
                  Dialog(
                    backgroundColor: Colors.transparent,
                    child: LessonCompletionDialog(
                      lesson: lesson,
                      onContinue: () async {
                        final beforeLesson =
                            ref.read(tutorialProgressProvider).currentLesson;

                        await ref
                            .read(tutorialProgressProvider.notifier)
                            .completeLesson(currentLesson);

                        // Prevent reopening the completion dialog immediately by clearing the
                        // `levelCompleteProvider` flag. The new lesson will reset this flag
                        // again when it's converted/loaded, but clearing it here avoids
                        // a race where the preview would re-open the completion dialog.
                        ref
                            .read(levelCompleteProvider.notifier)
                            .setComplete(false);
                        ref
                            .read(gameCompletedProvider.notifier)
                            .setCompleted(false);

                        // Check tutorial progress to ensure the lesson actually advanced
                        final after = ref.read(tutorialProgressProvider);
                        final advanced = after.currentLesson != beforeLesson;

                        if (mounted) {
                          setState(() => _showCompletionDialog = false);
                          // Only show the preview if we advanced to a new lesson and there are more lessons
                          if (!after.allLessonsCompleted && advanced) {
                            setState(() => _showPreviewDialog = true);
                          }
                        }
                      },
                    ),
                  ),
              ],
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
}
