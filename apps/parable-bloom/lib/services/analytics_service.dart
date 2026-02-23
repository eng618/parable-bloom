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

  // Add more as needed: hint_used, mercy_purchase, parable_viewed
}
