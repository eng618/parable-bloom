import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parable_bloom/core/providers/infrastructure_providers.dart';
import 'package:parable_bloom/features/game/application/providers/module_providers.dart';
import 'package:parable_bloom/features/game/application/providers/progress_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';

/// New cloud levels arrive after a profile finished everything:
/// playlist [lvl_m01_01, lvl_m01_02, lvl_m01_03], completed {lvl_m01_01},
/// but the persisted pointer names a since-removed ID.
ModuleData _module() => ModuleData.fromJson({
      'id': 1,
      'name': 'Module 1',
      'theme_seed': 'forest',
      'levels': ['lvl_m01_01', 'lvl_m01_02', 'lvl_m01_03'],
      'challenge_level': '',
      'parable': <String, dynamic>{},
      'unlock_message': '',
      'scriptures': [],
    });

Map<String, dynamic> _seedJson({
  required String currentLevel,
  required List<String> completed,
}) =>
    GameProgress.initial().copyWith(
      currentLevel: currentLevel,
      completedLevels: Set<String>.from(completed),
      tutorialCompleted: true,
    ).toJson();

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      gameProgressRepositoryProvider.overrideWith(
        (ref) => ref.watch(localGameProgressRepositoryProvider),
      ),
      modulesProvider.overrideWith((ref) async => [_module()]),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _seed(ProviderContainer container, Map<String, dynamic> json) {
  final box = container.read(hiveBoxProvider);
  return box.put('progress', json);
}

void main() {
  group('GameProgress.nextUncompletedLevel', () {
    test('returns first uncompleted level', () {
      final progress = GameProgress.initial().copyWith(
        completedLevels: {'lvl_m01_01'},
      );
      expect(
        progress.nextUncompletedLevel(
            ['lvl_m01_01', 'lvl_m01_02', 'lvl_m01_03']),
        'lvl_m01_02',
      );
    });

    test('returns null when everything is completed', () {
      final progress = GameProgress.initial().copyWith(
        completedLevels: {'lvl_m01_01', 'lvl_m01_02'},
      );
      expect(
        progress.nextUncompletedLevel(['lvl_m01_01', 'lvl_m01_02']),
        isNull,
      );
    });

    test('returns null for an empty playlist (registry unavailable)', () {
      final progress = GameProgress.initial();
      expect(progress.nextUncompletedLevel([]), isNull);
    });
  });

  group('GameProgressNotifier.healCurrentLevel', () {
    test('heals dangling pointer to first uncompleted level', () async {
      final container = _container();
      await _seed(container, _seedJson(
        currentLevel: 'lvl_m99_99',
        completed: ['lvl_m01_01'],
      ));
      final notifier = container.read(gameProgressProvider.notifier);
      await notifier.initialize();

      final healed = await notifier.healCurrentLevel();

      expect(healed, 'lvl_m01_02');
      expect(container.read(gameProgressProvider).currentLevel, 'lvl_m01_02');
    });

    test('leaves a valid pointer untouched', () async {
      final container = _container();
      await _seed(container, _seedJson(
        currentLevel: 'lvl_m01_02',
        completed: ['lvl_m01_01'],
      ));
      final notifier = container.read(gameProgressProvider.notifier);
      await notifier.initialize();

      final healed = await notifier.healCurrentLevel();

      expect(healed, 'lvl_m01_02');
      expect(container.read(gameProgressProvider).currentLevel, 'lvl_m01_02');
    });

    test('returns null when everything is completed (truly finished)',
        () async {
      final container = _container();
      await _seed(container, _seedJson(
        currentLevel: 'lvl_m01_03',
        completed: ['lvl_m01_01', 'lvl_m01_02', 'lvl_m01_03'],
      ));
      final notifier = container.read(gameProgressProvider.notifier);
      await notifier.initialize();

      expect(await notifier.healCurrentLevel(), isNull);
    });
  });
}
