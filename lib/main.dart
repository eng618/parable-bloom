import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'game/garden_game.dart';
import 'providers/game_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive (local storage)
  await Hive.initFlutter();
  final box = await Hive.openBox('garden_save'); // We'll use this for progress

  runApp(
    ProviderScope(
      overrides: [
        hiveBoxProvider.overrideWithValue(box),
      ],
      child: const ParableWeaveApp(),
    ),
  );
}

class ParableWeaveApp extends StatelessWidget {
  const ParableWeaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        // Create game instance only once and store in provider
        final gameInstance = ref.watch(gameInstanceProvider);
        final game = gameInstance ?? GardenGame(ref: ref);

        // Store the game instance in the provider after build is complete
        if (gameInstance == null) {
          Future.microtask(() {
            ref.read(gameInstanceProvider.notifier).setGame(game);
          });
        }

        return _buildGameWidget(game);
      },
    );
  }

  Widget _buildGameWidget(GardenGame game) {
    return MaterialApp(
      title: 'ParableWeave',
      debugShowCheckedModeBanner: false,
      home: _GameScreen(game: game),
    );
  }
}

class _GameScreen extends ConsumerStatefulWidget {
  final GardenGame game;

  const _GameScreen({required this.game});

  @override
  ConsumerState<_GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<_GameScreen> {
  @override
  Widget build(BuildContext context) {
    // Watch for level completion and show dialog
    ref.listen(levelCompleteProvider, (previous, next) {
      debugPrint('_GameScreen: levelCompleteProvider changed from $previous to $next');
      if (next && (previous == null || !previous)) {
        debugPrint('_GameScreen: Showing level complete dialog');
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
      backgroundColor: const Color(0xFF2D4A3A), // Deep moss green - matches game design
      appBar: AppBar(
        title: Row(
          children: [
            const Text('ParableWeave'),
            const SizedBox(width: 16),
            _buildLivesDisplay(),
          ],
        ),
        backgroundColor: const Color(0xFF1E3528),
        actions: [
          // TODO: Replace with actual UI buttons
          // Placeholder hint button - replace with actual hint system
          IconButton(
            icon: const Icon(Icons.lightbulb),
            onPressed: () {
              // Placeholder hint action
              debugPrint('Hint button pressed - replace with actual hint system');
            },
            tooltip: 'Hint (placeholder)',
          ),
          // Debug reset button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Reset progress
              ref.read(gameProgressProvider.notifier).resetProgress();
              // Reset current level
              ref.read(currentLevelProvider.notifier).state = null;
              // Reset level complete state
              ref.read(levelCompleteProvider.notifier).state = false;
              // Reset game completion state
              ref.read(gameCompletedProvider.notifier).state = false;

              // Reload the level in the game instance
              final gameInstance = ref.read(gameInstanceProvider);
              gameInstance?.reloadLevel();

              debugPrint('Debug: Progress reset and level reloaded');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Progress reset and level reloaded')),
              );
            },
            tooltip: 'Debug: Reset Progress',
          ),
          // TODO: Replace with settings menu
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Placeholder settings action
              debugPrint('Settings button pressed - replace with actual settings');
            },
            tooltip: 'Settings (placeholder)',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Always show the game
          GameWidget<GardenGame>(
            game: widget.game,
            loadingBuilder: (_) => const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _showLevelCompleteDialog() {
    final currentLevel = ref.read(currentLevelProvider);
    if (currentLevel == null) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E3528),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'LEVEL COMPLETE!',
            style: TextStyle(
              color: Colors.white,
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
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '"${currentLevel.parable['content']}"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '- ${currentLevel.parable['scripture']}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  // Mark level as completed and advance to next level
                  await ref.read(gameProgressProvider.notifier).completeLevel(currentLevel.levelNumber);

                  // Reset level complete state
                  ref.read(levelCompleteProvider.notifier).state = false;

                  // Close dialog
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }

                  debugPrint('Advanced to next level after completing ${currentLevel.title}');
                  
                  // Reload the level in the game instance
                  await widget.game.reloadLevel();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A7C59),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'NEXT LEVEL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E3528),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'CONGRATULATIONS!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 64),
              SizedBox(height: 16),
              Text(
                'You have completed the game!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Stay tuned for updates that are released regularly.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Reset game completion state
                  ref.read(gameCompletedProvider.notifier).state = false;
                  // Reset progress to level 1 for now (or just leave it)
                  ref.read(gameProgressProvider.notifier).resetProgress();
                  ref.read(currentLevelProvider.notifier).state = null;
                  widget.game.reloadLevel();
                  
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A7C59),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E3528),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'GAME OVER',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, color: Colors.grey, size: 64),
              SizedBox(height: 16),
              Text(
                'You ran out of lives!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Reset lives and reload level
                  ref.read(gameInstanceProvider.notifier).resetLives();
                  widget.game.reloadLevel();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A7C59),
                  foregroundColor: Colors.white,
                ),
                child: const Text('RETRY LEVEL'),
              ),
            ),
          ],
        );
      },
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


}
