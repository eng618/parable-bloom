import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/providers/service_providers.dart";
import "../../../../core/providers/settings_providers.dart";
import "../../../../core/widgets/scripture_citation.dart";
import "../../domain/entities/journal_theme.dart";
import "journal_paper.dart";
import "journal_unlock_text.dart";

/// Single passage page: unlocked verses render as book text with
/// marginalia prompts + lined notes; locked pages render sealed/teaser.
class JournalPassagePage extends ConsumerStatefulWidget {
  const JournalPassagePage({
    super.key,
    required this.passage,
    required this.theme,
    required this.isUnlocked,
    required this.preferredTranslation,
    required this.initialNote,
    required this.runningHeader,
    required this.pageLabel,
    required this.showTeaser,
    required this.onSaveNote,
    this.bindLeft = true,
  });

  final JournalPassage passage;
  final JournalTheme theme;
  final bool isUnlocked;
  final String preferredTranslation;
  final String initialNote;
  final String runningHeader;
  final String pageLabel;
  final bool showTeaser;
  final Future<void> Function(String note) onSaveNote;
  final bool bindLeft;

  @override
  ConsumerState<JournalPassagePage> createState() => _JournalPassagePageState();
}

class _JournalPassagePageState extends ConsumerState<JournalPassagePage> {
  late TextEditingController _notesController;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.initialNote);
  }

  @override
  void didUpdateWidget(JournalPassagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialNote != widget.initialNote &&
        _notesController.text != widget.initialNote) {
      _notesController.text = widget.initialNote;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isUnlocked) {
      return _lockedPaper(context);
    }
    return JournalPaper(
      runningHeader: widget.runningHeader,
      pageLabel: widget.pageLabel,
      bindLeft: widget.bindLeft,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleBlock(),
            const SizedBox(height: 10),
            _VerseBlock(passage: widget.passage),
            if (widget.passage.reflectionPrompts.isNotEmpty) ...[
              const SizedBox(height: 14),
              _PromptsBlock(prompts: widget.passage.reflectionPrompts),
            ],
            const SizedBox(height: 14),
            _NotesBlock(
              controller: _notesController,
              saved: _saved,
              onChanged: () => setState(() => _saved = false),
              onSave: () async {
                await widget.onSaveNote(_notesController.text);
                if (!context.mounted) return;
                setState(() => _saved = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Reflection note saved."),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _lockedPaper(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hint = formatJournalTriggerText(widget.passage.triggerLevel);

    return JournalPaper(
      runningHeader: widget.runningHeader,
      pageLabel: widget.pageLabel,
      bindLeft: widget.bindLeft,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              JournalWaxSeal(sealed: true, size: 56),
              const SizedBox(height: 12),
              if (widget.showTeaser) ...[
                Text(
                  widget.passage.title.isEmpty
                      ? "Locked Scripture"
                      : widget.passage.title,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: "Georgia",
                    fontFamilyFallback: const ["Serif"],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.passage.reference,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
              ] else ...[
                Text(
                  "Sealed Page",
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: "Georgia",
                    fontFamilyFallback: const ["Serif"],
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.showTeaser ? hint : "Locked Scripture",
                  textAlign: TextAlign.center,
                  style: textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              if (!widget.showTeaser) ...[
                const SizedBox(height: 8),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleBlock() {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              widget.passage.type == "parable"
                  ? Icons.menu_book
                  : (widget.passage.type == "starter" ? Icons.star : Icons.spa),
              color: cs.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.passage.title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: "Georgia",
                  fontFamilyFallback: const ["Serif"],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          "${widget.passage.reference} (${widget.preferredTranslation})",
          style: textTheme.labelMedium?.copyWith(color: cs.primary),
        ),
      ],
    );
  }
}

class _VerseBlock extends ConsumerStatefulWidget {
  const _VerseBlock({required this.passage});

  final JournalPassage passage;

  @override
  ConsumerState<_VerseBlock> createState() => _VerseBlockState();
}

class _VerseBlockState extends ConsumerState<_VerseBlock> {
  late Future<Map<String, String>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(scriptureServiceProvider).loadScripture(
          widget.passage.reference,
          preferredTranslationId: ref.read(preferredTranslationProvider),
        );
  }

  @override
  void didUpdateWidget(_VerseBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.passage.reference != widget.passage.reference) {
      _future = ref.read(scriptureServiceProvider).loadScripture(
            widget.passage.reference,
            preferredTranslationId: ref.read(preferredTranslationProvider),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder<Map<String, String>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
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
              // Drop-cap style first letter via RichText.
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
                    if (text.length > 1) TextSpan(text: text.substring(1)),
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
    );
  }
}

class _PromptsBlock extends StatelessWidget {
  const _PromptsBlock({required this.prompts});

  final List<String> prompts;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        ...prompts.asMap().entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "✦ ",
                  style: TextStyle(color: cs.primary),
                ),
                Expanded(
                  child: Text(
                    e.value,
                    style: textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _NotesBlock extends StatelessWidget {
  const _NotesBlock({
    required this.controller,
    required this.saved,
    required this.onChanged,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool saved;
  final VoidCallback onChanged;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            if (saved)
              Row(
                children: [
                  Icon(Icons.check_circle, color: cs.primary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "Inked",
                    style: textTheme.labelSmall?.copyWith(color: cs.primary),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
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
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => onSave(),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text("Ink it"),
          ),
        ),
      ],
    );
  }
}
