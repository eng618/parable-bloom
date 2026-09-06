import '../../../tutorial/domain/entities/lesson_data.dart';

class GameProgress {
  // Lesson tracking (separate from levels)
  final String?
      currentLesson; // e.g. "lesson_1" if in tutorial, null if tutorial complete
  final Set<String> completedLessons; // Which lessons have been completed
  final bool lessonCompleted; // True after all lessons done

  // Level tracking (main game)
  final String currentLevel; // Current main game level ID (e.g. "lvl_m01_01")
  final Set<String> completedLevels; // Main game level IDs completed
  final bool tutorialCompleted; // Legacy field - true when lessons complete
  final String?
      savedMainGameLevel; // Level ID to return to after tutorial replay

  // Scripture tracking (unlocked translations per module)
  final Map<String, String>
      unlockedTranslations; // maps moduleId or scriptureId to translationId
  final Set<String>
      unlockedScriptureIds; // individual unlocked micro-verse or starter scripture IDs
  final Map<String, String>
      journalNotes; // maps scriptureId to user reflection notes

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
    this.journalNotes = const {},
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
    Map<String, String>? journalNotes,
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
      journalNotes: journalNotes ?? this.journalNotes,
    );
  }

  factory GameProgress.initial() {
    return GameProgress(
      currentLesson: 'lesson_1',
      completedLessons: {},
      lessonCompleted: false,
      currentLevel: 'lvl_m01_01',
      completedLevels: {},
      tutorialCompleted: false,
      savedMainGameLevel: null,
      unlockedTranslations: {},
      unlockedScriptureIds: {},
      journalNotes: const {},
    );
  }

  GameProgress completeLevel(String levelId, List<String> manifestLevels) {
    final newCompletedLevels = Set<String>.from(completedLevels)..add(levelId);

    // If completing the last tutorial lesson
    if (levelId == 'lesson_${LessonData.totalLessons}') {
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
          currentLevel: 'lvl_m01_01',
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

  /// First playlist level the player has not completed, or null when the
  /// playlist is exhausted (truly finished) or empty (registry unavailable).
  ///
  /// This is the single source of truth for "what to play next". The
  /// persisted [currentLevel] goes stale when the playlist grows (new cloud
  /// levels) or IDs migrate, so callers must prefer this over trusting
  /// [currentLevel] blindly.
  String? nextUncompletedLevel(List<String> playlist) {
    for (final id in playlist) {
      if (!completedLevels.contains(id)) return id;
    }
    return null;
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
      'journalNotes': journalNotes,
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

    final rawCurrentLevel = json['currentLevel'] ?? 'lvl_m01_01';
    String currentLevelStr;
    if (rawCurrentLevel is int) {
      // Map legacy int save to new String ID
      currentLevelStr = _mapLegacyLevelId(rawCurrentLevel);
    } else {
      currentLevelStr = _migrateLevelId(rawCurrentLevel.toString());
    }

    final completedLessonsList = (json['completedLessons'] as List<dynamic>?)
            ?.map((e) => e is int ? 'lesson_$e' : e.toString())
            .toList() ??
        [];

    final completedLevelsList = (json['completedLevels'] as List<dynamic>?)
            ?.map((e) =>
                e is int ? _mapLegacyLevelId(e) : _migrateLevelId(e.toString()))
            .toList() ??
        [];

    final rawSavedLevel = json['savedMainGameLevel'];
    String? savedLevelStr;
    if (rawSavedLevel != null) {
      savedLevelStr = rawSavedLevel is int
          ? _mapLegacyLevelId(rawSavedLevel)
          : _migrateLevelId(rawSavedLevel.toString());
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

    final journalNotesMap = (json['journalNotes'] as Map<dynamic, dynamic>?)
            ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
        <String, String>{};

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
      journalNotes: journalNotesMap,
    );
  }

  static String _mapLegacyLevelId(int legacyId) {
    // Maps a physical level number to the unified generic scheme
    // (lvl_mNN_MM, lvl_mNN_challenge). Level IDs below 1 fall back to the
    // first level.
    if (legacyId < 1) return 'lvl_m01_01';
    final module = (legacyId - 1) ~/ 21 + 1;
    final index = (legacyId - 1) % 21;
    final modStr = module < 10 ? '0$module' : '$module';
    if (index == 20) return 'lvl_m${modStr}_challenge';
    final lvlStr = index + 1 < 10 ? '0${index + 1}' : '${index + 1}';
    return 'lvl_m${modStr}_$lvlStr';
  }

  /// Migrates pre-standardization string IDs (lvl_m01_01, …) to the unified
  /// generic scheme. Unknown values pass through untouched.
  static String _migrateLevelId(String levelId) {
    const prefixes = {
      'lvl_seed_': 'lvl_m01_',
      'lvl_sprout_': 'lvl_m02_',
      'lvl_blossom_': 'lvl_m03_',
      'lvl_flourish_': 'lvl_m04_',
      'lvl_harvest_': 'lvl_m05_',
    };
    for (final entry in prefixes.entries) {
      if (levelId.startsWith(entry.key)) {
        return entry.value + levelId.substring(entry.key.length);
      }
    }
    return levelId;
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
          _setEquals(unlockedScriptureIds, other.unlockedScriptureIds) &&
          _mapEquals(journalNotes, other.journalNotes);

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
      unlockedScriptureIds.hashCode ^
      journalNotes.hashCode;

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
      'GameProgress(currentLesson: $currentLesson, lessonCompleted: $lessonCompleted, currentLevel: $currentLevel, tutorialCompleted: $tutorialCompleted, unlockedTranslationsCount: ${unlockedTranslations.length}, unlockedScripturesCount: ${unlockedScriptureIds.length}, journalNotesCount: ${journalNotes.length})';
}
