/// Abstract repository for managing application settings persistence.
/// Implementations can use Hive, Firebase, or other storage backends.
abstract class SettingsRepository {
  /// Get the current theme mode.
  /// Returns 'light', 'dark', or 'system'.
  Future<String> getThemeMode();

  /// Set the theme mode.
  /// [mode] should be 'light', 'dark', or 'system'.
  Future<void> setThemeMode(String mode);
}
