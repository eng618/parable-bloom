import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parable_bloom/features/tutorial/application/providers/tutorial_providers.dart';
import 'mock_repository_example_test.dart';
import 'package:parable_bloom/features/game/application/providers/progress_providers.dart';
import 'package:parable_bloom/core/providers/infrastructure_providers.dart';
import 'package:parable_bloom/features/game/application/providers/module_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TutorialProgressNotifier completes a lesson and updates GameProgress',
      () async {
    final mockRepo = MockGameProgressRepository();
    final modules = [
      ModuleData(
        id: 1,
        name: 'Seedling',
        themeSeed: 'forest',
        levels: const [],
        challengeLevel: '',
        parable: const {},
        unlockMessage: '',
        scriptures: const [],
      ),
    ];
    final container = ProviderContainer(
      overrides: [
        gameProgressRepositoryProvider.overrideWithValue(mockRepo),
        modulesProvider.overrideWithValue(AsyncValue.data(modules)),
      ],
    );
    addTearDown(container.dispose);

    // initialize GameProgressNotifier to load from repo
    await container.read(gameProgressProvider.notifier).initialize();

    final notifier = container.read(tutorialProgressProvider.notifier);

    expect(container.read(tutorialProgressProvider).currentLesson, 1);
    expect(container.read(tutorialProgressProvider).completedLessons, isEmpty);
    expect(container.read(tutorialProgressProvider).allLessonsCompleted, false);

    await notifier.completeLesson(1);

    final state = container.read(tutorialProgressProvider);
    expect(state.currentLesson, 2);
    expect(state.completedLessons.contains(1), isTrue);
    expect(state.allLessonsCompleted, isFalse);

    final saved = await mockRepo.getProgress();
    expect(saved.completedLessons.contains('lesson_1'), isTrue);
  });

  test('Completing all lessons marks allComplete and sets currentLevel to 1',
      () async {
    final mockRepo = MockGameProgressRepository();
    final modules = [
      ModuleData(
        id: 1,
        name: 'Seedling',
        themeSeed: 'forest',
        levels: const [],
        challengeLevel: '',
        parable: const {},
        unlockMessage: '',
        scriptures: [
          ModuleScripture(
            id: 'seed_starter',
            triggerLevel: 'lesson_5',
            reference: 'Luke 8:11',
            title: 'The Seed is the Word',
            type: 'starter',
          ),
        ],
      ),
    ];
    final container = ProviderContainer(
      overrides: [
        gameProgressRepositoryProvider.overrideWithValue(mockRepo),
        modulesProvider.overrideWithValue(AsyncValue.data(modules)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(gameProgressProvider.notifier).initialize();
    final notifier = container.read(tutorialProgressProvider.notifier);

    for (var i = 1; i <= 5; i++) {
      await notifier.completeLesson(i);
    }

    final state = container.read(tutorialProgressProvider);
    expect(state.allLessonsCompleted, isTrue);
    // currentLesson remains as last played lesson (5), TutorialProgress keeps an int
    expect(state.currentLesson, equals(5));

    final saved = await mockRepo.getProgress();
    expect(saved.lessonCompleted, isTrue);
    expect(saved.currentLevel, 'lvl_seed_01');
  });
}
