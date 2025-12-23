import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:parable_bloom/features/game/data/repositories/hive_game_progress_repository.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';

void main() {
  late Box box;
  late HiveGameProgressRepository repository;

  setUpAll(() async {
    // Use in-memory adapter for testing
    Hive.init(null);
  });

  setUp(() async {
    box = await Hive.openBox('test_box', bytes: null);
    repository = HiveGameProgressRepository(box);
  });

  tearDown(() async {
    await box.clear();
    await box.close();
  });

  group('HiveGameProgressRepository', () {
    test('should return initial progress when no data exists', () async {
      final progress = await repository.getProgress();

      expect(progress.currentLevel, equals(1));
      expect(progress.completedLevels, isEmpty);
    });

    test('should save and retrieve progress correctly', () async {
      final originalProgress = GameProgress(
        currentLevel: 3,
        completedLevels: {1, 2},
      );

      await repository.saveProgress(originalProgress);
      final retrievedProgress = await repository.getProgress();

      expect(retrievedProgress.currentLevel, equals(3));
      expect(retrievedProgress.completedLevels, equals({1, 2}));
    });

    test('should reset progress correctly', () async {
      final progress = GameProgress(
        currentLevel: 5,
        completedLevels: {1, 2, 3, 4},
      );

      await repository.saveProgress(progress);
      await repository.resetProgress();

      final resetProgress = await repository.getProgress();
      expect(resetProgress.currentLevel, equals(1));
      expect(resetProgress.completedLevels, isEmpty);
    });

    test('should handle empty completed levels set', () async {
      final progress = GameProgress(currentLevel: 2, completedLevels: {});

      await repository.saveProgress(progress);
      final retrievedProgress = await repository.getProgress();

      expect(retrievedProgress.currentLevel, equals(2));
      expect(retrievedProgress.completedLevels, isEmpty);
    });

    test('should persist data across repository instances', () async {
      final progress1 = GameProgress(
        currentLevel: 4,
        completedLevels: {1, 2, 3},
      );

      await repository.saveProgress(progress1);

      // Create new repository instance with same box
      final repository2 = HiveGameProgressRepository(box);
      final retrievedProgress = await repository2.getProgress();

      expect(retrievedProgress.currentLevel, equals(4));
      expect(retrievedProgress.completedLevels, equals({1, 2, 3}));
    });
  });
}
