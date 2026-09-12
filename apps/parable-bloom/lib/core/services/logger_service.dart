import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../config/environment_config.dart';
import 'error_reporting_service.dart';

/// Centralized logging service for the application.
///
/// Console logging in development; breadcrumbs via Firebase Crashlytics and
/// error reporting via Sentry (all platforms, including web) in production.
class LoggerService {
  // FirebaseCrashlytics is only available after a Firebase app is initialized.
  // In unit tests we typically don't call `Firebase.initializeApp`, so we
  // lazily resolve the instance and quietly ignore calls if it fails.
  static FirebaseCrashlytics? get _crashlytics {
    if (kIsWeb) {
      return null;
    }
    try {
      return FirebaseCrashlytics.instance;
    } catch (_) {
      // initialization failure (no app) – just disable crashlytics
      return null;
    }
  }

  static void _safeCrashlyticsLog(String message) {
    final crashlytics = _crashlytics;
    if (crashlytics == null) {
      return;
    }
    try {
      crashlytics.log(message);
    } catch (_) {
      // Ignore Crashlytics runtime issues in local/dev environments.
    }
  }

  static void _reportError(Object error, StackTrace? stackTrace) {
    // Fire-and-forget: callers (including framework error handlers) must
    // never block or throw on reporting. No-op without a Sentry DSN.
    unawaited(ErrorReporting.reportError(error, stackTrace));
  }

  /// Log an info message.
  ///
  /// Appears in console in dev and as a breadcrumb in Crashlytics.
  static void info(
    String message, {
    String? tag,
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final formattedMessage =
        _format(message, level: 'INFO', tag: tag, metadata: metadata);

    if (kDebugMode || !EnvironmentConfig.isProd()) {
      debugPrint(formattedMessage);
      if (error != null) debugPrint('Error: $error');
      if (stackTrace != null) debugPrint('StackTrace: $stackTrace');
    }

    _safeCrashlyticsLog(formattedMessage);
    if (error != null) {
      _reportError(error, stackTrace);
    }
  }

  /// Log a warning message.
  ///
  /// Appears in console in dev and as a breadcrumb in Crashlytics.
  static void warn(
    String message, {
    String? tag,
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final formattedMessage =
        _format(message, level: 'WARN', tag: tag, metadata: metadata);

    if (kDebugMode || !EnvironmentConfig.isProd()) {
      debugPrint(formattedMessage);
      if (error != null) debugPrint('Error: $error');
      if (stackTrace != null) debugPrint('StackTrace: $stackTrace');
    }

    _safeCrashlyticsLog(formattedMessage);
    if (error != null) {
      _reportError(error, stackTrace);
    }
  }

  /// Log a debug message.
  ///
  /// Only appears in console in dev. Does NOT go to Crashlytics.
  /// Use this for high-volume logs like engine ticks or animations.
  static void debug(String message,
      {String? tag, Map<String, dynamic>? metadata}) {
    if (kDebugMode) {
      debugPrint(
          _format(message, level: 'DEBUG', tag: tag, metadata: metadata));
    }
  }

  /// Log an error with an optional stack trace.
  ///
  /// Always reported to Sentry (all platforms) and printed to console in dev.
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    Map<String, dynamic>? metadata,
    bool fatal = false,
  }) {
    final formattedMessage =
        _format(message, level: 'ERROR', tag: tag, metadata: metadata);

    if (kDebugMode || !EnvironmentConfig.isProd()) {
      debugPrint(formattedMessage);
      if (error != null) debugPrint('Error: $error');
      if (stackTrace != null) debugPrint('StackTrace: $stackTrace');
    }

    _reportError(error ?? message, stackTrace);
  }

  static String _format(String message,
      {required String level, String? tag, Map<String, dynamic>? metadata}) {
    final timestamp =
        DateTime.now().toIso8601String().split('T').last.substring(0, 12);
    final tagPart = tag != null ? '[$tag] ' : '';
    final metadataPart = (metadata != null && metadata.isNotEmpty)
        ? ' | metadata: $metadata'
        : '';
    return '[$timestamp] [$level] $tagPart$message$metadataPart';
  }
}
