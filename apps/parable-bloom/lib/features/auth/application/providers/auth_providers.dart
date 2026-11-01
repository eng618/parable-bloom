import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/infrastructure_providers.dart';
import '../../data/services/auth_service.dart';

const bool _isScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

final authServiceProvider = Provider<AuthService>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  return AuthService(firebaseAuth);
});

final authUserProvider = StreamProvider<User?>((ref) {
  // Screenshot captures disable Firebase. Emit a signed-out user so settings
  // can render the account row without initializing Auth.
  if (_isScreenshotMode) {
    return Stream<User?>.value(null);
  }
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final isSignedInProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(authUserProvider);
  return userAsync.value != null;
});

final isAnonymousProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(authUserProvider);
  return userAsync.value?.isAnonymous ?? false;
});
