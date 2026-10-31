import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:parable_bloom/core/providers/infrastructure_providers.dart';
import 'package:parable_bloom/features/home/application/providers/habit_providers.dart';

class _FakeBox implements Box<dynamic> {
  final Map _store = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _store.containsKey(key) ? _store[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => _store[key] = value;

  @override
  Future<void> delete(dynamic key) async => _store.remove(key);

  @override
  bool containsKey(dynamic key) => _store.containsKey(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('habitLocalDateKey / habitCalendarDaysBetween', () {
    test('formats local calendar day', () {
      expect(habitLocalDateKey(DateTime(2026, 10, 31, 23, 59)), '2026-10-31');
    });

    test('counts calendar days not wall-clock hours', () {
      final evening = DateTime(2026, 10, 30, 23, 0);
      final morning = DateTime(2026, 10, 31, 1, 0);
      expect(habitCalendarDaysBetween(evening, morning), 1);
    });
  });

  group('HabitSessionNotifier', () {
    late ProviderContainer container;
    late _FakeBox box;

    setUp(() {
      box = _FakeBox();
      container = ProviderContainer(
        overrides: [hiveBoxProvider.overrideWithValue(box as Box)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('recordOpen does not mark first-ever visit as returning day', () {
      final notifier = container.read(habitSessionProvider.notifier);
      final days = notifier.recordOpen(now: DateTime(2026, 10, 31, 10));

      expect(days, isNull);
      expect(container.read(habitSessionProvider).isReturningDay, isFalse);
      expect(box.get(kHabitLastSessionAtKey), isNotNull);
    });

    test('recordOpen detects prior calendar day return and caps days', () {
      box.put(
        kHabitLastSessionAtKey,
        DateTime(2026, 9, 1, 8).toIso8601String(),
      );
      final notifier = container.read(habitSessionProvider.notifier);
      final days = notifier.recordOpen(now: DateTime(2026, 10, 31, 9));

      expect(days, kHabitDaysSinceLastCap);
      expect(container.read(habitSessionProvider).isReturningDay, isTrue);
      expect(box.get(kHabitReturnDayKey), '2026-10-31');
    });

    test('same-day reopen is not a day return analytics event', () {
      box.put(
        kHabitLastSessionAtKey,
        DateTime(2026, 10, 31, 8).toIso8601String(),
      );
      final notifier = container.read(habitSessionProvider.notifier);
      final days = notifier.recordOpen(now: DateTime(2026, 10, 31, 18));

      expect(days, isNull);
    });
  });
}
