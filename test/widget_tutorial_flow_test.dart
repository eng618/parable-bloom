import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parable_bloom/features/tutorial/domain/entities/lesson_data.dart';
import 'package:hive/hive.dart';
import 'package:parable_bloom/providers/game_providers.dart';
import 'package:parable_bloom/providers/tutorial_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/features/game/domain/repositories/game_progress_repository.dart';
import 'package:parable_bloom/features/tutorial/presentation/screens/tutorial_flow_screen.dart';

class _InMemoryRepo implements GameProgressRepository {
  GameProgress _progress = GameProgress.initial();

  @override
  Future<GameProgress> getProgress() async => _progress;

  @override
  Future<void> saveProgress(GameProgress progress) async {
    _progress = progress;
  }

  @override
  Future<void> resetProgress() async {
    _progress = GameProgress.initial();
  }

  @override
  Future<void> syncToCloud() async {}

  @override
  Future<DateTime?> getLastSyncTime() async => null;

  @override
  Future<bool> isCloudSyncAvailable() async => false;

  @override
  Future<void> setCloudSyncEnabled(bool enabled) async {}

  @override
  Future<bool> isCloudSyncEnabled() async => false;
}

// Minimal fake Hive Box to avoid initializing Hive in widget tests.
class _FakeBox implements Box<dynamic> {
  final Map _store = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _store.containsKey(key) ? _store[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => _store[key] = value;

  @override
  Future<void> delete(dynamic key) async => _store.remove(key);

  @override
  Future<int> clear() async {
    final len = _store.length;
    _store.clear();
    return len;
  }

  @override
  bool containsKey(dynamic key) => _store.containsKey(key);

  @override
  Iterable get keys => _store.keys;

  @override
  Iterable get values => _store.values;

  @override
  Map toMap() => Map.from(_store);

  @override
  int get length => _store.length;

  @override
  String get name => 'fake_box';

  @override
  bool get isOpen => true;

  @override
  Future<void> close() async {}

  // Use noSuchMethod to gracefully handle other Box API calls we don't need here.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Level complete advances to next lesson', (tester) async {
    final repo = _InMemoryRepo();
    final overrides = [
      hiveBoxProvider.overrideWithValue(_FakeBox()),
      gameProgressRepositoryProvider.overrideWithValue(repo),
      disableAnimationsProvider.overrideWithValue(true),
      lessonProvider(1).overrideWithValue(
        const AsyncValue.data(
          LessonData(
            id: 1,
            title: 'Test',
            objective: 'Test objective',
            instructions: 'inst',
            learningPoints: ['p1', 'p2'],
            gridWidth: 3,
            gridHeight: 3,
            vines: [],
          ),
        ),
      ),
      lessonProvider(2).overrideWithValue(
        const AsyncValue.data(
          LessonData(
            id: 2,
            title: 'Test2',
            objective: 'obj',
            instructions: 'inst',
            learningPoints: ['p1', 'p2'],
            gridWidth: 3,
            gridHeight: 3,
            vines: [
              LessonVineData(id: 'v2', headDirection: 'right', orderedPath: [
                {'x': 2, 'y': 1},
                {'x': 1, 'y': 1},
              ])
            ],
          ),
        ),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: const TutorialFlowScreen(),
        ),
      ),
    );

    // Allow widgets to build (single frame to avoid heavy Flame rendering)
    await tester.pump();

    // Wait for widgets to build fully
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Verify GameHeader is present (pause button)
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    // Simulate level complete
    final container = ProviderScope.containerOf(
        tester.element(find.byType(TutorialFlowScreen)));
    container.read(levelCompleteProvider.notifier).setComplete(true);
    // Pump once to process the completion listener
    await tester.pump();

    // Level complete overlay should show (celebration icon)
    expect(find.byIcon(Icons.celebration), findsOneWidget);

    // Wait for the 2-second delay and lesson advancement
    await tester.pump(const Duration(seconds: 3));

    // TutorialProgress should have advanced to lesson 2
    final progress = container.read(tutorialProgressProvider);
    expect(progress.currentLesson, equals(2));
  });

  testWidgets('Completing all lessons navigates home', (tester) async {
    final repo = _InMemoryRepo();
    final overrides = [
      hiveBoxProvider.overrideWithValue(_FakeBox()),
      gameProgressRepositoryProvider.overrideWithValue(repo),
      disableAnimationsProvider.overrideWithValue(true),
      lessonProvider(1).overrideWithValue(const AsyncValue.data(
        LessonData(
          id: 1,
          title: 'L1',
          objective: 'o',
          instructions: 'i',
          learningPoints: ['a', 'b'],
          gridWidth: 3,
          gridHeight: 3,
          vines: [],
        ),
      )),
      lessonProvider(2).overrideWithValue(const AsyncValue.data(
        LessonData(
          id: 2,
          title: 'L2',
          objective: 'o',
          instructions: 'i',
          learningPoints: ['a', 'b'],
          gridWidth: 3,
          gridHeight: 3,
          vines: [],
        ),
      )),
      lessonProvider(3).overrideWithValue(const AsyncValue.data(
        LessonData(
          id: 3,
          title: 'L3',
          objective: 'o',
          instructions: 'i',
          learningPoints: ['a', 'b'],
          gridWidth: 3,
          gridHeight: 3,
          vines: [],
        ),
      )),
      lessonProvider(4).overrideWithValue(const AsyncValue.data(
        LessonData(
          id: 4,
          title: 'L4',
          objective: 'o',
          instructions: 'i',
          learningPoints: ['a', 'b'],
          gridWidth: 3,
          gridHeight: 3,
          vines: [],
        ),
      )),
      lessonProvider(5).overrideWithValue(const AsyncValue.data(
        LessonData(
          id: 5,
          title: 'L5',
          objective: 'o',
          instructions: 'i',
          learningPoints: ['a', 'b'],
          gridWidth: 3,
          gridHeight: 3,
          vines: [],
        ),
      )),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          initialRoute: '/tutorial',
          routes: {
            '/': (ctx) => const Scaffold(body: Center(child: Text('Home'))),
            '/tutorial': (ctx) => const TutorialFlowScreen(),
          },
        ),
      ),
    );

    // Allow widgets to build (single frame)
    await tester.pump();

    for (var i = 1; i <= 5; i++) {
      final container = ProviderScope.containerOf(
          tester.element(find.byType(TutorialFlowScreen)));
      container.read(levelCompleteProvider.notifier).setComplete(true);
      await tester.pump();

      // Level complete overlay should show (celebration icon)
      expect(find.byIcon(Icons.celebration), findsOneWidget);

      // Wait for the 2-second delay
      await tester.pump(const Duration(seconds: 3));
    }

    // Final pump to allow navigation to replace the route
    await tester.pumpAndSettle();

    // After finishing all lessons, we should navigate to Home
    expect(find.text('Home'), findsOneWidget);
  });

  // TODO: Fix Flame timer disposal issue in test environment
  /*
  testWidgets('GameHeader pause button shows pause menu', (tester) async {
    final repo = _InMemoryRepo();
    final overrides = [
      hiveBoxProvider.overrideWithValue(_FakeBox()),
      gameProgressRepositoryProvider.overrideWithValue(repo),
      disableAnimationsProvider.overrideWithValue(true),
      lessonProvider(1).overrideWithValue(
        const AsyncValue.data(
          LessonData(
            id: 1,
            title: 'Test',
            objective: 'Test objective',
            instructions: 'inst',
            learningPoints: ['p1', 'p2'],
            gridWidth: 3,
            gridHeight: 3,
            vines: [],
          ),
        ),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: const TutorialFlowScreen(),
        ),
      ),
    );

    // Wait for widgets to build fully
    // Use pump instead of pumpAndSettle to avoid timeout from Flame game loop
    await tester.pump(const Duration(milliseconds: 100));

    // Tap the pause button (use warnIfMissed: false because Flame game overlays may affect hit testing)
    await tester.tap(find.byIcon(Icons.pause_rounded), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Pause menu should show with "Paused" text
    expect(find.text('Paused'), findsOneWidget);

    // Verify Home and Restart buttons are present
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);

    // Drain any pending timers from the game loop
    await tester.pump(const Duration(seconds: 1));
  });
  */
}
