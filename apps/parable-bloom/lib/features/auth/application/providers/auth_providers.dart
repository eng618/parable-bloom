import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/infrastructure_providers.dart';
import '../../data/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  return AuthService(firebaseAuth);
});

final authUserProvider = StreamProvider<User?>((ref) {
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
