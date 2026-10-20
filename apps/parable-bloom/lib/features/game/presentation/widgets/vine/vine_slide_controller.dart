import 'dart:math' as math;

import 'package:parable_bloom/core/constants/animation_timing.dart';
import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

/// Per-frame outcomes of a controller step, mirroring the legacy animator's
/// side effects so [VineComponent] wiring does not change.
class VineSlideUpdate {
  /// True on the single frame the head center passes one full cell beyond
  /// the board edge (bloom trigger parity with `hasExitedVisibleGrid`).
  bool justExitedBoard = false;

  /// True on the single frame a blocked run reaches its forward extent.
  bool justReachedBlocker = false;

  /// True on the single frame a blocked run fully returns to its start.
  bool justReturnedHome = false;

  /// True on the last update of the whole run.
  bool justFinished = false;
}

typedef VineCurve = double Function(double t);

/// Slide-state machine over a [VineTrack].
///
/// The entire motion model is one scalar: the head's arc position on the
/// rail. Instead of per-cell-step easing (the legacy sawtooth velocity
/// profile), each phase eases *globally*, so velocity is smooth across the
/// whole run and the vine reads as one continuous object.
///
/// - Clearing run: head slides from arc 0, crossing [VineTrack.exitArc]
///   (fade begins) and [VineTrack.exitTriggerArc] (bloom), then stops once
///   the tail has fully faded out.
/// - Blocked run: forward to `approachArc` (eased into the wall), then back
///   to 0.
final class VineSlideController {
  VineSlideController._internal();

  /// Idle controller for a vine that is not animating.
  factory VineSlideController.idle() => VineSlideController._internal();

  Phase _phase = Phase.idle;
  double _headArc = 0;

  double _approachArc = 0;
  double _clearEndArc = 0;
  double _exitTriggerArc = 0;
  bool _isClearRun = false;
  bool _onReturnLeg = false;

  double _legTimer = 0;
  double _legDuration = 0;
  VineCurve _curve = _easeInOutSine;

  double _stepDuration = AnimationTiming.vineStepSeconds;

  // Mirror the legacy animator fields the grid layer reads.
  bool get isAnimating => _phase != Phase.idle;

  /// Current head arc position on the track.
  double get headArc => _headArc;
  double get approachArc => _approachArc;
  double get animationTimer => _legTimer;
  double get stepDuration => _stepDuration;
  bool get isClearRun => _isClearRun;

  static double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3.0).toDouble();
  static double _easeInOutSine(double t) =>
      (-(math.cos(math.pi * t) - 1) / 2).toDouble();

  /// Starts a run on [track].
  ///
  /// [approachSteps] is the solver's distance-to-blocker in cells.
  /// [isClear] mirrors the legacy `canClearThisRun`.
  void startRun({
    required VineTrack track,
    required int approachSteps,
    required bool isClear,
  }) {
    reset();
    final pitch = GameBoardLayout.pointSpacing.toDouble();

    _isClearRun = isClear;
    _approachArc = approachSteps.clamp(0, 4096) * pitch;
    _exitTriggerArc = track.exitTriggerArc;

    // Adaptive pacing (same contract as VineMetrics.stepDurationFor).
    final plannedSteps =
        approachSteps + (track.windowLength / pitch).ceil() + 6;
    _stepDuration = VineMetrics.stepDurationFor(plannedSteps);
    final speed = pitch / _stepDuration; // px per second

    _phase = Phase.running;
    if (isClear) {
      _clearEndArc =
          track.exitArc + track.windowLength + VineMetrics.exitFadeArc;
      _legDuration = _clearEndArc / speed;
      _legTimer = 0;
      _curve = _easeInOutSine;
      _onReturnLeg = false;
    } else if (_approachArc > 0) {
      _clearEndArc = _approachArc;
      _legDuration = _approachArc / speed;
      _legTimer = 0;
      _curve = _easeOutCubic;
      _onReturnLeg = false;
    } else {
      // Nothing to move: report an instantly finished, no-op run.
      _clearEndArc = 0;
      _legDuration = 0;
      _legTimer = 0;
      _curve = _easeOutCubic;
      _onReturnLeg = false;
    }
  }

  /// Advances the run by [dt]. Returns the per-frame flags for this step.
  VineSlideUpdate update(double dt) {
    final result = VineSlideUpdate();
    if (_phase != Phase.running) return result;

    final prevHeadArc = _headArc;
    _legTimer += dt;
    final t =
        (_legDuration <= 0) ? 1.0 : (_legTimer / _legDuration).clamp(0.0, 1.0);

    if (_isClearRun) {
      _headArc = _curve(t) * _clearEndArc;
      if (prevHeadArc < _exitTriggerArc && _headArc >= _exitTriggerArc) {
        result.justExitedBoard = true;
      }
      if (t >= 1.0) {
        _headArc = _clearEndArc;
        result.justFinished = true;
        _stop();
      }
      return result;
    }

    // Blocked round-trip.
    if (!_onReturnLeg) {
      _headArc = _curve(t) * _approachArc;
      if (t >= 1.0) {
        _headArc = _approachArc;
        result.justReachedBlocker = true;
        _onReturnLeg = true;
        _legTimer -= _legDuration;
        // Return leg keeps the same pacing, eased back like the bump.
        _curve = _easeInOutSine;
      }
      return result;
    }

    _headArc = (1 - _curve(t)) * _approachArc;
    if (t >= 1.0) {
      _headArc = 0.0;
      result.justReturnedHome = true;
      result.justFinished = true;
      _stop();
    }
    return result;
  }

  void _stop() {
    _phase = Phase.idle;
  }

  /// Fully resets to idle (the vine body returns to its authored track).
  void reset() {
    _phase = Phase.idle;
    _headArc = 0;
    _approachArc = 0;
    _clearEndArc = 0;
    _exitTriggerArc = 0;
    _isClearRun = false;
    _onReturnLeg = false;
    _legTimer = 0;
    _legDuration = 0;
  }
}

enum Phase { idle, running }
