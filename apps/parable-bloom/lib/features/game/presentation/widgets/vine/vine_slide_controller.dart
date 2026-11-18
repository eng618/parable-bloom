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
  double _easeStartArc = 0;
  bool _isClearRun = false;
  bool _onReturnLeg = false;

  double _legTimer = 0;
  double _legDuration = 0;
  double _cruiseEndTime = 0;
  double _easeEndTime = 0;
  VineCurve _curve = _easeInOutSine;

  double _stepDuration = AnimationTiming.vineStepSeconds;

  /// Planned length of the current leg, in seconds. For a clear this is the
  /// whole exit, including a tail that may have been sped up to the cap.
  double get plannedDuration => _legDuration;

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

  /// Distance-normalized deceleration. Starts near cruise speed and ends
  /// slower, so the head settles off the edge instead of whipping through.
  static double _decelerate(double t) {
    final raw = t - 0.3 * t * t;
    return raw / 0.7;
  }

  /// Starts a run on [track].
  ///
  /// [approachSteps] is the solver's distance-to-blocker in cells.
  /// [isClear] mirrors the legacy `canClearThisRun`.
  /// [isLastVine] selects the slower ending cruise. Occupancy is unchanged
  /// by either rate: the vine has already left the solver's board.
  void startRun({
    required VineTrack track,
    required int approachSteps,
    required bool isClear,
    bool isLastVine = false,
  }) {
    reset();
    final pitch = GameBoardLayout.pointSpacing.toDouble();

    _isClearRun = isClear;
    _approachArc = approachSteps.clamp(0, 4096) * pitch;
    _exitTriggerArc = track.exitTriggerArc;
    _phase = Phase.running;
    _legTimer = 0;
    _onReturnLeg = false;

    if (isClear) {
      final cruise = VineMetrics.cruiseSecondsPerCell(isLastVine: isLastVine);
      _stepDuration = cruise;
      final cruiseSpeed = pitch / cruise;
      _clearEndArc =
          track.exitArc + track.windowLength + VineMetrics.exitFadeArc;
      if (_clearEndArc < _exitTriggerArc) _clearEndArc = _exitTriggerArc;

      final easeBand = AnimationTiming.vineEdgeSettleCells * pitch;
      _easeStartArc = math.max(0.0, _exitTriggerArc - easeBand);
      _cruiseEndTime = _easeStartArc / cruiseSpeed;
      final easeDist = math.max(0.0, _exitTriggerArc - _easeStartArc);
      _easeEndTime = _cruiseEndTime + easeDist / cruiseSpeed;

      final tailDist = math.max(0.0, _clearEndArc - _exitTriggerArc);
      var tailTime = tailDist / cruiseSpeed;
      final cap = AnimationTiming.vineClearCapSeconds;
      // Speed only the off-screen tail. If the approach to the edge is
      // already longer than the cap, keep the cruise and let the run run long.
      if (_easeEndTime + tailTime > cap && tailDist > 0 && _easeEndTime < cap) {
        tailTime = cap - _easeEndTime;
      }
      _legDuration = _easeEndTime + tailTime;
      _curve = _easeInOutSine;
      return;
    }

    // Blocked bumps keep the fast step. A mistake should return home quickly.
    final plannedSteps =
        approachSteps + (track.windowLength / pitch).ceil() + 6;
    _stepDuration = VineMetrics.stepDurationFor(plannedSteps);
    final speed = pitch / _stepDuration;

    if (_approachArc > 0) {
      _clearEndArc = _approachArc;
      _legDuration = _approachArc / speed;
      _curve = _easeOutCubic;
    } else {
      // Nothing to move: report an instantly finished, no-op run.
      _clearEndArc = 0;
      _legDuration = 0;
      _curve = _easeOutCubic;
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
      if (_legDuration <= 0 || _legTimer >= _legDuration) {
        _headArc = _clearEndArc;
        if (prevHeadArc < _exitTriggerArc && _headArc >= _exitTriggerArc) {
          result.justExitedBoard = true;
        }
        result.justFinished = true;
        _stop();
        return result;
      }
      _headArc = _clearArcAt(_legTimer);
      if (prevHeadArc < _exitTriggerArc && _headArc >= _exitTriggerArc) {
        result.justExitedBoard = true;
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

  /// Cruise to the settle band, decelerate across the edge, then linear
  /// (possibly sped-up) travel for the off-screen tail.
  double _clearArcAt(double elapsed) {
    if (elapsed <= _cruiseEndTime) {
      if (_cruiseEndTime <= 1e-9) return _easeStartArc;
      return _easeStartArc * (elapsed / _cruiseEndTime);
    }
    if (elapsed <= _easeEndTime) {
      final span = _easeEndTime - _cruiseEndTime;
      if (span <= 1e-9) return _exitTriggerArc;
      final t = ((elapsed - _cruiseEndTime) / span).clamp(0.0, 1.0);
      return _easeStartArc + (_exitTriggerArc - _easeStartArc) * _decelerate(t);
    }
    final span = _legDuration - _easeEndTime;
    if (span <= 1e-9) return _clearEndArc;
    final t = ((elapsed - _easeEndTime) / span).clamp(0.0, 1.0);
    return _exitTriggerArc + (_clearEndArc - _exitTriggerArc) * t;
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
    _easeStartArc = 0;
    _isClearRun = false;
    _onReturnLeg = false;
    _legTimer = 0;
    _legDuration = 0;
    _cruiseEndTime = 0;
    _easeEndTime = 0;
  }
}

enum Phase { idle, running }
