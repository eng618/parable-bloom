import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/repositories/settings_repository.dart';

/// Hive-based implementation of SettingsRepository.
/// Stores settings locally using the Hive key-value database.
class HiveSettingsRepository implements SettingsRepository {
  final Box hiveBox;
  static const String _themeModeKey = 'themeMode';
  static const String _defaultThemeMode = 'system';

  HiveSettingsRepository(this.hiveBox);

  @override
  Future<String> getThemeMode() async {
    return hiveBox.get(_themeModeKey, defaultValue: _defaultThemeMode)
        as String;
  }

  @override
  Future<void> setThemeMode(String mode) async {
    await hiveBox.put(_themeModeKey, mode);
  }
}
