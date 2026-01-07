import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../../../core/app_theme.dart';
import '../../../../providers/game_providers.dart';
import '../widgets/game_header.dart';
import '../widgets/garden_game.dart';
import '../widgets/pause_menu_dialog.dart';
import '../widgets/pond_ripple_effect_component.dart';
import '../widgets/ripple_fireworks_component.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  GardenGame? _game;
  late bool _isLevelCompleteOverlayVisible;
  late String _currentCongratulationMessage;

  // List of congratulatory messages
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
  void initState() {
    super.initState();
    debugPrint('GameScreen: initState called, _game is null: ${_game == null}');
    _isLevelCompleteOverlayVisible = false;
    _currentCongratulationMessage = '';
  }

  @override
  void dispose() {
    debugPrint('GameScreen: dispose called');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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

    // Watch for level completion and show overlay
    ref.listen(levelCompleteProvider, (previous, next) {
      debugPrint(
        '_GameScreen: levelCompleteProvider changed from $previous to $next',
      );
      if (next && (previous == null || !previous)) {
        debugPrint('_GameScreen: Showing level complete overlay');
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
      floatingActionButton: _buildProjectionLinesFAB(),
      body: Stack(
        children: [
          _buildGameWidgetWithGestures(),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: GameHeader(onPause: _showPauseMenu),
            ),
          ),
          if (kIsWeb) _buildZoomControls(),
          if (_isLevelCompleteOverlayVisible) _buildLevelCompleteOverlay(),
        ],
      ),
    );
  }

  Widget _buildGameWidgetWithGestures() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onScaleStart: _handleScaleStart,
          onScaleUpdate: (details) => _handleScaleUpdate(
            details,
            constraints.maxWidth,
            constraints.maxHeight,
          ),
          onScaleEnd: _handleScaleEnd,
          child: GameWidget<GardenGame>(
            game: _game ??= () {
              debugPrint('GameScreen: Creating new GardenGame instance');
              return GardenGame(ref: ref);
            }(),
            loadingBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );
  }

  double _lastScale = 1.0;
  vm.Vector2 _lastFocalPoint = vm.Vector2.zero();
  vm.Vector2 _panStartOffset = vm.Vector2.zero();

  void _handleScaleStart(ScaleStartDetails details) {
    final cameraState = ref.read(cameraStateProvider);
    _lastScale = cameraState.zoom;
    _lastFocalPoint = vm.Vector2(
      details.focalPoint.dx,
      details.focalPoint.dy,
    );
    _panStartOffset = cameraState.panOffset;
  }

  void _handleScaleUpdate(
    ScaleUpdateDetails details,
    double screenWidth,
    double screenHeight,
  ) {
    final currentLevel = ref.read(currentLevelProvider);
    if (currentLevel == null) return;

    final cameraNotifier = ref.read(cameraStateProvider.notifier);

    // Handle zoom (pinch)
    if (details.scale != 1.0) {
      final newZoom = _lastScale * details.scale;
      cameraNotifier.updateZoom(newZoom);
    }

    // Handle pan (drag) - only when not zooming significantly
    if ((details.scale - 1.0).abs() < 0.1) {
      final focalDelta = vm.Vector2(
        details.focalPoint.dx - _lastFocalPoint.x,
        details.focalPoint.dy - _lastFocalPoint.y,
      );

      final newOffset = _panStartOffset + focalDelta;

      cameraNotifier.updatePanOffset(
        newOffset,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        gridCols: currentLevel.gridWidth,
        gridRows: currentLevel.gridHeight,
        cellSize: GardenGame.cellSize,
      );
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    // Scale gesture ended - store final state
    _lastScale = ref.read(cameraStateProvider).zoom;
    _panStartOffset = ref.read(cameraStateProvider).panOffset;
  }

  void _showPauseMenu() {
    showDialog(
      context: context,
      builder: (context) => PauseMenuDialog(
        onRestart: () {
          Navigator.of(context).pop(); // Close dialog
          _restartLevel();
        },
        onHome: () {
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        },
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

  Widget _buildZoomControls() {
    final currentLevel = ref.watch(currentLevelProvider);
    if (currentLevel == null) return const SizedBox.shrink();

    final cameraState = ref.watch(cameraStateProvider);

    return Positioned(
      right: 16,
      bottom: 80, // Position above FAB
      child: Card(
        elevation: 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Zoom In',
              splashColor: Colors.transparent,
              onPressed: cameraState.zoom >= cameraState.maxZoom
                  ? null
                  : () {
                      final newZoom = (cameraState.zoom + 0.2).clamp(
                        cameraState.minZoom,
                        cameraState.maxZoom,
                      );
                      ref
                          .read(cameraStateProvider.notifier)
                          .updateZoom(newZoom);
                    },
            ),
            const Divider(height: 1),
            IconButton(
              icon: const Icon(Icons.remove),
              tooltip: 'Zoom Out',
              splashColor: Colors.transparent,
              onPressed: cameraState.zoom <= cameraState.minZoom
                  ? null
                  : () {
                      final newZoom = (cameraState.zoom - 0.2).clamp(
                        cameraState.minZoom,
                        cameraState.maxZoom,
                      );
                      ref
                          .read(cameraStateProvider.notifier)
                          .updateZoom(newZoom);
                    },
            ),
            const Divider(height: 1),
            IconButton(
              icon: const Icon(Icons.center_focus_strong),
              tooltip: 'Reset Zoom',
              splashColor: Colors.transparent,
              onPressed: () {
                ref.read(cameraStateProvider.notifier).resetToCenter(
                      screenWidth: MediaQuery.of(context).size.width,
                      screenHeight: MediaQuery.of(context).size.height,
                      gridCols: currentLevel.gridWidth,
                      gridRows: currentLevel.gridHeight,
                      cellSize: GardenGame.cellSize,
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Confetti implementation removed; celebration handled via in-game ripple effect.

  Widget _buildLevelCompleteOverlay() {
    return Stack(
      children: [
        // Content only (no rigid colored box), with subtle text shadow
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
                    // Subtle drop shadow to lift text from the scene
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

  void _showLevelCompleteOverlay() async {
    // Select a random congratulatory message
    final randomIndex =
        DateTime.now().millisecondsSinceEpoch % _congratulationMessages.length;
    _currentCongratulationMessage = _congratulationMessages[randomIndex];

    setState(() {
      _isLevelCompleteOverlayVisible = true;
    });

    // Add subtle pond ripple effect to the game scene
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_game != null) {
        final cs = Theme.of(context).colorScheme;
        final center = Vector2(_game!.size.x / 2, _game!.size.y / 2);
        final effect = ref.read(celebrationEffectProvider);
        switch (effect) {
          case CelebrationEffect.pondRipples:
            _game!.add(
              PondRippleEffectComponent(
                center: center,
                maxRadius: (_game!.size.y * 0.45),
                ringCount: 4,
                duration: 2.0,
                colors: [cs.primary, cs.secondary],
              ),
            );
            break;
          case CelebrationEffect.rippleFireworks:
            _game!.add(
              RippleFireworksComponent(
                count: 8,
                duration: 2.0,
                minRippleRadius: 30,
                maxRippleRadius: 64,
                colors: [cs.primary, cs.secondary],
                paddingRatio: 0.12,
              ),
            );
            break;
          case CelebrationEffect.leafPetals:
            // Future: add leaf petals effect
            break;
          case CelebrationEffect.confetti:
            // Deprecated: previously used external package
            break;
        }
      }
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

      final isDebugPlay = ref.read(debugPlayModeProvider);
      if (!isDebugPlay) {
        await ref
            .read(gameProgressProvider.notifier)
            .completeLevel(currentLevel.id);
      } else {
        debugPrint(
            'GameScreen: Debug play — skipping persistence for level ${currentLevel.id}');
      }
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
      // Clear debug selection if active
      if (ref.read(debugPlayModeProvider)) {
        ref.read(debugSelectedLevelProvider.notifier).setLevel(null);
      }
      await _showParableUnlockedDialog(completedModule);
      return;
    }

    // Clear debug selection if active before navigating home
    if (ref.read(debugPlayModeProvider)) {
      ref.read(debugSelectedLevelProvider.notifier).setLevel(null);
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
                Navigator.of(context).pop(); // pop game screen to home
                Navigator.of(context).pushNamed('/journal');
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
              Icon(Icons.emoji_events, color: cs.onSurface, size: 64),
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
                  debugPrint('_showGameCompletedDialog: Returning to home');
                  ref.read(gameCompletedProvider.notifier).setCompleted(false);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (route) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('BACK TO HOME'),
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
