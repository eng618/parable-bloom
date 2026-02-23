import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/presentation/widgets/tap_effect_component.dart';

void main() {
  group('TapEffectComponent Tests', () {
    test('Component initializes with correct properties', () {
      final tapPos = Vector2(10.0, 20.0);
      final color = Colors.blue;
      const maxRadius = 30.0;
      const duration = 0.5;

      final component = TapEffectComponent(
        tapPosition: tapPos,
        color: color,
        maxRadius: maxRadius,
        duration: duration,
      );

      expect(component.tapPosition, tapPos);
      expect(component.color, color);
      expect(component.maxRadius, maxRadius);
      expect(component.duration, duration);
      expect(component.position, tapPos);
      expect(component.anchor, Anchor.center);
      expect(component.priority, 10000);
    });

    test('Component initializes with default values', () {
      final tapPos = Vector2(5.0, 5.0);

      final component = TapEffectComponent(
        tapPosition: tapPos,
      );

      expect(component.tapPosition, tapPos);
      expect(component.color, Colors.white);
      expect(component.maxRadius, 15.0);
      expect(component.duration, 0.4);
    });

    test('Component priority is always 10000', () {
      final component1 = TapEffectComponent(
        tapPosition: Vector2.zero(),
      );
      final component2 = TapEffectComponent(
        tapPosition: Vector2(100, 100),
        maxRadius: 50.0,
      );

      expect(component1.priority, 10000);
      expect(component2.priority, 10000);
    });

    test('Components can be created with theme-aware colors', () {
      final lightEffect = TapEffectComponent(
        tapPosition: Vector2(50, 50),
        color: const Color(0xFF1C1B1F), // Light mode color
      );
      final darkEffect = TapEffectComponent(
        tapPosition: Vector2(50, 50),
        color: const Color(0xFFE6E1E5), // Dark mode color
      );

      expect(lightEffect.color, const Color(0xFF1C1B1F));
      expect(darkEffect.color, const Color(0xFFE6E1E5));
    });

    test('Component at different positions have correct positions', () {
      final topLeft = TapEffectComponent(
        tapPosition: Vector2(10, 10),
      );
      final bottomRight = TapEffectComponent(
        tapPosition: Vector2(200, 200),
      );

      expect(topLeft.position, Vector2(10, 10));
      expect(bottomRight.position, Vector2(200, 200));
    });

    test('Component with different colors maintains color values', () {
      final redEffect = TapEffectComponent(
        tapPosition: Vector2(50, 50),
        color: Colors.red,
      );
      final blueEffect = TapEffectComponent(
        tapPosition: Vector2(100, 100),
        color: Colors.blue,
      );

      expect(redEffect.color, Colors.red);
      expect(blueEffect.color, Colors.blue);
    });

    test('Component with different radii maintains radius values', () {
      final smallEffect = TapEffectComponent(
        tapPosition: Vector2.zero(),
        maxRadius: 15.0,
      );
      final largeEffect = TapEffectComponent(
        tapPosition: Vector2.zero(),
        maxRadius: 50.0,
      );

      expect(smallEffect.maxRadius, 15.0);
      expect(largeEffect.maxRadius, 50.0);
    });

    test('Short duration effects have correct duration', () {
      final quickEffect = TapEffectComponent(
        tapPosition: Vector2.zero(),
        duration: 0.1,
      );

      expect(quickEffect.duration, 0.1);
    });

    test('Long duration effects have correct duration', () {
      final longEffect = TapEffectComponent(
        tapPosition: Vector2.zero(),
        duration: 2.0,
      );

      expect(longEffect.duration, 2.0);
    });

    test('Multiple effects at same position have correct properties', () {
      final effect1 = TapEffectComponent(
        tapPosition: Vector2(100, 100),
        duration: 1.0,
      );
      final effect2 = TapEffectComponent(
        tapPosition: Vector2(100, 100),
        duration: 1.0,
      );

      expect(effect1.position, effect2.position);
      expect(effect1.duration, effect2.duration);
    });

    test('Multiple effects can be created with different properties', () {
      final effects = List.generate(
        10,
        (i) => TapEffectComponent(
          tapPosition: Vector2(i * 10.0, i * 10.0),
          duration: 0.5,
        ),
      );

      expect(effects.length, 10);
      for (var i = 0; i < effects.length; i++) {
        expect(effects[i].position, Vector2(i * 10.0, i * 10.0));
        expect(effects[i].duration, 0.5);
      }
    });
  });

  group('TapEffectComponent Render Tests', () {
    test('Component render does not throw during animation', () {
      final component = TapEffectComponent(
        tapPosition: Vector2(50, 50),
        color: Colors.red,
        maxRadius: 15.0,
        duration: 0.4,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Render at start
      expect(() => component.render(canvas), returnsNormally);

      // Render mid-animation
      component.update(0.2);
      expect(() => component.render(canvas), returnsNormally);

      // Render near end
      component.update(0.15);
      expect(() => component.render(canvas), returnsNormally);
    });

    test('Component render does not throw after duration', () {
      final component = TapEffectComponent(
        tapPosition: Vector2(50, 50),
        duration: 0.4,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      component.update(0.5);
      expect(() => component.render(canvas), returnsNormally);
    });

    test('Component renders at different animation stages', () {
      final component = TapEffectComponent(
        tapPosition: Vector2.zero(),
        duration: 1.0,
        maxRadius: 30.0,
      );

      // At start (progress = 0.0)
      final recorder1 = PictureRecorder();
      final canvas1 = Canvas(recorder1);
      expect(() => component.render(canvas1), returnsNormally);

      // At halfway (progress = 0.5)
      component.update(0.5);
      final recorder2 = PictureRecorder();
      final canvas2 = Canvas(recorder2);
      expect(() => component.render(canvas2), returnsNormally);

      // Near end (progress = 0.9)
      component.update(0.4);
      final recorder3 = PictureRecorder();
      final canvas3 = Canvas(recorder3);
      expect(() => component.render(canvas3), returnsNormally);
    });

    test('Component renders with different colors', () {
      final redComponent = TapEffectComponent(
        tapPosition: Vector2.zero(),
        color: Colors.red,
      );
      final blueComponent = TapEffectComponent(
        tapPosition: Vector2.zero(),
        color: Colors.blue,
      );

      final recorder1 = PictureRecorder();
      final canvas1 = Canvas(recorder1);
      expect(() => redComponent.render(canvas1), returnsNormally);

      final recorder2 = PictureRecorder();
      final canvas2 = Canvas(recorder2);
      expect(() => blueComponent.render(canvas2), returnsNormally);
    });

    test('Component renders with different radii', () {
      final smallComponent = TapEffectComponent(
        tapPosition: Vector2.zero(),
        maxRadius: 15.0,
      );
      final largeComponent = TapEffectComponent(
        tapPosition: Vector2.zero(),
        maxRadius: 50.0,
      );

      final recorder1 = PictureRecorder();
      final canvas1 = Canvas(recorder1);
      expect(() => smallComponent.render(canvas1), returnsNormally);

      final recorder2 = PictureRecorder();
      final canvas2 = Canvas(recorder2);
      expect(() => largeComponent.render(canvas2), returnsNormally);
    });
  });
}
