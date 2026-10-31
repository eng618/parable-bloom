import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/infrastructure_providers.dart';

/// Hive keys for device-local habit / retention UX (not synced to cloud).
const String kHabitLastSessionAtKey = 'habit_last_session_at';
const String kHabitLastCloseShownDateKey = 'habit_last_close_shown_date';
const String kHabitLastLevelCompleteDateKey = 'habit_last_level_complete_date';
const String kHabitScriptureUnlockDateKey = 'habit_scripture_unlock_date';
const String kHabitScriptureIdTodayKey = 'habit_scripture_id_today';
const String kHabitReturnDayKey = 'habit_return_day';

/// Cap for [HabitSessionState.daysSinceLast] analytics property.
const int kHabitDaysSinceLastCap = 30;

/// Delay before showing the session-close invite so a quick Play tap can cancel.
const Duration kSessionClosePlayGrace = Duration(seconds: 3);

final _localDateFormat = DateFormat('yyyy-MM-dd');

/// Formats [date] as a local calendar-day key (`yyyy-MM-dd`).
String habitLocalDateKey(DateTime date) => _localDateFormat.format(date);

/// Calendar-day difference between [earlier] and [later] in local time.
int habitCalendarDaysBetween(DateTime earlier, DateTime later) {
  final a = DateTime(earlier.year, earlier.month, earlier.day);
  final b = DateTime(later.year, later.month, later.day);
  return b.difference(a).inDays;
}

/// Soft habit / retention session state (local Hive + in-memory flags).
class HabitSessionState {
  final DateTime? lastSessionAt;
  final String? lastCloseShownDate;
  final String? lastLevelCompleteDate;
  final bool hadScriptureUnlockToday;
  final String? scriptureIdToday;
  final bool isReturningDay;
  final int? daysSinceLast;

  const HabitSessionState({
    this.lastSessionAt,
    this.lastCloseShownDate,
    this.lastLevelCompleteDate,
    this.hadScriptureUnlockToday = false,
    this.scriptureIdToday,
    this.isReturningDay = false,
    this.daysSinceLast,
  });

  bool get completedLevelToday {
    if (lastLevelCompleteDate == null) return false;
    return lastLevelCompleteDate == habitLocalDateKey(DateTime.now());
  }

  bool get sessionCloseShownToday {
    if (lastCloseShownDate == null) return false;
    return lastCloseShownDate == habitLocalDateKey(DateTime.now());
  }

  HabitSessionState copyWith({
    DateTime? lastSessionAt,
    String? lastCloseShownDate,
    String? lastLevelCompleteDate,
    bool? hadScriptureUnlockToday,
    String? scriptureIdToday,
    bool? isReturningDay,
    int? daysSinceLast,
    bool clearScriptureIdToday = false,
    bool clearDaysSinceLast = false,
  }) {
    return HabitSessionState(
      lastSessionAt: lastSessionAt ?? this.lastSessionAt,
      lastCloseShownDate: lastCloseShownDate ?? this.lastCloseShownDate,
      lastLevelCompleteDate:
          lastLevelCompleteDate ?? this.lastLevelCompleteDate,
      hadScriptureUnlockToday:
          hadScriptureUnlockToday ?? this.hadScriptureUnlockToday,
      scriptureIdToday: clearScriptureIdToday
          ? null
          : (scriptureIdToday ?? this.scriptureIdToday),
      isReturningDay: isReturningDay ?? this.isReturningDay,
      daysSinceLast: clearDaysSinceLast
          ? null
          : (daysSinceLast ?? this.daysSinceLast),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HabitSessionState &&
        other.lastSessionAt == lastSessionAt &&
        other.lastCloseShownDate == lastCloseShownDate &&
        other.lastLevelCompleteDate == lastLevelCompleteDate &&
        other.hadScriptureUnlockToday == hadScriptureUnlockToday &&
        other.scriptureIdToday == scriptureIdToday &&
        other.isReturningDay == isReturningDay &&
        other.daysSinceLast == daysSinceLast;
  }

  @override
  int get hashCode => Object.hash(
    lastSessionAt,
    lastCloseShownDate,
    lastLevelCompleteDate,
    hadScriptureUnlockToday,
    scriptureIdToday,
    isReturningDay,
    daysSinceLast,
  );
}

final habitSessionProvider =
    NotifierProvider<HabitSessionNotifier, HabitSessionState>(
      HabitSessionNotifier.new,
    );

class HabitSessionNotifier extends Notifier<HabitSessionState> {
  @override
  HabitSessionState build() {
    final box = ref.watch(hiveBoxProvider);
    final now = DateTime.now();
    final today = habitLocalDateKey(now);

    final lastSessionRaw = box.get(kHabitLastSessionAtKey) as String?;
    final lastSessionAt = lastSessionRaw != null
        ? DateTime.tryParse(lastSessionRaw)
        : null;
    final lastCloseShownDate = box.get(kHabitLastCloseShownDateKey) as String?;
    final lastLevelCompleteDate =
        box.get(kHabitLastLevelCompleteDateKey) as String?;
    final scriptureUnlockDate =
        box.get(kHabitScriptureUnlockDateKey) as String?;
    final scriptureIdToday = scriptureUnlockDate == today
        ? box.get(kHabitScriptureIdTodayKey) as String?
        : null;
    final returnDay = box.get(kHabitReturnDayKey) as String?;

    return HabitSessionState(
      lastSessionAt: lastSessionAt,
      lastCloseShownDate: lastCloseShownDate,
      lastLevelCompleteDate: lastLevelCompleteDate,
      hadScriptureUnlockToday: scriptureUnlockDate == today,
      scriptureIdToday: scriptureIdToday,
      isReturningDay: returnDay == today,
    );
  }

  /// Records an app/home open. Detects prior-calendar-day returns.
  ///
  /// Returns `daysSinceLast` (capped) when this open is a day return so the
  /// caller can emit analytics once; otherwise `null`.
  int? recordOpen({DateTime? now}) {
    final box = ref.read(hiveBoxProvider);
    final moment = now ?? DateTime.now();
    final today = habitLocalDateKey(moment);

    final prevRaw = box.get(kHabitLastSessionAtKey) as String?;
    final prev = prevRaw != null ? DateTime.tryParse(prevRaw) : null;

    int? daysSinceLast;
    if (prev != null) {
      final days = habitCalendarDaysBetween(prev, moment);
      if (days >= 1) {
        daysSinceLast = days > kHabitDaysSinceLastCap
            ? kHabitDaysSinceLastCap
            : days;
        box.put(kHabitReturnDayKey, today);
      }
    }

    box.put(kHabitLastSessionAtKey, moment.toIso8601String());

    final returnDay = box.get(kHabitReturnDayKey) as String?;
    final lastCloseShownDate = box.get(kHabitLastCloseShownDateKey) as String?;
    final lastLevelCompleteDate =
        box.get(kHabitLastLevelCompleteDateKey) as String?;
    final scriptureUnlockDate =
        box.get(kHabitScriptureUnlockDateKey) as String?;
    final scriptureIdToday = scriptureUnlockDate == today
        ? box.get(kHabitScriptureIdTodayKey) as String?
        : null;

    state = HabitSessionState(
      lastSessionAt: moment,
      lastCloseShownDate: lastCloseShownDate,
      lastLevelCompleteDate: lastLevelCompleteDate,
      hadScriptureUnlockToday: scriptureUnlockDate == today,
      scriptureIdToday: scriptureIdToday,
      isReturningDay: returnDay == today,
      daysSinceLast: daysSinceLast,
    );

    return daysSinceLast;
  }

  /// Marks that the player completed a level (or lesson) today.
  void recordLevelComplete({String? scriptureId, DateTime? now}) {
    final box = ref.read(hiveBoxProvider);
    final moment = now ?? DateTime.now();
    final today = habitLocalDateKey(moment);

    box.put(kHabitLastLevelCompleteDateKey, today);

    var hadScripture = state.hadScriptureUnlockToday;
    var resolvedScriptureId = state.scriptureIdToday;

    if (scriptureId != null && scriptureId.isNotEmpty) {
      box.put(kHabitScriptureUnlockDateKey, today);
      box.put(kHabitScriptureIdTodayKey, scriptureId);
      hadScripture = true;
      resolvedScriptureId = scriptureId;
    }

    state = state.copyWith(
      lastLevelCompleteDate: today,
      hadScriptureUnlockToday: hadScripture,
      scriptureIdToday: resolvedScriptureId,
    );
  }

  /// True when Home should offer the once-per-day session-close invite.
  bool shouldShowSessionClose({DateTime? now}) {
    final moment = now ?? DateTime.now();
    final today = habitLocalDateKey(moment);
    final completeDate =
        state.lastLevelCompleteDate ??
        ref.read(hiveBoxProvider).get(kHabitLastLevelCompleteDateKey)
            as String?;
    final closeShown =
        state.lastCloseShownDate ??
        ref.read(hiveBoxProvider).get(kHabitLastCloseShownDateKey) as String?;
    return completeDate == today && closeShown != today;
  }

  /// Persists that the session-close invite was shown today.
  void markSessionCloseShown({DateTime? now}) {
    final box = ref.read(hiveBoxProvider);
    final today = habitLocalDateKey(now ?? DateTime.now());
    box.put(kHabitLastCloseShownDateKey, today);
    state = state.copyWith(lastCloseShownDate: today);
  }
}
