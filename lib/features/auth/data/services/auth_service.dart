import 'package:firebase_auth/firebase_auth.dart';
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
    } catch (e) {
      debugPrint('AuthService: Error signing in anonymously: $e');
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
    } catch (e) {
      debugPrint('AuthService: Error creating user: $e');
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
    } catch (e) {
      // If the email is already in use by another account, we might want to sign in to that account instead.
      // handling that case requires UI intervention (merge accounts?)
      debugPrint('AuthService: Error linking account: $e');
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
    } catch (e) {
      debugPrint('AuthService: Error signing in: $e');
      rethrow;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
