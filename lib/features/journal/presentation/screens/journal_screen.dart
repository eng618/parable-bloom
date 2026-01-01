import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../providers/game_providers.dart";

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(modulesProvider);
    final progress = ref.watch(globalProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Journal"),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      body: modulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text("Error: $error")),
        data: (modules) {
          final unlocked =
              modules
                  .where((m) => progress.isModuleCompleted(m.id, modules))
                  .toList();

          if (unlocked.isEmpty) {
            return const Center(
              child: Text("No parables unlocked yet."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: unlocked.length,
            itemBuilder: (context, index) {
              final module = unlocked[index];
              final parable = module.parable;

              final title = (parable["title"] as String?)?.trim();
              final scripture = (parable["scripture"] as String?)?.trim();
              final content = (parable["content"] as String?)?.trim();
              final reflection = (parable["reflection"] as String?)?.trim();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title?.isNotEmpty == true
                            ? title!
                            : "Module ${module.id}",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (scripture?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          scripture!,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                      if (content?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        Text(
                          content!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (reflection?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        Text(
                          reflection!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
