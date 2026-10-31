import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:parable_bloom/core/providers/infrastructure_providers.dart';
import 'package:parable_bloom/core/providers/service_providers.dart';
import 'package:parable_bloom/core/services/analytics_service.dart';
import 'package:parable_bloom/features/game/application/providers/module_providers.dart';
import 'package:parable_bloom/features/game/application/providers/progress_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/home/application/providers/habit_providers.dart';
import 'package:parable_bloom/features/home/presentation/screens/home_screen.dart';
import 'package:parable_bloom/features/home/presentation/widgets/session_close_sheet.dart';

class _FakeAnalyticsService extends AnalyticsService {
  @override
  Future<void> logScreenView(String screenName) async {}

  @override
  Future<void> logHabitDayReturn({required int daysSinceLast}) async {}

  @override
  Future<void> logHabitSessionCloseShown({
    required bool hadScriptureUnlockToday,
  }) async {}

  @override
  Future<void> logHabitSessionCloseAction(String action) async {}
}

class _FakeBox implements Box<dynamic> {
  final Map _store = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _store.containsKey(key) ? _store[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => _store[key] = value;

  @override
  Future<void> delete(dynamic key) async => _store.remove(key);

  @override
  bool containsKey(dynamic key) => _store.containsKey(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testModules = [
    ModuleData(
      id: 1,
      name: 'Seedling',
      themeSeed: 'forest',
      levels: ['lvl_m01_01', 'lvl_m01_02'],
      challengeLevel: 'lvl_m01_challenge',
      parable: const {},
      unlockMessage: 'Unlocked Seedling',
      scriptures: const [],
    ),
  ];

  Widget createHomeScreen({
    required GameProgress progress,
    AsyncValue<List<ModuleData>>? modules,
    Box? habitBox,
  }) {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService()),
        hiveBoxProvider.overrideWithValue(habitBox ?? _FakeBox() as Box),
        gameProgressProvider.overrideWith(
          () => _FakeProgressNotifier(progress),
        ),
        modulesProvider.overrideWithValue(
          modules ?? AsyncValue.data(testModules),
        ),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  group('HomeScreen Widget Tests', () {
    testWidgets('Renders title, settings, and journal buttons', (tester) async {
      final initialProgress = GameProgress.initial();

      await tester.pumpWidget(createHomeScreen(progress: initialProgress));
      await tester.pump();

      expect(find.text('Parable Bloom'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
    });

    testWidgets('Shows "Start Tutorial" when tutorial is not completed', (
      tester,
    ) async {
      final uncompletedProgress = GameProgress.initial();

      await tester.pumpWidget(createHomeScreen(progress: uncompletedProgress));
      await tester.pump();

      expect(find.text('Start Tutorial'), findsOneWidget);
    });

    testWidgets('Shows "Play Level 1" when tutorial is completed', (
      tester,
    ) async {
      final progress = GameProgress.initial().copyWith(
        tutorialCompleted: true,
        currentLevel: 'lvl_m01_01',
      );

      await tester.pumpWidget(createHomeScreen(progress: progress));
      await tester.pump();

      expect(find.text('Play Level 1'), findsOneWidget);
    });

    testWidgets(
      'Shows "All Levels Complete" when all playlist levels are finished',
      (tester) async {
        final completedProgress = GameProgress.initial().copyWith(
          tutorialCompleted: true,
          completedLevels: {'lvl_m01_01', 'lvl_m01_02', 'lvl_m01_challenge'},
          currentLevel: 'lvl_m01_challenge',
        );

        await tester.pumpWidget(createHomeScreen(progress: completedProgress));
        await tester.pump();

        expect(find.text('All Levels Complete'), findsOneWidget);
        expect(find.text('More levels coming soon!'), findsOneWidget);
      },
    );

    testWidgets('Shows error and retry button when modules fail to load', (
      tester,
    ) async {
      final initialProgress = GameProgress.initial();

      await tester.pumpWidget(
        createHomeScreen(
          progress: initialProgress,
          modules: AsyncValue.error(
            Exception('Failed to load modules'),
            StackTrace.empty,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Failed to load levels. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Shows welcome-back line after a prior calendar day visit', (
      tester,
    ) async {
      final box = _FakeBox();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      box.put(kHabitLastSessionAtKey, yesterday.toIso8601String());

      await tester.pumpWidget(
        createHomeScreen(
          progress: GameProgress.initial(),
          habitBox: box as Box,
        ),
      );
      await tester.pump();
      await tester.pump();

      final welcomeFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text && kWelcomeBackMessages.contains(widget.data),
      );
      expect(welcomeFinder, findsOneWidget);
    });
  });
}

class _FakeProgressNotifier extends Notifier<GameProgress>
    implements GameProgressNotifier {
  final GameProgress _initialState;
  _FakeProgressNotifier(this._initialState);

  @override
  GameProgress build() => _initialState;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
