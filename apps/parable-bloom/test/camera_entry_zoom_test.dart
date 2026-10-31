import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parable_bloom/core/constants/animation_timing.dart';
import 'package:parable_bloom/features/game/application/providers/camera_providers.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('level-entry fit zoom', () {
    test('computeFitZoom picks the tighter axis with padding', () {
      // 10x10 board ≈ 430px; 800x600 screen with 0.9 padding → height-limited.
      final fit = CameraStateNotifier.computeFitZoom(
        screenWidth: 800,
        screenHeight: 600,
        gridCols: 10,
        gridRows: 10,
      );
      expect(fit, greaterThan(0.5));
      expect(fit, lessThan(2.0));
    });

    test('animateToDefaultZoom eases from entry factor to resting fit',
        () async {
      final container = ProviderContainer(
        overrides: [
          disableAnimationsProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cameraStateProvider.notifier);
      notifier.animateToDefaultZoom(
        screenWidth: 390,
        screenHeight: 700,
        gridCols: 4,
        gridRows: 3,
      );

      final state = container.read(cameraStateProvider);
      expect(state.isAnimating, isFalse);
      expect(state.fitZoom, greaterThan(0));
      // Resting = fit × boardZoomScale (default 1.0).
      expect(state.zoom, closeTo(state.fitZoom, 0.0001));
      expect(state.panOffset.x, 0);
      expect(state.panOffset.y, 0);
    });

    test('entry start zoom is ~1.22× resting before animation runs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cameraStateProvider.notifier);
      // Keep animations enabled so the first frame holds the entry zoom.
      notifier.animateToDefaultZoom(
        screenWidth: 390,
        screenHeight: 700,
        gridCols: 12,
        gridRows: 12,
      );

      final state = container.read(cameraStateProvider);
      expect(state.isAnimating, isTrue);
      final resting = state.fitZoom; // boardZoomScale defaults to 1.0
      expect(
        state.zoom,
        closeTo(resting * AnimationTiming.entryZoomFactor, 0.02),
      );
      expect(state.zoom, greaterThan(resting));

      notifier.resetToCenter();
      final reset = container.read(cameraStateProvider);
      expect(reset.isAnimating, isFalse);
      expect(reset.zoom, closeTo(resting, 0.0001));
      expect(reset.panOffset.x, 0);
      expect(reset.panOffset.y, 0);
    });

    test('dense and tutorial boards both fit within phone viewport', () {
      const phoneW = 390.0;
      const phoneH = 700.0;

      final dense = CameraStateNotifier.computeFitZoom(
        screenWidth: phoneW,
        screenHeight: phoneH,
        gridCols: 15,
        gridRows: 15,
      );
      final tutorial = CameraStateNotifier.computeFitZoom(
        screenWidth: phoneW,
        screenHeight: phoneH,
        gridCols: 3,
        gridRows: 3,
      );

      expect(dense, lessThan(tutorial));
      expect(dense * AnimationTiming.entryZoomFactor, greaterThan(dense));
      expect(tutorial, greaterThan(1.0));
    });
  });
}
