import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'core/services/error_reporting_service.dart';
import 'core/services/logger_service.dart';
import 'core/services/openpanel_analytics_client.dart';

const bool _isScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

/// Cold start will not wait longer than this for anonymous sign-in.
/// The attempt keeps running after the budget; auth listeners apply it.
const Duration _guestSessionBudget = Duration(seconds: 2);

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

  // Hive is the offline source of truth and does not depend on the network.
  // Overlap it with Firebase so a slow auth handshake cannot delay the box
  // open. Guest sign-in stays off this path: bundled assets cover play
  // until the session exists.
  if (_isScreenshotMode) {
    LoggerService.info('Running in screenshot mode (Firebase disabled)');
    await Hive.initFlutter();
  } else {
    await Future.wait([
      _initFirebaseAndReporting(),
      Hive.initFlutter(),
    ]);
  }

  // Pass all uncaught framework errors to the logger (→ Sentry).
  // Works on web too, unlike the previous Crashlytics-only handler.
  // Installed after Sentry init so the first captured error has a client.
  // Screenshot runs ignore tooltip pointer-routing noise (it does not
  // affect the captured frame) and forward every other error to the
  // integration-test handler. Production keeps the logger as the sink.
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    LoggerService.error(
      'Uncaught Flutter error',
      error: details.exception,
      stackTrace: details.stack,
      fatal: true,
    );
    if (!_isScreenshotMode) {
      return;
    }
    if (details.exceptionAsString().contains('RawTooltipState')) {
      return;
    }
    originalOnError?.call(details);
  };

  if (!_isScreenshotMode) {
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Sentry
    PlatformDispatcher.instance.onError = (error, stack) {
      LoggerService.error('Uncaught platform error',
          error: error, stackTrace: stack, fatal: true);
      return true;
    };
  }

  final hiveBox = await Hive.openBox('garden_save');

  if (_isScreenshotMode) {
    await _seedScreenshotData(hiveBox);
  }

  // Initialize Analytics (Firebase + OpenPanel self-hosted).
  // Guest sign-in overlaps this work. Auth-gated reads (configs_prod)
  // need a session, and progress sync keys off the UID. Bundled assets
  // cover play when the handshake is slow or unavailable.
  final Future<void>? guestSession =
      _isScreenshotMode ? null : _ensureGuestSession();

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
    try {
      await guestSession!.timeout(_guestSessionBudget);
    } on TimeoutException {
      LoggerService.info(
        'Guest session still pending; continuing offline-first',
        tag: 'AuthBootstrap',
      );
    }
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

/// Initializes Firebase and Sentry. Sentry is a no-op without a
/// `SENTRY_DSN` dart-define; pass `--dart-define=SENTRY_DSN=...` in CI.
Future<void> _initFirebaseAndReporting() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ErrorReporting.init();
  LoggerService.info(
    'Firebase initialized (error reporting via Sentry)',
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

Future<void> _seedScreenshotData(Box<dynamic> hiveBox) async {
  final completedLevelsList = <String>[];
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
