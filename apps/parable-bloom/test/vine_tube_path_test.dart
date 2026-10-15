import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_tube_path.dart';

void main() {
  group('VineTubePath.buildRoundedTube', () {
    test('empty input yields empty path', () {
      final path = VineTubePath.buildRoundedTube(const []);
      expect(path.getBounds(), Rect.zero);
    });

    test('two points yield a straight segment', () {
      final path = VineTubePath.buildRoundedTube(
        const [Offset(0, 0), Offset(42, 0)],
      );
      final bounds = path.getBounds();
      expect(bounds.left, 0.0);
      expect(bounds.right, 42.0);
      expect(bounds.top, 0.0);
      expect(bounds.bottom, 0.0);
    });

    test('L corner stays inside the lane box', () {
      final points = const [
        Offset(0, 0),
        Offset(42, 0),
        Offset(42, 42),
      ];
      final path = VineTubePath.buildRoundedTube(points);
      final bounds = path.getBounds();
      expect(bounds, const Rect.fromLTWH(0, 0, 42, 42));
    });

    test('tight U-turn clamps radius without overshoot', () {
      final points = const [
        Offset(0, 0),
        Offset(42, 0),
        Offset(42, 42),
        Offset(0, 42),
      ];
      final path = VineTubePath.buildRoundedTube(points);
      final bounds = path.getBounds();
      expect(bounds.left, greaterThanOrEqualTo(-1.0));
      expect(bounds.right, lessThanOrEqualTo(43.0));
      expect(bounds.top, greaterThanOrEqualTo(-1.0));
      expect(bounds.bottom, lessThanOrEqualTo(43.0));
    });
  });

  group('VineTubePath.buildArrowHead', () {
    const stroke = VineMetrics.tubeWidth;
    final expectedLength = stroke * VineMetrics.arrowLengthScale;
    final expectedHalf = stroke * VineMetrics.arrowHalfWidthScale;

    test('right head extends forward and stays narrow', () {
      final head = VineTubePath.buildArrowHead(
        const Offset(100, 100),
        'right',
        stroke,
      ).getBounds();
      expect(head.left, closeTo(100 - expectedLength * 0.3, 0.5));
      expect(head.right, closeTo(100 + expectedLength * 0.7, 0.5));
      expect(head.height, closeTo(expectedHalf * 2, 0.5));
    });

    test('all directions produce equal-area heads', () {
      double area(String dir) {
        final b = VineTubePath.buildArrowHead(
          const Offset(50, 50),
          dir,
          stroke,
        ).getBounds();
        return b.width * b.height;
      }

      final areas = ['up', 'down', 'left', 'right'].map(area).toList();
      for (final a in areas) {
        expect(a, closeTo(areas.first, 1.0));
      }
    });

    test('head fits inside one lane pitch', () {
      final b = VineTubePath.buildArrowHead(
        const Offset(0, 0),
        'up',
        stroke,
      ).getBounds();
      expect(b.width, lessThan(42.0));
      expect(b.height, lessThan(42.0));
    });
  });

  group('VineMetrics', () {
    test('thin tube leaves generous lane whitespace', () {
      expect(VineMetrics.tubeWidth, 13.0);
      // 42px pitch minus 13px tube = 29px gap.
      expect(42.0 - VineMetrics.tubeWidth, greaterThan(28.0));
    });

    test('foliage LOD stride', () {
      expect(
        VineMetrics.foliageStride(isAnimating: true, vineCount: 4),
        2,
      );
      expect(
        VineMetrics.foliageStride(isAnimating: false, vineCount: 4),
        3,
      );
      expect(
        VineMetrics.foliageStride(isAnimating: false, vineCount: 24),
        4,
      );
    });

    test('adaptive step duration keeps long clears snappy', () {
      expect(VineMetrics.stepDurationFor(5), 0.06);
      expect(VineMetrics.stepDurationFor(20), 0.035);
    });
  });
}
