import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_slide_controller.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

void main() {
  const pitch = GameBoardLayout.pointSpacing;

  List<Map<String, int>> path() => const [
        {'x': 2, 'y': 0},
        {'x': 1, 'y': 0},
        {'x': 0, 'y': 0},
        {'x': 0, 'y': 1},
      ];

  VineTrack buildTrack() => VineTrack.build(
        orderedPath: path(),
        headDirection: 'right',
        gridWidth: 4,
        gridHeight: 4,
        extensionArc: 12 * pitch,
      );

  /// Runs the controller to completion, collecting per-frame updates.
  List<VineSlideUpdate> runToFinish(VineSlideController controller,
      {double dt = 1 / 120, int maxFrames = 6000}) {
    final updates = <VineSlideUpdate>[];
    for (var i = 0; i < maxFrames && controller.isAnimating; i++) {
      updates.add(controller.update(dt));
    }
    return updates;
  }

  group('clear run', () {
    test('head sweeps the whole clear plan and finishes', () {
      final controller = VineSlideController.idle();
      final track = buildTrack();
      controller.startRun(track: track, approachSteps: 2, isClear: true);
      expect(controller.isClearRun, isTrue);

      final updates = runToFinish(controller);
      expect(controller.isAnimating, isFalse);
      expect(
          controller.headArc,
          closeTo(
            track.exitArc + track.windowLength + VineMetrics.exitFadeArc,
            0.5,
          ));

      final exited = updates.where((u) => u.justExitedBoard);
      expect(exited, hasLength(1));
      final finished = updates.where((u) => u.justFinished);
      expect(finished, hasLength(1));
    });

    test('headArc is monotonic through the slide', () {
      final controller = VineSlideController.idle();
      final track = buildTrack();
      controller.startRun(track: track, approachSteps: 1, isClear: true);

      double prev = 0;
      var advanced = 0;
      while (controller.isAnimating) {
        controller.update(1 / 120);
        if (controller.headArc >= prev) {
          advanced++;
        }
        prev = controller.headArc;
      }
      expect(advanced, greaterThan(8));
    });

    test('adaptive pacing keeps long clears snappy', () {
      final controller = VineSlideController.idle();
      final track = buildTrack();
      controller.startRun(track: track, approachSteps: 2, isClear: true);
      // plannedSteps = 2 approach + 3 length + 6 = 11 → matches the legacy
      // step-duration contract (only >12 steps pick the fast pace).
      expect(controller.stepDuration, 0.06);
    });
  });

  group('blocked run', () {
    test('travels to the blocker, then returns home', () {
      final controller = VineSlideController.idle();
      final track = buildTrack();
      controller.startRun(track: track, approachSteps: 2, isClear: false);

      final updates = runToFinish(controller);
      expect(controller.isAnimating, isFalse);
      expect(controller.headArc, closeTo(0.0, 1.0));

      final reached = updates.where((u) => u.justReachedBlocker);
      expect(reached, hasLength(1));
      expect(controller.approachArc, closeTo(2 * pitch, 0.5));

      final returned = updates.where((u) => u.justReturnedHome);
      expect(returned, hasLength(1));
      final finished = updates.where((u) => u.justFinished);
      expect(finished, hasLength(1));
      // A blocked run must never fire the bloom trigger.
      expect(
        updates.any((u) => u.justExitedBoard),
        isFalse,
      );
    });
  });

  group('no-op run', () {
    test('approach of zero finishes immediately', () {
      final controller = VineSlideController.idle();
      final track = buildTrack();
      controller.startRun(track: track, approachSteps: 0, isClear: false);
      final updates = runToFinish(controller);
      expect(controller.headArc, 0);
      expect(updates.any((u) => u.justFinished), isTrue);
    });
  });

  group('reset', () {
    test('reset restores the authored track window', () {
      final controller = VineSlideController.idle();
      final track = buildTrack();
      controller.startRun(track: track, approachSteps: 2, isClear: true);
      controller.update(0.2);
      controller.reset();
      expect(controller.isAnimating, isFalse);
      expect(controller.headArc, 0);
      expect(controller.isClearRun, isFalse);
    });
  });
}
