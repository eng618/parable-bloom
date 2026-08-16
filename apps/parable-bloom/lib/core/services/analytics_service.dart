import 'package:firebase_analytics/firebase_analytics.dart';

import 'logger_service.dart';
import 'openpanel_analytics_client.dart';

class AnalyticsService {
  final FirebaseAnalytics? _analytics;
  final OpenpanelAnalyticsClient? _openpanel;

  AnalyticsService({
    FirebaseAnalytics? analytics,
    OpenpanelAnalyticsClient? openpanelClient,
  })  : _analytics = analytics,
        _openpanel = openpanelClient;

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
  Future<void> init({bool enabled = true}) async {
    final firebase = _firebase;
    if (firebase == null) {
      return;
    }
    await firebase.setAnalyticsCollectionEnabled(enabled);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Core Gameplay & Level Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> logLevelStart(
    dynamic levelId, {
    String? moduleId,
    String? tier,
    bool? isChallenge,
    int attempts = 1,
  }) async {
    final params = <String, Object>{
      'level_id': levelId.toString(),
      if (moduleId != null) 'module_id': moduleId,
      if (tier != null) 'tier': tier,
      if (isChallenge != null) 'is_challenge': isChallenge ? 1 : 0,
      'attempts': attempts,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'level_start', parameters: params);
    }
    await _trackOpenpanel(eventName: 'level_start', properties: params);
  }

  Future<void> logLevelComplete(
    dynamic levelId,
    int taps,
    int wrongTaps, {
    int attempts = 1,
    int elapsedSeconds = -1,
    String? moduleId,
    String? tier,
  }) async {
    final params = <String, Object>{
      'level_id': levelId.toString(),
      'taps_total': taps,
      'wrong_taps': wrongTaps,
      'perfect': wrongTaps == 0 ? 1 : 0,
      'attempts': attempts,
      'elapsed_seconds': elapsedSeconds,
      if (moduleId != null) 'module_id': moduleId,
      if (tier != null) 'tier': tier,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'level_complete', parameters: params);
    }
    await _trackOpenpanel(eventName: 'level_complete', properties: params);
  }

  Future<void> logLevelRestart(
    dynamic levelId,
    int attempts, {
    int elapsedSeconds = -1,
  }) async {
    final params = <String, Object>{
      'level_id': levelId.toString(),
      'attempts': attempts,
      if (elapsedSeconds >= 0) 'elapsed_seconds': elapsedSeconds,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'level_restart', parameters: params);
    }
    await _trackOpenpanel(eventName: 'level_restart', properties: params);
  }

  Future<void> logLevelQuit({
    required dynamic levelId,
    int elapsedSeconds = -1,
    int taps = -1,
    int remainingVines = -1,
  }) async {
    final params = <String, Object>{
      'level_id': levelId.toString(),
      if (elapsedSeconds >= 0) 'elapsed_seconds': elapsedSeconds,
      if (taps >= 0) 'taps_before_quit': taps,
      if (remainingVines >= 0) 'remaining_vines': remainingVines,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'level_quit', parameters: params);
    }
    await _trackOpenpanel(eventName: 'level_quit', properties: params);
  }

  Future<void> logWrongTap(dynamic levelId, int remainingLives) async {
    final params = <String, Object>{
      'level_id': levelId.toString(),
      'remaining_lives': remainingLives,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'wrong_tap', parameters: params);
    }
    await _trackOpenpanel(eventName: 'wrong_tap', properties: params);
  }

  Future<void> logGameOver(dynamic levelId) async {
    final params = <String, Object>{'level_id': levelId.toString()};

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'game_over', parameters: params);
    }
    await _trackOpenpanel(eventName: 'game_over', properties: params);
  }

  Future<void> logModuleCompleted({
    required String moduleId,
    required String title,
    int totalTimeSeconds = -1,
  }) async {
    final params = <String, Object>{
      'module_id': moduleId,
      'module_title': title,
      if (totalTimeSeconds >= 0) 'total_time_seconds': totalTimeSeconds,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'module_completed', parameters: params);
    }
    await _trackOpenpanel(eventName: 'module_completed', properties: params);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Onboarding & Tutorial
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> logTutorialStart({String source = 'new_game'}) async {
    final params = <String, Object>{'source': source};

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'tutorial_start', parameters: params);
    }
    await _trackOpenpanel(eventName: 'tutorial_start', properties: params);
  }

  Future<void> logTutorialStepComplete({
    required int stepNumber,
    required String stepId,
    int elapsedSeconds = -1,
  }) async {
    final params = <String, Object>{
      'step_number': stepNumber,
      'step_id': stepId,
      if (elapsedSeconds >= 0) 'elapsed_seconds': elapsedSeconds,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(
          name: 'tutorial_step_complete', parameters: params);
    }
    await _trackOpenpanel(
        eventName: 'tutorial_step_complete', properties: params);
  }

  Future<void> logTutorialComplete({
    int totalSeconds = -1,
    bool skipped = false,
  }) async {
    final params = <String, Object>{
      'skipped': skipped ? 1 : 0,
      if (totalSeconds >= 0) 'total_seconds': totalSeconds,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'tutorial_complete', parameters: params);
    }
    await _trackOpenpanel(eventName: 'tutorial_complete', properties: params);
  }

  Future<void> logTutorialSkip({required int atStep}) async {
    final params = <String, Object>{'at_step': atStep};

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'tutorial_skip', parameters: params);
    }
    await _trackOpenpanel(eventName: 'tutorial_skip', properties: params);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Spiritual Journey & Scripture Library
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> logParableViewed(String parableId,
      {String source = 'game_unlock'}) async {
    final params = <String, Object>{
      'parable_id': parableId,
      'source': source,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'parable_viewed', parameters: params);
    }
    await _trackOpenpanel(eventName: 'parable_viewed', properties: params);
  }

  Future<void> logScriptureUnlocked({
    required String scriptureId,
    required String reference,
    required String parableId,
  }) async {
    final params = <String, Object>{
      'scripture_id': scriptureId,
      'reference': reference,
      'parable_id': parableId,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'scripture_unlocked', parameters: params);
    }
    await _trackOpenpanel(eventName: 'scripture_unlocked', properties: params);
  }

  Future<void> logScriptureRead({
    required String scriptureId,
    required String reference,
    required String translation,
    int durationSeconds = -1,
  }) async {
    final params = <String, Object>{
      'scripture_id': scriptureId,
      'reference': reference,
      'translation': translation,
      if (durationSeconds >= 0) 'duration_seconds': durationSeconds,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'scripture_read', parameters: params);
    }
    await _trackOpenpanel(eventName: 'scripture_read', properties: params);
  }

  Future<void> logTranslationChanged({
    required String previousTranslation,
    required String newTranslation,
  }) async {
    final params = <String, Object>{
      'previous_translation': previousTranslation,
      'new_translation': newTranslation,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'translation_changed', parameters: params);
    }
    await _trackOpenpanel(eventName: 'translation_changed', properties: params);
  }

  Future<void> logScriptureShared({
    required String scriptureId,
    required String reference,
    required String translation,
  }) async {
    final params = <String, Object>{
      'scripture_id': scriptureId,
      'reference': reference,
      'translation': translation,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'scripture_shared', parameters: params);
    }
    await _trackOpenpanel(eventName: 'scripture_shared', properties: params);
  }

  Future<void> logJournalOpened({
    required String initialTab,
    int unlockedCount = 0,
    int totalCount = 0,
  }) async {
    final params = <String, Object>{
      'initial_tab': initialTab,
      'unlocked_count': unlockedCount,
      'total_count': totalCount,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'journal_opened', parameters: params);
    }
    await _trackOpenpanel(eventName: 'journal_opened', properties: params);
  }

  Future<void> logJournalTabChanged(String tabName) async {
    final params = <String, Object>{'tab_name': tabName};

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'journal_tab_changed', parameters: params);
    }
    await _trackOpenpanel(eventName: 'journal_tab_changed', properties: params);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Garden & Visual Feedback
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> logGardenViewed({
    required int bloomedCount,
    required String currentStage,
  }) async {
    final params = <String, Object>{
      'bloomed_count': bloomedCount,
      'current_stage': currentStage,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'garden_viewed', parameters: params);
    }
    await _trackOpenpanel(eventName: 'garden_viewed', properties: params);
  }

  Future<void> logFlowerBloomed({
    required String flowerId,
    required dynamic levelId,
    required int totalBloomed,
  }) async {
    final params = <String, Object>{
      'flower_id': flowerId,
      'level_id': levelId.toString(),
      'total_bloomed': totalBloomed,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'flower_bloomed', parameters: params);
    }
    await _trackOpenpanel(eventName: 'flower_bloomed', properties: params);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Auth, Cloud Sync & Conflicts
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> logAuthAction({
    required String action,
    required bool success,
    String? errorCode,
  }) async {
    final params = <String, Object>{
      'action': action,
      'success': success ? 1 : 0,
      if (errorCode != null) 'error_code': errorCode,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'auth_action', parameters: params);
    }
    await _trackOpenpanel(eventName: 'auth_action', properties: params);
  }

  Future<void> logSyncConflictDetected({
    required String source,
    required String conflictType,
    required dynamic localLevel,
    dynamic cloudLevel,
  }) async {
    final params = <String, Object>{
      'source': source,
      'conflict_type': conflictType,
      'local_level': localLevel.toString(),
      'cloud_level': (cloudLevel ?? 'unknown').toString(),
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(
          name: 'sync_conflict_detected', parameters: params);
    }
    await _trackOpenpanel(
        eventName: 'sync_conflict_detected', properties: params);
  }

  Future<void> logSyncConflictResolved({
    required String source,
    required String conflictType,
    required String resolution,
    required bool automatic,
  }) async {
    final params = <String, Object>{
      'source': source,
      'conflict_type': conflictType,
      'resolution': resolution,
      'automatic': automatic ? 1 : 0,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(
          name: 'sync_conflict_resolved', parameters: params);
    }
    await _trackOpenpanel(
        eventName: 'sync_conflict_resolved', properties: params);
  }

  Future<void> logCloudSyncUnavailable({
    required String source,
    required String reason,
  }) async {
    final params = <String, Object>{
      'source': source,
      'reason': reason,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(
          name: 'cloud_sync_unavailable', parameters: params);
    }
    await _trackOpenpanel(
        eventName: 'cloud_sync_unavailable', properties: params);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Settings, Screen Views & Session Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> logSettingChanged({
    required String settingName,
    required Object value,
  }) async {
    final params = <String, Object>{
      'setting_name': settingName,
      'value': value.toString(),
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'setting_changed', parameters: params);
    }
    await _trackOpenpanel(eventName: 'setting_changed', properties: params);
  }

  Future<void> logScreenView(String screenName) async {
    final params = <String, Object>{'screen_name': screenName};

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logScreenView(screenName: screenName);
    }
    await _trackOpenpanel(eventName: 'screen_view', properties: params);
  }

  Future<void> logSessionStart({
    required String sessionId,
    int completedLevelsCount = 0,
    required String appVersion,
  }) async {
    final params = <String, Object>{
      'session_id': sessionId,
      'completed_levels_count': completedLevelsCount,
      'app_version': appVersion,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'session_start', parameters: params);
    }
    await _trackOpenpanel(eventName: 'session_start', properties: params);
  }

  Future<void> logSessionEnd({
    int sessionDurationSeconds = -1,
    int levelsPlayed = 0,
  }) async {
    final params = <String, Object>{
      if (sessionDurationSeconds >= 0)
        'session_duration_seconds': sessionDurationSeconds,
      'levels_played': levelsPlayed,
    };

    final firebase = _firebase;
    if (firebase != null) {
      await firebase.logEvent(name: 'session_end', parameters: params);
    }
    await _trackOpenpanel(eventName: 'session_end', properties: params);
  }

  Future<void> setCollectionEnabled(bool enabled) async {
    final firebase = _firebase;
    if (firebase == null) {
      return;
    }
    await firebase.setAnalyticsCollectionEnabled(enabled);
  }

  Future<void> _trackOpenpanel({
    required String eventName,
    required Map<String, Object?> properties,
  }) async {
    final openpanel = _openpanel;
    if (openpanel == null) {
      return;
    }
    await openpanel.trackEvent(
      eventName: eventName,
      properties: properties,
    );
  }
}
