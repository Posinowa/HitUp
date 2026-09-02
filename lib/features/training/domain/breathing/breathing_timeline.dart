import 'package:flutter/foundation.dart';

import '../models/exercise_config.dart';

/// One phase of a guided breathing cycle.
///
/// A cycle is always inhale, then hold, then exhale, in that order. The hold is
/// the only one a pattern may leave out, and it leaves it out by lasting zero
/// seconds rather than by being absent from this list.
enum BreathingPhase {
  /// Breathing in.
  inhale,

  /// Holding at the top. Skipped entirely when the pattern holds for zero
  /// seconds, so this value never appears in a snapshot of such a pattern.
  hold,

  /// Breathing out.
  exhale,
}

/// Where a breathing exercise stands at one instant.
///
/// A value, not a view: it answers what is true at the moment it describes and
/// holds no reference to whatever produced it.
@immutable
class BreathingSnapshot {
  /// Creates a snapshot.
  const BreathingSnapshot({
    required this.phase,
    required this.cycle,
    required this.elapsedInPhase,
    required this.phaseDuration,
    required this.isComplete,
  });

  /// The phase now under way.
  ///
  /// After the last cycle finishes this stays [BreathingPhase.exhale] rather
  /// than becoming null or gaining a "done" member. The exercise ends on an
  /// exhale, and a caller drawing the final frame should draw a completed
  /// exhale; [isComplete] is what distinguishes the end from the run.
  final BreathingPhase phase;

  /// Which repetition this is, counting from one.
  ///
  /// One-based because it is shown to a person: "cycle 1 of 5" is what a user
  /// reads, and a display that subtracts one everywhere is a display that will
  /// eventually forget to.
  final int cycle;

  /// How far into [phase] the exercise has travelled.
  final Duration elapsedInPhase;

  /// How long [phase] lasts in total.
  final Duration phaseDuration;

  /// Whether every cycle has finished.
  final bool isComplete;

  /// How much of [phase] is left.
  Duration get remainingInPhase => phaseDuration - elapsedInPhase;

  /// Progress through [phase], from 0.0 to 1.0.
  ///
  /// A phase never lasts zero seconds, because a zero second hold is skipped
  /// rather than entered, so this never divides by zero. That invariant belongs
  /// to [BreathingTimeline], which is why it is stated here rather than guarded.
  double get phaseProgress =>
      elapsedInPhase.inMicroseconds / phaseDuration.inMicroseconds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BreathingSnapshot &&
          other.phase == phase &&
          other.cycle == cycle &&
          other.elapsedInPhase == elapsedInPhase &&
          other.phaseDuration == phaseDuration &&
          other.isComplete == isComplete;

  @override
  int get hashCode => Object.hash(
        phase,
        cycle,
        elapsedInPhase,
        phaseDuration,
        isComplete,
      );

  @override
  String toString() => 'BreathingSnapshot(${phase.name}, cycle $cycle, '
      '${elapsedInPhase.inMilliseconds}/${phaseDuration.inMilliseconds}ms'
      '${isComplete ? ', complete' : ''})';
}

/// The schedule a [BreathingConfig] describes, read at any instant.
///
/// Pure and stateless: the same elapsed time always produces the same snapshot,
/// and nothing here starts a timer, listens to a clock or holds a position.
/// Time arrives as an argument.
///
/// That split is deliberate. All of the arithmetic that can be wrong lives here,
/// where it can be checked at the exact instants it is most likely to be wrong,
/// the boundaries between phases. [BreathingEngine] holds the position and
/// leaves the arithmetic alone.
@immutable
class BreathingTimeline {
  /// Creates a timeline for [config].
  const BreathingTimeline(this.config);

  /// The pattern being timed.
  final BreathingConfig config;

  /// How long one cycle lasts.
  Duration get cycleDuration => config.cycleDuration;

  /// How long the whole exercise lasts.
  Duration get totalDuration => config.totalDuration;

  /// The state of the exercise [elapsed] into it.
  ///
  /// **Boundaries belong to the phase that is starting, not the one that
  /// ended.** With a four second inhale, the instant at exactly four seconds is
  /// the first instant of the hold: four seconds of inhaling are finished. The
  /// same rule ends the exercise, so [totalDuration] exactly is complete rather
  /// than the last microsecond of the final exhale.
  ///
  /// Throws an [ArgumentError] when [elapsed] is negative. Time before the start
  /// is not an edge of this exercise, it is a caller that subtracted in the
  /// wrong direction, and clamping it to zero would hide that.
  BreathingSnapshot snapshotAt(Duration elapsed) {
    if (elapsed < Duration.zero) {
      throw ArgumentError.value(
        elapsed,
        'elapsed',
        'Elapsed time cannot be negative',
      );
    }

    final Duration total = totalDuration;
    if (elapsed >= total) {
      return BreathingSnapshot(
        phase: BreathingPhase.exhale,
        cycle: config.cycles,
        elapsedInPhase: Duration(seconds: config.exhaleSeconds),
        phaseDuration: Duration(seconds: config.exhaleSeconds),
        isComplete: true,
      );
    }

    // Integer microseconds throughout. Duration is stored that way, so the
    // division is exact and no phase boundary can land a microsecond early
    // because a double could not represent it.
    final int cycleMicros = cycleDuration.inMicroseconds;
    final int completedCycles = elapsed.inMicroseconds ~/ cycleMicros;
    final int withinCycle = elapsed.inMicroseconds % cycleMicros;

    final int inhaleMicros =
        config.inhaleSeconds * Duration.microsecondsPerSecond;
    final int holdMicros = config.holdSeconds * Duration.microsecondsPerSecond;

    final BreathingPhase phase;
    final int phaseStart;
    final int phaseMicros;
    if (withinCycle < inhaleMicros) {
      phase = BreathingPhase.inhale;
      phaseStart = 0;
      phaseMicros = inhaleMicros;
    } else if (withinCycle < inhaleMicros + holdMicros) {
      // Unreachable when the pattern holds for zero seconds: the test above
      // already failed, and `inhaleMicros + 0` cannot be greater than a value
      // that is not less than `inhaleMicros`. That is how a zero second hold is
      // skipped rather than entered for an instant.
      phase = BreathingPhase.hold;
      phaseStart = inhaleMicros;
      phaseMicros = holdMicros;
    } else {
      phase = BreathingPhase.exhale;
      phaseStart = inhaleMicros + holdMicros;
      phaseMicros = cycleMicros - phaseStart;
    }

    return BreathingSnapshot(
      phase: phase,
      cycle: completedCycles + 1,
      elapsedInPhase: Duration(microseconds: withinCycle - phaseStart),
      phaseDuration: Duration(microseconds: phaseMicros),
      isComplete: false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BreathingTimeline && other.config == config;

  @override
  int get hashCode => config.hashCode;

  @override
  String toString() => 'BreathingTimeline($config)';
}
