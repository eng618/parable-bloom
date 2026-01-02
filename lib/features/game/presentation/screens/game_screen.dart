import 'package:confetti/confetti.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_theme.dart';
import '../../../../providers/game_providers.dart';
import '../widgets/garden_game.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late ConfettiController _leftConfettiController;
  late ConfettiController _rightConfettiController;
  GardenGame? _game;
  late bool _isLevelCompleteOverlayVisible;
  late String _currentCongratulationMessage;

  // List of congratulatory messages
  static const List<String> _congratulationMessages = [
    'Awesome!',
    'Great Job!',
    'Excellent!',
    'Well Done!',
    'Fantastic!',
    'Outstanding!',
    'Brilliant!',
    'Perfect!',
    'Superb!',
    'Amazing!',
  ];

  @override
  void initState() {
    super.initState();
    _isLevelCompleteOverlayVisible = false;
    _currentCongratulationMessage = '';
    _leftConfettiController = ConfettiController(
      duration: const Duration(milliseconds: 500),
    );
    _rightConfettiController = ConfettiController(
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _leftConfettiController.dispose();
    _rightConfettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Update game theme colors when theme changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_game != null) {
        final gameBackground = AppTheme.getGameBackground(
          Theme.of(context).brightness,
        );
        final gameSurface = AppTheme.getGameSurface(
          Theme.of(context).brightness,
        );
        final gridBackground = AppTheme.getGridBackground(
          Theme.of(context).brightness,
        );

        _game!.updateThemeColors(gameBackground, gameSurface, gridBackground);
      }
    });

    // Watch for level completion and show overlay
    ref.listen(levelCompleteProvider, (previous, next) {
      debugPrint(
        '_GameScreen: levelCompleteProvider changed from $previous to $next',
      );
      if (next && (previous == null || !previous)) {
        debugPrint('_GameScreen: Showing level complete overlay');
        debugPrint('_GameScreen: Starting both confetti cannons');
        debugPrint(
          '_GameScreen: Left controller state before play: ${_leftConfettiController.state}',
        );
        debugPrint(
          '_GameScreen: Right controller state before play: ${_rightConfettiController.state}',
        );
        // Confetti playback moved to _showLevelCompleteOverlay to ensure widget is built
        debugPrint(
          '_GameScreen: Left controller state after play: ${_leftConfettiController.state}',
        );
        debugPrint(
          '_GameScreen: Right controller state after play: ${_rightConfettiController.state}',
        );
        _showLevelCompleteOverlay();
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
            _buildGraceDisplay(),
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
      floatingActionButton: _buildProjectionLinesFAB(),
      body: Stack(
        children: [
          GameWidget<GardenGame>(
            game: _game ??= GardenGame(ref: ref),
            loadingBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
          ),
          if (_isLevelCompleteOverlayVisible) _buildLevelCompleteOverlay(),
        ],
      ),
    );
  }

  Widget _buildProjectionLinesFAB() {
    return FloatingActionButton(
      onPressed: () {
        ref.read(projectionLinesVisibleProvider.notifier).toggle();
      },
      tooltip: 'Toggle projection lines',
      child: const Icon(Icons.tag),
    );
  }

  Widget _buildGraceDisplay() {
    final grace = ref.watch(graceProvider);
    return Row(
      children: List.generate(3, (index) {
        return Icon(
          index < grace ? Icons.favorite : Icons.favorite_border,
          color: Colors.redAccent,
          size: 20,
        );
      }),
    );
  }

  Widget _buildCurrentLevelDisplay() {
    final globalProgress = ref.watch(globalProgressProvider);
    final currentLevel = ref.watch(currentLevelProvider);

    debugPrint('GameScreen: Global progress: $globalProgress');
    debugPrint('GameScreen: Current level: ${currentLevel?.name ?? "null"}');

    if (currentLevel == null) return const SizedBox.shrink();

    return Text(
      'Level ${currentLevel.id}: ${currentLevel.name}',
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildConfetti() {
    // Ensure controllers are properly initialized
    return Stack(
      children: [
        // Left cannon - positioned at bottom-left corner
        Positioned(
          bottom: 20,
          left: 20,
          child: ConfettiWidget(
            confettiController: _leftConfettiController,
            blastDirection: -3.14159 / 3, // -60 degrees (up and left)
            emissionFrequency: 0.5, // High frequency for immediate burst
            numberOfParticles: 50, // Increased for denser blast
            maxBlastForce: 80, // Increased from 50 for longer/faster distance
            minBlastForce: 55, // Increased from 35 for more power
            gravity: 0.4, // Increased from 0.2 for faster falling
            shouldLoop: false,
            colors: const [
              Colors.red,
              Colors.blue,
              Colors.green,
              Colors.yellow,
              Colors.purple,
              Colors.orange,
            ],
          ),
        ),
        // Right cannon - positioned at bottom-right corner
        Positioned(
          bottom: 20,
          right: 20,
          child: ConfettiWidget(
            confettiController: _rightConfettiController,
            blastDirection: -2 * 3.14159 / 3, // -120 degrees (up and right)
            emissionFrequency: 0.5, // High frequency for immediate burst
            numberOfParticles: 50, // Increased for denser blast
            maxBlastForce: 80, // Increased from 50 for longer/faster distance
            minBlastForce: 55, // Increased from 35 for more power
            gravity: 0.4, // Increased from 0.2 for faster falling
            shouldLoop: false,
            colors: const [
              Colors.red,
              Colors.blue,
              Colors.green,
              Colors.yellow,
              Colors.purple,
              Colors.orange,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLevelCompleteOverlay() {
    return Stack(
      children: [
        // Confetti (no background overlay - completely transparent)
        _buildConfetti(),
        // Content
        Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentCongratulationMessage,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black.withValues(alpha: 1.0),
                        offset: const Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Icon(Icons.celebration, color: Colors.yellow, size: 80),
              ],
            ),
          ),
        ),
      ],
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

    // Play confetti after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _leftConfettiController.play();
      _rightConfettiController.play();
    });

    // Advance to next level
    final currentLevel = ref.read(currentLevelProvider);
    ModuleData? completedModule;
    if (currentLevel != null) {
      final modules = await ref.read(modulesProvider.future);
      for (final m in modules) {
        if (m.endLevel == currentLevel.id) {
          completedModule = m;
          break;
        }
      }

      await ref
          .read(globalProgressProvider.notifier)
          .completeLevel(currentLevel.id);
    }
    ref.read(levelCompleteProvider.notifier).setComplete(false);

    // Reset grace for the next level
    ref.read(gameInstanceProvider.notifier).resetGrace();

    // Wait for 2 seconds then navigate back to home OR show parable unlock.
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isLevelCompleteOverlayVisible = false;
    });

    if (completedModule != null) {
      await _showParableUnlockedDialog(completedModule);
      return;
    }

    // Navigate back to home screen and clear game screen from stack
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _showParableUnlockedDialog(ModuleData module) async {
    if (!mounted) return;

    final parable = module.parable;
    final title = (parable['title'] as String?)?.trim();
    final scripture = (parable['scripture'] as String?)?.trim();
    final content = (parable['content'] as String?)?.trim();
    final reflection = (parable['reflection'] as String?)?.trim();

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
          title: Text(
            title?.isNotEmpty == true ? title! : 'Parable Unlocked',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book, size: 48),
                const SizedBox(height: 12),
                if (module.unlockMessage.trim().isNotEmpty)
                  Text(
                    module.unlockMessage,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                if (scripture?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    scripture!,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (content?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    content!,
                    style: TextStyle(color: cs.onSurface, fontSize: 14),
                    textAlign: TextAlign.left,
                  ),
                ],
                if (reflection?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    reflection!,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    textAlign: TextAlign.left,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/journal', (route) => false);
              },
              child: const Text('GO TO JOURNAL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: const Text('CONTINUE'),
            ),
          ],
        );
      },
    );
  }

  void _restartLevel() {
    ref.read(levelCompleteProvider.notifier).setComplete(false);
    ref.read(gameOverProvider.notifier).setGameOver(false);
    ref.read(gameInstanceProvider.notifier).resetGrace();
    _game?.reloadLevel();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Level restarted')));
  }

  void _resetProgress() {
    debugPrint('_resetProgress: Starting progress reset');
    ref.read(gameProgressProvider.notifier).resetProgress();
    ref.read(globalProgressProvider.notifier).resetProgress();
    // Invalidate the progress provider to force refresh
    ref.invalidate(gameProgressProvider);
    ref.invalidate(globalProgressProvider);
    ref.read(currentLevelProvider.notifier).setLevel(null);
    ref.read(levelCompleteProvider.notifier).setComplete(false);
    ref.read(gameCompletedProvider.notifier).setCompleted(false);
    _game?.reloadLevel();
    debugPrint('_resetProgress: Progress reset completed');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progress reset and level reloaded')),
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
                  debugPrint('_showGameCompletedDialog: Resetting for replay');
                  ref.read(gameCompletedProvider.notifier).setCompleted(false);
                  ref.read(gameProgressProvider.notifier).resetProgress();
                  ref.read(globalProgressProvider.notifier).resetProgress();
                  ref.invalidate(gameProgressProvider);
                  ref.invalidate(globalProgressProvider);
                  ref.read(currentLevelProvider.notifier).setLevel(null);
                  _game?.reloadLevel();
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
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
    // Log game over analytics
    final currentLevel = ref.read(currentLevelProvider);
    if (currentLevel != null) {
      ref.read(analyticsServiceProvider).logGameOver(currentLevel.id);
    }

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
            'OUT OF GRACE',
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
              Icon(Icons.healing, color: cs.onSurfaceVariant, size: 64),
              const SizedBox(height: 16),
              Text(
                'God\'s grace is endless—try again!',
                style: TextStyle(color: cs.onSurface, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Take a moment to reflect and try again.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Reset grace and retry the current level
                  ref.read(gameInstanceProvider.notifier).resetGrace();
                  ref.read(gameOverProvider.notifier).setGameOver(false);
                  _game?.reloadLevel();
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
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
                  'TRY AGAIN',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
