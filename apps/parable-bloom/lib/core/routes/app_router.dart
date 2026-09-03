import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/game/presentation/screens/game_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/journal/presentation/screens/journal_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/tutorial/presentation/screens/tutorial_flow_screen.dart';

/// The global router for the application using go_router.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  errorBuilder: (BuildContext context, GoRouterState state) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.nature_people_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Garden Path Not Found',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Let us return to the quiet garden of grace.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home),
                  label: const Text('Return Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const HomeScreen();
      },
    ),
    GoRoute(
      path: '/game',
      builder: (BuildContext context, GoRouterState state) {
        return const GameScreen();
      },
    ),
    GoRoute(
      path: '/tutorial',
      builder: (BuildContext context, GoRouterState state) {
        return const TutorialFlowScreen();
      },
    ),
    GoRoute(
      path: '/journal',
      builder: (BuildContext context, GoRouterState state) {
        return const JournalScreen();
      },
    ),
    GoRoute(
      path: '/auth',
      builder: (BuildContext context, GoRouterState state) {
        return const AuthScreen();
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (BuildContext context, GoRouterState state) {
        return const SettingsScreen();
      },
    ),
  ],
);
