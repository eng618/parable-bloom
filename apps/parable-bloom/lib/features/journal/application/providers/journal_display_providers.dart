import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/providers/infrastructure_providers.dart";

/// How locked passages render in the journal book.
///
/// - [sealed]: fully sealed page, title hidden ("Sealed Page").
/// - [teaser]: title + reference visible, verse hidden behind lock hint.
///
/// Configurable so both treatments can be A/B tested without code changes.
enum JournalLockedStyle { sealed, teaser }

final journalLockedStyleProvider =
    NotifierProvider<JournalLockedStyleNotifier, JournalLockedStyle>(
  JournalLockedStyleNotifier.new,
);

class JournalLockedStyleNotifier extends Notifier<JournalLockedStyle> {
  static const String _key = "journalLockedStyle";

  @override
  JournalLockedStyle build() {
    final box = ref.watch(hiveBoxProvider);
    final raw = box.get(_key, defaultValue: JournalLockedStyle.sealed.name);
    return JournalLockedStyle.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => JournalLockedStyle.sealed,
    );
  }

  Future<void> setStyle(JournalLockedStyle style) async {
    state = style;
    final box = ref.read(hiveBoxProvider);
    await box.put(_key, style.name);
  }

  Future<void> toggle() async {
    await setStyle(
      state == JournalLockedStyle.sealed
          ? JournalLockedStyle.teaser
          : JournalLockedStyle.sealed,
    );
  }
}

/// Last opened book page, used as the ribbon bookmark target.
final journalBookmarkProvider = NotifierProvider<JournalBookmarkNotifier, int>(
  JournalBookmarkNotifier.new,
);

class JournalBookmarkNotifier extends Notifier<int> {
  static const String _key = "journalBookmarkPage";

  @override
  int build() {
    final box = ref.watch(hiveBoxProvider);
    final raw = box.get(_key, defaultValue: 0);
    return (raw as int?) ?? 0;
  }

  Future<void> save(int page) async {
    state = page;
    final box = ref.read(hiveBoxProvider);
    await box.put(_key, page);
  }
}
