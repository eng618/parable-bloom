import 'package:firebase_analytics/firebase_analytics.dart';

import 'logger_service.dart';
import 'plausible_analytics_client.dart';

class AnalyticsService {
  final FirebaseAnalytics? _analytics;
  final PlausibleAnalyticsClient? _plausible;

  AnalyticsService({
    FirebaseAnalytics? analytics,
    PlausibleAnalyticsClient? plausibleClient,
  })  : _analytics = analytics,
        _plausible = plausibleClient;

  FirebaseAnalytics? get _firebase {
    if (_analytics != null) {
      return _analytics;
    }
    try {
      return FirebaseAnalytics.instance;
    } catch (error, stackTrace) {
      LoggerService.error(
        'Firebase Analytics unavailable',
        error: error,
        stackTrace: stackTrace,
        tag: 'AnalyticsService',
      );
      return null;
    }
  }

  // Enable debug view locally if needed
  Future<void> init() async {
    final firebase = _firebase;
    if (firebase == null) {
      return;
    }
    await firebase.setAnalyticsCollectionEnabled(true);
    // Optional: Debug mode for local testing
    // await _analytics.setCurrentScreen(screenName: 'Home');
  }

  Future<void> logLevelStart(int levelId) async {
    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(
        name: 'level_start',
        parameters: {'level_id': levelId},
      );
    }
    await _trackPlausible(
      eventName: 'level_start',
      properties: {'level_id': levelId},
    );
  }

  Future<void> logLevelComplete(
    int levelId,
    int taps,
    int wrongTaps, {
    int attempts = 1,
    int elapsedSeconds = -1,
  }) async {
    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(
        name: 'level_complete',
        parameters: {
          'level_id': levelId,
          'taps_total': taps,
          'wrong_taps': wrongTaps,
          'perfect': wrongTaps == 0 ? 1 : 0,
          'attempts': attempts,
          'elapsed_seconds': elapsedSeconds,
        },
      );
    }
    await _trackPlausible(
      eventName: 'level_complete',
      properties: {
        'level_id': levelId,
        'taps_total': taps,
        'wrong_taps': wrongTaps,
        'perfect': wrongTaps == 0 ? 1 : 0,
        'attempts': attempts,
        'elapsed_seconds': elapsedSeconds,
      },
    );
  }

  Future<void> logLevelRestart(int levelId, int attempts) async {
    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(
        name: 'level_restart',
        parameters: {
          'level_id': levelId,
          'attempts': attempts,
        },
      );
    }
    await _trackPlausible(
      eventName: 'level_restart',
      properties: {
        'level_id': levelId,
        'attempts': attempts,
      },
    );
  }

  Future<void> logWrongTap(int levelId, int remainingLives) async {
    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(
        name: 'wrong_tap',
        parameters: {'level_id': levelId, 'remaining_lives': remainingLives},
      );
    }
    await _trackPlausible(
      eventName: 'wrong_tap',
      properties: {
        'level_id': levelId,
        'remaining_lives': remainingLives,
      },
    );
  }

  Future<void> logGameOver(int levelId) async {
    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(
        name: 'game_over',
        parameters: {'level_id': levelId},
      );
    }
    await _trackPlausible(
      eventName: 'game_over',
      properties: {'level_id': levelId},
    );
  }

  Future<void> logSyncConflictDetected({
    required String source,
    required String conflictType,
    required int localLevel,
    int? cloudLevel,
  }) async {
    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(
        name: 'sync_conflict_detected',
        parameters: {
          'source': source,
          'conflict_type': conflictType,
          'local_level': localLevel,
          'cloud_level': cloudLevel ?? -1,
        },
      );
    }
    await _trackPlausible(
      eventName: 'sync_conflict_detected',
      properties: {
        'source': source,
        'conflict_type': conflictType,
        'local_level': localLevel,
        'cloud_level': cloudLevel ?? -1,
      },
    );
  }

  Future<void> logSyncConflictResolved({
    required String source,
    required String conflictType,
    required String resolution,
    required bool automatic,
  }) async {
    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(
        name: 'sync_conflict_resolved',
        parameters: {
          'source': source,
          'conflict_type': conflictType,
          'resolution': resolution,
          'automatic': automatic ? 1 : 0,
        },
      );
    }
    await _trackPlausible(
      eventName: 'sync_conflict_resolved',
      properties: {
        'source': source,
        'conflict_type': conflictType,
        'resolution': resolution,
        'automatic': automatic ? 1 : 0,
      },
    );
  }

  Future<void> logCloudSyncUnavailable({
    required String source,
    required String reason,
  }) async {
    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(
        name: 'cloud_sync_unavailable',
        parameters: {
          'source': source,
          'reason': reason,
        },
      );
    }
    await _trackPlausible(
      eventName: 'cloud_sync_unavailable',
      properties: {
        'source': source,
        'reason': reason,
      },
    );
  }

  Future<void> _trackPlausible({
    required String eventName,
    required Map<String, Object?> properties,
  }) async {
    final plausible = _plausible;
    if (plausible == null) {
      return;
    }
    await plausible.trackEvent(
      eventName: eventName,
      properties: properties,
    );
  }

  // Add more as needed: hint_used, mercy_purchase, parable_viewed
}
