import 'package:confetti/confetti.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/app_theme.dart';
import '../../../../providers/game_providers.dart';
import '../../../domain/usecases/complete_level_usecase.dart';
import '../widgets/garden_game.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late ConfettiController _confettiController;
  GardenGame? _game;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Watch for level completion and show dialog
    ref.listen(levelCompleteProvider, (previous, next) {
      debugPrint(
        '_GameScreen: levelCompleteProvider changed from $previous to $next',
      );
      if (next && (previous == null || !previous)) {
        debugPrint('_GameScreen: Showing level complete dialog');
        _confettiController.play();
        _showLevelCompleteDialog();
      }
    });

    // Watch for total game completion
    ref.listen(gameCompletedProvider, (previous, next) {
      if (next && (previous == null || !previous)) {
        debugPrint('_GameScreen: Showing game completed dialog');
        _showGameCompletedDialog();
      }
    });

    // Watch for Game Over
    ref.listen(gameOverProvider, (previous, next) {
      if (next && (previous == null || !previous)) {
        debugPrint('_GameScreen: Showing game over dialog');
        _showGameOverDialog();
      }
    });

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Parable Bloom'),
            const SizedBox(width: 16),
            _buildLivesDisplay(),
            const SizedBox(width: 16),
            _buildCurrentLevelDisplay(),
          ],
        ),
        backgroundColor: colorScheme.surfaceContainerHighest,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb),
            onPressed: () => debugPrint('Hint button pressed - placeholder'),
            tooltip: 'Hint (placeholder)',
          ),
          IconButton(
            icon: const Icon(Icons.replay),
            onPressed: _restartLevel,
            tooltip: 'Restart Level',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetProgress,
            tooltip: 'Debug: Reset Progress',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Stack(
        children: [
          GameWidget<GardenGame>(
            game: _game ??= GardenGame(ref: ref),
            loadingBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
          ),
          _buildConfetti(),
        ],
      ),
    );
  }

  Widget _buildLivesDisplay() {
    final lives = ref.watch(livesProvider);
    return Row(
      children: List.generate(3, (index) {
        return Icon(
          index < lives ? Icons.favorite : Icons.favorite_border,
          color: Colors.redAccent,
          size: 20,
        );
      }),
    );
  }

  Widget _buildCurrentLevelDisplay() {
    final currentLevel = ref.watch(currentLevelProvider);
    if (currentLevel == null) return const SizedBox.shrink();

    return Text(
      'Level ${currentLevel.levelNumber}: ${currentLevel.title}',
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildConfetti() {
    return Stack(
      children: [
        Positioned(
          bottom: 0,
          left: 0,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: -3.14159 / 3,
            emissionFrequency: 0.03,
            numberOfParticles: 25,
            maxBlastForce: 50,
            minBlastForce: 35,
            gravity: 0.2,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: -2 * 3.14159 / 3,
            emissionFrequency: 0.03,
            numberOfParticles: 25,
            maxBlastForce: 50,
            minBlastForce: 35,
            gravity: 0.2,
          ),
        ),
      ],
    );
  }

  void _restartLevel() {
    ref.read(levelCompleteProvider.notifier).state = false;
    ref.read(gameOverProvider.notifier).state = false;
    ref.read(gameInstanceProvider.notifier).resetLives();
    _game?.reloadLevel();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Level restarted')));
  }

  void _resetProgress() {
    ref.read(gameProgressProvider.notifier).resetProgress();
    ref.read(currentLevelProvider.notifier).state = null;
    ref.read(levelCompleteProvider.notifier).state = false;
    ref.read(gameCompletedProvider.notifier).state = false;
    _game?.reloadLevel();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progress reset and level reloaded')),
    );
  }

  void _showLevelCompleteDialog() {
    final currentLevel = ref.read(currentLevelProvider);
    if (currentLevel == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'LEVEL COMPLETE!',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentLevel.title,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '"${currentLevel.parable['content']}"',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '- ${currentLevel.parable['scripture']}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  await GetIt.I<CompleteLevelUseCase>().execute(
                    currentLevel.levelNumber,
                  );
                  ref.read(levelCompleteProvider.notifier).state = false;
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  await _game?.reloadLevel();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'NEXT LEVEL',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGameCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'CONGRATULATIONS!',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
              const SizedBox(height: 16),
              Text(
                'You have completed the game!',
                style: TextStyle(color: cs.onSurface, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Stay tuned for updates that are released regularly.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  ref.read(gameCompletedProvider.notifier).state = false;
                  GetIt.I<CompleteLevelUseCase>().execute(1).then((_) {
                    ref.read(gameProgressProvider.notifier).resetProgress();
                    ref.read(currentLevelProvider.notifier).state = null;
                    _game?.reloadLevel();
                    if (dialogContext.mounted)
                      Navigator.of(dialogContext).pop();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('PLAY AGAIN'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'GAME OVER',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, color: cs.onSurfaceVariant, size: 64),
              const SizedBox(height: 16),
              Text(
                'You ran out of lives!',
                style: TextStyle(color: cs.onSurface, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  ref.read(gameInstanceProvider.notifier).resetLives();
                  _game?.reloadLevel();
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('RETRY LEVEL'),
              ),
            ),
          ],
        );
      },
    );
  }
}
