import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:parable_bloom/core/providers/infrastructure_providers.dart';
import 'package:parable_bloom/core/providers/service_providers.dart';
import 'package:parable_bloom/core/providers/settings_providers.dart';
import 'package:parable_bloom/core/services/analytics_service.dart';
import 'package:parable_bloom/features/auth/application/providers/auth_providers.dart';
import 'package:parable_bloom/features/auth/data/services/auth_service.dart';
import 'package:parable_bloom/features/game/application/providers/module_providers.dart';
import 'package:parable_bloom/features/game/application/providers/progress_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/cloud_sync_state.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/settings/presentation/screens/settings_screen.dart';

class _FakeBox implements Box<dynamic> {
  final Map<dynamic, dynamic> _store = {};
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _store.containsKey(key) ? _store[key] : defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async => _store[key] = value;
  @override
  Future<int> clear() async {
    _store.clear();
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAnalyticsService extends AnalyticsService {
  @override
  Future<void> logScreenView(String screenName) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testModules = [
    ModuleData(
      id: 1,
      name: 'Seedling',
      themeSeed: 'forest',
      levels: ['lvl_m01_01'],
      challengeLevel: '',
      parable: const {},
      unlockMessage: '',
      scriptures: const [],
    ),
  ];

  Widget createSettingsScreen() {
    final fakeBox = _FakeBox();
    final mockAuth = MockFirebaseAuth();
    return ProviderScope(
      overrides: [
        hiveBoxProvider.overrideWithValue(fakeBox),
        analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService()),
        authServiceProvider.overrideWithValue(AuthService(mockAuth)),
        authUserProvider.overrideWith((ref) => Stream.value(null)),
        cloudSyncAvailabilityProvider
            .overrideWith((ref) async => const CloudSyncAvailability(
                  isAvailable: false,
                  reason: CloudSyncAvailabilityReason.signedOut,
                )),
        cloudSyncEnabledProvider.overrideWith((ref) async => false),
        gameProgressProvider
            .overrideWith(() => _FakeProgressNotifier(GameProgress.initial())),
        modulesProvider.overrideWithValue(AsyncValue.data(testModules)),
        appVersionProvider.overrideWith((ref) async => '1.8.2+19'),
        themeModeProvider.overrideWith(() => _FakeThemeModeNotifier()),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  group('SettingsScreen Widget Tests', () {
    testWidgets('Renders app bar title and major setting categories',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Audio & Haptics'), findsOneWidget);
      expect(find.text('Data & Sync'), findsOneWidget);
    });

    testWidgets('Toggles theme mode selection', (tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Theme'), findsOneWidget);
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
    });

    testWidgets('Displays version information in About & Privacy',
        (tester) async {
      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Version'),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Version'), findsOneWidget);
      expect(find.text('1.8.2+19'), findsOneWidget);
    });
  });
}

class _FakeProgressNotifier extends Notifier<GameProgress>
    implements GameProgressNotifier {
  final GameProgress _initial;
  _FakeProgressNotifier(this._initial);
  @override
  GameProgress build() => _initial;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeThemeModeNotifier extends Notifier<AppThemeMode>
    implements ThemeModeNotifier {
  @override
  AppThemeMode build() => AppThemeMode.system;
  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
  }
}
