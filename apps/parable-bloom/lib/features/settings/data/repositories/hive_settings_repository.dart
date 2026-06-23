import 'package:hive_flutter/hive_flutter.dart';

import '../../../../services/logger_service.dart';
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

  static const String _useSimpleVinesKey = 'useSimpleVines';

  static const String _vineStyleKey = 'vineStyle';
  static const String _defaultVineStyle = 'classic';

  static const String _boardZoomScaleKey = 'boardZoomScale';
  static const double _defaultBoardZoomScale = 1.0;

  HiveSettingsRepository(this.hiveBox);

  T _readTypedValue<T>(String key, T defaultValue) {
    final value = hiveBox.get(key, defaultValue: defaultValue);
    if (value is T) {
      return value;
    }

    LoggerService.warn(
      'Invalid settings value type. Falling back to default.',
      tag: 'HiveSettingsRepository',
      metadata: {
        'key': key,
        'expected_type': '$T',
        'actual_type': value.runtimeType.toString(),
      },
    );
    return defaultValue;
  }

  @override
  Future<String> getThemeMode() async {
    return _readTypedValue<String>(_themeModeKey, _defaultThemeMode);
  }

  @override
  Future<void> setThemeMode(String mode) async {
    await hiveBox.put(_themeModeKey, mode);
  }

  @override
  Future<bool> getBackgroundAudioEnabled() async {
    return _readTypedValue<bool>(
      _backgroundAudioEnabledKey,
      _defaultBackgroundAudioEnabled,
    );
  }

  @override
  Future<void> setBackgroundAudioEnabled(bool enabled) async {
    await hiveBox.put(_backgroundAudioEnabledKey, enabled);
  }

  @override
  Future<bool> getHapticsEnabled() async {
    return _readTypedValue<bool>(_hapticsEnabledKey, _defaultHapticsEnabled);
  }

  @override
  Future<void> setHapticsEnabled(bool enabled) async {
    await hiveBox.put(_hapticsEnabledKey, enabled);
  }

  @override
  Future<bool> getUseSimpleVines() async {
    final style = await getVineStyle();
    return style == 'simple';
  }

  @override
  Future<void> setUseSimpleVines(bool enabled) async {
    await setVineStyle(enabled ? 'simple' : 'classic');
  }

  @override
  Future<String> getVineStyle() async {
    final oldVal = hiveBox.get(_useSimpleVinesKey);
    if (oldVal != null) {
      final styleName = oldVal as bool ? 'simple' : 'classic';
      await hiveBox.put(_vineStyleKey, styleName);
      await hiveBox.delete(_useSimpleVinesKey);
      return styleName;
    }
    return _readTypedValue<String>(_vineStyleKey, _defaultVineStyle);
  }

  @override
  Future<void> setVineStyle(String style) async {
    await hiveBox.put(_vineStyleKey, style);
  }

  @override
  Future<double> getBoardZoomScale() async {
    return _readTypedValue<double>(_boardZoomScaleKey, _defaultBoardZoomScale);
  }

  @override
  Future<void> setBoardZoomScale(double scale) async {
    await hiveBox.put(_boardZoomScaleKey, scale);
  }
}
