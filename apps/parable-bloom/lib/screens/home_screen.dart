import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/game_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final gameProgress = ref.watch(gameProgressProvider);
    final modulesAsync = ref.watch(modulesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Game Title
              Text(
                'Parable Bloom',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Main Image in the middle
              Expanded(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/art/cross.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Play Next Level Button or Completed Message
              modulesAsync.when(
                data: (modules) {
                  final totalLevels = modules.fold<int>(
                    0,
                    (sum, module) =>
                        sum + (module.endLevel - module.startLevel + 1),
                  );
                  final allLevelsCompleted =
                      gameProgress.currentLevel > totalLevels;

                  if (allLevelsCompleted) {
                    return Column(
                      children: [
                        ElevatedButton(
                          onPressed: null, // Disabled
                          style: ElevatedButton.styleFrom(
                            disabledBackgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            disabledForegroundColor:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'All Levels Complete',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'More levels coming soon!',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  }

                  return ElevatedButton(
                    onPressed: () => _playNextLevel(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      gameProgress.tutorialCompleted
                          ? 'Play Level ${gameProgress.currentLevel}'
                          : 'Start Tutorial',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => ElevatedButton(
                  onPressed: () => _playNextLevel(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    gameProgress.tutorialCompleted
                        ? 'Play Level ${gameProgress.currentLevel}'
                        : 'Start Tutorial',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Settings Button
              OutlinedButton.icon(
                onPressed: () => _openSettings(),
                icon: const Icon(Icons.settings),
                label: const Text('Settings'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Journal Button
              OutlinedButton.icon(
                onPressed: () => _openJournal(),
                icon: const Icon(Icons.menu_book),
                label: const Text('Journal'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playNextLevel() {
    // Check if tutorial is completed and route accordingly
    final gameProgress = ref.read(gameProgressProvider);

    if (!gameProgress.tutorialCompleted) {
      // Route to tutorial flow if tutorial is not completed
      Navigator.of(context).pushNamed('/tutorial');
    } else {
      // Route to game for regular levels
      Navigator.of(context).pushNamed('/game');
    }
  }

  void _openSettings() {
    Navigator.of(context).pushNamed('/settings');
  }

  void _openJournal() {
    Navigator.of(context).pushNamed('/journal');
  }
}
