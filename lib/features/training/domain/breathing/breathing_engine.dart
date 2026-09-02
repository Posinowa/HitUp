import 'package:flutter/foundation.dart';

import '../models/exercise_config.dart';
import 'breathing_timeline.dart';

/// Runs a breathing pattern, one advance at a time.
///
/// The engine holds a position in a [BreathingTimeline] and nothing else. It
/// starts no timer, subscribes to no clock and owns nothing that has to be
/// disposed; time reaches it only through [advance].
///
/// That is what makes it testable without waiting: a thirty second pattern is
/// exercised in one call, and every boundary can be landed on exactly. It also
/// keeps the drawing loop in charge of the clock, which is where Flutter already
/// puts it, instead of running a second clock beside it that can drift.
///
/// ```dart
/// final BreathingEngine engine = BreathingEngine(
///   config: config,
///   onPhaseChanged: (BreathingSnapshot s) => cue(s.phase),
/// );
/// engine.advance(const Duration(milliseconds: 16)); // once per frame
/// ```
class BreathingEngine {
  /// Creates an engine for [config], positioned at the start.
  ///
  /// [onPhaseChanged] is called when an [advance] lands in a phase or a cycle
  /// other than the one it started in, and is passed the snapshot it landed on.
  /// It is the hook a sound cue hangs from later: nothing here plays anything,
  /// but the moment a cue would need is reported.
  ///
  /// [onComplete] is called once, on the advance that finishes the last cycle.
  BreathingEngine({
    required this.config,
    this.onPhaseChanged,
    this.onComplete,
  }) : timeline = BreathingTimeline(config) {
    final BreathingSnapshot start = timeline.snapshotAt(Duration.zero);
    _lastPhase = start.phase;
    _lastCycle = start.cycle;
  }

  /// The pattern being run.
  final BreathingConfig config;

  /// The schedule [config] describes.
  final BreathingTimeline timeline;

  /// Called when an advance crosses into a different phase or cycle.
  final void Function(BreathingSnapshot snapshot)? onPhaseChanged;

  /// Called once, when the last cycle finishes.
  final VoidCallback? onComplete;

  Duration _elapsed = Duration.zero;
  bool _isPaused = false;
  bool _completeReported = false;
  late BreathingPhase _lastPhase;
  late int _lastCycle;

  /// How far into the exercise the engine has travelled.
  Duration get elapsed => _elapsed;

  /// Whether [advance] is currently ignoring the time it is given.
  bool get isPaused => _isPaused;

  /// Whether every cycle has finished.
  bool get isComplete => _elapsed >= timeline.totalDuration;

  /// The state of the exercise right now.
  BreathingSnapshot get snapshot => timeline.snapshotAt(_elapsed);

  /// Moves [delta] further into the exercise.
  ///
  /// Does nothing while paused, so a caller driving this from a frame callback
  /// does not have to check first. Elapsed time stops at the end of the last
  /// cycle rather than running past it, which keeps [elapsed] meaningful as a
  /// progress value and is also what makes advancing a finished engine harmless.
  ///
  /// There is deliberately no second guard for "already finished". The clamp
  /// below is what holds the position, and a guard that only repeats what the
  /// clamp already does is a guard no test can tell apart from its absence.
  /// [onComplete] firing once is [_completeReported]'s job alone, so that flag
  /// is load bearing rather than a second belt.
  ///
  /// **A single advance reports the phase it arrives in, not every phase it
  /// passed over.** A delta long enough to skip one only happens when the app
  /// was suspended or the device stalled, and replaying the cues for phases that
  /// are already in the past would fire sounds for breaths the user never took.
  ///
  /// Throws an [ArgumentError] when [delta] is negative. Rewinding is what
  /// [reset] is for, and a negative frame delta is a caller bug worth seeing.
  void advance(Duration delta) {
    if (delta < Duration.zero) {
      throw ArgumentError.value(
        delta,
        'delta',
        'An advance cannot be negative',
      );
    }
    if (_isPaused) {
      return;
    }

    final Duration total = timeline.totalDuration;
    final Duration next = _elapsed + delta;
    _elapsed = next > total ? total : next;

    final BreathingSnapshot now = snapshot;
    if (now.phase != _lastPhase || now.cycle != _lastCycle) {
      _lastPhase = now.phase;
      _lastCycle = now.cycle;
      onPhaseChanged?.call(now);
    }
    if (isComplete && !_completeReported) {
      _completeReported = true;
      onComplete?.call();
    }
  }

  /// Stops [advance] from consuming time until [resume].
  ///
  /// Pausing an already paused engine, or one that has finished, does nothing.
  void pause() => _isPaused = true;

  /// Lets [advance] consume time again.
  void resume() => _isPaused = false;

  /// Returns the engine to the start of the first cycle.
  ///
  /// Clears the pause as well, so a reset engine is ready to run rather than
  /// ready and stopped. Neither callback fires: a reset is something the caller
  /// did, so telling it what it just did is noise, and firing a phase change
  /// from here would let a sound cue play when nobody breathed.
  void reset() {
    _elapsed = Duration.zero;
    _isPaused = false;
    _completeReported = false;
    final BreathingSnapshot start = timeline.snapshotAt(Duration.zero);
    _lastPhase = start.phase;
    _lastCycle = start.cycle;
  }

  @override
  String toString() =>
      'BreathingEngine($config, at ${_elapsed.inMilliseconds}ms'
      '${_isPaused ? ', paused' : ''})';
}
