class GameProgress {
  // Lesson tracking (separate from levels)
  final int? currentLesson; // 1-5 if in tutorial, null if tutorial complete
  final Set<int> completedLessons; // Which lessons (1-5) have been completed
  final bool lessonCompleted; // True after all 5 lessons done

  // Level tracking (main game)
  final int
      currentLevel; // Current main game level (starts at 1 after tutorials)
  final Set<int> completedLevels; // Main game levels completed
  final bool tutorialCompleted; // Legacy field - true when lessons complete
  final int? savedMainGameLevel; // Level to return to after tutorial replay

  GameProgress({
    this.currentLesson,
    required this.completedLessons,
    required this.lessonCompleted,
    required this.currentLevel,
    required this.completedLevels,
    required this.tutorialCompleted,
    this.savedMainGameLevel,
  });

  GameProgress copyWith({
    int? currentLesson,
    Set<int>? completedLessons,
    bool? lessonCompleted,
    int? currentLevel,
    Set<int>? completedLevels,
    bool? tutorialCompleted,
    int? savedMainGameLevel,
  }) {
    return GameProgress(
      currentLesson: currentLesson ?? this.currentLesson,
      completedLessons: completedLessons ?? this.completedLessons,
      lessonCompleted: lessonCompleted ?? this.lessonCompleted,
      currentLevel: currentLevel ?? this.currentLevel,
      completedLevels: completedLevels ?? this.completedLevels,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      savedMainGameLevel: savedMainGameLevel ?? this.savedMainGameLevel,
    );
  }

  factory GameProgress.initial() {
    return GameProgress(
      currentLesson: 1,
      completedLessons: {},
      lessonCompleted: false,
      currentLevel: 1,
      completedLevels: {},
      tutorialCompleted: false,
      savedMainGameLevel: null,
    );
  }
  GameProgress completeLevel(int levelNumber) {
    final newCompletedLevels = Set<int>.from(completedLevels)..add(levelNumber);

    // If completing level 5 (last tutorial)
    if (levelNumber == 5) {
      if (savedMainGameLevel != null) {
        // User replayed tutorial from main game - restore their main game level
        return copyWith(
          completedLevels: newCompletedLevels,
          currentLevel: savedMainGameLevel,
          tutorialCompleted: true,
          savedMainGameLevel: null, // Clear the saved level
        );
      } else {
        // User completed tutorial for the first time - move to level 6 (first main level)
        return copyWith(
          completedLevels: newCompletedLevels,
          currentLevel: 6,
          tutorialCompleted: true,
        );
      }
    }

    final newCurrentLevel = levelNumber + 1;
    return copyWith(
      completedLevels: newCompletedLevels,
      currentLevel: newCurrentLevel,
    );
  }

  // Check if a module is completed (all levels in the module are done)
  bool isModuleCompleted(int moduleId, List<dynamic> modules) {
    final module = modules.firstWhere((m) => m.id == moduleId);
    final moduleLevels = List.generate(
      module.endLevel - module.startLevel + 1,
      (i) => module.startLevel + i,
    );
    return moduleLevels.every(completedLevels.contains);
  }

  Map<String, dynamic> toJson() {
    return {
      'currentLesson': currentLesson,
      'completedLessons': completedLessons.toList(),
      'lessonCompleted': lessonCompleted,
      'currentLevel': currentLevel,
      'completedLevels': completedLevels.toList(),
      'tutorialCompleted': tutorialCompleted,
      'savedMainGameLevel': savedMainGameLevel,
    };
  }

  factory GameProgress.fromJson(Map<String, dynamic> json) {
    return GameProgress(
      currentLesson: json['currentLesson'],
      completedLessons: Set<int>.from(json['completedLessons'] ?? []),
      lessonCompleted: json['lessonCompleted'] ?? false,
      currentLevel: json['currentLevel'] ?? 1,
      completedLevels: Set<int>.from(json['completedLevels'] ?? []),
      tutorialCompleted: json['tutorialCompleted'] ?? false,
      savedMainGameLevel: json['savedMainGameLevel'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameProgress &&
          runtimeType == other.runtimeType &&
          currentLesson == other.currentLesson &&
          _setEquals(completedLessons, other.completedLessons) &&
          lessonCompleted == other.lessonCompleted &&
          currentLevel == other.currentLevel &&
          _setEquals(completedLevels, other.completedLevels) &&
          tutorialCompleted == other.tutorialCompleted &&
          savedMainGameLevel == other.savedMainGameLevel;

  @override
  int get hashCode =>
      currentLesson.hashCode ^
      completedLessons.hashCode ^
      lessonCompleted.hashCode ^
      currentLevel.hashCode ^
      completedLevels.hashCode ^
      tutorialCompleted.hashCode ^
      savedMainGameLevel.hashCode;

  bool _setEquals(Set<int> a, Set<int> b) {
    return a.length == b.length && a.every(b.contains);
  }

  @override
  String toString() =>
      'GameProgress(currentLesson: $currentLesson, lessonCompleted: $lessonCompleted, currentLevel: $currentLevel, tutorialCompleted: $tutorialCompleted)';
}
