import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';

/// Full-screen "Level Complete" celebration overlay content.
///
/// Pure presentation: the owning screen owns visibility timing, analytics,
/// and the congratulatory message.
class LevelCompleteOverlay extends StatelessWidget {
  const LevelCompleteOverlay({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
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
                  message,
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
}
