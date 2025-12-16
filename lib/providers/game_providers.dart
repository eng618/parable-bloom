import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../game/garden_game.dart';

// Models for game state
class VineData {
  final String id;
  final String color;
  final String description;
  final List<Map<String, int>> path;
  final List<String> blockingVines;

  VineData({
    required this.id,
    required this.color,
    required this.description,
    required this.path,
    required this.blockingVines,
  });

  factory VineData.fromJson(Map<String, dynamic> json) {
    return VineData(
      id: json['id'],
      color: json['color'],
      description: json['description'],
      path: List<Map<String, int>>.from(
        json['path'].map((cell) => Map<String, int>.from(cell))
      ),
      blockingVines: List<String>.from(json['blockingVines']),
    );
  }
}

class LevelData {
  final String levelId;
  final int levelNumber;
  final String title;
  final int difficulty;
  final Map<String, int> grid;
  final List<VineData> vines;
  final Map<String, dynamic> parable;
  final List<String> hints;
  final List<String> optimalSequence;
  final int optimalMoves;

  LevelData({
    required this.levelId,
    required this.levelNumber,
    required this.title,
    required this.difficulty,
    required this.grid,
    required this.vines,
    required this.parable,
    required this.hints,
    required this.optimalSequence,
    required this.optimalMoves,
  });

  factory LevelData.fromJson(Map<String, dynamic> json) {
    return LevelData(
      levelId: json['levelId'],
      levelNumber: json['levelNumber'],
      title: json['title'],
      difficulty: json['difficulty'],
      grid: Map<String, int>.from(json['grid']),
      vines: List<VineData>.from(
        json['vines'].map((vine) => VineData.fromJson(vine))
      ),
      parable: Map<String, dynamic>.from(json['parable']),
      hints: List<String>.from(json['hints']),
      optimalSequence: List<String>.from(json['optimalSequence']),
      optimalMoves: json['optimalMoves'],
    );
  }
}

class GameProgress {
  final int currentLevel;
  final Set<int> completedLevels;

  GameProgress({
    required this.currentLevel,
    required this.completedLevels,
  });

  GameProgress copyWith({
    int? currentLevel,
    Set<int>? completedLevels,
  }) {
    return GameProgress(
      currentLevel: currentLevel ?? this.currentLevel,
      completedLevels: completedLevels ?? this.completedLevels,
    );
  }

  factory GameProgress.fromJson(Map<String, dynamic> json) {
    return GameProgress(
      currentLevel: json['currentLevel'] ?? 1,
      completedLevels: Set<int>.from(json['completedLevels'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentLevel': currentLevel,
      'completedLevels': completedLevels.toList(),
    };
  }
}

// Providers
final hiveBoxProvider = Provider<Box>((ref) {
  throw UnimplementedError('Hive box must be initialized in main');
});

final gameProgressProvider = StateNotifierProvider<GameProgressNotifier, GameProgress>((ref) {
  final box = ref.watch(hiveBoxProvider);
  return GameProgressNotifier(box);
});

class GameProgressNotifier extends StateNotifier<GameProgress> {
  final Box _box;

  GameProgressNotifier(this._box) : super(_loadProgress(_box));

  static GameProgress _loadProgress(Box box) {
    final data = box.get('progress');
    if (data != null) {
      return GameProgress.fromJson(Map<String, dynamic>.from(data));
    }
    return GameProgress(currentLevel: 1, completedLevels: {});
  }

  Future<void> completeLevel(int levelNumber) async {
    final newCompletedLevels = Set<int>.from(state.completedLevels)..add(levelNumber);
    final newCurrentLevel = levelNumber < 2 ? levelNumber + 1 : state.currentLevel; // For now, just increment

    state = state.copyWith(
      completedLevels: newCompletedLevels,
      currentLevel: newCurrentLevel,
    );

    await _saveProgress();
  }

  Future<void> resetProgress() async {
    state = GameProgress(currentLevel: 1, completedLevels: {});
    await _saveProgress();
  }

  Future<void> _saveProgress() async {
    await _box.put('progress', state.toJson());
  }
}

// Current level provider
final currentLevelProvider = StateProvider<LevelData?>((ref) => null);

// Level completion state provider
final levelCompleteProvider = StateProvider<bool>((ref) => false);

// Game instance provider
final gameInstanceProvider = StateNotifierProvider<GameInstanceNotifier, GardenGame?>((ref) {
  return GameInstanceNotifier();
});

class GameInstanceNotifier extends StateNotifier<GardenGame?> {
  GameInstanceNotifier() : super(null);

  void setGame(GardenGame game) {
    state = game;
  }
}

// Vine state for current level
class VineState {
  final String id;
  final bool isBlocked;
  final bool isCleared;

  VineState({
    required this.id,
    required this.isBlocked,
    required this.isCleared,
  });

  VineState copyWith({
    bool? isBlocked,
    bool? isCleared,
  }) {
    return VineState(
      id: id,
      isBlocked: isBlocked ?? this.isBlocked,
      isCleared: isCleared ?? this.isCleared,
    );
  }
}

final vineStatesProvider = StateNotifierProvider<VineStatesNotifier, Map<String, VineState>>((ref) {
  final levelData = ref.watch(currentLevelProvider);
  return VineStatesNotifier(levelData, ref);
});

class VineStatesNotifier extends StateNotifier<Map<String, VineState>> {
  final Ref _ref;
  LevelData? _levelData;

  VineStatesNotifier(LevelData? levelData, this._ref) : super(_initializeVineStates(levelData)) {
    _levelData = levelData;
  }

  static Map<String, VineState> _initializeVineStates(LevelData? levelData) {
    if (levelData == null) return {};

    final states = <String, VineState>{};
    for (final vine in levelData.vines) {
      states[vine.id] = VineState(
        id: vine.id,
        isBlocked: vine.blockingVines.isNotEmpty,
        isCleared: false,
      );
    }
    return states;
  }

  void clearVine(String vineId) {
    debugPrint('VineStatesNotifier: Clearing vine $vineId');
    state = Map.from(state)..[vineId] = state[vineId]!.copyWith(isCleared: true);

    // Update blocking status for remaining vines
    _updateBlockingStates();

    // Check if level is complete
    _checkLevelComplete();
  }

  void _checkLevelComplete() {
    final allCleared = state.values.every((vineState) => vineState.isCleared);
    debugPrint('VineStatesNotifier: Checking completion - all cleared: $allCleared, total vines: ${state.length}');
    if (allCleared) {
      debugPrint('VineStatesNotifier: LEVEL COMPLETE detected! Setting levelCompleteProvider to true');
      // Trigger level complete
      _ref.read(levelCompleteProvider.notifier).state = true;
      debugPrint('VineStatesNotifier: levelCompleteProvider set to true');
    }
  }

  void _updateBlockingStates() {
    if (_levelData == null) return;

    final newStates = Map<String, VineState>.from(state);

    for (final entry in state.entries) {
      if (entry.value.isCleared) continue;

      // A vine is blocked if any of its blocking vines are not cleared
      final vineData = _levelData!.vines.firstWhere((v) => v.id == entry.key);
      final isBlocked = vineData.blockingVines.any((blockingId) => !(state[blockingId]?.isCleared ?? false));
      newStates[entry.key] = entry.value.copyWith(isBlocked: isBlocked);
    }

    state = newStates;
  }

  void resetForLevel(LevelData levelData) {
    _levelData = levelData;
    state = _initializeVineStates(levelData);
  }
}
