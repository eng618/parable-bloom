import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import '../../features/tutorial/domain/entities/lesson_data.dart';
import '../../providers/game_providers.dart';

/// Provides lesson data by ID (1-5)
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

/// Tracks the current lesson and completion state
final tutorialProgressProvider =
    NotifierProvider<TutorialProgressNotifier, TutorialProgress>(
  TutorialProgressNotifier.new,
);

class TutorialProgress {
  final int currentLesson; // 1-5
  final Set<int> completedLessons; // Which lessons completed (1-5)
  final bool allLessonsCompleted; // True when all 5 complete

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
    // Get initial state from game progress
    final gameProgress = ref.read(gameProgressProvider);
    return TutorialProgress(
      currentLesson: gameProgress.currentLesson ?? 1,
      completedLessons: gameProgress.completedLessons,
      allLessonsCompleted: gameProgress.lessonCompleted,
    );
  }

  /// Completes the current lesson and moves to next or marks all complete
  Future<void> completeLesson(int lessonId) async {
    if (lessonId < 1 || lessonId > 5) {
      throw ArgumentError('Lesson ID must be between 1 and 5');
    }

    final newCompleted = Set<int>.from(state.completedLessons)..add(lessonId);
    final allComplete = newCompleted.length == 5;
    final nextLesson = allComplete ? null : lessonId + 1;

    state = state.copyWith(
      currentLesson: nextLesson,
      completedLessons: newCompleted,
      allLessonsCompleted: allComplete,
    );

    // Debug log for progression
    print(
        'TutorialProgressNotifier: Completed $lessonId -> next: $nextLesson allComplete: $allComplete');

    // Update game progress to reflect lesson completion
    await ref.read(gameProgressProvider.notifier).completeLesson(
          lessonId: lessonId,
          nextLesson: nextLesson,
          allLessonsCompleted: allComplete,
        );

    print('TutorialProgressNotifier: GameProgress updated');
  }

  /// Resets all lessons (for replay)
  Future<void> resetAllLessons() async {
    state = state.copyWith(
      currentLesson: 1,
      completedLessons: {},
      allLessonsCompleted: false,
    );

    // Update game progress
    await ref.read(gameProgressProvider.notifier).resetLessons();
  }

  /// Sets a specific lesson as current (for navigation)
  void setCurrentLesson(int lessonId) {
    if (lessonId < 1 || lessonId > 5) {
      throw ArgumentError('Lesson ID must be between 1 and 5');
    }
    state = state.copyWith(currentLesson: lessonId);
  }
}
