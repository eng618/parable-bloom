import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/core/constants/animation_timing.dart';
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

    test(
        'clear cruise is slower than the blocked step, and the last vine is slower still',
        () {
      final track = buildTrack();
      final mid = VineSlideController.idle()
        ..startRun(track: track, approachSteps: 2, isClear: true);
      final last = VineSlideController.idle()
        ..startRun(
          track: track,
          approachSteps: 2,
          isClear: true,
          isLastVine: true,
        );

      expect(mid.stepDuration, AnimationTiming.vineCruiseSecondsPerCell);
      expect(last.stepDuration, AnimationTiming.vineLastCruiseSecondsPerCell);
      expect(last.plannedDuration, greaterThan(mid.plannedDuration * 1.3));
      // The old short-vine step was 0.06s. Cruise must not regress to that.
      expect(mid.stepDuration, greaterThan(0.06));
    });

    test(
        'a long tail speeds up only after the head leaves, and the run stays within the cap',
        () {
      const cols = 12;
      final cells = <Map<String, int>>[];
      for (var y = 3; y >= 0; y--) {
        if (y.isEven) {
          for (var x = 0; x < cols; x++) {
            cells.add({'x': x, 'y': y});
          }
        } else {
          for (var x = cols - 1; x >= 0; x--) {
            cells.add({'x': x, 'y': y});
          }
        }
      }
      final ordered = cells.reversed.toList();
      final track = VineTrack.build(
        orderedPath: ordered,
        headDirection: 'right',
        gridWidth: cols,
        gridHeight: 4,
        extensionArc: 80 * pitch,
      );
      final controller = VineSlideController.idle()
        ..startRun(track: track, approachSteps: 0, isClear: true);

      expect(
        controller.plannedDuration,
        closeTo(AnimationTiming.vineClearCapSeconds, 0.05),
      );

      // The approach to the edge keeps the cruise. At 90% of the time it
      // takes the head to reach the edge, the head is still on that approach.
      final cruiseSpeed = pitch / AnimationTiming.vineCruiseSecondsPerCell;
      final onScreenSeconds = track.exitTriggerArc / cruiseSpeed;
      var elapsed = 0.0;
      const dt = 1 / 120;
      while (controller.isAnimating && elapsed < onScreenSeconds * 0.9) {
        controller.update(dt);
        elapsed += dt;
      }
      expect(controller.headArc, lessThan(track.exitTriggerArc));

      while (controller.isAnimating && elapsed < onScreenSeconds + 0.2) {
        controller.update(dt);
        elapsed += dt;
      }
      expect(controller.headArc, greaterThanOrEqualTo(track.exitTriggerArc));
      expect(elapsed, lessThan(AnimationTiming.vineClearCapSeconds));
    });

    test('a viewport exit cruises until the tail leaves the screen', () {
      final track = buildTrack();
      const tailClear = 640.0;
      final controller = VineSlideController.idle()
        ..startRun(
          track: track,
          approachSteps: 2,
          isClear: true,
          tailClearArc: tailClear,
        );

      final end = tailClear + track.windowLength;
      final cruiseSpeed = pitch / AnimationTiming.vineCruiseSecondsPerCell;
      expect(controller.plannedDuration, closeTo(end / cruiseSpeed, 0.02));
      expect(
        controller.plannedDuration,
        greaterThan(AnimationTiming.vineClearCapSeconds),
      );

      // The head reaches the board edge on the cruise clock, not a sped-up one.
      var elapsed = 0.0;
      var exited = 0;
      const dt = 1 / 120;
      final edgeTime = track.exitTriggerArc / cruiseSpeed;
      while (controller.isAnimating && elapsed < edgeTime) {
        final update = controller.update(dt);
        if (update.justExitedBoard) exited++;
        elapsed += dt;
      }
      expect(controller.headArc, closeTo(track.exitTriggerArc, 4));

      final updates = runToFinish(controller);
      exited += updates.where((u) => u.justExitedBoard).length;
      expect(controller.headArc, closeTo(end, 0.5));
      expect(exited, 1);
      expect(updates.where((u) => u.justFinished), hasLength(1));
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
      expect(controller.stepDuration, 0.06);

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
