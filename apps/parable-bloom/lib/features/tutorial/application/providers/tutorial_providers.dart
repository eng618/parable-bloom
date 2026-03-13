import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game/application/providers/progress_providers.dart';
import '../../domain/entities/lesson_data.dart';

final lessonProvider =
    FutureProvider.family<LessonData, int>((ref, lessonId) async {
  if (lessonId < 1 || lessonId > 5) {
    throw ArgumentError('Lesson ID must be between 1 and 5');
  }

  final json =
      await rootBundle.loadString('assets/lessons/lesson_$lessonId.json');
  final data = jsonDecode(json) as Map<String, dynamic>;
  return LessonData.fromJson(data);
});

final tutorialProgressProvider =
    NotifierProvider<TutorialProgressNotifier, TutorialProgress>(
  TutorialProgressNotifier.new,
);

class TutorialProgress {
  final int currentLesson;
  final Set<int> completedLessons;
  final bool allLessonsCompleted;

  const TutorialProgress({
    required this.currentLesson,
    required this.completedLessons,
    required this.allLessonsCompleted,
  });

  TutorialProgress copyWith({
    int? currentLesson,
    Set<int>? completedLessons,
    bool? allLessonsCompleted,
  }) {
    return TutorialProgress(
      currentLesson: currentLesson ?? this.currentLesson,
      completedLessons: completedLessons ?? this.completedLessons,
      allLessonsCompleted: allLessonsCompleted ?? this.allLessonsCompleted,
    );
  }

  @override
  String toString() =>
      'TutorialProgress(lesson: $currentLesson, completed: $completedLessons)';
}

class TutorialProgressNotifier extends Notifier<TutorialProgress> {
  @override
  TutorialProgress build() {
    final gameProgress = ref.read(gameProgressProvider);
    return TutorialProgress(
      currentLesson: gameProgress.currentLesson ?? 1,
      completedLessons: gameProgress.completedLessons,
      allLessonsCompleted: gameProgress.lessonCompleted,
    );
  }

  Future<void> completeLesson(int lessonId) async {
    if (lessonId < 1 || lessonId > 5) {
      throw ArgumentError('Lesson ID must be between 1 and 5');
    }

    final newCompleted = Set<int>.from(state.completedLessons)..add(lessonId);
    final allComplete = newCompleted.length == 5;
    final nextLesson = allComplete ? null : lessonId + 1;

    await ref.read(gameProgressProvider.notifier).completeLesson(
          lessonId: lessonId,
          nextLesson: nextLesson,
          allLessonsCompleted: allComplete,
        );

    state = state.copyWith(
      currentLesson: nextLesson,
      completedLessons: newCompleted,
      allLessonsCompleted: allComplete,
    );
  }

  Future<void> resetAllLessons() async {
    state = state.copyWith(
      currentLesson: 1,
      completedLessons: {},
      allLessonsCompleted: false,
    );

    await ref.read(gameProgressProvider.notifier).resetLessons();
  }

  void setCurrentLesson(int lessonId) {
    if (lessonId < 1 || lessonId > 5) {
      throw ArgumentError('Lesson ID must be between 1 and 5');
    }
    state = state.copyWith(currentLesson: lessonId);
  }

  void resetForReplay() {
    state = const TutorialProgress(
      currentLesson: 1,
      completedLessons: {},
      allLessonsCompleted: false,
    );
  }
}
