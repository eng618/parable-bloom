import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/infrastructure_providers.dart';

/// Hive keys for device-local habit / retention UX (not synced to cloud).
const String kHabitLastSessionAtKey = 'habit_last_session_at';
const String kHabitReturnDayKey = 'habit_return_day';

/// Cap for [HabitSessionState.daysSinceLast] analytics property.
const int kHabitDaysSinceLastCap = 30;

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
///
/// Powers next-day Home welcome-back only — no session-close overlay.
class HabitSessionState {
  final DateTime? lastSessionAt;
  final bool isReturningDay;
  final int? daysSinceLast;

  const HabitSessionState({
    this.lastSessionAt,
    this.isReturningDay = false,
    this.daysSinceLast,
  });

  HabitSessionState copyWith({
    DateTime? lastSessionAt,
    bool? isReturningDay,
    int? daysSinceLast,
    bool clearDaysSinceLast = false,
  }) {
    return HabitSessionState(
      lastSessionAt: lastSessionAt ?? this.lastSessionAt,
      isReturningDay: isReturningDay ?? this.isReturningDay,
      daysSinceLast:
          clearDaysSinceLast ? null : (daysSinceLast ?? this.daysSinceLast),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HabitSessionState &&
        other.lastSessionAt == lastSessionAt &&
        other.isReturningDay == isReturningDay &&
        other.daysSinceLast == daysSinceLast;
  }

  @override
  int get hashCode => Object.hash(
        lastSessionAt,
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
    final lastSessionAt =
        lastSessionRaw != null ? DateTime.tryParse(lastSessionRaw) : null;
    final returnDay = box.get(kHabitReturnDayKey) as String?;

    return HabitSessionState(
      lastSessionAt: lastSessionAt,
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
        daysSinceLast =
            days > kHabitDaysSinceLastCap ? kHabitDaysSinceLastCap : days;
        box.put(kHabitReturnDayKey, today);
      }
    }

    box.put(kHabitLastSessionAtKey, moment.toIso8601String());

    final returnDay = box.get(kHabitReturnDayKey) as String?;

    state = HabitSessionState(
      lastSessionAt: moment,
      isReturningDay: returnDay == today,
      daysSinceLast: daysSinceLast,
    );

    return daysSinceLast;
  }
}
