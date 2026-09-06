import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/camera_providers.dart';
import '../../application/providers/gameplay_state_providers.dart';

/// Zoom controls card shown above the projection FAB.
///
/// Self-contained: watches the camera state and drives the notifier
/// directly, so owning screens stay lean.
class GameZoomControls extends ConsumerWidget {
  const GameZoomControls({super.key});

  static const double _zoomStep = 0.2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLevel = ref.watch(currentLevelProvider);
    if (currentLevel == null) return const SizedBox.shrink();

    final cameraState = ref.watch(cameraStateProvider);
    final notifier = ref.read(cameraStateProvider.notifier);

    return Positioned(
      right: 16,
      bottom: 80, // Position above FAB
      child: Card(
        elevation: 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Zoom In',
              splashColor: Colors.transparent,
              onPressed: cameraState.zoom >= cameraState.maxZoom
                  ? null
                  : () {
                      final newZoom = (cameraState.zoom + _zoomStep).clamp(
                        cameraState.minZoom,
                        cameraState.maxZoom,
                      );
                      notifier.updateZoom(newZoom);
                    },
            ),
            const Divider(height: 1),
            IconButton(
              icon: const Icon(Icons.remove),
              tooltip: 'Zoom Out',
              splashColor: Colors.transparent,
              onPressed: cameraState.zoom <= cameraState.minZoom
                  ? null
                  : () {
                      final newZoom = (cameraState.zoom - _zoomStep).clamp(
                        cameraState.minZoom,
                        cameraState.maxZoom,
                      );
                      notifier.updateZoom(newZoom);
                    },
            ),
            const Divider(height: 1),
            IconButton(
              icon: const Icon(Icons.center_focus_strong),
              tooltip: 'Reset Zoom',
              splashColor: Colors.transparent,
              onPressed: notifier.resetToCenter,
            ),
          ],
        ),
      ),
    );
  }
}
