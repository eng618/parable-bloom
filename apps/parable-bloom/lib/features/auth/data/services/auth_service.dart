import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for handling user authentication.
class AuthService {
  final FirebaseAuth _firebaseAuth;

  AuthService(this._firebaseAuth);

  /// Helper to get the current user.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Stream of auth state changes.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Sign in anonymously.
  /// Used for "Guest" access.
  Future<UserCredential> signInAnonymously() async {
    try {
      final credential = await _firebaseAuth.signInAnonymously();
      debugPrint('AuthService: Signed in anonymously: ${credential.user?.uid}');
      return credential;
    } catch (e, stack) {
      debugPrint('AuthService: Error signing in anonymously: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'AuthService: Error signing in anonymously');
      rethrow;
    }
  }

  /// Create user with email and password.
  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // If we were anonymous, link could be handled here or separately.
      // For now, raw creation.
      return credential;
    } catch (e, stack) {
      debugPrint('AuthService: Error creating user: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'AuthService: Error creating user');
      rethrow;
    }
  }

  /// Upgrade anonymous account to permanent account with email/password
  Future<UserCredential> linkEmailAndPassword(
      String email, String password) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
          code: 'no-current-user', message: 'No user signed in');
    }

    try {
      final credential =
          EmailAuthProvider.credential(email: email, password: password);
      return await user.linkWithCredential(credential);
    } catch (e, stack) {
      // If the email is already in use by another account, we might want to sign in to that account instead.
      // handling that case requires UI intervention (merge accounts?)
      debugPrint('AuthService: Error linking account: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'AuthService: Error linking account');
      rethrow;
    }
  }

  /// Sign in with email and password.
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e, stack) {
      debugPrint('AuthService: Error signing in: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'AuthService: Error signing in');
      rethrow;
    }
  }

  /// Delete the user account.
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
          code: 'no-current-user', message: 'No user signed in');
    }
    try {
      await user.delete();
      debugPrint('AuthService: Account deleted successfully');
    } catch (e, stack) {
      debugPrint('AuthService: Error deleting account: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'AuthService: Error deleting account');
      rethrow;
    }
  }

  /// Send a password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      debugPrint('AuthService: Password reset email sent securely');
    } catch (e, stack) {
      debugPrint('AuthService: Error sending password reset email: $e');
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'AuthService: Error sending password reset email');
      rethrow;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
