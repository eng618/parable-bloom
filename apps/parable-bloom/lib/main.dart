import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/parable_bloom_app.dart';
import 'features/game/data/constants/game_progress_storage_keys.dart';
import 'features/game/domain/entities/game_progress.dart';
import 'firebase_options.dart';
import 'core/providers/infrastructure_providers.dart';
import 'core/providers/service_providers.dart';
import 'core/services/analytics_service.dart';
import 'core/services/logger_service.dart';
import 'core/services/openpanel_analytics_client.dart';

const bool _isScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

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

  if (!_isScreenshotMode) {
    // Initialize Firebase with FlutterFire-generated options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  if (!_isScreenshotMode && !kIsWeb) {
    // Pass all uncaught "fatal" errors from the framework to Crashlytics.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  }

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    LoggerService.error('Uncaught platform error',
        error: error, stackTrace: stack, fatal: true);
    return true;
  };

  if (_isScreenshotMode) {
    LoggerService.info('Running in screenshot mode (Firebase disabled)');
  } else {
    LoggerService.info(
      kIsWeb
          ? 'Firebase initialized (Crashlytics disabled on web)'
          : 'Firebase initialized with Crashlytics',
    );
    // Guest session for logged-out users: auth-gated reads (configs_prod)
    // require request.auth != null, and progress sync keys off the UID.
    // Non-fatal — bundled assets cover offline use. Requires Anonymous
    // sign-in enabled in the Firebase console.
    await _ensureGuestSession();
  }

  // Initialize Hive
  await Hive.initFlutter();
  final hiveBox = await Hive.openBox('garden_save');

  if (_isScreenshotMode) {
    await _seedScreenshotData(hiveBox);
  }

  // Initialize Analytics (Firebase + OpenPanel self-hosted)
  final AnalyticsService analyticsService;
  if (_isScreenshotMode) {
    analyticsService = AnalyticsService();
  } else {
    final isOptedOut =
        hiveBox.get('openpanel_ignore', defaultValue: false) as bool;
    final openpanelClient = OpenpanelAnalyticsClient.fromEnvironment(
      isOptedOut: () =>
          hiveBox.get('openpanel_ignore', defaultValue: false) as bool,
    );
    analyticsService = AnalyticsService(openpanelClient: openpanelClient);
    await analyticsService.init(enabled: !isOptedOut);
  }

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

/// Signs in anonymously when no user session exists so auth-gated Firestore
/// reads (e.g. configs_prod) and UID-keyed progress sync work for guests.
/// Upgrading to a permanent account later preserves progress via linking.
Future<void> _ensureGuestSession() async {
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      final credential = await FirebaseAuth.instance.signInAnonymously();
      LoggerService.info(
        'Guest session started: ${credential.user?.uid}',
        tag: 'AuthBootstrap',
      );
    }
  } catch (e, stack) {
    LoggerService.warn(
      'Anonymous sign-in unavailable; continuing offline-first',
      tag: 'AuthBootstrap',
    );
    LoggerService.debug('$e $stack', tag: 'AuthBootstrap');
  }
}

Future<void> _seedScreenshotData(Box<dynamic> hiveBox) async {  final completedLevelsList = <String>[];
  // Seedling levels (1 to 20 + challenge)
  for (int i = 1; i <= 20; i++) {
    final idxStr = i < 10 ? '0$i' : '$i';
    completedLevelsList.add('lvl_m01_$idxStr');
  }
  completedLevelsList.add('lvl_m01_challenge');
  // Sprout levels (1 to 20 + challenge)
  for (int i = 1; i <= 20; i++) {
    final idxStr = i < 10 ? '0$i' : '$i';
    completedLevelsList.add('lvl_m02_$idxStr');
  }
  completedLevelsList.add('lvl_m02_challenge');

  final seededProgress = GameProgress(
    currentLesson: null,
    completedLessons: {
      'lesson_1',
      'lesson_2',
      'lesson_3',
      'lesson_4',
      'lesson_5'
    },
    lessonCompleted: true,
    currentLevel: 'lvl_m03_01',
    completedLevels: Set<String>.from(completedLevelsList),
    tutorialCompleted: true,
    savedMainGameLevel: null,
    unlockedTranslations: {},
    unlockedScriptureIds: {},
  );

  await hiveBox.put(GameProgressStorageKeys.progress, seededProgress.toJson());
  await hiveBox.put(GameProgressStorageKeys.cloudSyncEnabled, false);
  await hiveBox.put('openpanel_ignore', true);
}
