import 'dart:async';

import 'package:flutter/foundation.dart';

/// The time on the exercise screen (HIT-028): the countdown for the exercise
/// on screen, and how long the session has actually been worked.
///
/// The session itself holds no clock (`TRAINING.md`), so this is where the
/// time `TrainingDayRecorder` is given comes from.
///
/// Counts whole seconds with a periodic [Timer], and only while running. A
/// paused session, or one left in the background, is not training time, and
/// counting it would inflate the minutes the user sees on their progress.
///
/// Whole seconds rather than a [Stopwatch]: the countdown is shown in whole
/// seconds, the recorder rounds to minutes, and a timer is what a widget test
/// can drive without waiting in real time.
class ExerciseClock extends ChangeNotifier {
  Timer? _timer;
  int? _exerciseIndex;
  int _remaining = 0;
  int _elapsed = 0;

  /// Time left on the current exercise. Stops at zero.
  Duration get remaining => Duration(seconds: _remaining);

  /// Time the session has been running, across every exercise.
  ///
  /// Keeps counting after an exercise's own time is up: the user is still
  /// working, and that is time they spent.
  Duration get elapsed => Duration(seconds: _elapsed);

  /// Whether the clock is counting.
  bool get isRunning => _timer != null;

  /// Whether the current exercise's time has run out.
  bool get isTimeUp => _exerciseIndex != null && _remaining == 0;

  /// Puts exercise [index] on the clock, with [duration] to go.
  ///
  /// The same index again is not a new exercise and resets nothing, so this
  /// can be called on every change to the session.
  void showExercise(int index, Duration duration) {
    if (index == _exerciseIndex) {
      return;
    }
    _exerciseIndex = index;
    _remaining = duration.inSeconds;
    notifyListeners();
  }

  /// Starts counting. Does nothing when already counting.
  void run() {
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    notifyListeners();
  }

  /// Stops counting, keeping what was counted. Does nothing when stopped.
  void stop() {
    if (_timer == null) {
      return;
    }
    _timer!.cancel();
    _timer = null;
    notifyListeners();
  }

  void _tick(Timer _) {
    _elapsed++;
    if (_remaining > 0) {
      _remaining--;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    // A periodic timer outlives the screen that started it unless something
    // stops it.
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
