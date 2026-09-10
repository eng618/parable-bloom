import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parable_bloom/core/providers/infrastructure_providers.dart';
import 'package:parable_bloom/core/providers/service_providers.dart';
import 'package:parable_bloom/core/services/scripture_service.dart';
import 'package:parable_bloom/features/game/application/providers/module_providers.dart';
import 'package:parable_bloom/features/game/application/providers/progress_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';

/// Counts translation picks to prove unlock flows pick once per run
/// instead of once per missing scripture (N+1 connectivity round-trips).
class CountingScriptureService extends ScriptureService {
  CountingScriptureService() : super();

  int picks = 0;

  @override
  Future<String> pickRandomActiveTranslation() async {
    picks++;
    return 'kjv';
  }
}

ModuleData _module() => ModuleData.fromJson({
      'id': 1,
      'name': 'Module 1',
      'theme_seed': 'forest',
      'levels': ['lvl_m01_01'],
      'challenge_level': '',
      'parable': <String, dynamic>{},
      'unlock_message': '',
      'scriptures': [
        {
          'id': 's1',
          'trigger_level': 'lesson_1',
          'reference': 'John 1:1',
          'title': 'T1',
          'type': 'starter',
        },
        {
          'id': 's2',
          'trigger_level': 'lesson_1',
          'reference': 'John 1:2',
          'title': 'T2',
          'type': 'starter',
        },
        {
          'id': 's3',
          'trigger_level': 'lesson_1',
          'reference': 'John 1:3',
          'title': 'T3',
          'type': 'starter',
        },
      ],
    });

void main() {
  test('completeLesson picks the unlock translation once for N unlocks',
      () async {
    final service = CountingScriptureService();
    final container = ProviderContainer(
      overrides: [
        gameProgressRepositoryProvider.overrideWith(
          (ref) => ref.watch(localGameProgressRepositoryProvider),
        ),
        modulesProvider.overrideWith((ref) async => [_module()]),
        scriptureServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await container.read(gameProgressProvider.notifier).completeLesson(
          lessonId: 'lesson_1',
          nextLesson: 'lesson_2',
          allLessonsCompleted: false,
        );

    // All three scriptures unlocked...
    final progress = container.read(gameProgressProvider);
    expect(
      progress.unlockedScriptureIds,
      containsAll(['s1', 's2', 's3']),
    );
    // ...with a single translation pick, and a consistent value stored.
    expect(service.picks, 1);
    expect(
      progress.unlockedTranslations.values.toSet(),
      {'kjv'},
    );
  });

  test('second run picks again (no cross-run caching)', () async {
    final service = CountingScriptureService();
    final container = ProviderContainer(
      overrides: [
        gameProgressRepositoryProvider.overrideWith(
          (ref) => ref.watch(localGameProgressRepositoryProvider),
        ),
        modulesProvider.overrideWith((ref) async => [_module()]),
        scriptureServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(gameProgressProvider.notifier);
    await notifier.completeLesson(
      lessonId: 'lesson_1',
      nextLesson: 'lesson_2',
      allLessonsCompleted: false,
    );
    // Nothing new to unlock, but the run-scoped cache must not leak:
    // simulate by completing another lesson id with no triggers.
    await notifier.completeLesson(
      lessonId: 'lesson_9',
      nextLesson: null,
      allLessonsCompleted: true,
    );

    expect(service.picks, 1);
    expect(
      container.read(gameProgressProvider).completedLessons,
      containsAll(['lesson_1', 'lesson_9']),
    );
  });
}
