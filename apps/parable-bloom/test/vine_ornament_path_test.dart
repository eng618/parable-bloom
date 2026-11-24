import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/appearance/domain/vine_skin.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_ornament_path.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

void main() {
  final track = VineTrack.build(
    orderedPath: const [
      {'x': 4, 'y': 0},
      {'x': 3, 'y': 0},
      {'x': 2, 'y': 0},
      {'x': 1, 'y': 0},
      {'x': 0, 'y': 0},
    ],
    headDirection: 'right',
    gridWidth: 5,
    gridHeight: 1,
    extensionArc: 0,
  );
  const headX = 4 * 42.0 + 26.0;
  const centerY = 26.0;

  test('a stamp inside the arrow clearance is omitted', () {
    expect(VineOrnamentPath.clearsArrow(0, -20), isFalse);
    expect(
      VineOrnamentPath.clearsArrow(0, -VineMetrics.arrowClearArc),
      isTrue,
    );

    final ornaments = VineOrnamentPath.build(
      track: track,
      headArc: 0,
      windowLength: track.windowLength,
      stride: 1,
      foliage: VineFoliage.leaves,
      scratch: Float32List(VineTrack.positionW),
    );
    final bounds = ornaments.fill.getBounds();
    expect(bounds.width, greaterThan(0));
    expect(
      bounds.right,
      lessThan(headX - VineMetrics.tubeWidth * VineMetrics.arrowLengthScale),
    );
  });

  test('ornaments stay inside the lane gap', () {
    for (final foliage in VineFoliage.values) {
      final ornaments = VineOrnamentPath.build(
        track: track,
        headArc: 0,
        windowLength: track.windowLength,
        stride: 1,
        foliage: foliage,
        scratch: Float32List(VineTrack.positionW),
      );
      if (foliage == VineFoliage.none) {
        expect(ornaments.fill.getBounds().isEmpty, isTrue);
        continue;
      }
      final bounds = ornaments.fill.getBounds();
      expect(
        (bounds.top - centerY).abs(),
        lessThanOrEqualTo(VineMetrics.ornamentReach + 0.5),
        reason: foliage.name,
      );
      expect(
        (bounds.bottom - centerY).abs(),
        lessThanOrEqualTo(VineMetrics.ornamentReach + 0.5),
        reason: foliage.name,
      );
    }
  });
}
