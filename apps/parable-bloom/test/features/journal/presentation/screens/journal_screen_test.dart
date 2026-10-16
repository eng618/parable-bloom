import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:parable_bloom/core/providers/service_providers.dart';
import 'package:parable_bloom/core/services/analytics_service.dart';
import 'package:parable_bloom/core/services/scripture_service.dart';
import 'package:parable_bloom/features/game/application/providers/progress_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/features/journal/application/providers/journal_display_providers.dart';
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
      {String? translationId, String? preferredTranslationId}) async {
    return {
      'text': 'Now faith is the substance of things hoped for.',
      'reference': reference,
      'translation': 'KJV',
      'didFallback': 'false',
      'fromCache': 'false',
      'requiresDownload': 'false',
    };
  }
}

class _FakeLockedNotifier extends JournalLockedStyleNotifier {
  final JournalLockedStyle _style;
  _FakeLockedNotifier(this._style);
  @override
  JournalLockedStyle build() => _style;
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
          triggerLevel: 'lvl_m01_01',
          reflectionPrompts: ['What does faith mean to you?'],
          defaultContent: 'Understanding faith and trust in God.',
        ),
      ],
    ),
  ];

  Widget createJournalScreen({
    required GameProgress progress,
    JournalLockedStyle lockedStyle = JournalLockedStyle.sealed,
  }) {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService()),
        scriptureServiceProvider.overrideWithValue(_FakeScriptureService()),
        gameProgressProvider
            .overrideWith(() => _FakeProgressNotifier(progress)),
        journalThemesProvider.overrideWithValue(AsyncValue.data(testThemes)),
        journalLockedStyleProvider
            .overrideWith(() => _FakeLockedNotifier(lockedStyle)),
      ],
      child: const MaterialApp(
        home: JournalScreen(),
      ),
    );
  }

  Future<void> turnPage(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
  }

  group('JournalScreen Widget Tests', () {
    testWidgets('Renders app bar and chapter page', (tester) async {
      final progress = GameProgress.initial();

      await tester.pumpWidget(createJournalScreen(progress: progress));
      await tester.pumpAndSettle();

      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Seeds of Faith'), findsWidgets);
      expect(find.textContaining('0 / 1 Collected'), findsWidgets);
    });

    testWidgets('Sealed style hides title until unlocked', (tester) async {
      final progress = GameProgress.initial();

      await tester.pumpWidget(createJournalScreen(progress: progress));
      await tester.pumpAndSettle();
      await turnPage(tester);

      expect(find.text('Sealed Page'), findsOneWidget);
      expect(find.text('Locked Scripture'), findsOneWidget);
      expect(
        find.text('Unlocks at Level 1 (Module 1)'),
        findsOneWidget,
      );
    });

    testWidgets('Teaser style shows title with lock hint', (tester) async {
      final progress = GameProgress.initial();

      await tester.pumpWidget(
        createJournalScreen(
          progress: progress,
          lockedStyle: JournalLockedStyle.teaser,
        ),
      );
      await tester.pumpAndSettle();
      await turnPage(tester);

      // Title visible in teaser mode (chapter chip + passage title).
      expect(find.text('Faith in Action'), findsWidgets);
      expect(
        find.text('Unlocks at Level 1 (Module 1)'),
        findsOneWidget,
      );
    });

    testWidgets('Unlocked passage renders verse inline', (tester) async {
      final progress = GameProgress.initial().copyWith(
        unlockedScriptureIds: {'faith_1'},
      );

      await tester.pumpWidget(createJournalScreen(progress: progress));
      await tester.pumpAndSettle();
      await turnPage(tester);

      expect(
        find.textContaining(
          'Now faith is the substance',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('What does faith mean to you?'), findsOneWidget);
      expect(find.textContaining('1 / 1 Collected'), findsWidgets);
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
