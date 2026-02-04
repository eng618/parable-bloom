import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/game_providers.dart'; // For firebaseAuthProvider
import '../../data/services/auth_service.dart';

/// Provider for the AuthService.
final authServiceProvider = Provider<AuthService>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  return AuthService(firebaseAuth);
});

/// Provider for the current user state.
/// This stream will update whenever the user logs in or out.
final authUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Provider to check if the user is currently signed in.
final isSignedInProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(authUserProvider);
  return userAsync.value != null;
});

/// Provider to check if the current user is anonymous.
final isAnonymousProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(authUserProvider);
  return userAsync.value?.isAnonymous ?? false;
});
