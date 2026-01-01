/// Application environment enumeration for dev, preview, and production.
enum AppEnvironment { dev, preview, prod }

/// Centralized environment configuration.
/// Environment is determined at compile time via the APP_ENV dart-define.
class EnvironmentConfig {
  static const String _envVarName = 'APP_ENV';

  static const String _rawEnv = String.fromEnvironment(
    _envVarName,
    defaultValue: 'dev',
  );

  /// Current application environment (defaults to dev if not specified).
  static AppEnvironment current = _parseEnvironment();

  /// Parses the APP_ENV dart-define to determine the current environment.
  static AppEnvironment _parseEnvironment() {
    return AppEnvironment.values.firstWhere(
      (e) => e.name == _rawEnv,
      orElse: () => AppEnvironment.dev,
    );
  }

  /// Returns the Firestore collection name for the current environment.
  static String getFirestoreCollection() {
    switch (current) {
      case AppEnvironment.dev:
        return 'game_progress_dev';
      case AppEnvironment.preview:
        return 'game_progress_preview';
      case AppEnvironment.prod:
        return 'game_progress_prod';
    }
  }

  /// Returns a human-readable environment name.
  static String environmentName() {
    switch (current) {
      case AppEnvironment.dev:
        return 'Development';
      case AppEnvironment.preview:
        return 'Preview';
      case AppEnvironment.prod:
        return 'Production';
    }
  }

  /// Returns whether this is a production environment.
  static bool isProd() => current == AppEnvironment.prod;

  /// Returns whether this is a development environment.
  static bool isDev() => current == AppEnvironment.dev;

  /// Returns whether this is a preview environment.
  static bool isPreview() => current == AppEnvironment.preview;
}
