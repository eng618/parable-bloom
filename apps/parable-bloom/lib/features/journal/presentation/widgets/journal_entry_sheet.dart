import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/providers/service_providers.dart";
import "../../../../core/providers/settings_providers.dart";
import "../../../../core/widgets/scripture_citation.dart";
import "../../../game/application/providers/progress_providers.dart";
import "../../domain/entities/journal_theme.dart";

/// Parchment reading sheet for one unlocked passage: verse, guided
/// reflection prompts, and margin notes that persist to game progress.
class JournalEntrySheet extends ConsumerStatefulWidget {
  const JournalEntrySheet({super.key, required this.passage});

  final JournalPassage passage;

  @override
  ConsumerState<JournalEntrySheet> createState() => _JournalEntrySheetState();
}

class _JournalEntrySheetState extends ConsumerState<JournalEntrySheet> {
  late final TextEditingController _notesController;
  late final Future<Map<String, String>> _scriptureFuture;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final progress = ref.read(gameProgressProvider);
    _notesController = TextEditingController(
      text: progress.journalNotes[widget.passage.id] ?? "",
    );
    _scriptureFuture = ref.read(scriptureServiceProvider).loadScripture(
          widget.passage.reference,
          preferredTranslationId: ref.read(preferredTranslationProvider),
        );
    final analytics = ref.read(analyticsServiceProvider);
    final loggedCode = ref.read(preferredTranslationProvider).toUpperCase();
    final loggedId = widget.passage.id;
    final loggedReference = widget.passage.reference;
    final loggedIsParable = widget.passage.type == "parable";
    WidgetsBinding.instance.addPostFrameCallback((_) {
      analytics.logScriptureRead(
        scriptureId: loggedId,
        reference: loggedReference,
        translation: loggedCode,
      );
      if (loggedIsParable) {
        analytics.logParableViewed(loggedId, source: "journal_browse");
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    await ref
        .read(gameProgressProvider.notifier)
        .saveJournalNote(widget.passage.id, _notesController.text);
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Reflection note saved."),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? const Color(0xFF1E241E) : const Color(0xFFFFFBF3);
    final preferred = ref.watch(preferredTranslationProvider).toUpperCase();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (scrollContext, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: paper,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                left: BorderSide(color: cs.error.withValues(alpha: 0.4)),
              ),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.passage.title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: "Georgia",
                    fontFamilyFallback: const ["Serif"],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${widget.passage.reference} ($preferred)",
                  style: textTheme.labelLarge?.copyWith(
                    color: cs.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<Map<String, String>>(
                  future: _scriptureFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final data = snapshot.data;
                    final text = data?["text"] ??
                        widget.passage.defaultContent ??
                        "Scripture text not found.";
                    final code = data?["translation"] ?? "NET";
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border(
                          left: BorderSide(color: cs.primary, width: 3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: textTheme.bodyLarge?.copyWith(
                                height: 1.7,
                                fontStyle: FontStyle.italic,
                                fontFamily: "Georgia",
                                fontFamilyFallback: const ["Serif"],
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              children: [
                                if (text.isNotEmpty)
                                  TextSpan(
                                    text: text[0],
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FontStyle.normal,
                                    ),
                                  ),
                                if (text.length > 1)
                                  TextSpan(text: text.substring(1)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: ScriptureCitation(
                              reference: widget.passage.reference,
                              translationCode: code,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (widget.passage.reflectionPrompts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    "Guided Reflection",
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      fontFamily: "Georgia",
                      fontFamilyFallback: const ["Serif"],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.passage.reflectionPrompts.map((prompt) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("✦ ", style: TextStyle(color: cs.primary)),
                          Expanded(
                            child: Text(
                              prompt,
                              style: textTheme.bodyMedium?.copyWith(
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Marginalia",
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        fontFamily: "Georgia",
                        fontFamilyFallback: const ["Serif"],
                      ),
                    ),
                    if (_saved)
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: cs.primary, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "Inked",
                            style: textTheme.labelSmall
                                ?.copyWith(color: cs.primary),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  minLines: 3,
                  decoration: InputDecoration(
                    hintText: "Write in the margins…",
                    filled: true,
                    fillColor: cs.surfaceContainerLow.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                  ),
                  onChanged: (_) {
                    if (_saved) setState(() => _saved = false);
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _saveNotes,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text("Ink it"),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Close"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
