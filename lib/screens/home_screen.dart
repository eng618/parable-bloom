import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/game_providers.dart';

/// Helper function to format level display text.
/// Shows "Lession X" for tutorial levels, "Level X" for main levels.
String _formatLevelText(int levelNumber, bool tutorialCompleted) {
  if (!tutorialCompleted && levelNumber >= 1 && levelNumber <= 5) {
    return 'Lession $levelNumber';
  }
  return 'Level $levelNumber';
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

              // Stylized Grid in the middle
              const Expanded(child: Center(child: StylizedGrid())),

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
                    onPressed: () => _playNextLevel(context),
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
                      'Play ${_formatLevelText(gameProgress.currentLevel, gameProgress.tutorialCompleted)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => ElevatedButton(
                  onPressed: () => _playNextLevel(context),
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
                    'Play ${_formatLevelText(gameProgress.currentLevel, gameProgress.tutorialCompleted)}',
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
                onPressed: () => _openSettings(context),
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
                onPressed: () => _openJournal(context),
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

  void _playNextLevel(BuildContext context) {
    Navigator.of(context).pushNamed('/game');
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).pushNamed('/settings');
  }

  void _openJournal(BuildContext context) {
    Navigator.of(context).pushNamed('/journal');
  }
}

class StylizedGrid extends StatelessWidget {
  const StylizedGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(painter: GridPainter(context: context)),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final BuildContext context;

  GridPainter({required this.context});

  @override
  void paint(Canvas canvas, Size size) {
    // Use theme-based colors instead of hardcoded greens
    final ThemeData theme = Theme.of(context);

    final paint = Paint()
      ..color =
          theme.colorScheme.secondary.withValues(alpha: 0.6) // Medium green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color =
          theme.colorScheme.secondary.withValues(alpha: 0.1) // Light green tint
      ..style = PaintingStyle.fill;

    const gridSize = 5;
    final cellSize = size.width / gridSize;

    // Draw grid background
    canvas.drawRect(Offset.zero & size, fillPaint);

    // Draw grid lines
    for (int i = 0; i <= gridSize; i++) {
      final x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);

      final y = i * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw some decorative vine-like elements
    final vinePaint = Paint()
      ..color =
          theme.colorScheme.secondary.withValues(alpha: 0.8) // Stronger green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw curved vine elements
    final path1 = Path()
      ..moveTo(cellSize * 1, cellSize * 1)
      ..quadraticBezierTo(
        cellSize * 2,
        cellSize * 0.5,
        cellSize * 3,
        cellSize * 1,
      );

    final path2 = Path()
      ..moveTo(cellSize * 4, cellSize * 4)
      ..quadraticBezierTo(
        cellSize * 3,
        cellSize * 4.5,
        cellSize * 2,
        cellSize * 4,
      );

    canvas.drawPath(path1, vinePaint);
    canvas.drawPath(path2, vinePaint);

    // Draw some small circles to represent vine heads
    final circlePaint = Paint()
      ..color = theme.colorScheme.secondary // Pure secondary green
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cellSize * 1, cellSize * 1), 4, circlePaint);
    canvas.drawCircle(Offset(cellSize * 4, cellSize * 4), 4, circlePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
