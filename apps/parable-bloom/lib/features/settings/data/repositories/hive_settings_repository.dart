import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/repositories/settings_repository.dart';

/// Hive-based implementation of SettingsRepository.
/// Stores settings locally using the Hive key-value database.
class HiveSettingsRepository implements SettingsRepository {
  final Box hiveBox;
  static const String _themeModeKey = 'themeMode';
  static const String _defaultThemeMode = 'system';

  static const String _backgroundAudioEnabledKey = 'backgroundAudioEnabled';
  static const bool _defaultBackgroundAudioEnabled = true;

  static const String _hapticsEnabledKey = 'hapticsEnabled';
  static const bool _defaultHapticsEnabled = true;

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

  @override
  Future<bool> getBackgroundAudioEnabled() async {
    return hiveBox.get(
      _backgroundAudioEnabledKey,
      defaultValue: _defaultBackgroundAudioEnabled,
    ) as bool;
  }

  @override
  Future<void> setBackgroundAudioEnabled(bool enabled) async {
    await hiveBox.put(_backgroundAudioEnabledKey, enabled);
  }

  @override
  Future<bool> getHapticsEnabled() async {
    return hiveBox.get(_hapticsEnabledKey, defaultValue: _defaultHapticsEnabled)
        as bool;
  }

  @override
  Future<void> setHapticsEnabled(bool enabled) async {
    await hiveBox.put(_hapticsEnabledKey, enabled);
  }
}
