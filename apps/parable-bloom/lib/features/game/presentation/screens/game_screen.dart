import 'package:go_router/go_router.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../../../core/app_theme.dart';
import '../../../../features/game/domain/entities/level_data.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/settings_providers.dart';
import '../../application/providers/camera_providers.dart';
import '../../application/providers/counter_providers.dart';
import '../../application/providers/gameplay_state_providers.dart';
import '../../application/providers/module_providers.dart';
import '../../application/providers/progress_providers.dart';
import '../widgets/game_header.dart';
import '../widgets/garden_game.dart';
import '../widgets/pause_menu_dialog.dart';
import '../widgets/pond_ripple_effect_component.dart';
import '../widgets/ripple_fireworks_component.dart';
import '../../../../core/services/logger_service.dart';

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
    'Blessed are you in Christ!',
    'Your faith is bearing fruit!',
    'The Lord is with you always!',
    'Rejoice in the Lord!',
    'Grace upon grace!',
    'In His strength alone!',
    'Abundant life in Christ!',
    'A fruitful harvest awaits!',
    'Seeds of faith growing deep!',
    'Abide in His love!',
    'He makes your path straight!',
    'The joy of the Lord is your strength!',
    'Walk by faith, not by sight!',
    'Rooted and built up in Him!',
  ];

  @override
  void initState() {
    super.initState();
    LoggerService.debug('GameScreen init',
        tag: 'GameScreen', metadata: {'game_is_null': _game == null});
    _isLevelCompleteOverlayVisible = false;
    _currentCongratulationMessage = '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logScreenView('Gameplay');
    });
  }

  @override
  void dispose() {
    LoggerService.debug('GameScreen dispose', tag: 'GameScreen');
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
      LoggerService.debug('levelCompleteProvider changed',
          tag: 'GameScreen',
          metadata: {
            'previous': previous,
            'next': next,
          });
      if (next && (previous == null || !previous)) {
        LoggerService.info('Showing level complete overlay', tag: 'GameScreen');
        _showLevelCompleteOverlay();
      }
    });

    // Watch for total game completion
    ref.listen(gameCompletedProvider, (previous, next) {
      if (next && (previous == null || !previous)) {
        LoggerService.info('Showing game completed dialog', tag: 'GameScreen');
        _showGameCompletedDialog();
      }
    });

    // Watch for Game Over
    ref.listen(gameOverProvider, (previous, next) {
      if (next && (previous == null || !previous)) {
        LoggerService.info('Showing game over dialog', tag: 'GameScreen');
        _showGameOverDialog();
      }
    });

    // Sync state with Flame GardenGame instance
    ref.listen(cameraStateProvider, (previous, next) {
      _game?.applyCameraTransform(next);
    });

    ref.listen(vineStatesProvider, (previous, next) {
      _game?.updateVineStates(next);
    });

    ref.listen(vineStyleProvider, (previous, next) {
      _game?.updateSimpleVines(next == VineStyle.simple);
    });

    ref.listen(projectionLinesVisibleProvider, (previous, next) {
      _updateProjectionLinesVisibility();
    });

    ref.listen(anyVineAnimatingProvider, (previous, next) {
      _updateProjectionLinesVisibility();
    });

    ref.listen(hintedVineIdsProvider, (previous, next) {
      _updateProjectionLinesVisibility();
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
        return Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              final cameraNotifier = ref.read(cameraStateProvider.notifier);
              final cameraState = ref.read(cameraStateProvider);
              final currentLevel = ref.read(currentLevelProvider);
              if (currentLevel == null) return;

              final newOffset = cameraState.panOffset -
                  vm.Vector2(
                    pointerSignal.scrollDelta.dx,
                    pointerSignal.scrollDelta.dy,
                  );

              cameraNotifier.updatePanOffset(
                newOffset,
                screenWidth: constraints.maxWidth,
                screenHeight: constraints.maxHeight,
                gridCols: currentLevel.gridWidth,
                gridRows: currentLevel.gridHeight,
              );
            }
          },
          child: GestureDetector(
            onScaleStart: _handleScaleStart,
            onScaleUpdate: (details) => _handleScaleUpdate(
              details,
              constraints.maxWidth,
              constraints.maxHeight,
            ),
            onScaleEnd: _handleScaleEnd,
            child: GameWidget<GardenGame>(
              game: _game ??= () {
                LoggerService.debug('Creating new GardenGame instance',
                    tag: 'GameScreen');
                return GardenGame(
                  callbacks: GardenGameCallbacks(
                    onGameLoaded: (game) {
                      ref.read(gameInstanceProvider.notifier).setGame(game);
                      _loadLevelForGame(game);
                    },
                    onGameRemoved: () {
                      if (ref.read(gameInstanceProvider) == _game) {
                        ref.read(gameInstanceProvider.notifier).setGame(null);
                      }
                    },
                    onVineCleared: (vineId) {
                      ref.read(vineStatesProvider.notifier).clearVine(vineId);
                    },
                    onVineAnimationStateChanged: (vineId, animationState) {
                      ref
                          .read(vineStatesProvider.notifier)
                          .setAnimationState(vineId, animationState);
                    },
                    onVineAttempted: (vineId) {
                      ref
                          .read(vineStatesProvider.notifier)
                          .markAttempted(vineId);
                    },
                    onTapIncrement: (count) {
                      for (int i = 0; i < count; i++) {
                        ref.read(levelTotalTapsProvider.notifier).increment();
                      }
                    },
                    onTapOutsideGrid: () {
                      ref.read(hintedVineIdsProvider.notifier).clear();
                    },
                    getUseSimpleVines: () => ref.read(useSimpleVinesProvider),
                    getHapticsEnabled: () => ref.read(hapticsEnabledProvider),
                  ),
                );
              }(),
              loadingBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
            ),
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
          if (context.canPop()) context.pop(); // Close dialog
          _restartLevel();
        },
        onHome: () {
          if (context.canPop()) context.pop(); // Close dialog
          context.go('/');
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
                ref.read(cameraStateProvider.notifier).resetToCenter();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Confetti implementation removed; celebration handled via in-game ripple effect.

  Widget _buildLevelCompleteOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = isDark ? AppTheme.secondarySeed : AppTheme.primarySeed;

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
                  'Level Complete',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: themeColor,
                        fontWeight: FontWeight.w900,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _currentCongratulationMessage,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: themeColor,
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
                  color: themeColor,
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
    if (_isLevelCompleteOverlayVisible) return;

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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final animationColors =
            isDark ? [AppTheme.secondarySeed] : [AppTheme.primarySeed];
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
                colors: animationColors,
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
                colors: animationColors,
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
    ModuleScripture? newlyUnlockedScripture;

    if (currentLevel != null) {
      List<ModuleData> modules = [];
      try {
        modules = await ref.read(modulesProvider.future);
        for (final m in modules) {
          if (m.endLevel == currentLevel.id) {
            completedModule = m;
            break;
          }
        }
      } catch (error, stackTrace) {
        LoggerService.warn(
          'Skipping module completion lookup due to module load failure',
          tag: 'GameScreen',
          error: error,
          stackTrace: stackTrace,
          metadata: {'level_id': currentLevel.id},
        );
      }

      final prevUnlockedScriptures =
          ref.read(gameProgressProvider).unlockedScriptureIds;

      final isDebugPlay = ref.read(debugPlayModeProvider);
      if (!isDebugPlay) {
        await ref
            .read(gameProgressProvider.notifier)
            .completeLevel(currentLevel.id);
      } else {
        LoggerService.debug('Debug play — skipping persistence',
            tag: 'GameScreen', metadata: {'level_id': currentLevel.id});
      }

      final postProgress = ref.read(gameProgressProvider);
      if (modules.isNotEmpty) {
        for (final m in modules) {
          for (final s in m.scriptures) {
            if (!prevUnlockedScriptures.contains(s.id) &&
                postProgress.unlockedScriptureIds.contains(s.id)) {
              newlyUnlockedScripture = s;
              completedModule = m; // Associate for the dialog
              break;
            }
          }
        }
      }
    }

    // Reset grace for the next level
    ref.read(gameInstanceProvider.notifier).resetGrace();

    // Wait for 2 seconds then navigate back to home OR show parable/scripture unlock.
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Reset completion flag
    ref.read(levelCompleteProvider.notifier).setComplete(false);

    setState(() {
      _isLevelCompleteOverlayVisible = false;
    });

    if (newlyUnlockedScripture != null && completedModule != null) {
      if (ref.read(debugPlayModeProvider)) {
        ref.read(debugSelectedLevelProvider.notifier).setLevel(null);
      }
      await _showScriptureUnlockedDialog(
          newlyUnlockedScripture, completedModule);
      return;
    }

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
    context.go('/');
  }

  Future<void> _showScriptureUnlockedDialog(
    ModuleScripture scripture,
    ModuleData module,
  ) async {
    if (!mounted) return;

    ref.read(analyticsServiceProvider).logParableViewed(scripture.id);

    final progress = ref.read(gameProgressProvider);
    final savedTranslationId = progress.unlockedTranslations[scripture.id];

    String resolvedText = '';
    String displayCitation = scripture.reference;

    try {
      final result = await ref.read(scriptureServiceProvider).loadScripture(
            scripture.reference,
            translationId: savedTranslationId,
          );

      resolvedText = result['text'] ?? '';
      final translationCode = result['translation'] ?? 'KJV';
      displayCitation = '${scripture.reference} ($translationCode)';
    } catch (e, stack) {
      LoggerService.error(
        'Error loading scripture for unlocked dialog',
        error: e,
        stackTrace: stack,
        tag: 'GameScreen',
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
                const SizedBox(height: 8),
                Text(
                  'Added to your Journal under the ${module.name} set.',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 12,
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
                if (context.canPop()) context.pop(); // pop game screen to home
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

  Future<void> _showParableUnlockedDialog(ModuleData module) async {
    if (!mounted) return;

    ref.read(analyticsServiceProvider).logParableViewed(module.id.toString());

    final parable = module.parable;
    final title = (parable['title'] as String?)?.trim();
    final scripture = (parable['scripture'] as String?)?.trim();
    final reflection = (parable['reflection'] as String?)?.trim();

    String resolvedText = (parable['content'] as String?)?.trim() ?? '';
    String displayCitation = scripture ?? '';

    if (scripture != null && scripture.isNotEmpty) {
      try {
        final progress = ref.read(gameProgressProvider);
        final savedTranslationId =
            progress.unlockedTranslations[module.id.toString()];

        final result = await ref.read(scriptureServiceProvider).loadScripture(
              scripture,
              translationId: savedTranslationId,
            );

        resolvedText = result['text'] ?? resolvedText;
        final translationCode = result['translation'] ?? 'KJV';
        displayCitation = '$scripture ($translationCode)';

        if (savedTranslationId == null) {
          await ref.read(gameProgressProvider.notifier).saveUnlockedTranslation(
                module.id.toString(),
                translationCode.toLowerCase(),
              );
        }
      } catch (e, stack) {
        LoggerService.error(
          'Error loading scripture for unlocked parable dialog',
          error: e,
          stackTrace: stack,
          tag: 'GameScreen',
        );
      }
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
                if (displayCitation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    displayCitation,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (resolvedText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    resolvedText,
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
                if (context.canPop()) context.pop(); // pop game screen to home
                context.push('/journal');
              },
              child: const Text('GO TO JOURNAL'),
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

  Future<void> _loadLevelForGame(GardenGame game) async {
    final debugSelected = ref.read(debugSelectedLevelProvider);
    final gameProgress = ref.read(gameProgressProvider);
    final levelId = debugSelected ?? gameProgress.currentLevel;

    try {
      final mappings = await ref.read(levelMappingsProvider.future);
      if (!mappings.containsKey(levelId)) {
        ref.read(gameCompletedProvider.notifier).setCompleted(true);
        return;
      }

      final levelData = await ref.read(levelDataProvider(levelId).future);

      ref.read(currentLevelProvider.notifier).setLevel(levelData);
      ref.read(gameCompletedProvider.notifier).setCompleted(false);

      ref.read(levelTotalTapsProvider.notifier).reset();
      ref.read(levelWrongTapsProvider.notifier).reset();

      final previousLevelId = ref.read(currentLevelProvider)?.id;
      final attemptNotifier = ref.read(levelAttemptCountProvider.notifier);
      if (previousLevelId != levelData.id) {
        attemptNotifier.set(1);
      }

      ref.read(levelStartTimestampProvider.notifier).set(DateTime.now());

      if (!ref.read(debugPlayModeProvider)) {
        ref.read(analyticsServiceProvider).logLevelStart(levelData.id);
      }

      ref.read(vineStatesProvider.notifier).resetForLevel(levelData);

      final vineStates = ref.read(vineStatesProvider);
      game.startLevel(levelData, vineStates);

      final cameraNotifier = ref.read(cameraStateProvider.notifier);
      cameraNotifier.updateZoomBounds(
        screenWidth: game.size.x,
        screenHeight: game.size.y,
        gridCols: levelData.gridWidth,
        gridRows: levelData.gridHeight,
      );
      cameraNotifier.animateToDefaultZoom(
        screenWidth: game.size.x,
        screenHeight: game.size.y,
        gridCols: levelData.gridWidth,
        gridRows: levelData.gridHeight,
      );

      game.applyCameraTransform(ref.read(cameraStateProvider));
    } catch (e, stack) {
      LoggerService.error('Error loading level $levelId on game screen',
          error: e, stackTrace: stack, tag: 'GameScreen');
      ref.read(gameOverProvider.notifier).setGameOver(true);
    }
  }

  void _updateProjectionLinesVisibility() {
    if (_game == null) return;
    final shouldShow = ref.read(projectionLinesVisibleProvider);
    final hintedVines = ref.read(hintedVineIdsProvider);
    final isAnimating = ref.read(anyVineAnimatingProvider);

    if (isAnimating && shouldShow) {
      ref.read(projectionLinesVisibleProvider.notifier).setVisible(false);
    }
    if (isAnimating && hintedVines.isNotEmpty) {
      ref.read(hintedVineIdsProvider.notifier).clear();
    }

    _game!.updateProjectionLinesVisibility(
      visible: shouldShow,
      hintedVines: hintedVines,
      isAnimating: isAnimating,
    );
  }

  void _restartLevel() {
    final currentLevel = ref.read(currentLevelProvider);
    if (currentLevel != null) {
      final attemptsNotifier = ref.read(levelAttemptCountProvider.notifier);
      attemptsNotifier.increment();
      final attempts = ref.read(levelAttemptCountProvider);

      ref
          .read(analyticsServiceProvider)
          .logLevelRestart(currentLevel.id, attempts);

      ref.read(levelStartTimestampProvider.notifier).set(DateTime.now());

      ref.read(vineStatesProvider.notifier).resetForLevel(currentLevel);
      ref.read(levelCompleteProvider.notifier).setComplete(false);
      ref.read(gameOverProvider.notifier).setGameOver(false);
      ref.read(gameInstanceProvider.notifier).resetGrace();

      ref.read(projectionLinesVisibleProvider.notifier).setVisible(false);

      if (_game != null) {
        _game!.startLevel(currentLevel, ref.read(vineStatesProvider));
        final cameraNotifier = ref.read(cameraStateProvider.notifier);
        cameraNotifier.animateToDefaultZoom(
          screenWidth: _game!.size.x,
          screenHeight: _game!.size.y,
          gridCols: currentLevel.gridWidth,
          gridRows: currentLevel.gridHeight,
        );
      }
    }
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
                  LoggerService.info('Returning to home from completion dialog',
                      tag: 'GameScreen');
                  ref.read(gameCompletedProvider.notifier).setCompleted(false);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  context.go('/');
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
