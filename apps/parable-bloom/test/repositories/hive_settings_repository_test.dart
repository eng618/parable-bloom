import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:parable_bloom/features/settings/data/repositories/hive_settings_repository.dart';
import 'dart:io';

void main() {
  group('HiveSettingsRepository', () {
    late Box box;
    late HiveSettingsRepository repository;
    late Directory tempDir;

    setUp(() async {
      // Create temp directory for Hive
      tempDir = await Directory.systemTemp.createTemp('hive_settings_test_');
      Hive.init(tempDir.path);
      box = await Hive.openBox('test_settings');
      repository = HiveSettingsRepository(box);
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('test_settings');
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should be instantiable', () {
      expect(repository, isNotNull);
      expect(repository, isA<HiveSettingsRepository>());
    });

    test('should return default theme mode when none is set', () async {
      final themeMode = await repository.getThemeMode();
      expect(themeMode, 'system'); // Default value
    });

    test('should save and retrieve theme mode', () async {
      await repository.setThemeMode('dark');
      final themeMode = await repository.getThemeMode();
      expect(themeMode, 'dark');
    });

    test('should update theme mode', () async {
      await repository.setThemeMode('light');
      expect(await repository.getThemeMode(), 'light');

      await repository.setThemeMode('dark');
      expect(await repository.getThemeMode(), 'dark');
    });

    test('should persist theme mode across repository instances', () async {
      await repository.setThemeMode('light');

      // Create new repository instance with same box
      final repository2 = HiveSettingsRepository(box);
      final themeMode = await repository2.getThemeMode();

      expect(themeMode, 'light');
    });
  });
}
