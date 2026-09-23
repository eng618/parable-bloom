import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parable_bloom/features/game/application/providers/progress_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/features/game/application/providers/module_providers.dart';
import 'package:parable_bloom/core/services/scripture_service.dart';
import 'package:parable_bloom/core/providers/service_providers.dart';
import 'package:parable_bloom/features/game/domain/repositories/game_progress_repository.dart';
import 'package:parable_bloom/core/providers/infrastructure_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/journal/application/providers/journal_providers.dart';
import 'package:parable_bloom/features/journal/domain/entities/journal_theme.dart';

class MockScriptureService implements ScriptureService {
  @override
  Future<String> pickRandomActiveTranslation() async {
    return 'KJV';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockGameProgressRepository implements GameProgressRepository {
  GameProgress _progress = GameProgress.initial();
  @override
  Future<GameProgress> getProgress() async => _progress;
  @override
  Future<void> saveProgress(GameProgress progress) async {
    _progress = progress;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Benchmark completeLevel', () async {
    final container = ProviderContainer(overrides: [
      scriptureServiceProvider.overrideWithValue(MockScriptureService()),
      gameProgressRepositoryProvider
          .overrideWithValue(MockGameProgressRepository()),
      modulesProvider.overrideWith((ref) => List.generate(
          5,
          (i) => ModuleData(
              id: i,
              name: 'Module $i',
              themeSeed: 'Theme',
              challengeLevel: 'm${i}_c',
              levels: ['m${i}_1', 'm${i}_2'],
              parable: {},
              unlockMessage: '',
              scriptures: List.generate(
                  200,
                  (j) => ModuleScripture(
                        id: 'm${i}_s${j}',
                        reference: 'Ref $j',
                        triggerLevel: 'test_level',
                        title: 'T',
                        type: 'starter',
                      ))))),
      journalThemesProvider.overrideWith((ref) => List.generate(
          2,
          (i) => JournalTheme(
              id: 't$i',
              name: 'Theme $i',
              description: '',
              icon: 'icon',
              passages: List.generate(
                  50,
                  (j) => JournalPassage(
                        id: 't${i}_p${j}',
                        reference: 'Ref',
                        triggerLevel: 'test_level',
                        themeId: 't$i',
                        title: 'T',
                        type: 'type',
                        reflectionPrompts: [],
                      ))))),
    ]);

    final notifier = container.read(gameProgressProvider.notifier);

    // wait for overrides
    await container.read(modulesProvider.future);
    await container.read(journalThemesProvider.future);

    final stopwatch = Stopwatch()..start();
    await notifier.completeLevel('test_level');
    stopwatch.stop();
    print('Baseline completeLevel took: ${stopwatch.elapsedMilliseconds} ms');
  });
}
