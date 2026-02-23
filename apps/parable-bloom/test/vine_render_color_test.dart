import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine_component.dart';

void main() {
  test('Blocked color only applied when attempted and blocked', () {
    final calm = const Color(0xFF4CAF50);
    final attempted = const Color(0xFFB00020);

    // Not attempted -> should be calm color
    final c1 = VineComponent.computeRenderColor(calm, false, attempted);
    expect(c1 == calm, isTrue);

    // Attempted -> should use the attempted color exactly
    final c2 = VineComponent.computeRenderColor(calm, true, attempted);
    expect(c2 == attempted, isTrue);
  });
}
