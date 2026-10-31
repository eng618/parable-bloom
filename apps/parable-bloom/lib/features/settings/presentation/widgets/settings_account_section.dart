import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/application/providers/auth_providers.dart';

/// Account row: guest sign-in, or the signed-in email with logout.
class SettingsAccountSection extends ConsumerWidget {
  const SettingsAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserProvider);

    return userAsync.when(
      data: (user) {
        final isAnonymous = user?.isAnonymous ?? true;
        final email = user?.email;
        final subtitle = isAnonymous
            ? 'Guest Account (Not Synced)'
            : 'Signed in as ${email ?? "User"}';

        return ListTile(
          leading: Icon(
            isAnonymous ? Icons.account_circle_outlined : Icons.account_circle,
            color: isAnonymous ? null : Theme.of(context).colorScheme.primary,
          ),
          title: Text(isAnonymous ? 'Sign In / Sign Up' : 'Account Status'),
          subtitle: Text(subtitle),
          trailing: isAnonymous
              ? const Icon(Icons.chevron_right)
              : IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await ref.read(authServiceProvider).signOut();
                  },
                ),
          onTap: isAnonymous
              ? () {
                  context.push('/auth');
                }
              : null, // Disable tap if already signed in, logic is in logout button
        );
      },
      loading: () => const ListTile(
        leading: CircularProgressIndicator(),
        title: Text('Account'),
      ),
      error: (e, s) => ListTile(
        leading: const Icon(Icons.error),
        title: const Text('Account Error'),
        subtitle: Text(e.toString()),
      ),
    );
  }
}
