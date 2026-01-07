import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/game_providers.dart';

class GameHeader extends ConsumerWidget {
  final VoidCallback onPause;

  const GameHeader({super.key, required this.onPause});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildGraceDisplay(ref, context),
          IconButton(
            icon: const Icon(Icons.pause_rounded),
            onPressed: onPause,
            splashColor: Colors.transparent,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Pause',
          ),
        ],
      ),
    );
  }

  Widget _buildGraceDisplay(WidgetRef ref, BuildContext context) {
    final grace = ref.watch(graceProvider);
    const maxGrace = 3; // Assuming max grace is 3 for now

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(maxGrace, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Icon(
              index < grace ? Icons.favorite : Icons.favorite_border,
              color: Colors.redAccent,
              size: 24,
            ),
          );
        }),
      ),
    );
  }
}
