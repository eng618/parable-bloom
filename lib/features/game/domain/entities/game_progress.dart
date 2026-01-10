class GameProgress {
  final int currentLevel;
  final Set<int> completedLevels;
  final bool tutorialCompleted;
  final int? savedMainGameLevel; // Level to return to after tutorial replay

  GameProgress({
    required this.currentLevel,
    required this.completedLevels,
    required this.tutorialCompleted,
    this.savedMainGameLevel,
  });

  GameProgress copyWith({
    int? currentLevel,
    Set<int>? completedLevels,
    bool? tutorialCompleted,
    int? savedMainGameLevel,
  }) {
    return GameProgress(
      currentLevel: currentLevel ?? this.currentLevel,
      completedLevels: completedLevels ?? this.completedLevels,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      savedMainGameLevel: savedMainGameLevel ?? this.savedMainGameLevel,
    );
  }

  factory GameProgress.initial() {
    return GameProgress(
        currentLevel: 1,
        completedLevels: {},
        tutorialCompleted: false,
        savedMainGameLevel: null);
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
      'currentLevel': currentLevel,
      'completedLevels': completedLevels.toList(),
      'tutorialCompleted': tutorialCompleted,
      'savedMainGameLevel': savedMainGameLevel,
    };
  }

  factory GameProgress.fromJson(Map<String, dynamic> json) {
    return GameProgress(
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
          currentLevel == other.currentLevel &&
          _setEquals(completedLevels, other.completedLevels);

  @override
  int get hashCode => currentLevel.hashCode ^ completedLevels.hashCode;

  bool _setEquals(Set<int> a, Set<int> b) {
    return a.length == b.length && a.every(b.contains);
  }

  @override
  String toString() =>
      'GameProgress(currentLevel: $currentLevel, completedLevels: $completedLevels)';
}
