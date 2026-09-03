import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:parable_bloom/core/providers/service_providers.dart';
import 'package:parable_bloom/core/services/analytics_service.dart';
import 'package:parable_bloom/core/services/scripture_service.dart';
import 'package:parable_bloom/features/game/application/providers/progress_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/features/journal/application/providers/journal_providers.dart';
import 'package:parable_bloom/features/journal/domain/entities/journal_theme.dart';
import 'package:parable_bloom/features/journal/presentation/screens/journal_screen.dart';

class _FakeAnalyticsService extends AnalyticsService {
  @override
  Future<void> logScreenView(String screenName) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScriptureService extends ScriptureService {
  @override
  Future<Map<String, String>> loadScripture(String reference,
      {String? translationId}) async {
    return {
      'text': 'Now faith is the substance of things hoped for.',
      'reference': reference,
      'translation': 'KJV',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<JournalTheme> testThemes = [
    const JournalTheme(
      id: 'faith',
      name: 'Seeds of Faith',
      description: 'Reflecting upon trust and faith.',
      icon: 'spa',
      passages: [
        JournalPassage(
          id: 'faith_1',
          themeId: 'faith',
          title: 'Faith in Action',
          reference: 'Hebrews 11:1',
          type: 'starter',
          triggerLevel: 'lvl_seed_01',
          reflectionPrompts: ['What does faith mean to you?'],
          defaultContent: 'Understanding faith and trust in God.',
        ),
      ],
    ),
  ];

  Widget createJournalScreen({required GameProgress progress}) {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService()),
        scriptureServiceProvider.overrideWithValue(_FakeScriptureService()),
        gameProgressProvider
            .overrideWith(() => _FakeProgressNotifier(progress)),
        journalThemesProvider.overrideWithValue(AsyncValue.data(testThemes)),
      ],
      child: const MaterialApp(
        home: JournalScreen(),
      ),
    );
  }

  group('JournalScreen Widget Tests', () {
    testWidgets('Renders app bar and theme card', (tester) async {
      final progress = GameProgress.initial();

      await tester.pumpWidget(createJournalScreen(progress: progress));
      await tester.pumpAndSettle();

      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Seeds of Faith'), findsOneWidget);
      expect(find.text('0 / 1 Collected'), findsOneWidget);
    });

    testWidgets('Shows locked scripture state when level not completed',
        (tester) async {
      final progress = GameProgress.initial();

      await tester.pumpWidget(createJournalScreen(progress: progress));
      await tester.pumpAndSettle();

      expect(find.text('Locked Scripture'), findsOneWidget);
      expect(find.text('Unlocks at Level 1'), findsOneWidget);
    });

    testWidgets('Shows unlocked passage when scripture is in unlocked list',
        (tester) async {
      final progress = GameProgress.initial().copyWith(
        unlockedScriptureIds: {'faith_1'},
      );

      await tester.pumpWidget(createJournalScreen(progress: progress));
      await tester.pumpAndSettle();

      expect(find.text('Faith in Action'), findsOneWidget);
      expect(find.text('Hebrews 11:1 (KJV)'), findsOneWidget);
      expect(find.text('1 / 1 Collected'), findsOneWidget);
    });

    testWidgets('Tapping unlocked passage opens scripture reflection sheet',
        (tester) async {
      final progress = GameProgress.initial().copyWith(
        unlockedScriptureIds: {'faith_1'},
      );

      await tester.pumpWidget(createJournalScreen(progress: progress));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Faith in Action'));
      await tester.pumpAndSettle();

      expect(find.text('What does faith mean to you?'), findsOneWidget);
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
