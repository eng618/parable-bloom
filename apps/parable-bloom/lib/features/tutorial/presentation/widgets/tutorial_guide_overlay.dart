import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';

import '../../../game/application/providers/camera_providers.dart';
import '../../../game/application/providers/gameplay_state_providers.dart';
import '../../../game/application/providers/solver_providers.dart';

/// State of a blocked tap event, used for drawing collision indicators.
class BlockedTapState {
  final Offset headPosition;
  final Offset blockerPosition;
  final DateTime timestamp;

  BlockedTapState({
    required this.headPosition,
    required this.blockerPosition,
    required this.timestamp,
  });
}

/// Global provider notifier for tracking the last blocked tap to render indicators.
class BlockedTapNotifier extends Notifier<BlockedTapState?> {
  @override
  BlockedTapState? build() => null;

  void setBlockedTap(BlockedTapState? val) {
    state = val;
  }
}

final blockedTapProvider = NotifierProvider<BlockedTapNotifier, BlockedTapState?>(
  BlockedTapNotifier.new,
);

/// A highly polished, tap-based tutorial guide overlay that sits on top of the Flame canvas.
/// Uses coordinate projections to draw context-sensitive highlights, glassmorphic micro-prompts,
/// and red collision indicators.
class TutorialGuideOverlay extends ConsumerStatefulWidget {
  const TutorialGuideOverlay({super.key});

  @override
  ConsumerState<TutorialGuideOverlay> createState() => _TutorialGuideOverlayState();
}

class _TutorialGuideOverlayState extends ConsumerState<TutorialGuideOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _blockedTapTimer;

  @override
  void initState() {
    super.initState();
    // Concentric pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _blockedTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch cameraState to trigger rebuilds on pan/zoom so projections align perfectly
    ref.watch(cameraStateProvider);

    final currentLevel = ref.watch(currentLevelProvider);
    final vineStates = ref.watch(vineStatesProvider);
    final blockedTap = ref.watch(blockedTapProvider);

    final game = ref.watch(gameInstanceProvider);

    if (currentLevel == null || game == null || !game.grid.isMounted) {
      return const SizedBox.shrink();
    }

    final lessonId = currentLevel.id;

    // Reset blocked tap indicator after 1.5 seconds automatically
    if (blockedTap != null) {
      _blockedTapTimer?.cancel();
      _blockedTapTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          ref.read(blockedTapProvider.notifier).setBlockedTap(null);
        }
      });
    }

    // Determine visual guides and prompt text based on current lesson
    Offset? highlightPosition;
    String promptText = '';
    Color highlightColor = const Color(0xFF6B8E23); // Moss Green default

    if (lessonId == 1) {
      // Lesson 1: Highlight head of vine_1 at (3,1)
      final vineState = vineStates['vine_1'];
      if (vineState != null && !vineState.isCleared) {
        highlightPosition = game.getCellScreenPosition(3, 1);
        promptText = "Tap head to slide";
      }
    } else if (lessonId == 2) {
      // Lesson 2: Multiple free-choice heads highlighted
      // Find first non-cleared vine
      final activeVineId = vineStates.entries
          .where((e) => !e.value.isCleared)
          .map((e) => e.key)
          .firstOrNull;

      if (activeVineId != null) {
        final vine = currentLevel.vines.firstWhere((v) => v.id == activeVineId);
        final head = vine.orderedPath.first;
        highlightPosition = game.getCellScreenPosition(head['x']!, head['y']!);
        promptText = "Clear the garden";
      }
    } else if (lessonId == 3) {
      // Lesson 3: Blocker is vine_2 (4,0), blocked is vine_1 (3,1)
      final blockerState = vineStates['vine_2'];
      final blockedState = vineStates['vine_1'];

      if (blockerState != null && !blockerState.isCleared) {
        highlightPosition = game.getCellScreenPosition(4, 0);
        promptText = "Clear blocker first";
        highlightColor = const Color(0xFF4682B4); // Sky Blue for priority
      } else if (blockedState != null && !blockedState.isCleared) {
        highlightPosition = game.getCellScreenPosition(3, 1);
        promptText = "Now clear!";
      }
    } else if (lessonId == 4) {
      // Lesson 4: Highlight the starting vine which can clear completely
      final activeVineIds = vineStates.entries
          .where((e) => !e.value.isCleared)
          .map((e) => e.key)
          .toList();

      final solver = ref.read(levelSolverServiceProvider);
      String? freeVineId;
      for (final vineId in activeVineIds) {
        if (solver.getDistanceToBlocker(currentLevel, vineId, activeVineIds) > 0) {
          freeVineId = vineId;
          break;
        }
      }

      if (freeVineId != null) {
        final vine = currentLevel.vines.firstWhere((v) => v.id == freeVineId);
        final head = vine.orderedPath.first;
        highlightPosition = game.getCellScreenPosition(head['x']!, head['y']!);
        promptText = "Start the chain";
      }
    } else if (lessonId == 5) {
      // Lesson 5: Capstone challenge, minimal text
      promptText = "Untangle the vines";
    }

    final targetPosition = highlightPosition;

    return IgnorePointer(
      child: Stack(
        children: [
          // 1. Draw collision path if a blocked tap occurred recently
          if (blockedTap != null) ...[
            CustomPaint(
              size: Size.infinite,
              painter: CollisionPathPainter(
                from: blockedTap.headPosition,
                to: blockedTap.blockerPosition,
              ),
            ),
            // Floating warning next to the blocker
            Positioned(
              left: blockedTap.blockerPosition.dx - 80,
              top: blockedTap.blockerPosition.dy - 65,
              child: _buildFloatingAlert("Blocked! Blocker first"),
            ),
          ],

          // 2. Pulse Highlight Ring on target cell
          if (targetPosition != null) ...[
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Positioned(
                  left: targetPosition.dx - 36 * _pulseAnimation.value,
                  top: targetPosition.dy - 36 * _pulseAnimation.value,
                  child: Container(
                    width: 72 * _pulseAnimation.value,
                    height: 72 * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: highlightColor.withValues(
                          alpha: (1.2 - _pulseAnimation.value).clamp(0.0, 1.0),
                        ),
                        width: 3.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: highlightColor.withValues(alpha: 0.15),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Moss green glow ring
            Positioned(
              left: targetPosition.dx - 18,
              top: targetPosition.dy - 18,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: highlightColor.withValues(alpha: 0.25),
                  border: Border.all(color: highlightColor, width: 2),
                ),
              ),
            ),

            // Hand tap indicator
            Positioned(
              left: targetPosition.dx - 12,
              top: targetPosition.dy + 8,
              child: Icon(
                Icons.touch_app,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
                shadows: const [
                  Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 1)),
                ],
              ),
            ),
          ],

          // 3. Glassmorphic Micro-Prompt anchored near the top of the screen (in clear sky area)
          if (promptText.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              top: 90, // Positioned beautifully below the progress indicator
              child: Center(
                child: _buildGlassmorphicPrompt(promptText),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassmorphicPrompt(String text) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.spa_outlined,
                color: colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: colorScheme.onSurface,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingAlert(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Dynamic dashed line custom painter for collision feedback.
class CollisionPathPainter extends CustomPainter {
  final Offset from;
  final Offset to;

  CollisionPathPainter({required this.from, required this.to});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double dashWidth = 8.0;
    const double dashSpace = 4.0;

    double dx = to.dx - from.dx;
    double dy = to.dy - from.dy;
    double distance = Offset(dx, dy).distance;

    double progress = 0.0;
    while (progress < distance) {
      final double startFraction = progress / distance;
      progress += dashWidth;
      final double endFraction = (progress > distance ? distance : progress) / distance;

      canvas.drawLine(
        Offset(from.dx + dx * startFraction, from.dy + dy * startFraction),
        Offset(from.dx + dx * endFraction, from.dy + dy * endFraction),
        paint,
      );

      progress += dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CollisionPathPainter oldDelegate) {
    return oldDelegate.from != from || oldDelegate.to != to;
  }
}
