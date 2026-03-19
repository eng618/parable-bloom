import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parable_bloom/features/game/application/providers/camera_providers.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/presentation/screens/game_screen.dart';
import 'package:parable_bloom/main.dart' as app;
import 'package:parable_bloom/providers/settings_providers.dart';

void main() {
  final binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Required on Android before calling takeScreenshot().
    await binding.convertFlutterSurfaceToImage();
  });

  testWidgets('capture store listing screenshots - light', (tester) async {
    await _captureStoreListingScreenshots(
      tester,
      themeMode: AppThemeMode.light,
      suffix: 'light',
    );
  });

  testWidgets('capture store listing screenshots - dark', (tester) async {
    await _captureStoreListingScreenshots(
      tester,
      themeMode: AppThemeMode.dark,
      suffix: 'dark',
    );
  });
}

Future<void> _captureStoreListingScreenshots(
  WidgetTester tester, {
  required AppThemeMode themeMode,
  required String suffix,
}) async {
    app.main();

    // Use bounded pumping instead of pumpAndSettle because Flame keeps ticking.
    await _pumpFor(tester, const Duration(seconds: 6));

    final playButton = find.textContaining('Play Level');
    expect(playButton, findsOneWidget);

    final rootContainer = ProviderScope.containerOf(tester.element(playButton));
    await rootContainer.read(themeModeProvider.notifier).setThemeMode(themeMode);
    await _pumpFor(tester, const Duration(seconds: 1));

    await _takeScreenshot('01_home_$suffix');

    await tester.tap(playButton);
    await tester.pump();
    await _pumpFor(tester, const Duration(seconds: 4));

    await _prepareZoomedOutGameplayShot(tester);

    await _takeScreenshot('02_gameplay_$suffix');

    // Trigger level-complete overlay directly for deterministic win capture.
    final gameScreen = find.byType(GameScreen);
    expect(gameScreen, findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(gameScreen));
    _clearAllVines(container);
    container.read(levelCompleteProvider.notifier).setComplete(true);

    await _pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Level Complete'), findsOneWidget);
    expect(find.byIcon(Icons.celebration), findsOneWidget);
    await _takeScreenshot('03_win_$suffix');

    // Allow overlay flow to complete and return to home before journal capture.
    await _pumpFor(tester, const Duration(seconds: 5));

    final journalButton = find.text('Journal');
    expect(journalButton, findsOneWidget);

    await tester.tap(journalButton);
    await tester.pump();
    await _pumpFor(tester, const Duration(seconds: 3));

    expect(find.text('The Sower and the Seed'), findsOneWidget);

    await _takeScreenshot('04_journal_$suffix');
}

Future<void> _takeScreenshot(String name) async {
  await IntegrationTestWidgetsFlutterBinding.instance.takeScreenshot(name);
}

Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 100);
  final ticks = (duration.inMilliseconds / step.inMilliseconds).ceil();
  for (var i = 0; i < ticks; i++) {
    await tester.pump(step);
  }
}

void _clearAllVines(ProviderContainer container) {
  final vineIds = container.read(vineStatesProvider).keys.toList(growable: false);
  final notifier = container.read(vineStatesProvider.notifier);
  for (final vineId in vineIds) {
    notifier.clearVine(vineId);
  }
}

Future<void> _prepareZoomedOutGameplayShot(WidgetTester tester) async {
  final gameScreen = find.byType(GameScreen);
  expect(gameScreen, findsOneWidget);

  final container = ProviderScope.containerOf(tester.element(gameScreen));

  // Wait for intro camera animation to finish before overriding zoom.
  for (var i = 0; i < 20; i++) {
    final cameraState = container.read(cameraStateProvider);
    if (!cameraState.isAnimating) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  final cameraNotifier = container.read(cameraStateProvider.notifier);
  final cameraState = container.read(cameraStateProvider);
  cameraNotifier.resetToCenter();
  cameraNotifier.updateZoom(cameraState.minZoom);
  await tester.pump(const Duration(milliseconds: 300));
}
