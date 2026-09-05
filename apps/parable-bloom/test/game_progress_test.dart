import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';

void main() {
  group('GameProgress Equality', () {
    test('initial state should be equal to another initial state', () {
      final p1 = GameProgress.initial();
      final p2 = GameProgress.initial();
      expect(p1, equals(p2));
    });

    test('changing tutorialCompleted should make objects unequal', () {
      final p1 = GameProgress.initial();
      final p2 = p1.copyWith(tutorialCompleted: true);
      expect(p1, isNot(equals(p2)));
    });

    test('changing currentLesson should make objects unequal', () {
      final p1 = GameProgress.initial();
      final p2 = p1.copyWith(currentLesson: 'lesson_2');
      expect(p1, isNot(equals(p2)));
    });

    test('changing completedLessons should make objects unequal', () {
      final p1 = GameProgress.initial();
      final p2 = p1.copyWith(completedLessons: {'lesson_1'});
      expect(p1, isNot(equals(p2)));
    });

    test('changing lessonCompleted should make objects unequal', () {
      final p1 = GameProgress.initial();
      final p2 = p1.copyWith(lessonCompleted: true);
      expect(p1, isNot(equals(p2)));
    });

    test('changing savedMainGameLevel should make objects unequal', () {
      final p1 = GameProgress.initial();
      final p2 = p1.copyWith(savedMainGameLevel: 'lvl_m01_05');
      expect(p1, isNot(equals(p2)));
    });

    test('Objects with same values should be equal', () {
      final p1 = GameProgress(
        currentLesson: 'lesson_2',
        completedLessons: {'lesson_1'},
        lessonCompleted: false,
        currentLevel: 'lvl_m01_01',
        completedLevels: {},
        tutorialCompleted: false,
        savedMainGameLevel: null,
        unlockedTranslations: {},
        unlockedScriptureIds: {},
      );
      final p2 = GameProgress(
        currentLesson: 'lesson_2',
        completedLessons: {'lesson_1'},
        lessonCompleted: false,
        currentLevel: 'lvl_m01_01',
        completedLevels: {},
        tutorialCompleted: false,
        savedMainGameLevel: null,
        unlockedTranslations: {},
        unlockedScriptureIds: {},
      );
      expect(p1, equals(p2));
    });
  });

  group('GameProgress Legacy Migration', () {
    test('correctly maps legacy level integers across all modules', () {
      final legacyJson = {
        'currentLesson': 1,
        'completedLessons': [1, 2, 3, 4, 5],
        'lessonCompleted': true,
        'currentLevel': 96,
        'completedLevels': [
          1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
          21, // Seedling
          22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38,
          39, 40, 41, 42, // Sprout
          43, 63, // Blossom start & challenge
          64, 84, // Flourish start & challenge
          85, 96, 105, // Harvest
        ],
        'tutorialCompleted': true,
        'savedMainGameLevel': 22,
      };

      final progress = GameProgress.fromJson(legacyJson);

      expect(progress.currentLesson, equals('lesson_1'));
      expect(progress.completedLessons,
          equals({'lesson_1', 'lesson_2', 'lesson_3', 'lesson_4', 'lesson_5'}));
      expect(progress.currentLevel, equals('lvl_m05_12')); // 96 - 84 = 12
      expect(
          progress.savedMainGameLevel, equals('lvl_m02_01')); // 22 - 21 = 1

      // Seedling levels check
      for (int i = 1; i <= 20; i++) {
        final idxStr = i < 10 ? '0$i' : '$i';
        expect(progress.completedLevels.contains('lvl_m01_$idxStr'), isTrue,
            reason: 'Should contain lvl_m01_$idxStr');
      }
      expect(progress.completedLevels.contains('lvl_m01_challenge'), isTrue);

      // Sprout levels check
      for (int i = 1; i <= 20; i++) {
        final idxStr = i < 10 ? '0$i' : '$i';
        expect(progress.completedLevels.contains('lvl_m02_$idxStr'), isTrue,
            reason: 'Should contain lvl_m02_$idxStr');
      }
      expect(progress.completedLevels.contains('lvl_m02_challenge'), isTrue);

      // Blossom, Flourish, Harvest spot checks
      expect(progress.completedLevels.contains('lvl_m03_01'), isTrue);
      expect(
          progress.completedLevels.contains('lvl_m03_challenge'), isTrue);
      expect(progress.completedLevels.contains('lvl_m04_01'), isTrue);
      expect(
          progress.completedLevels.contains('lvl_m04_challenge'), isTrue);
      expect(progress.completedLevels.contains('lvl_m05_01'), isTrue);
      expect(progress.completedLevels.contains('lvl_m05_12'), isTrue);
      expect(
          progress.completedLevels.contains('lvl_m05_challenge'), isTrue);
    });

    test('migrates pre-standardization string IDs to the generic scheme', () {
      final progress = GameProgress.fromJson({
        'currentLesson': 'lesson_1',
        'completedLessons': ['lesson_1'],
        'lessonCompleted': false,
        'currentLevel': 'lvl_sprout_05',
        'completedLevels': ['lvl_seed_01', 'lvl_sprout_challenge', 'lvl_m03_07'],
        'tutorialCompleted': false,
        'savedMainGameLevel': 'lvl_harvest_20',
        'unlockedTranslations': {},
        'unlockedScriptureIds': [],
      });

      expect(progress.currentLevel, equals('lvl_m02_05'));
      expect(
          progress.completedLevels,
          equals({'lvl_m01_01', 'lvl_m02_challenge', 'lvl_m03_07'}));
      expect(progress.savedMainGameLevel, equals('lvl_m05_20'));
    });
  });
}
