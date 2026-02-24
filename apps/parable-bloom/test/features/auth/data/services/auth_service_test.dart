import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:parable_bloom/features/auth/data/services/auth_service.dart';

void main() {
  group('AuthService Tests', () {
    late MockFirebaseAuth mockAuth;
    late AuthService authService;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      authService = AuthService(mockAuth);
    });

    test('Initial user is null', () {
      expect(authService.currentUser, isNull);
    });

    test('signInAnonymously sets current user', () async {
      final credential = await authService.signInAnonymously();
      
      expect(credential.user, isNotNull);
      expect(credential.user?.isAnonymous, isTrue);
      expect(authService.currentUser, isNotNull);
    });

    test('createUserWithEmailAndPassword sets current user', () async {
      final email = 'test@example.com';
      final password = 'password123';

      final credential =
          await authService.createUserWithEmailAndPassword(email, password);
          
      expect(credential.user, isNotNull);
      expect(credential.user?.email, equals(email));
      expect(authService.currentUser, isNotNull);
    });

    test('signInWithEmailAndPassword logs in existing user', () async {
      final email = 'test@example.com';
      final password = 'password123';

      // Mock user creation first
      await mockAuth.createUserWithEmailAndPassword(
          email: email, password: password);
      await mockAuth.signOut(); // Ensure signed out before testing signIn

      final credential =
          await authService.signInWithEmailAndPassword(email, password);

      expect(credential.user, isNotNull);
      expect(credential.user?.email, equals(email));
    });

    test('signOut clears current user', () async {
      await authService.signInAnonymously();
      expect(authService.currentUser, isNotNull);

      await authService.signOut();
      expect(authService.currentUser, isNull);
    });
  });
}
