class GameProgress {
  // Lesson tracking (separate from levels)
  final String?
      currentLesson; // e.g. "lesson_1" if in tutorial, null if tutorial complete
  final Set<String> completedLessons; // Which lessons have been completed
  final bool lessonCompleted; // True after all 5 lessons done

  // Level tracking (main game)
  final String currentLevel; // Current main game level ID (e.g. "lvl_seed_01")
  final Set<String> completedLevels; // Main game level IDs completed
  final bool tutorialCompleted; // Legacy field - true when lessons complete
  final String?
      savedMainGameLevel; // Level ID to return to after tutorial replay

  // Scripture tracking (unlocked translations per module)
  final Map<String, String>
      unlockedTranslations; // maps moduleId or scriptureId to translationId
  final Set<String>
      unlockedScriptureIds; // individual unlocked micro-verse or starter scripture IDs

  GameProgress({
    this.currentLesson,
    required this.completedLessons,
    required this.lessonCompleted,
    required this.currentLevel,
    required this.completedLevels,
    required this.tutorialCompleted,
    this.savedMainGameLevel,
    required this.unlockedTranslations,
    required this.unlockedScriptureIds,
  });

  GameProgress copyWith({
    String? currentLesson,
    Set<String>? completedLessons,
    bool? lessonCompleted,
    String? currentLevel,
    Set<String>? completedLevels,
    bool? tutorialCompleted,
    String? savedMainGameLevel,
    Map<String, String>? unlockedTranslations,
    Set<String>? unlockedScriptureIds,
  }) {
    return GameProgress(
      currentLesson: currentLesson ?? this.currentLesson,
      completedLessons: completedLessons ?? this.completedLessons,
      lessonCompleted: lessonCompleted ?? this.lessonCompleted,
      currentLevel: currentLevel ?? this.currentLevel,
      completedLevels: completedLevels ?? this.completedLevels,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      savedMainGameLevel: savedMainGameLevel ?? this.savedMainGameLevel,
      unlockedTranslations: unlockedTranslations ?? this.unlockedTranslations,
      unlockedScriptureIds: unlockedScriptureIds ?? this.unlockedScriptureIds,
    );
  }

  factory GameProgress.initial() {
    return GameProgress(
      currentLesson: 'lesson_1',
      completedLessons: {},
      lessonCompleted: false,
      currentLevel: 'lvl_seed_01',
      completedLevels: {},
      tutorialCompleted: false,
      savedMainGameLevel: null,
      unlockedTranslations: {},
      unlockedScriptureIds: {},
    );
  }

  GameProgress completeLevel(String levelId, List<String> manifestLevels) {
    final newCompletedLevels = Set<String>.from(completedLevels)..add(levelId);

    // If completing the last tutorial lesson
    if (levelId == 'lesson_5') {
      if (savedMainGameLevel != null) {
        // User replayed tutorial from main game - restore their main game level
        return copyWith(
          completedLevels: newCompletedLevels,
          currentLevel: savedMainGameLevel,
          tutorialCompleted: true,
          savedMainGameLevel: null, // Clear the saved level
        );
      } else {
        // User completed tutorial for the first time - move to first standard level
        return copyWith(
          completedLevels: newCompletedLevels,
          currentLevel: 'lvl_seed_01',
          tutorialCompleted: true,
        );
      }
    }

    // Find next level in manifest levels
    final currentIndex = manifestLevels.indexOf(levelId);
    if (currentIndex != -1 && currentIndex < manifestLevels.length - 1) {
      final nextLevel = manifestLevels[currentIndex + 1];
      return copyWith(
        completedLevels: newCompletedLevels,
        currentLevel: nextLevel,
      );
    }

    return copyWith(
      completedLevels: newCompletedLevels,
    );
  }

  // Check if a module is completed (all levels in the module are done)
  bool isModuleCompleted(int moduleId, List<dynamic> modules) {
    final module = modules.firstWhere((m) => m.id == moduleId);
    return module.allLevels.every(completedLevels.contains);
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
      'unlockedTranslations': unlockedTranslations,
      'unlockedScriptureIds': unlockedScriptureIds.toList(),
    };
  }

  factory GameProgress.fromJson(Map<String, dynamic> json) {
    final rawCurrentLesson = json['currentLesson'];
    String? currentLessonStr;
    if (rawCurrentLesson != null) {
      currentLessonStr = rawCurrentLesson is int
          ? 'lesson_$rawCurrentLesson'
          : rawCurrentLesson.toString();
    }

    final rawCurrentLevel = json['currentLevel'] ?? 'lvl_seed_01';
    String currentLevelStr;
    if (rawCurrentLevel is int) {
      // Map legacy int save to new String ID
      currentLevelStr = _mapLegacyLevelId(rawCurrentLevel);
    } else {
      currentLevelStr = rawCurrentLevel.toString();
    }

    final completedLessonsList = (json['completedLessons'] as List<dynamic>?)
            ?.map((e) => e is int ? 'lesson_$e' : e.toString())
            .toList() ??
        [];

    final completedLevelsList = (json['completedLevels'] as List<dynamic>?)
            ?.map((e) => e is int ? _mapLegacyLevelId(e) : e.toString())
            .toList() ??
        [];

    final rawSavedLevel = json['savedMainGameLevel'];
    String? savedLevelStr;
    if (rawSavedLevel != null) {
      savedLevelStr = rawSavedLevel is int
          ? _mapLegacyLevelId(rawSavedLevel)
          : rawSavedLevel.toString();
    }

    final unlockedTranslationsMap =
        (json['unlockedTranslations'] as Map<dynamic, dynamic>?)
                ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
            <String, String>{};

    final unlockedScriptureIdsList =
        (json['unlockedScriptureIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

    return GameProgress(
      currentLesson: currentLessonStr,
      completedLessons: Set<String>.from(completedLessonsList),
      lessonCompleted: json['lessonCompleted'] ?? false,
      currentLevel: currentLevelStr,
      completedLevels: Set<String>.from(completedLevelsList),
      tutorialCompleted: json['tutorialCompleted'] ?? false,
      savedMainGameLevel: savedLevelStr,
      unlockedTranslations: unlockedTranslationsMap,
      unlockedScriptureIds: Set<String>.from(unlockedScriptureIdsList),
    );
  }

  static String _mapLegacyLevelId(int legacyId) {
    if (legacyId <= 5) return 'lesson_$legacyId';
    // challenge levels
    if (legacyId == 21) return 'lvl_seed_challenge';
    if (legacyId == 42) return 'lvl_sprout_challenge';
    if (legacyId == 63) return 'lvl_blossom_challenge';
    if (legacyId == 84) return 'lvl_flourish_challenge';
    if (legacyId == 105) return 'lvl_harvest_challenge';

    // level 6-20 map to lvl_seed_01-15 (Wait, seedling actually has 20 levels in the new v3 format)
    // level 6-25 map to lvl_seed_01-20
    if (legacyId >= 6 && legacyId <= 25) {
      final idx = legacyId - 5;
      final idxStr = idx < 10 ? '0$idx' : '$idx';
      return 'lvl_seed_$idxStr';
    }
    // sprout levels (22 to 41)
    if (legacyId >= 22 && legacyId <= 41) {
      final idx = legacyId - 21;
      final idxStr = idx < 10 ? '0$idx' : '$idx';
      return 'lvl_sprout_$idxStr';
    }
    // blossom levels (43 to 62)
    if (legacyId >= 43 && legacyId <= 62) {
      final idx = legacyId - 42;
      final idxStr = idx < 10 ? '0$idx' : '$idx';
      return 'lvl_blossom_$idxStr';
    }
    // flourish levels (64 to 83)
    if (legacyId >= 64 && legacyId <= 83) {
      final idx = legacyId - 63;
      final idxStr = idx < 10 ? '0$idx' : '$idx';
      return 'lvl_flourish_$idxStr';
    }
    // harvest levels (85 to 104)
    if (legacyId >= 85 && legacyId <= 104) {
      final idx = legacyId - 84;
      final idxStr = idx < 10 ? '0$idx' : '$idx';
      return 'lvl_harvest_$idxStr';
    }

    return 'lvl_seed_01';
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
          savedMainGameLevel == other.savedMainGameLevel &&
          _mapEquals(unlockedTranslations, other.unlockedTranslations) &&
          _setEquals(unlockedScriptureIds, other.unlockedScriptureIds);

  @override
  int get hashCode =>
      currentLesson.hashCode ^
      completedLessons.hashCode ^
      lessonCompleted.hashCode ^
      currentLevel.hashCode ^
      completedLevels.hashCode ^
      tutorialCompleted.hashCode ^
      savedMainGameLevel.hashCode ^
      unlockedTranslations.hashCode ^
      unlockedScriptureIds.hashCode;

  bool _setEquals(Set<String> a, Set<String> b) {
    return a.length == b.length && a.every(b.contains);
  }

  bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (b[key] != a[key]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'GameProgress(currentLesson: $currentLesson, lessonCompleted: $lessonCompleted, currentLevel: $currentLevel, tutorialCompleted: $tutorialCompleted, unlockedTranslationsCount: ${unlockedTranslations.length}, unlockedScripturesCount: ${unlockedScriptureIds.length})';
}
