class GameProgress {
  final int currentLevel;
  final Set<int> completedLevels;

  GameProgress({required this.currentLevel, required this.completedLevels});

  GameProgress copyWith({int? currentLevel, Set<int>? completedLevels}) {
    return GameProgress(
      currentLevel: currentLevel ?? this.currentLevel,
      completedLevels: completedLevels ?? this.completedLevels,
    );
  }

  factory GameProgress.initial() {
    return GameProgress(currentLevel: 1, completedLevels: {});
  }

  GameProgress completeLevel(int levelNumber) {
    final newCompletedLevels = Set<int>.from(completedLevels)..add(levelNumber);
    final newCurrentLevel = levelNumber + 1;

    return copyWith(
      completedLevels: newCompletedLevels,
      currentLevel: newCurrentLevel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentLevel': currentLevel,
      'completedLevels': completedLevels.toList(),
    };
  }

  factory GameProgress.fromJson(Map<String, dynamic> json) {
    return GameProgress(
      currentLevel: json['currentLevel'] ?? 1,
      completedLevels: Set<int>.from(json['completedLevels'] ?? []),
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
