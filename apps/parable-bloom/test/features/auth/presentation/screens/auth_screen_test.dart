import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/auth/data/services/auth_service.dart';
import 'package:parable_bloom/features/auth/application/providers/auth_providers.dart';
import 'package:parable_bloom/features/auth/presentation/screens/auth_screen.dart';
import 'package:parable_bloom/features/game/application/providers/progress_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/cloud_sync_state.dart';
import 'package:parable_bloom/features/game/domain/entities/game_progress.dart';
import 'package:parable_bloom/providers/service_providers.dart';
import 'package:parable_bloom/services/analytics_service.dart';

class FakeUserCredential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestGameProgressNotifier extends GameProgressNotifier {
  SyncConflictState nextConflictState = SyncConflictState(
    type: SyncConflictType.none,
    localProgress: GameProgress.initial(),
    cloudProgress: null,
  );

  bool enableCalled = false;
  SyncConflictResolution? resolvedWith;

  @override
  GameProgress build() => GameProgress.initial();

  @override
  Future<void> enableCloudSync() async {
    enableCalled = true;
  }

  @override
  Future<SyncConflictState> inspectSyncConflict() async => nextConflictState;

  @override
  Future<void> resolveSyncConflict(SyncConflictResolution resolution) async {
    resolvedWith = resolution;
  }
}

class FakeAnalyticsService extends AnalyticsService {
  @override
  Future<void> init() async {}

  @override
  Future<void> logLevelStart(int levelId) async {}

  @override
  Future<void> logLevelComplete(int levelId, int taps, int wrongTaps) async {}

  @override
  Future<void> logWrongTap(int levelId, int remainingLives) async {}

  @override
  Future<void> logGameOver(int levelId) async {}

  @override
  Future<void> logSyncConflictDetected({
    required String source,
    required String conflictType,
    required int localLevel,
    int? cloudLevel,
  }) async {}

  @override
  Future<void> logSyncConflictResolved({
    required String source,
    required String conflictType,
    required String resolution,
    required bool automatic,
  }) async {}

  @override
  Future<void> logCloudSyncUnavailable({
    required String source,
    required String reason,
  }) async {}
}

class MockAuthService implements AuthService {
  Exception? _exceptionToThrow;

  void throwException(Exception e) {
    _exceptionToThrow = e;
  }

  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<UserCredential> createUserWithEmailAndPassword(
      String email, String password) async {
    if (_exceptionToThrow != null) throw _exceptionToThrow!;
    return FakeUserCredential();
  }

  @override
  Future<UserCredential> linkEmailAndPassword(
      String email, String password) async {
    if (_exceptionToThrow != null) throw _exceptionToThrow!;
    return FakeUserCredential();
  }

  @override
  Future<UserCredential> signInAnonymously() async {
    if (_exceptionToThrow != null) throw _exceptionToThrow!;
    return FakeUserCredential();
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    if (_exceptionToThrow != null) throw _exceptionToThrow!;
    return FakeUserCredential();
  }

  @override
  Future<void> deleteAccount() async {
    if (_exceptionToThrow != null) throw _exceptionToThrow!;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (_exceptionToThrow != null) throw _exceptionToThrow!;
  }

  @override
  Future<void> signOut() async {
    if (_exceptionToThrow != null) throw _exceptionToThrow!;
  }
}

void main() {
  group('AuthScreen Tests', () {
    late MockAuthService mockAuthService;
    late TestGameProgressNotifier testGameProgressNotifier;
    late FakeAnalyticsService fakeAnalyticsService;

    setUp(() {
      mockAuthService = MockAuthService();
      testGameProgressNotifier = TestGameProgressNotifier();
      fakeAnalyticsService = FakeAnalyticsService();
    });

    Widget createAuthScreen() {
      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          isAnonymousProvider.overrideWithValue(false),
          gameProgressProvider.overrideWith(() => testGameProgressNotifier),
          analyticsServiceProvider.overrideWithValue(fakeAnalyticsService),
        ],
        child: const MaterialApp(
          home: AuthScreen(),
        ),
      );
    }

    testWidgets('Shows invalid email error when Firebase throws invalid-email',
        (WidgetTester tester) async {
      mockAuthService.throwException(FirebaseAuthException(
          code: 'invalid-email', message: 'Invalid email'));

      await tester.pumpWidget(createAuthScreen());

      // Enter details
      await tester.enterText(find.byType(TextFormField).first, 'bad@email.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');

      // Tap sign in
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('The email address is invalid.'), findsOneWidget);
    });

    testWidgets(
        'Shows already in use error when Firebase throws email-already-in-use',
        (WidgetTester tester) async {
      mockAuthService.throwException(FirebaseAuthException(
          code: 'email-already-in-use', message: 'Already used'));

      await tester.pumpWidget(createAuthScreen());

      // Enter details
      await tester.enterText(
          find.byType(TextFormField).first, 'test@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');

      // Tap sign in
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(
          find.text(
              'This email is already in use by another account. Please sign in instead.'),
          findsOneWidget);
    });

    testWidgets(
        'Shows wrong password error when Firebase throws wrong-password',
        (WidgetTester tester) async {
      mockAuthService.throwException(
          FirebaseAuthException(code: 'wrong-password', message: 'Wrong pwd'));

      await tester.pumpWidget(createAuthScreen());

      // Enter details
      await tester.enterText(
          find.byType(TextFormField).first, 'test@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'wrongpass');

      // Tap sign in
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect password.'), findsOneWidget);
    });

    testWidgets('shows conflict dialog and resolves with local choice',
        (WidgetTester tester) async {
      testGameProgressNotifier.nextConflictState = SyncConflictState(
        type: SyncConflictType.divergent,
        localProgress: GameProgress.initial()
            .copyWith(currentLevel: 6, completedLevels: {1, 2, 3, 4, 5}),
        cloudProgress: GameProgress.initial()
            .copyWith(currentLevel: 4, completedLevels: {1, 2, 3}),
      );

      await tester.pumpWidget(createAuthScreen());

      await tester.enterText(
          find.byType(TextFormField).first, 'test@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Choose Progress to Keep'), findsOneWidget);
      expect(find.text('Keep This Device'), findsOneWidget);

      await tester.tap(find.text('Keep This Device'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(testGameProgressNotifier.enableCalled, isTrue);
      expect(testGameProgressNotifier.resolvedWith,
          SyncConflictResolution.keepLocal);
    });
  });
}
