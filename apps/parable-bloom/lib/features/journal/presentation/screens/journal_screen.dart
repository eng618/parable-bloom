import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../game/application/providers/module_providers.dart";
import "../../../game/application/providers/progress_providers.dart";
import "../../../../providers/service_providers.dart";

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logScreenView('Journal');
    });
  }

  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(modulesProvider);
    final progress = ref.watch(gameProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Journal"),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      body: modulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text("Error: $error")),
        data: (modules) {
          final unlocked = modules
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
              final reflection = (parable["reflection"] as String?)?.trim();
              final savedTranslationId = progress.unlockedTranslations[module.id.toString()];

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
                      if (scripture?.isNotEmpty == true)
                        FutureBuilder<Map<String, String>>(
                          future: ref.read(scriptureServiceProvider).loadScripture(
                            scripture!,
                            translationId: savedTranslationId,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: SizedBox(
                                  height: 2,
                                  child: LinearProgressIndicator(),
                                ),
                              );
                            }
                            
                            final data = snapshot.data;
                            final text = data?['text'] ?? (parable['content'] as String?)?.trim() ?? '';
                            final translation = data?['translation'] ?? 'KJV';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '$scripture ($translation)',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                if (text.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    text,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
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
