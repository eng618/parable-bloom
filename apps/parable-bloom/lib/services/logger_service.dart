import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../core/config/environment_config.dart';

/// Centralized logging service for the application.
///
/// Handles console logging in development and breadcrumbs/error reporting
/// in production via Firebase Crashlytics.
class LoggerService {
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

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

    _crashlytics.log(formattedMessage);
    if (error != null) {
      _crashlytics.recordError(error, stackTrace,
          reason: formattedMessage, fatal: false);
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

    _crashlytics.log(formattedMessage);
    if (error != null) {
      _crashlytics.recordError(error, stackTrace,
          reason: formattedMessage, fatal: false);
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
  /// Always reported to Crashlytics and printed to console in dev.
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

    _crashlytics.recordError(
      error ?? message,
      stackTrace,
      reason: formattedMessage,
      fatal: fatal,
    );
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
