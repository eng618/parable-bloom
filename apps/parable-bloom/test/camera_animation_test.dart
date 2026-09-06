import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'package:parable_bloom/features/game/application/providers/camera_providers.dart';

void main() {
  group('Camera animation decoupling (2.6)', () {
    test('gesture interrupts animation instead of being dropped', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cameraStateProvider.notifier);

      // Start a 0.8s animation, then gesture mid-flight.
      final future = notifier.animateToPosition(
        targetZoom: 1.5,
        targetPanOffset: vm.Vector2(20, 20),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      expect(container.read(cameraStateProvider).isAnimating, isTrue);

      notifier.updateZoom(1.2);

      // The awaited animation future must resolve (no hang) ...
      await future.timeout(const Duration(seconds: 2));
      // ... and the gesture wins.
      final state = container.read(cameraStateProvider);
      expect(state.isAnimating, isFalse);
      expect(state.zoom, 1.2);
    });

    test('animation settles on target with few notifications', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var notifications = 0;
      container.listen<CameraState>(
        cameraStateProvider,
        (_, __) => notifications++,
      );

      await container.read(cameraStateProvider.notifier).animateToPosition(
            targetZoom: 1.5,
            targetPanOffset: vm.Vector2(20, -10),
          );

      final state = container.read(cameraStateProvider);
      expect(state.isAnimating, isFalse);
      expect(state.zoom, 1.5);
      expect(state.panOffset.x, 20);
      expect(state.panOffset.y, -10);
      // Start + throttled progress + final. The old design emitted ~50.
      expect(notifications, lessThan(15));
    });

    test('resetToCenter works during animation', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cameraStateProvider.notifier);
      final future = notifier.animateToPosition(
        targetZoom: 2.0,
        targetPanOffset: vm.Vector2(30, 30),
      );
      await Future.delayed(const Duration(milliseconds: 100));

      notifier.resetToCenter();
      await future.timeout(const Duration(seconds: 2));

      final state = container.read(cameraStateProvider);
      expect(state.isAnimating, isFalse);
      expect(state.panOffset, vm.Vector2.zero());
    });
  });
}
