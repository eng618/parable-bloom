import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Enable debug view locally if needed
  Future<void> init() async {
    await _analytics.setAnalyticsCollectionEnabled(true);
    // Optional: Debug mode for local testing
    // await _analytics.setCurrentScreen(screenName: 'Home');
  }

  Future<void> logLevelStart(int levelId) async {
    await _analytics.logEvent(
      name: 'level_start',
      parameters: {'level_id': levelId},
    );
  }

  Future<void> logLevelComplete(int levelId, int taps, int wrongTaps) async {
    await _analytics.logEvent(
      name: 'level_complete',
      parameters: {
        'level_id': levelId,
        'taps_total': taps,
        'wrong_taps': wrongTaps,
        'perfect':
            wrongTaps == 0 ? 1 : 0, // Firebase requires num/string, not bool
      },
    );
  }

  Future<void> logWrongTap(int levelId, int remainingLives) async {
    await _analytics.logEvent(
      name: 'wrong_tap',
      parameters: {'level_id': levelId, 'remaining_lives': remainingLives},
    );
  }

  Future<void> logGameOver(int levelId) async {
    await _analytics.logEvent(
      name: 'game_over',
      parameters: {'level_id': levelId},
    );
  }

  Future<void> logSyncConflictDetected({
    required String source,
    required String conflictType,
    required int localLevel,
    int? cloudLevel,
  }) async {
    await _analytics.logEvent(
      name: 'sync_conflict_detected',
      parameters: {
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
    await _analytics.logEvent(
      name: 'sync_conflict_resolved',
      parameters: {
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
    await _analytics.logEvent(
      name: 'cloud_sync_unavailable',
      parameters: {
        'source': source,
        'reason': reason,
      },
    );
  }

  // Add more as needed: hint_used, mercy_purchase, parable_viewed
}
