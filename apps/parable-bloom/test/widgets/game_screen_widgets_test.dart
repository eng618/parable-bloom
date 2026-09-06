import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parable_bloom/features/game/application/providers/camera_providers.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/presentation/widgets/game_state_dialogs.dart';
import 'package:parable_bloom/features/game/presentation/widgets/game_zoom_controls.dart';
import 'package:parable_bloom/features/game/presentation/widgets/level_complete_overlay.dart';

LevelData _level() => LevelData(
      id: 'lvl_m01_01',
      name: 'Test',
      difficulty: 'easy',
      gridWidth: 4,
      gridHeight: 4,
      maxMoves: 10,
      minMoves: 1,
      complexity: 'low',
      grace: 3,
      mask: MaskData(mode: 'show-all', points: []),
      vines: const [],
    );

void main() {
  group('LevelCompleteOverlay', () {
    testWidgets('shows title and message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LevelCompleteOverlay(message: 'Well done!'),
          ),
        ),
      );

      expect(find.text('Level Complete'), findsOneWidget);
      expect(find.text('Well done!'), findsOneWidget);
      expect(find.byIcon(Icons.celebration), findsOneWidget);
    });
  });

  group('GameZoomControls', () {
    testWidgets('renders nothing without a level', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Stack(children: [GameZoomControls()]),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('zoom in updates camera state', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(currentLevelProvider.notifier).setLevel(_level());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(children: [GameZoomControls()]),
            ),
          ),
        ),
      );

      final before = container.read(cameraStateProvider).zoom;
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(container.read(cameraStateProvider).zoom, greaterThan(before));
    });
  });

  group('game state dialogs', () {
    testWidgets('completed dialog invokes callback', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGameCompletedDialog(
                context,
                onBackToHome: () => called = true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('CONGRATULATIONS!'), findsOneWidget);

      await tester.tap(find.text('BACK TO HOME'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });

    testWidgets('game over dialog invokes callback', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGameOverDialog(
                context,
                onTryAgain: () => called = true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('OUT OF GRACE'), findsOneWidget);

      await tester.tap(find.text('TRY AGAIN'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });
  });
}
