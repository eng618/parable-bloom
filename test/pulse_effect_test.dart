import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/presentation/widgets/pulse_effect_component.dart';

void main() {
  group('PulseEffectComponent', () {
    test('should be created with default color', () {
      final pulse = PulseEffectComponent(
        position: Vector2(100, 100),
      );

      expect(pulse.position, Vector2(100, 100));
      expect(pulse.anchor, Anchor.center);
    });

    test('should be created with custom color', () {
      final customColor = Colors.red.withValues(alpha: 0.5);
      final pulse = PulseEffectComponent(
        position: Vector2(50, 50),
        color: customColor,
      );

      expect(pulse.position, Vector2(50, 50));
    });

    test('should have correct priority for rendering above other components', () {
      final pulse = PulseEffectComponent(
        position: Vector2(100, 100),
      );

      // Verify high priority to render above grid/vines
      expect(pulse.priority, 100);
    });

    test('should have correct size for max radius', () {
      final pulse = PulseEffectComponent(
        position: Vector2(100, 100),
      );

      // Size should be 2 * maxRadius (30px * 2 = 60px)
      expect(pulse.size, Vector2.all(60.0));
    });

    test('should remove itself after animation duration completes', () async {
      final game = FlameGame();
      await game.onLoad();

      final pulse = PulseEffectComponent(
        position: Vector2(100, 100),
      );

      await game.add(pulse);
      await game.ready();

      expect(game.children.contains(pulse), true);

      // Update past the duration (0.4 seconds + small buffer)
      game.update(0.5);

      // Component should remove itself after animation completes
      expect(game.children.contains(pulse), false);
    });

    test('should not remove itself before animation duration', () async {
      final game = FlameGame();
      await game.onLoad();

      final pulse = PulseEffectComponent(
        position: Vector2(100, 100),
      );

      await game.add(pulse);
      await game.ready();

      expect(game.children.contains(pulse), true);

      // Update for less than duration (0.2 seconds)
      game.update(0.2);

      // Component should still be present
      expect(game.children.contains(pulse), true);
    });

    test('should process multiple update cycles correctly', () async {
      final game = FlameGame();
      await game.onLoad();

      final pulse = PulseEffectComponent(
        position: Vector2(100, 100),
      );

      await game.add(pulse);
      await game.ready();

      // Update with multiple small time steps
      game.update(0.1);
      expect(game.children.contains(pulse), true);

      game.update(0.1);
      expect(game.children.contains(pulse), true);

      game.update(0.1);
      expect(game.children.contains(pulse), true);

      game.update(0.15); // Total now > 0.4 seconds
      expect(game.children.contains(pulse), false);
    });
  });
}
