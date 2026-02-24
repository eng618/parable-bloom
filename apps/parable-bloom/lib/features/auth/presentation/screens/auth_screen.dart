import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/auth_providers.dart';
import '../../../../providers/game_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  static const routeName = '/auth';

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final authService = ref.read(authServiceProvider);
    final isAnon = ref.read(isAnonymousProvider);

    try {
      if (_isLogin) {
        // Just sign in
        await authService.signInWithEmailAndPassword(email, password);
      } else {
        // Sign Up
        if (isAnon) {
          // We are currently anonymous, so we should convert this account
          await authService.linkEmailAndPassword(email, password);
        } else {
          // Normal create (shouldn't happen if we force anon entry, but good for completeness)
          await authService.createUserWithEmailAndPassword(email, password);
        }
      }

      // Automatically enable cloud sync when a persistent account is created/linked/signed-in
      if (mounted) {
        await ref.read(gameProgressProvider.notifier).enableCloudSync();
      }

      // If successful, close the screen
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          switch (e.code) {
            case 'email-already-in-use':
            case 'credential-already-in-use':
              _errorMessage =
                  'This email is already in use by another account. Please sign in instead.';
              break;
            case 'user-not-found':
              _errorMessage = 'No user found with this email.';
              break;
            case 'wrong-password':
            case 'invalid-credential':
              _errorMessage = 'Incorrect password.';
              break;
            case 'invalid-email':
              _errorMessage = 'The email address is invalid.';
              break;
            case 'weak-password':
              _errorMessage = 'The password provided is too weak.';
              break;
            default:
              _errorMessage = e.message ?? 'An unknown authentication error occurred.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Sign In' : 'Create Account'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            !value.contains('@')) {
                          return 'Please enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton(
                            onPressed: _submit,
                            child: Text(_isLogin ? 'Sign In' : 'Sign Up'),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                                _errorMessage = null;
                              });
                            },
                            child: Text(_isLogin
                                ? 'Create a new account'
                                : 'I already have an account'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
