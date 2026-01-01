import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'core/config/environment_config.dart';
import 'features/game/presentation/screens/game_screen.dart';
import 'features/journal/presentation/screens/journal_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'providers/game_providers.dart';
import 'screens/home_screen.dart';

class ParableBloomApp extends ConsumerWidget {
  const ParableBloomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
