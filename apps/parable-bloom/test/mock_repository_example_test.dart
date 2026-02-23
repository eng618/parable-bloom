import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/features/game/domain/repositories/game_progress_repository.dart';

/// Example mock repository for testing without Hive.
/// This shows how the repository abstraction allows easy test mocking.
class MockGameProgressRepository implements GameProgressRepository {
  GameProgress _progress = GameProgress.initial();
  bool _cloudSyncEnabled = false;
  DateTime? _lastSyncTime;

  @override
  Future<GameProgress> getProgress() async => _progress;

  @override
  Future<void> saveProgress(GameProgress progress) async {
    _progress = progress;
  }

  @override
  Future<void> resetProgress() async {
    _progress = GameProgress.initial();
  }

  @override
  Future<void> syncToCloud() async {
    _lastSyncTime = DateTime.now();
  }

  @override
  Future<void> syncFromCloud() async {
    _lastSyncTime = DateTime.now();
  }

  @override
  Future<DateTime?> getLastSyncTime() async => _lastSyncTime;

  @override
  Future<bool> isCloudSyncAvailable() async => true;

  @override
  Future<void> setCloudSyncEnabled(bool enabled) async {
    _cloudSyncEnabled = enabled;
  }

  @override
  Future<bool> isCloudSyncEnabled() async => _cloudSyncEnabled;
}

void main() {
  group('MockGameProgressRepository Example', () {
    late MockGameProgressRepository repository;

    setUp(() {
      repository = MockGameProgressRepository();
    });

    test('should start with initial progress', () async {
      final progress = await repository.getProgress();

      expect(progress.currentLevel, equals(1));
      expect(progress.completedLevels, isEmpty);
    });

    test('should save and retrieve progress', () async {
      final newProgress = GameProgress.initial().copyWith(
        currentLevel: 5,
        completedLevels: {1, 2, 3, 4},
        tutorialCompleted: false,
      );

      await repository.saveProgress(newProgress);
      final retrieved = await repository.getProgress();

      expect(retrieved.currentLevel, equals(5));
      expect(retrieved.completedLevels, containsAll([1, 2, 3, 4]));
    });

    test('should reset to initial state', () async {
      await repository.saveProgress(
        GameProgress.initial().copyWith(
          currentLevel: 10,
          completedLevels: {1, 2, 3},
          tutorialCompleted: false,
        ),
      );

      await repository.resetProgress();
      final progress = await repository.getProgress();

      expect(progress.currentLevel, equals(1));
      expect(progress.completedLevels, isEmpty);
    });

    test('should track sync operations', () async {
      expect(await repository.getLastSyncTime(), isNull);

      await repository.syncToCloud();

      final syncTime = await repository.getLastSyncTime();
      expect(syncTime, isNotNull);
      expect(
        syncTime!.isBefore(DateTime.now().add(Duration(seconds: 1))),
        isTrue,
      );
    });

    test('should manage cloud sync preferences', () async {
      expect(await repository.isCloudSyncEnabled(), isFalse);

      await repository.setCloudSyncEnabled(true);

      expect(await repository.isCloudSyncEnabled(), isTrue);
      expect(await repository.isCloudSyncAvailable(), isTrue);
    });
  });
}
