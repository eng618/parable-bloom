import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parable_bloom/features/game/presentation/providers/game_state_providers.dart';

void main() {
  group('LevelCompleteNotifier', () {
    test('should initialize with false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isComplete = container.read(levelCompleteProvider);
      expect(isComplete, false);
    });

    test('should set completion state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(levelCompleteProvider.notifier);

      notifier.setComplete(true);
      expect(container.read(levelCompleteProvider), true);

      notifier.setComplete(false);
      expect(container.read(levelCompleteProvider), false);
    });
  });

  group('GameOverNotifier', () {
    test('should initialize with false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isGameOver = container.read(gameOverProvider);
      expect(isGameOver, false);
    });

    test('should set game over state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gameOverProvider.notifier);

      notifier.setGameOver(true);
      expect(container.read(gameOverProvider), true);

      notifier.setGameOver(false);
      expect(container.read(gameOverProvider), false);
    });
  });

  group('GameInstanceNotifier', () {
    test('should initialize with null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final game = container.read(gameInstanceProvider);
      expect(game, null);
    });

    // Note: Full integration tests with GardenGame would require
    // mocking Flame game engine components
  });
}
