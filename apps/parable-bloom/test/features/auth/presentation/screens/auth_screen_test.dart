import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/auth/data/services/auth_service.dart';
import 'package:parable_bloom/features/auth/presentation/providers/auth_providers.dart';
import 'package:parable_bloom/features/auth/presentation/screens/auth_screen.dart';

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
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    if (_exceptionToThrow != null) throw _exceptionToThrow!;
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> linkEmailAndPassword(String email, String password) async {
    if (_exceptionToThrow != null) throw _exceptionToThrow!;
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> signInAnonymously() async {
    if (_exceptionToThrow != null) throw _exceptionToThrow!;
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    if (_exceptionToThrow != null) throw _exceptionToThrow!;
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    if (_exceptionToThrow != null) throw _exceptionToThrow!;
  }
}

void main() {
  group('AuthScreen Tests', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
    });

    Widget createAuthScreen() {
      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          isAnonymousProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          home: AuthScreen(),
        ),
      );
    }

    testWidgets('Shows invalid email error when Firebase throws invalid-email', (WidgetTester tester) async {
      mockAuthService.throwException(FirebaseAuthException(code: 'invalid-email', message: 'Invalid email'));

      await tester.pumpWidget(createAuthScreen());

      // Enter details
      await tester.enterText(find.byType(TextFormField).first, 'bad@email.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      
      // Tap sign in
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('The email address is invalid.'), findsOneWidget);
    });

    testWidgets('Shows already in use error when Firebase throws email-already-in-use', (WidgetTester tester) async {
      mockAuthService.throwException(FirebaseAuthException(code: 'email-already-in-use', message: 'Already used'));

      await tester.pumpWidget(createAuthScreen());

      // Enter details
      await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      
      // Tap sign in
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('This email is already in use by another account. Please sign in instead.'), findsOneWidget);
    });

    testWidgets('Shows wrong password error when Firebase throws wrong-password', (WidgetTester tester) async {
      mockAuthService.throwException(FirebaseAuthException(code: 'wrong-password', message: 'Wrong pwd'));

      await tester.pumpWidget(createAuthScreen());

      // Enter details
      await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'wrongpass');
      
      // Tap sign in
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect password.'), findsOneWidget);
    });
  });
}
