import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:parable_bloom/core/providers/settings_providers.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/presentation/widgets/game_header.dart';
import 'package:parable_bloom/features/game/presentation/widgets/pause_menu_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameHeader Widget Tests', () {
    testWidgets('Renders grace hearts and triggers pause callback',
        (tester) async {
      bool pauseTriggered = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            graceProvider.overrideWith(() => _FakeGraceNotifier(2)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: GameHeader(
                onPause: () {
                  pauseTriggered = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // With grace = 2 out of max 3, we should find 2 filled favorite icons and 1 border icon
      expect(find.byIcon(Icons.favorite), findsNWidgets(2));
      expect(find.byIcon(Icons.favorite_border), findsNWidgets(1));
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      expect(pauseTriggered, isTrue);
    });
  });

  group('PauseMenuDialog Widget Tests', () {
    testWidgets('Renders pause menu with action buttons and handles actions',
        (tester) async {
      bool restartTriggered = false;
      bool homeTriggered = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeModeProvider.overrideWith(() => _FakeThemeModeNotifier()),
            backgroundAudioEnabledProvider
                .overrideWith(() => _FakeAudioNotifier()),
            hapticsEnabledProvider.overrideWith(() => _FakeHapticsNotifier()),
            vineStyleProvider.overrideWith(() => _FakeVineStyleNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PauseMenuDialog(
                onRestart: () {
                  restartTriggered = true;
                },
                onHome: () {
                  homeTriggered = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.replay_rounded));
      await tester.pumpAndSettle();
      expect(restartTriggered, isTrue);

      await tester.tap(find.byIcon(Icons.home_rounded));
      await tester.pumpAndSettle();
      expect(homeTriggered, isTrue);
    });
  });
}

class _FakeGraceNotifier extends Notifier<int> implements GraceNotifier {
  final int _initial;
  _FakeGraceNotifier(this._initial);
  @override
  int build() => _initial;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeThemeModeNotifier extends Notifier<AppThemeMode>
    implements ThemeModeNotifier {
  @override
  AppThemeMode build() => AppThemeMode.system;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAudioNotifier extends Notifier<bool>
    implements BackgroundAudioEnabledNotifier {
  @override
  bool build() => true;
  @override
  Future<void> setEnabled(bool enabled) async {
    state = enabled;
  }
}

class _FakeHapticsNotifier extends Notifier<bool>
    implements HapticsEnabledNotifier {
  @override
  bool build() => true;
  @override
  Future<void> setEnabled(bool enabled) async {
    state = enabled;
  }
}

class _FakeVineStyleNotifier extends Notifier<VineStyle>
    implements VineStyleNotifier {
  @override
  VineStyle build() => VineStyle.classic;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
