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
      final p2 = p1.copyWith(savedMainGameLevel: 'lvl_seed_05');
      expect(p1, isNot(equals(p2)));
    });

    test('Objects with same values should be equal', () {
      final p1 = GameProgress(
        currentLesson: 'lesson_2',
        completedLessons: {'lesson_1'},
        lessonCompleted: false,
        currentLevel: 'lvl_seed_01',
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
        currentLevel: 'lvl_seed_01',
        completedLevels: {},
        tutorialCompleted: false,
        savedMainGameLevel: null,
        unlockedTranslations: {},
        unlockedScriptureIds: {},
      );
      expect(p1, equals(p2));
    });
  });
}
