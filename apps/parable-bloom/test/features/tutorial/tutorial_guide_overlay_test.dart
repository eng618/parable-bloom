import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/tutorial/domain/entities/lesson_data.dart';
import 'package:parable_bloom/features/tutorial/presentation/widgets/tutorial_guide_overlay.dart';
import 'package:parable_bloom/features/game/presentation/widgets/garden_game.dart';
import 'package:parable_bloom/features/game/presentation/widgets/grid_component.dart';

class MockTutorialGardenGame extends GardenGame {
  final Vector2 mockSize;
  MockTutorialGardenGame(this.mockSize)
      : super(
          callbacks: GardenGameCallbacks(
            onGameLoaded: (_) {},
            onGameRemoved: () {},
            onVineCleared: (_) {},
            onVineAnimationStateChanged: (_, __) {},
            onVineAttempted: (_) {},
            onTapIncrement: (_) {},
            onTapOutsideGrid: () {},
            getUseSimpleVines: () => false,
            getHapticsEnabled: () => false,
          ),
        ) {
    grid = GridComponent(
      cellSize: 48,
      onVineCleared: (_) {},
      onVineTap: (_) {},
      onVineAnimationStateChanged: (_, __) {},
      onVineAttempted: (_) {},
      onTapIncrement: (_) {},
      onTapEffect: (_) {},
    );
  }

  @override
  bool get isGridInitialized => true;

  @override
  Vector2 get size => mockSize;

  @override
  Offset getCellScreenPosition(int x, int y) {
    return Offset(100.0 + x * 20.0, 200.0 + y * 20.0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TutorialGuideOverlay Tests', () {
    testWidgets('Renders prompt and pulse indicator for lesson_1 level ID',
        (WidgetTester tester) async {
      const lesson1 = LessonData(
        id: 1,
        title: 'Clear the Vine',
        objective: 'Learn to select and clear a single vine',
        instructions: 'Tap the vine to clear it',
        learningPoints: ['Point 1', 'Point 2'],
        gridWidth: 4,
        gridHeight: 4,
        vines: [
          LessonVineData(
            id: 'vine_1',
            headDirection: 'right',
            orderedPath: [
              {'x': 3, 'y': 1},
              {'x': 2, 'y': 1},
              {'x': 1, 'y': 1},
              {'x': 0, 'y': 1},
            ],
          ),
        ],
      );

      final levelData = lesson1.toLevelData();
      final game = MockTutorialGardenGame(Vector2(400, 600));

      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  TutorialGuideOverlay(),
                ],
              ),
            ),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TutorialGuideOverlay)),
      );

      container.read(currentLevelProvider.notifier).setLevel(levelData);
      container.read(vineStatesProvider.notifier).resetForLevel(levelData);
      container.read(gameInstanceProvider.notifier).setGame(game);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify prompt text is displayed
      expect(find.text('Tap head to slide'), findsOneWidget);
      // Verify touch indicator icon is displayed
      expect(find.byIcon(Icons.touch_app), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Renders collision path when blocked tap occurs',
        (WidgetTester tester) async {
      const lesson3 = LessonData(
        id: 3,
        title: 'Blocking Mechanics',
        objective: 'Learn blocking',
        instructions: 'Clear blocker first',
        learningPoints: ['Point 1', 'Point 2'],
        gridWidth: 5,
        gridHeight: 5,
        vines: [
          LessonVineData(
            id: 'vine_1',
            headDirection: 'right',
            orderedPath: [
              {'x': 3, 'y': 1},
              {'x': 2, 'y': 1},
            ],
          ),
          LessonVineData(
            id: 'vine_2',
            headDirection: 'down',
            orderedPath: [
              {'x': 4, 'y': 0},
              {'x': 4, 'y': 1},
            ],
          ),
        ],
      );

      final levelData = lesson3.toLevelData();
      final game = MockTutorialGardenGame(Vector2(400, 600));

      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  TutorialGuideOverlay(),
                ],
              ),
            ),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TutorialGuideOverlay)),
      );

      container.read(currentLevelProvider.notifier).setLevel(levelData);
      container.read(vineStatesProvider.notifier).resetForLevel(levelData);
      container.read(gameInstanceProvider.notifier).setGame(game);

      // Trigger blocked tap event
      container.read(blockedTapProvider.notifier).setBlockedTap(
            BlockedTapState(
              headPosition: const Offset(100, 100),
              blockerPosition: const Offset(150, 150),
              timestamp: DateTime.now(),
            ),
          );

      await tester.pump();

      expect(find.text('Blocked! Blocker first'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
