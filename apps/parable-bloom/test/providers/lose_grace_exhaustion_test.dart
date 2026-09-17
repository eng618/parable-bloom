import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/application/providers/gameplay_state_providers.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';

LevelData level({String difficulty = 'easy'}) => LevelData(
      id: 't',
      name: 'T',
      difficulty: difficulty,
      gridWidth: 5,
      gridHeight: 5,
      vines: const [],
      maxMoves: 10,
      minMoves: 1,
      complexity: 'low',
      grace: 3,
      mask: MaskData(mode: 'none', points: []),
    );

void main() {
  test('wrong taps exhaust grace and trigger game over, restart resets', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(currentLevelProvider.notifier).setLevel(level());
    container.read(gameInstanceProvider.notifier).resetGrace();

    expect(container.read(graceProvider), 3);
    expect(container.read(gameOverProvider), isFalse);

    container.read(gameInstanceProvider.notifier).decrementGrace();
    container.read(gameInstanceProvider.notifier).decrementGrace();
    expect(container.read(graceProvider), 1);
    expect(container.read(gameOverProvider), isFalse);

    container.read(gameInstanceProvider.notifier).decrementGrace();
    expect(container.read(graceProvider), 0);
    expect(container.read(gameOverProvider), isTrue);

    container.read(gameInstanceProvider.notifier).resetGrace();
    expect(container.read(graceProvider), 3);
    expect(container.read(gameOverProvider), isFalse);
  });

  test('tutorial grace floors at 1 and never triggers game over', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(currentLevelProvider.notifier)
        .setLevel(level(difficulty: 'tutorial'));
    container.read(gameInstanceProvider.notifier).resetGrace();

    for (var i = 0; i < 5; i++) {
      container.read(gameInstanceProvider.notifier).decrementGrace();
    }
    expect(container.read(graceProvider), 1);
    expect(container.read(gameOverProvider), isFalse);
  });
}
