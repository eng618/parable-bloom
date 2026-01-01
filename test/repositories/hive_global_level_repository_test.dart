import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:parable_bloom/features/game/data/repositories/hive_global_level_repository.dart';
import 'dart:io';

void main() {
  group('HiveGlobalLevelRepository', () {
    late Box box;
    late HiveGlobalLevelRepository repository;
    late Directory tempDir;

    setUp(() async {
      // Create temp directory for Hive
      tempDir = await Directory.systemTemp.createTemp(
        'hive_global_level_test_',
      );
      Hive.init(tempDir.path);
      box = await Hive.openBox('test_global_level');
      repository = HiveGlobalLevelRepository(box);
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_global_level');
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should be instantiable', () {
      expect(repository, isNotNull);
      expect(repository, isA<HiveGlobalLevelRepository>());
    });

    test('should return default level 1 when no level is set', () async {
      final level = await repository.getCurrentGlobalLevel();
      expect(level, 1);
    });

    test('should save and retrieve current global level', () async {
      await repository.setCurrentGlobalLevel(5);
      final level = await repository.getCurrentGlobalLevel();
      expect(level, 5);
    });

    test('should update current global level', () async {
      await repository.setCurrentGlobalLevel(3);
      expect(await repository.getCurrentGlobalLevel(), 3);

      await repository.setCurrentGlobalLevel(7);
      expect(await repository.getCurrentGlobalLevel(), 7);
    });

    test('should handle level progression', () async {
      await repository.setCurrentGlobalLevel(1);
      expect(await repository.getCurrentGlobalLevel(), 1);

      await repository.setCurrentGlobalLevel(2);
      expect(await repository.getCurrentGlobalLevel(), 2);

      await repository.setCurrentGlobalLevel(3);
      expect(await repository.getCurrentGlobalLevel(), 3);
    });

    test('should persist level across repository instances', () async {
      await repository.setCurrentGlobalLevel(10);

      // Create new repository instance with same box
      final repository2 = HiveGlobalLevelRepository(box);
      final level = await repository2.getCurrentGlobalLevel();

      expect(level, 10);
    });
  });
}
