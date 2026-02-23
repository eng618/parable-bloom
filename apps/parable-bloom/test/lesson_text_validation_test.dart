import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/tutorial/domain/entities/lesson_data.dart';

void main() {
  final lessonsDir = Directory('assets/lessons');

  test('Lesson text validation for all lessons', () {
    final lessonFiles = lessonsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('lesson_') && f.path.endsWith('.json'))
        .toList();

    for (final file in lessonFiles) {
      final jsonMap =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;

      // Should not throw
      final lesson = LessonData.fromJson(jsonMap);

      expect(lesson.title.isNotEmpty, isTrue);
      expect(lesson.title.length <= 80, isTrue);

      expect(lesson.objective.isNotEmpty, isTrue);
      expect(lesson.objective.length <= 120, isTrue);

      expect(lesson.instructions.isNotEmpty, isTrue);
      expect(lesson.instructions.length <= 200, isTrue);

      expect(lesson.learningPoints.length >= 2, isTrue);
      for (final p in lesson.learningPoints) {
        expect(p.isNotEmpty, isTrue);
        expect(p.length <= 80, isTrue);
      }
    }
  });

  test('LessonData.fromJson rejects too-long instruction', () {
    final jsonMap = {
      'id': 99,
      'title': 'Test',
      'objective': 'obj',
      'instructions': 'a' * 1000,
      'learning_points': ['one', 'two'],
      'grid_size': [4, 4],
      'vines': []
    };

    expect(() => LessonData.fromJson(jsonMap), throwsFormatException);
  });
}
