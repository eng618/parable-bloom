import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/service_providers.dart';

/// App version row.
class SettingsAboutSection extends ConsumerWidget {
  const SettingsAboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);

    return versionAsync.when(
      data: (version) => ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Version'),
        subtitle: Text(version),
      ),
      loading: () => const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Version'),
        subtitle: Text('Loading...'),
      ),
      error: (error, stack) => const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Version'),
        subtitle: Text('Unknown'),
      ),
    );
  }
}
