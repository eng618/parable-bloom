import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'core/config/environment_config.dart';
import 'features/game/presentation/screens/game_screen.dart';
import 'features/journal/presentation/screens/journal_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'providers/game_providers.dart';
import 'screens/home_screen.dart';

class ParableBloomApp extends ConsumerStatefulWidget {
  const ParableBloomApp({super.key});

  @override
  ConsumerState<ParableBloomApp> createState() => _ParableBloomAppState();
}

class _ParableBloomAppState extends ConsumerState<ParableBloomApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final controller = ref.read(backgroundAudioControllerProvider);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Stop audio when app loses focus
      controller.setEnabled(false);
    } else if (state == AppLifecycleState.resumed) {
      // Resume audio if it was enabled
      final enabled = ref.read(backgroundAudioEnabledProvider);
      controller.setEnabled(enabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(backgroundAudioControllerProvider);

    return MaterialApp(
      title: 'Parable Bloom',
      debugShowCheckedModeBanner: EnvironmentConfig.isProd() ? false : true,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _convertToThemeMode(themeMode),
      home: _buildHome(),
      routes: {
        '/game': (context) => const GameScreen(),
        '/journal': (context) => const JournalScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }

  /// Builds the home screen with an optional environment indicator overlay.
  Widget _buildHome() {
    return Stack(
      children: [
        const HomeScreen(),
        // Environment indicator for non-production environments
        if (!EnvironmentConfig.isProd())
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

  /// Returns the color for the environment indicator badge.
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
