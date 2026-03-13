import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/parable_bloom_app.dart';
import 'firebase_options.dart';
import 'providers/infrastructure_providers.dart';
import 'providers/service_providers.dart';
import 'services/analytics_service.dart';
import 'services/logger_service.dart';
import 'services/plausible_analytics_client.dart';

/// Entry point for Parable Bloom.
///
/// Environment Configuration:
/// The app supports three environments via the APP_ENV dart-define variable:
/// - Development (dev):   Uses game_progress_dev Firestore collection
/// - Preview (preview):   Uses game_progress_preview Firestore collection
/// - Production (prod):   Uses game_progress_prod Firestore collection
///
/// Run the app with a specific environment:
/// - flutter run --dart-define=APP_ENV=dev       # Development (default)
/// - flutter run --dart-define=APP_ENV=preview   # Preview
/// - flutter run --dart-define=APP_ENV=prod      # Production
///
/// Run tests with a specific environment:
/// - flutter test --dart-define=APP_ENV=dev
///
/// Build web with a specific environment:
/// - flutter build web --dart-define=APP_ENV=prod
/// - flutter build web --dart-define=APP_ENV=preview
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with FlutterFire-generated options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    // Pass all uncaught "fatal" errors from the framework to Crashlytics.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  }

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    LoggerService.error('Uncaught platform error',
        error: error, stackTrace: stack, fatal: true);
    return true;
  };

  LoggerService.info(
    kIsWeb
        ? 'Firebase initialized (Crashlytics disabled on web)'
        : 'Firebase initialized with Crashlytics',
  );

  // Initialize Hive
  await Hive.initFlutter();
  final hiveBox = await Hive.openBox('garden_save');

  // Initialize Analytics (Firebase + Plausible self-hosted)
  final plausibleClient = PlausibleAnalyticsClient.fromEnvironment(
    isOptedOut: () => hiveBox.get('plausible_ignore', defaultValue: false) as bool,
  );
  final analyticsService = AnalyticsService(plausibleClient: plausibleClient);
  await analyticsService.init();

  runApp(
    ProviderScope(
      overrides: [
        hiveBoxProvider.overrideWithValue(hiveBox),
        analyticsServiceProvider.overrideWithValue(analyticsService),
      ],
      child: const ParableBloomApp(),
    ),
  );
}
