import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/game_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moduleProgress = ref.watch(moduleProgressProvider);

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

              // Play Next Level Button
              ElevatedButton(
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
                  'Play Module ${moduleProgress.currentModule} Level ${moduleProgress.currentLevelInModule}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
      ..color = theme.colorScheme.secondary
          .withValues(alpha: 0.6) // Medium green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = theme.colorScheme.secondary
          .withValues(alpha: 0.1) // Light green tint
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
      ..color = theme.colorScheme.secondary
          .withValues(alpha: 0.8) // Stronger green
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
      ..color = theme
          .colorScheme
          .secondary // Pure secondary green
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cellSize * 1, cellSize * 1), 4, circlePaint);
    canvas.drawCircle(Offset(cellSize * 4, cellSize * 4), 4, circlePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
