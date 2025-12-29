import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parable_bloom/features/game/presentation/providers/analytics_providers.dart';

void main() {
  group('LevelTotalTapsNotifier', () {
    test('should initialize with 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final taps = container.read(levelTotalTapsProvider);
      expect(taps, 0);
    });

    test('should increment tap count', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(levelTotalTapsProvider.notifier);

      notifier.increment();
      expect(container.read(levelTotalTapsProvider), 1);

      notifier.increment();
      expect(container.read(levelTotalTapsProvider), 2);
    });

    test('should reset tap count to 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(levelTotalTapsProvider.notifier);

      notifier.increment();
      notifier.increment();
      notifier.increment();
      expect(container.read(levelTotalTapsProvider), 3);

      notifier.reset();
      expect(container.read(levelTotalTapsProvider), 0);
    });
  });

  group('LevelWrongTapsNotifier', () {
    test('should initialize with 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final taps = container.read(levelWrongTapsProvider);
      expect(taps, 0);
    });

    test('should increment wrong tap count', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(levelWrongTapsProvider.notifier);

      notifier.increment();
      expect(container.read(levelWrongTapsProvider), 1);

      notifier.increment();
      expect(container.read(levelWrongTapsProvider), 2);
    });

    test('should reset wrong tap count to 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(levelWrongTapsProvider.notifier);

      notifier.increment();
      notifier.increment();
      expect(container.read(levelWrongTapsProvider), 2);

      notifier.reset();
      expect(container.read(levelWrongTapsProvider), 0);
    });

    test('should track wrong taps independently from total taps', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final totalNotifier = container.read(levelTotalTapsProvider.notifier);
      final wrongNotifier = container.read(levelWrongTapsProvider.notifier);

      totalNotifier.increment();
      totalNotifier.increment();
      totalNotifier.increment();

      wrongNotifier.increment();

      expect(container.read(levelTotalTapsProvider), 3);
      expect(container.read(levelWrongTapsProvider), 1);
    });
  });
}
