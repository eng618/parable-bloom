import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:parable_bloom/core/providers/service_providers.dart';
import 'package:parable_bloom/core/services/analytics_service.dart';
import 'package:parable_bloom/features/game/application/providers/module_providers.dart';
import 'package:parable_bloom/features/game/application/providers/progress_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/home/presentation/screens/home_screen.dart';

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
  }) {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService()),
        gameProgressProvider
            .overrideWith(() => _FakeProgressNotifier(progress)),
        modulesProvider
            .overrideWithValue(modules ?? AsyncValue.data(testModules)),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
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

    testWidgets('Shows "Start Tutorial" when tutorial is not completed',
        (tester) async {
      final uncompletedProgress = GameProgress.initial();

      await tester.pumpWidget(createHomeScreen(progress: uncompletedProgress));
      await tester.pump();

      expect(find.text('Start Tutorial'), findsOneWidget);
    });

    testWidgets('Shows "Play Level 1" when tutorial is completed',
        (tester) async {
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
    });

    testWidgets('Shows error and retry button when modules fail to load',
        (tester) async {
      final initialProgress = GameProgress.initial();

      await tester.pumpWidget(createHomeScreen(
        progress: initialProgress,
        modules: AsyncValue.error(
            Exception('Failed to load modules'), StackTrace.empty),
      ));
      await tester.pump();

      expect(find.text('Failed to load levels. Please try again.'),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
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
