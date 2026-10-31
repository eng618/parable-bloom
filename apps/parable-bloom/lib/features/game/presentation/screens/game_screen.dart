import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/constants/animation_timing.dart';
import '../../../../features/game/domain/entities/level_data.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/settings_providers.dart';
import '../../../../core/services/sfx_controller.dart';
import '../../application/providers/camera_providers.dart';
import '../../application/providers/counter_providers.dart';
import '../../application/providers/gameplay_state_providers.dart';
import '../../application/providers/solver_providers.dart';
import '../../application/providers/module_providers.dart';
import '../../application/providers/progress_providers.dart';
import '../widgets/game_board_gestures.dart';
import '../widgets/game_header.dart';
import '../widgets/celebration_effects.dart';
import '../widgets/game_event_sink.dart';
import '../widgets/game_sfx_bridge.dart';
import '../widgets/game_state_dialogs.dart';
import '../widgets/game_unlock_dialogs.dart';
import '../widgets/game_zoom_controls.dart';
import '../widgets/garden_game.dart';
import '../widgets/level_complete_overlay.dart';
import '../widgets/projection_sync.dart';
import '../widgets/pause_menu_dialog.dart';
import '../../../tutorial/presentation/widgets/tutorial_guide_overlay.dart';
import '../../../../core/services/logger_service.dart';

part 'game_screen_event_sink.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  GardenGame? _game;
  late bool _isLevelCompleteOverlayVisible;
  late String _currentCongratulationMessage;

  /// Set when the player intentionally leaves during the complete beat so we
  /// do not auto-advance into the next level after navigating Home.
  bool _homeExitRequested = false;

  /// Provider container captured in [didChangeDependencies] while the
  /// element is active. The Flame bridge sink reads through it instead of
  /// [WidgetRef.read], whose ancestor lookup throws while the element is
  /// deactivated (navigation transitions, hot reload) even though
  /// [State.mounted] is still true.
  ProviderContainer? _providerContainer;

  @override
  void initState() {
    super.initState();
    LoggerService.debug(
      'GameScreen init',
      tag: 'GameScreen',
      metadata: {'game_is_null': _game == null},
    );
    _isLevelCompleteOverlayVisible = false;
    _currentCongratulationMessage = '';
    _homeExitRequested = false;
    _initGame();
    _subscribeToProviders();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logScreenView('Gameplay');
    });
  }

  /// Provider subscriptions live here — not in [build] — so they are
  /// registered once instead of re-subscribed on every rebuild.
  /// Uses [listenManual]: [ref.listen] asserts a build context and throws
  /// when called from [initState]; manual subscriptions are closed
  /// automatically on unmount.
  void _subscribeToProviders() {
    // Watch for level completion and show overlay
    ref.listenManual(levelCompleteProvider, (previous, next) {
      LoggerService.debug(
        'levelCompleteProvider changed',
        tag: 'GameScreen',
        metadata: {'previous': previous, 'next': next},
      );
      if (next && (previous == null || !previous)) {
        LoggerService.info('Showing level complete overlay', tag: 'GameScreen');
        unawaited(
          ref.read(sfxControllerProvider).play(GameSfx.levelComplete),
        );
        _showLevelCompleteOverlay();
      }
    });

    // Watch for total game completion
    ref.listenManual(gameCompletedProvider, (previous, next) {
      if (next && (previous == null || !previous)) {
        LoggerService.info('Showing game completed dialog', tag: 'GameScreen');
        _showGameCompletedDialog();
      }
    });

    // Watch for Game Over
    ref.listenManual(gameOverProvider, (previous, next) {
      if (next && (previous == null || !previous)) {
        LoggerService.info('Showing game over dialog', tag: 'GameScreen');
        _showGameOverDialog();
      }
    });

    // Sync state with Flame GardenGame instance
    ref.listenManual(cameraStateProvider, (previous, next) {
      _game?.applyCameraTransform(next);
    });

    ref.listenManual(vineStatesProvider, (previous, next) {
      _game?.updateVineStates(next);
    });

    ref.listenManual(vineStyleProvider, (previous, next) {
      // Single entry point: also handles background visibility for
      // VineStyle.simple internally.
      _game?.updateVineStyle(next);
    });

    // Single subscription: ProjectionMode carries show-all + hints atomically.
    ref.listenManual(projectionModeProvider, (previous, next) {
      if (previous != next) syncProjectionLines(ref, _game);
    });

    ref.listenManual(anyVineAnimatingProvider, (previous, next) {
      syncProjectionLines(ref, _game);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Captured while the element is active: the Flame bridge sink reads
    // providers through this container instead of WidgetRef.read, whose
    // ancestor lookup throws during deactivate/unmount windows and hot
    // reload even though State.mounted is still true.
    _providerContainer = ProviderScope.containerOf(context, listen: false);
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

  void _initGame() {
    LoggerService.debug(
      'Creating new GardenGame instance in initState',
      tag: 'GameScreen',
    );
    _game = GardenGame(
      solver: ref.read(levelSolverServiceProvider),
      sink: _GameScreenEventSink(this),
    );
    // Vine renderer selection (rail vs legacy painter).
    _game!.updateVineRenderMode(ref.read(vineRenderModeProvider));
  }

  @override
  void dispose() {
    LoggerService.debug('GameScreen dispose', tag: 'GameScreen');
    if (ref.read(gameInstanceProvider) == _game) {
      ref.read(gameInstanceProvider.notifier).setGame(null);
    }
    _game = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      floatingActionButton: _buildProjectionLinesFAB(),
      body: Stack(
        children: [
          GameBoardGestures(game: _game!),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: GameHeader(
                onPause: _showPauseMenu,
                onHome: _goHomeFromHeader,
              ),
            ),
          ),
          if (kIsWeb) _buildZoomControls(),
          if (_isLevelCompleteOverlayVisible) _buildLevelCompleteOverlay(),
        ],
      ),
    );
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
          _goHomeFromGameplay(logQuit: true);
        },
      ),
    );
  }

  /// Dedicated header Home — intentional leave to Home.
  void _goHomeFromHeader() {
    if (_isLevelCompleteOverlayVisible) {
      _goHomeFromLevelComplete();
      return;
    }
    _goHomeFromGameplay(logQuit: true);
  }

  /// Pause / header Home while a level is in progress.
  void _goHomeFromGameplay({required bool logQuit}) {
    _homeExitRequested = true;
    if (logQuit) _logLevelQuit();
    if (!mounted) return;
    context.go('/');
  }

  /// Home during the level-complete celebration (level already persisted).
  void _goHomeFromLevelComplete() {
    _homeExitRequested = true;
    if (_isLevelCompleteOverlayVisible) {
      setState(() {
        _isLevelCompleteOverlayVisible = false;
      });
    }
    ref.read(levelCompleteProvider.notifier).setComplete(false);
    if (!mounted) return;
    context.go('/');
  }

  /// Analytics for abandoning a level via the pause menu or header Home.
  void _logLevelQuit() {
    final currentLevel = ref.read(currentLevelProvider);
    if (currentLevel == null) return;
    final startMs = ref.read(levelStartTimestampProvider);
    final elapsedSeconds = startMs != null
        ? ((DateTime.now().millisecondsSinceEpoch - startMs) / 1000).round()
        : -1;
    final tapCount = ref.read(levelTotalTapsProvider);
    final remainingVines =
        ref.read(vineStatesProvider).values.where((s) => !s.isCleared).length;

    ref.read(analyticsServiceProvider).logLevelQuit(
          levelId: currentLevel.id,
          elapsedSeconds: elapsedSeconds,
          taps: tapCount,
          remainingVines: remainingVines,
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

  Widget _buildZoomControls() {
    return const GameZoomControls();
  }

  // Confetti implementation removed; celebration handled via in-game ripple effect.

  Widget _buildLevelCompleteOverlay() {
    return LevelCompleteOverlay(
      message: _currentCongratulationMessage,
      onHome: _goHomeFromLevelComplete,
    );
  }

  void _showLevelCompleteOverlay() async {
    if (_isLevelCompleteOverlayVisible) return;

    _homeExitRequested = false;
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

    // Persist completion + detect unlocks; default path continues to next level.
    final currentLevel = ref.read(currentLevelProvider);
    ModuleData? completedModule;
    ModuleScripture? newlyUnlockedScripture;
    final isDebugPlay = ref.read(debugPlayModeProvider);

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

      if (!isDebugPlay) {
        await ref
            .read(gameProgressProvider.notifier)
            .completeLevel(currentLevel.id);
      } else {
        LoggerService.debug(
          'Debug play — skipping persistence',
          tag: 'GameScreen',
          metadata: {'level_id': currentLevel.id},
        );
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

    // Wait for celebration beat, then unlock dialog or next level.
    await Future.delayed(AnimationTiming.levelCompleteDelay);

    if (!mounted || _homeExitRequested) return;

    // Reset completion flag
    ref.read(levelCompleteProvider.notifier).setComplete(false);

    setState(() {
      _isLevelCompleteOverlayVisible = false;
    });

    if (newlyUnlockedScripture != null && completedModule != null) {
      final scripture = newlyUnlockedScripture;
      final module = completedModule;
      if (isDebugPlay) {
        ref.read(debugSelectedLevelProvider.notifier).setLevel(null);
      }
      await showScriptureUnlockedDialog(
        context,
        ref,
        scripture,
        module,
        onHome: _goHomeFromLevelComplete,
        onViewJournal: () {
          _homeExitRequested = true;
          context.go('/');
          context.push(
            '/journal?entry=${Uri.encodeComponent(scripture.id)}',
          );
        },
        onContinue: _continueToNextLevel,
      );
      return;
    }

    if (completedModule != null) {
      if (isDebugPlay) {
        ref.read(debugSelectedLevelProvider.notifier).setLevel(null);
      }
      await showParableUnlockedDialog(
        context,
        ref,
        completedModule,
        onHome: _goHomeFromLevelComplete,
        onViewJournal: (scripture) {
          _homeExitRequested = true;
          context.go('/');
          final entry = scripture != null && scripture.isNotEmpty
              ? '/journal?entry=${Uri.encodeComponent(scripture)}'
              : '/journal';
          context.push(entry);
        },
        onContinue: _continueToNextLevel,
      );
      return;
    }

    if (isDebugPlay) {
      // Debug selected a specific level — return to settings/home path.
      ref.read(debugSelectedLevelProvider.notifier).setLevel(null);
      if (!mounted || _homeExitRequested) return;
      context.go('/');
      return;
    }

    await _continueToNextLevel();
  }

  /// Load the next uncompleted level in-place. Playlist exhausted → completed.
  Future<void> _continueToNextLevel() async {
    if (!mounted || _homeExitRequested) return;

    final game = _game;
    if (game == null) {
      context.go('/');
      return;
    }

    List<String> playlist = const [];
    try {
      final modules = await ref.read(modulesProvider.future);
      playlist = modules.expand((m) => m.allLevels).toList();
    } catch (error, stackTrace) {
      LoggerService.warn(
        'Could not load playlist for next-level continue',
        tag: 'GameScreen',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (!mounted || _homeExitRequested) return;

    final progress = ref.read(gameProgressProvider);
    final nextId = progress.nextUncompletedLevel(playlist);
    if (nextId == null && playlist.isNotEmpty) {
      LoggerService.info(
        'Playlist exhausted after level complete — game completed',
        tag: 'GameScreen',
      );
      ref.read(gameCompletedProvider.notifier).setCompleted(true);
      return;
    }

    LoggerService.info(
      'Continuing to next level after clear',
      tag: 'GameScreen',
      metadata: {
        'next_level': nextId ?? progress.currentLevel,
      },
    );
    await _loadLevelForGame(game);
  }

  Future<void> _loadLevelForGame(GardenGame game) async {
    final debugSelected = ref.read(debugSelectedLevelProvider);
    final gameProgress = ref.read(gameProgressProvider);
    var levelId = debugSelected ?? gameProgress.currentLevel;

    try {
      final mappings = await ref.read(levelMappingsProvider.future);
      if (!mappings.containsKey(levelId) && debugSelected == null) {
        // The persisted pointer may predate the current playlist (new cloud
        // levels, migrated IDs) or the registry sources may disagree. Resolve
        // to something loadable before concluding anything about completion.
        // resolveLevelToLoad only returns IDs present in mappings.
        final resolved =
            await ref.read(gameProgressProvider.notifier).resolveLevelToLoad();
        if (resolved != null) {
          levelId = resolved;
        }
      }
      if (!mappings.containsKey(levelId)) {
        if (mappings.isEmpty) {
          // Registry failed to load (offline/error): this is a load failure,
          // not a finished game. Same handling as the exception path below.
          LoggerService.error(
            'Level mappings empty, cannot load $levelId (registry unavailable)',
            tag: 'GameScreen',
          );
          ref.read(gameOverProvider.notifier).setGameOver(true);
        } else {
          ref.read(gameCompletedProvider.notifier).setCompleted(true);
        }
        return;
      }

      final levelData = await ref.read(levelDataProvider(levelId).future);

      // Capture before setLevel: a fresh level starts the attempt count at
      // 1, a reloaded same level keeps counting. (Reading after setLevel
      // always compares the id to itself, so the reset never fired.)
      final previousLevelId = ref.read(currentLevelProvider)?.id;
      ref.read(currentLevelProvider.notifier).setLevel(levelData);
      ref.read(gameCompletedProvider.notifier).setCompleted(false);

      // Grace is app-scoped; always refill on level load so depleted hearts
      // from a prior board (tutorial→main or in-place next-level continue)
      // never carry over.
      ref.read(gameInstanceProvider.notifier).resetGrace();

      ref.read(levelTotalTapsProvider.notifier).reset();
      ref.read(levelWrongTapsProvider.notifier).reset();

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
      LoggerService.error(
        'Error loading level $levelId on game screen',
        error: e,
        stackTrace: stack,
        tag: 'GameScreen',
      );
      ref.read(gameOverProvider.notifier).setGameOver(true);
    }
  }

  void _restartLevel() {
    final currentLevel = ref.read(currentLevelProvider);
    if (currentLevel != null) {
      final attemptsNotifier = ref.read(levelAttemptCountProvider.notifier);
      attemptsNotifier.increment();
      final attempts = ref.read(levelAttemptCountProvider);

      final startMs = ref.read(levelStartTimestampProvider);
      final elapsedSeconds = startMs != null
          ? ((DateTime.now().millisecondsSinceEpoch - startMs) / 1000).round()
          : -1;

      ref.read(analyticsServiceProvider).logLevelRestart(
            currentLevel.id,
            attempts,
            elapsedSeconds: elapsedSeconds,
          );

      ref.read(levelStartTimestampProvider.notifier).set(DateTime.now());

      ref.read(vineStatesProvider.notifier).resetForLevel(currentLevel);
      ref.read(levelCompleteProvider.notifier).setComplete(false);
      ref.read(gameOverProvider.notifier).setGameOver(false);
      ref.read(gameInstanceProvider.notifier).resetGrace();

      ref.read(projectionModeProvider.notifier).setShowAll(false);

      if (_game != null) {
        _game!.startLevel(
          currentLevel,
          ref.read(vineStatesProvider),
          forceRebuild: true,
        );
        final cameraNotifier = ref.read(cameraStateProvider.notifier);
        cameraNotifier.animateToDefaultZoom(
          screenWidth: _game!.size.x,
          screenHeight: _game!.size.y,
          gridCols: currentLevel.gridWidth,
          gridRows: currentLevel.gridHeight,
        );
      }
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Level restarted')));
  }

  void _showGameCompletedDialog() {
    showGameCompletedDialog(
      context,
      onBackToHome: () {
        LoggerService.info(
          'Returning to home from completion dialog',
          tag: 'GameScreen',
        );
        ref.read(gameCompletedProvider.notifier).setCompleted(false);
        context.go('/');
      },
    );
  }

  void _showGameOverDialog() {
    // Log game over analytics
    final currentLevel = ref.read(currentLevelProvider);
    if (currentLevel != null) {
      ref.read(analyticsServiceProvider).logGameOver(currentLevel.id);
    }

    showGameOverDialog(context, onTryAgain: _restartLevel);
  }
}
