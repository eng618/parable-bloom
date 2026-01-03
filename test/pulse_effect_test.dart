import 'package:flame/components.dart';
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
  });
}
