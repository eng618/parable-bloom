import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parable_bloom/core/providers/settings_providers.dart';
import 'package:parable_bloom/core/routes/app_router.dart';
import 'package:parable_bloom/features/game/application/providers/camera_providers.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/presentation/screens/game_screen.dart';
import 'package:parable_bloom/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

/// Captures the full Play Store screenshot set for one theme.
///
/// Scenes (in order):
///   01_home         — Garden home with "Play Level" CTA
///   02_gameplay     — Mid-puzzle board with vines (~1/3 cleared)
///   03_win          — Level Complete celebration overlay
///   04_journal      — Scripture journal with unlocked entries
///   05_settings     — Settings screen showing the Theme toggle
///   06_tutorial     — Tutorial walkthrough screen
///
/// Each scene is captured once per theme (light/dark), yielding 12 screenshots
/// total — well within Play Store's 8-per-form-factor limit for the primary
/// phone set (trim to the first 8 if needed: drop 06_tutorial).
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

  // ── Scene 1: Home ──
  await _takeScreenshot(tester, '01_home_$suffix');

  // ── Scene 2: Gameplay ──
  await tester.tap(playButton);
  await tester.pump();
  await _waitForLevelLoaded(tester);

  // Clear ~1/3 of vines so the board reads as mid-puzzle gameplay rather than
  // a fresh or finished level. Leaves at least one vine active so the
  // level-complete overlay is not triggered.
  await _seedMidGameplayVines(tester);

  await _prepareZoomedOutGameplayShot(tester);
  await _takeScreenshot(tester, '02_gameplay_$suffix');

  // ── Scene 3: Win ──
  final gameScreen = find.byType(GameScreen);
  expect(gameScreen, findsOneWidget);

  final gameContainer = ProviderScope.containerOf(tester.element(gameScreen));
  _clearAllVines(gameContainer);
  gameContainer.read(levelCompleteProvider.notifier).setComplete(true);

  await _pumpFor(tester, const Duration(milliseconds: 600));
  expect(find.text('Level Complete'), findsOneWidget);
  expect(find.byIcon(Icons.celebration), findsOneWidget);
  await _takeScreenshot(tester, '03_win_$suffix');

  // The win overlay flow auto-returns to home.
  await _pumpFor(tester, const Duration(seconds: 5));

  // ── Scene 4: Journal ──
  final journalButton = find.text('Journal');
  expect(journalButton, findsOneWidget);

  await tester.tap(journalButton);
  await tester.pump();
  await _pumpFor(tester, const Duration(seconds: 3));

  expect(find.text('The Sower and the Seed'), findsOneWidget);
  await _takeScreenshot(tester, '04_journal_$suffix');

  // ── Scene 5: Settings ──
  await _navigateToHome(tester);
  await _pumpFor(tester, const Duration(seconds: 2));

  final settingsButton = find.text('Settings');
  expect(settingsButton, findsOneWidget);
  await tester.tap(settingsButton);
  await tester.pump();
  await _pumpFor(tester, const Duration(seconds: 2));

  await _takeScreenshot(tester, '05_settings_$suffix');

  // ── Scene 6: Tutorial ──
  await _navigateToHome(tester);
  await _pumpFor(tester, const Duration(seconds: 2));

  // Home button reads "Play Level" (tutorial already completed in seed data),
  // so navigate directly to the tutorial route.
  appRouter.go('/tutorial');
  await tester.pump();
  await _pumpFor(tester, const Duration(seconds: 3));

  await _takeScreenshot(tester, '06_tutorial_$suffix');
}

Future<void> _takeScreenshot(WidgetTester tester, String name) async {
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
  final vineIds =
      container.read(vineStatesProvider).keys.toList(growable: false);
  final notifier = container.read(vineStatesProvider.notifier);
  for (final vineId in vineIds) {
    notifier.clearVine(vineId);
  }
}

/// Waits until the game screen has a level loaded with vine states.
///
/// The level loads asynchronously (module registry → mappings → level data),
/// so we poll rather than using a fixed delay.
Future<void> _waitForLevelLoaded(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final gameScreens = find.byType(GameScreen).evaluate();
    if (gameScreens.isEmpty) continue;
    final container = ProviderScope.containerOf(gameScreens.first);
    final levelData = container.read(currentLevelProvider);
    final vineStates = container.read(vineStatesProvider);
    if (levelData != null && vineStates.isNotEmpty) {
      return;
    }
  }
  throw Exception('Level did not load within timeout for screenshot');
}

/// Clears roughly one third of the active vines so the board reads as
/// "mid-puzzle gameplay" rather than a fresh or finished level.
Future<void> _seedMidGameplayVines(WidgetTester tester) async {
  final gameScreens = find.byType(GameScreen).evaluate();
  if (gameScreens.isEmpty) return;
  final container = ProviderScope.containerOf(gameScreens.first);
  final vineStates = container.read(vineStatesProvider);
  final vineIds = vineStates.keys.toList(growable: false);
  if (vineIds.isEmpty) return;

  final notifier = container.read(vineStatesProvider.notifier);
  final toClear = (vineIds.length / 3).ceil().clamp(1, vineIds.length - 1);
  for (var i = 0; i < toClear; i++) {
    notifier.clearVine(vineIds[i]);
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _navigateToHome(WidgetTester tester) async {
  appRouter.go('/');
  await tester.pump();
  await _pumpFor(tester, const Duration(seconds: 1));
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
