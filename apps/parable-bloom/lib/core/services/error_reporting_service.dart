import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/environment_config.dart';

/// Single error-reporting path for all platforms (web, Android, iOS,
/// macOS) via Sentry.
///
/// Replaces Firebase Crashlytics, which cannot capture Flutter web crashes
/// at all. Enabled only when a `SENTRY_DSN` dart-define is baked in;
/// without it (local dev, tests) every call is a safe no-op.
class ErrorReporting {
  static const String dsn = String.fromEnvironment('SENTRY_DSN');

  static bool _initialized = false;

  static bool get isEnabled => dsn.isNotEmpty && _initialized;

  static Future<void> init() async {
    if (dsn.isEmpty || _initialized) return;
    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = EnvironmentConfig.current.name;
        options.tracesSampleRate = 0.2;
      },
    );
    _initialized = true;
  }

  static Future<void> reportError(
    Object error, [
    StackTrace? stackTrace,
  ]) async {
    if (!isEnabled) return;
    await Sentry.captureException(error, stackTrace: stackTrace);
  }
}
