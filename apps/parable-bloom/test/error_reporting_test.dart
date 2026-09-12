import 'package:flutter_test/flutter_test.dart';

import 'package:parable_bloom/core/services/error_reporting_service.dart';
import 'package:parable_bloom/core/services/logger_service.dart';

void main() {
  group('ErrorReporting', () {
    test('disabled without a baked-in DSN (unit tests)', () {
      // No --dart-define=SENTRY_DSN in tests, so reporting is inert.
      expect(ErrorReporting.dsn, isEmpty);
      expect(ErrorReporting.isEnabled, isFalse);
    });

    test('reportError is a safe no-op when disabled', () async {
      await ErrorReporting.reportError(
        Exception('boom'),
        StackTrace.current,
      );
    });

    test('LoggerService does not throw without backends', () {
      LoggerService.debug('debug message', tag: 'Test');
      LoggerService.info('info message', tag: 'Test');
      LoggerService.warn('warn message', tag: 'Test');
      LoggerService.error(
        'error message',
        error: Exception('boom'),
        stackTrace: StackTrace.current,
        tag: 'Test',
      );
    });
  });
}
