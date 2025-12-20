import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/app_theme.dart';
import 'game/garden_game.dart';
import 'providers/game_providers.dart';
import 'screens/settings_screen.dart';

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
      child: const ParableBloomApp(),
    ),
  );
}

class ParableBloomApp extends StatelessWidget {
  const ParableBloomApp({super.key});

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

        return _buildGameWidget(game, ref);
      },
    );
  }

  Widget _buildGameWidget(GardenGame game, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp(
      title: 'Parable Bloom',
      debugShowCheckedModeBanner: false,
      themeMode: _convertThemeMode(themeMode),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: _GameScreen(game: game),
    );
  }

  ThemeMode _convertThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light: return ThemeMode.light;
      case AppThemeMode.dark: return ThemeMode.dark;
      case AppThemeMode.system: return ThemeMode.system;
    }
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
    // Update game theme colors when theme changes
    final brightness = Theme.of(context).brightness;
    widget.game.updateThemeColors(
      AppTheme.getGameBackground(brightness),
      AppTheme.getGameSurface(brightness),
      AppTheme.getGridBackground(brightness),
    );
    
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

    final colorScheme = Theme.of(context).colorScheme;
    
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
          // Restart level button
          IconButton(
            icon: const Icon(Icons.replay),
            onPressed: () {
              // Reset level state without resetting progress
              ref.read(levelCompleteProvider.notifier).state = false;
              ref.read(gameOverProvider.notifier).state = false;
              ref.read(gameInstanceProvider.notifier).resetLives();

              // Reload the level in the game instance
              final gameInstance = ref.read(gameInstanceProvider);
              gameInstance?.reloadLevel();

              debugPrint('Level restarted');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Level restarted')),
              );
            },
            tooltip: 'Restart Level',
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
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
      builder: (BuildContext dialogContext) {
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
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 18,
                ),
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
                style: TextStyle(
                  color: cs.onSurfaceVariant,
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
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }

                  debugPrint('Advanced to next level after completing ${currentLevel.title}');
                  
                  // Reload the level in the game instance
                  await widget.game.reloadLevel();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
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
      builder: (BuildContext dialogContext) {
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
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Stay tuned for updates that are released regularly.',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
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
                  ref.read(gameCompletedProvider.notifier).state = false;
                  ref.read(gameProgressProvider.notifier).resetProgress();
                  ref.read(currentLevelProvider.notifier).state = null;
                  widget.game.reloadLevel();
                  Navigator.of(dialogContext).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
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
      builder: (BuildContext dialogContext) {
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
                style: TextStyle(
                  color: cs.onSurface,
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
                  ref.read(gameInstanceProvider.notifier).resetLives();
                  widget.game.reloadLevel();
                  Navigator.of(dialogContext).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
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

  Widget _buildCurrentLevelDisplay() {
    final currentLevel = ref.watch(currentLevelProvider);
    if (currentLevel == null) return const SizedBox.shrink();

    return Text(
      'Level ${currentLevel.levelNumber}: ${currentLevel.title}',
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }


}
