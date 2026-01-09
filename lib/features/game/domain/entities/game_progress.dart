class GameProgress {
  final int currentLevel;
  final Set<int> completedLevels;
  final bool tutorialCompleted;

  GameProgress({
    required this.currentLevel,
    required this.completedLevels,
    required this.tutorialCompleted,
  });

  GameProgress copyWith({
    int? currentLevel,
    Set<int>? completedLevels,
    bool? tutorialCompleted,
  }) {
    return GameProgress(
      currentLevel: currentLevel ?? this.currentLevel,
      completedLevels: completedLevels ?? this.completedLevels,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
    );
  }

  factory GameProgress.initial() {
    return GameProgress(
        currentLevel: 1, completedLevels: {}, tutorialCompleted: false);
  }

  GameProgress completeLevel(int levelNumber) {
    final newCompletedLevels = Set<int>.from(completedLevels)..add(levelNumber);
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
    };
  }

  factory GameProgress.fromJson(Map<String, dynamic> json) {
    return GameProgress(
      currentLevel: json['currentLevel'] ?? 1,
      completedLevels: Set<int>.from(json['completedLevels'] ?? []),
      tutorialCompleted: json['tutorialCompleted'] ?? false,
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
