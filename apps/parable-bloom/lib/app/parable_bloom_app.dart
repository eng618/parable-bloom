import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../core/config/environment_config.dart';
import '../features/auth/application/providers/auth_providers.dart';
import '../features/game/application/providers/progress_providers.dart';
import '../features/game/presentation/screens/game_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/journal/presentation/screens/journal_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/tutorial/presentation/screens/tutorial_flow_screen.dart';
import '../providers/infrastructure_providers.dart';
import '../providers/settings_providers.dart';
import '../services/logger_service.dart';

const bool _isScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

class ParableBloomApp extends ConsumerStatefulWidget {
  const ParableBloomApp({super.key});

  @override
  ConsumerState<ParableBloomApp> createState() => _ParableBloomAppState();
}

class _ParableBloomAppState extends ConsumerState<ParableBloomApp>
    with WidgetsBindingObserver {
  bool _didReceiveInteraction = false;
  bool _wasOnline = true;
  StreamSubscription<dynamic>? _connectivitySubscription;

  void _onPointerDown(PointerDownEvent _) {
    if (_didReceiveInteraction) return;
    _didReceiveInteraction = true;
    ref.read(backgroundAudioControllerProvider).notifyUserInteraction();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_isScreenshotMode) {
      unawaited(_initializeConnectivitySync());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameProgressProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeConnectivitySync() async {
    final connectivity = Connectivity();
    try {
      final current = await connectivity.checkConnectivity();
      _wasOnline = _isOnline(current);
    } catch (e, stack) {
      LoggerService.warn(
        'Failed to read initial connectivity state',
        error: e,
        stackTrace: stack,
        tag: 'App',
      );
    }

    _connectivitySubscription = ref.read(connectivityStreamProvider).listen(
      (event) {
        final isOnline = _isOnline(event);
        if (!_wasOnline && isOnline) {
          LoggerService.info(
            'Connectivity restored. Triggering sync...',
            tag: 'App',
          );
          unawaited(ref.read(gameProgressProvider.notifier).syncOnReconnect());
        }
        _wasOnline = isOnline;
      },
      onError: (Object e, StackTrace stack) {
        LoggerService.warn(
          'Connectivity stream error',
          error: e,
          stackTrace: stack,
          tag: 'App',
        );
      },
    );
  }

  bool _isOnline(dynamic connectivityEvent) {
    if (connectivityEvent is ConnectivityResult) {
      return connectivityEvent != ConnectivityResult.none;
    }
    if (connectivityEvent is List<ConnectivityResult>) {
      return connectivityEvent.any((result) => result != ConnectivityResult.none);
    }
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final controller = ref.read(backgroundAudioControllerProvider);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.setEnabled(false);
    } else if (state == AppLifecycleState.resumed) {
      final enabled = ref.read(backgroundAudioEnabledProvider);
      controller.setEnabled(enabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(backgroundAudioControllerProvider);

    if (!_isScreenshotMode) {
      ref.listen(authUserProvider, (previous, next) async {
        final user = next.value;
        final previousUser = previous?.value;

        if (user != null && user.uid != previousUser?.uid) {
          LoggerService.info('User logged in/changed. Triggering sync...',
              tag: 'App');
          await ref.read(gameProgressProvider.notifier).manualSync();
        }
      });
    }

    final app = MaterialApp(
      title: 'Parable Bloom',
      debugShowCheckedModeBanner:
          _isScreenshotMode ? false : !EnvironmentConfig.isProd(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _convertToThemeMode(themeMode),
      home: _buildHome(),
      routes: {
        '/tutorial': (context) => const TutorialFlowScreen(),
        '/game': (context) => const GameScreen(),
        '/journal': (context) => const JournalScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
    if (kIsWeb) {
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        child: app,
      );
    }
    return app;
  }

  Widget _buildHome() {
    return Stack(
      children: [
        const HomeScreen(),
        if (!_isScreenshotMode && !EnvironmentConfig.isProd())
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getEnvironmentColor(),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Text(
                EnvironmentConfig.environmentName(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _getEnvironmentColor() {
    switch (EnvironmentConfig.current) {
      case AppEnvironment.dev:
        return Colors.orange;
      case AppEnvironment.preview:
        return Colors.blue;
      case AppEnvironment.prod:
        return Colors.green;
    }
  }

  ThemeMode _convertToThemeMode(AppThemeMode appThemeMode) {
    switch (appThemeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
