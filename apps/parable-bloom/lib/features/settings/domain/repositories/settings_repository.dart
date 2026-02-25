/// Abstract repository for managing application settings persistence.
/// Implementations can use Hive, Firebase, or other storage backends.
abstract class SettingsRepository {
  /// Get the current theme mode.
  /// Returns 'light', 'dark', or 'system'.
  Future<String> getThemeMode();

  /// Set the theme mode.
  /// [mode] should be 'light', 'dark', or 'system'.
  Future<void> setThemeMode(String mode);

  /// Whether background audio is enabled.
  Future<bool> getBackgroundAudioEnabled();

  /// Enable/disable background audio.
  Future<void> setBackgroundAudioEnabled(bool enabled);

  /// Whether haptic feedback is enabled.
  Future<bool> getHapticsEnabled();

  /// Enable/disable haptic feedback.
  Future<void> setHapticsEnabled(bool enabled);

  /// Whether simple/trellis vines are enabled.
  Future<bool> getUseSimpleVines();

  /// Enable/disable simple/trellis vines.
  Future<void> setUseSimpleVines(bool enabled);

  /// Get the user's preferred board zoom scale (Default 1.0).
  Future<double> getBoardZoomScale();

  /// Set the user's preferred board zoom scale.
  Future<void> setBoardZoomScale(double scale);
}
