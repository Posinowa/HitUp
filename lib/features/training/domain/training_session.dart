import 'package:flutter/foundation.dart';

import 'models/models.dart';

/// Where a training session is (HIT-026).
enum SessionStatus {
  /// Built, not started. Nothing has been done yet.
  notStarted,

  /// Running, on the exercise at `currentIndex`.
  inProgress,

  /// Started and put down. The same exercise is still current.
  paused,

  /// Over, either because every exercise was done or because the user
  /// finished early.
  completed,
}

/// A training day being worked through.
///
/// A value, not a controller: each transition returns a new session rather
/// than changing this one, so the whole state machine can be read in one file
/// and tested without a widget, a timer or a repository.
///
/// **Illegal transitions throw.** Pausing something that was never started, or
/// completing an exercise after the session is over, is a bug in the caller,
/// not a state to fall back from. A screen asks with [canPause] and friends
/// before it offers a button.
@immutable
class TrainingSession {
  /// Creates a session in an explicit state.
  ///
  /// Prefer [TrainingSession.forToday]; this one is for restoring a saved
  /// session and for tests.
  TrainingSession({
    required this.programDay,
    required List<String> exerciseIds,
    required this.status,
    required this.currentIndex,
    required List<String> completedExerciseIds,
  })  : exerciseIds = List<String>.unmodifiable(exerciseIds),
        completedExerciseIds = List<String>.unmodifiable(completedExerciseIds) {
    if (programDay < 1) {
      throw ArgumentError.value(programDay, 'programDay', 'must be at least 1');
    }
    if (this.exerciseIds.isEmpty) {
      throw ArgumentError.value(
        exerciseIds,
        'exerciseIds',
        'a session needs at least one exercise',
      );
    }
    if (currentIndex < 0 || currentIndex >= this.exerciseIds.length) {
      throw ArgumentError.value(
        currentIndex,
        'currentIndex',
        'must point at one of the ${this.exerciseIds.length} exercises',
      );
    }
  }

  /// A session for the day the engine built (HIT-025).
  ///
  /// Throws an [ArgumentError] for a day with nothing to run, which is
  /// [TodayTraining.isEmpty]: a finished programme, or a day whose exercises
  /// this build cannot render. A screen checks that before offering to start.
  factory TrainingSession.forToday(TodayTraining today) => TrainingSession(
        programDay: today.programDay,
        exerciseIds: today.exercises.map((Exercise e) => e.id).toList(),
        status: SessionStatus.notStarted,
        currentIndex: 0,
        completedExerciseIds: const <String>[],
      );

  /// Which day of the programme this session is.
  final int programDay;

  /// The exercises to run, in order.
  final List<String> exerciseIds;

  /// Where the session is.
  final SessionStatus status;

  /// Which exercise is current, counting from zero.
  ///
  /// Stays where it is when the session completes, so a summary can still say
  /// which exercise the user stopped on.
  final int currentIndex;

  /// The exercises finished so far, in the order they were finished.
  ///
  /// Not the same as the first [currentIndex] ids: an exercise can be skipped,
  /// and a skipped one is not completed.
  final List<String> completedExerciseIds;

  /// The exercise being worked on, or the one stopped at when completed.
  String get currentExerciseId => exerciseIds[currentIndex];

  /// How many exercises the day has.
  int get exerciseCount => exerciseIds.length;

  /// How far through the session is, from 0 to 1, counted in completions.
  double get progress => completedExerciseIds.length / exerciseCount;

  /// True when every exercise was completed.
  bool get isFullyCompleted => completedExerciseIds.length == exerciseCount;

  /// True when there is something to resume: started, not finished.
  bool get isResumable =>
      status == SessionStatus.inProgress || status == SessionStatus.paused;

  /// Whether each transition is allowed from here.
  bool get canStart => status == SessionStatus.notStarted;

  /// Whether [pause] is allowed.
  bool get canPause => status == SessionStatus.inProgress;

  /// Whether [resume] is allowed.
  bool get canResume => status == SessionStatus.paused;

  /// Whether [completeCurrentExercise] and [skipCurrentExercise] are allowed.
  bool get canAdvance => status == SessionStatus.inProgress;

  /// Whether [finish] is allowed.
  bool get canFinish => status != SessionStatus.completed;

  /// Starts the session on its first exercise.
  TrainingSession start() {
    _require(canStart, 'start', 'a session that has already started');
    return _copyWith(status: SessionStatus.inProgress);
  }

  /// Puts the session down, keeping the current exercise.
  TrainingSession pause() {
    _require(canPause, 'pause', 'a session that is not running');
    return _copyWith(status: SessionStatus.paused);
  }

  /// Picks it up again, on the same exercise.
  TrainingSession resume() {
    _require(canResume, 'resume', 'a session that is not paused');
    return _copyWith(status: SessionStatus.inProgress);
  }

  /// Records the current exercise as done and moves on.
  ///
  /// Completing the last one completes the session, which is the whole point
  /// of the day: nothing else has to notice that it was the last.
  TrainingSession completeCurrentExercise() {
    _require(
      canAdvance,
      'complete an exercise in',
      'a session that is not running',
    );
    final List<String> completed = <String>[
      ...completedExerciseIds,
      // A repeated completion of the same exercise, which a double tap can
      // produce, is recorded once.
      if (!completedExerciseIds.contains(currentExerciseId)) currentExerciseId,
    ];
    return _advance(completed);
  }

  /// Moves past the current exercise without recording it.
  TrainingSession skipCurrentExercise() {
    _require(
      canAdvance,
      'skip an exercise in',
      'a session that is not running',
    );
    return _advance(completedExerciseIds);
  }

  /// Ends the session where it stands.
  ///
  /// What a user leaving early does. Whatever was completed stays completed;
  /// [isFullyCompleted] is what tells the difference afterwards.
  TrainingSession finish() {
    _require(canFinish, 'finish', 'a session that is already over');
    return _copyWith(status: SessionStatus.completed);
  }

  TrainingSession _advance(List<String> completed) {
    final bool wasLast = currentIndex == exerciseCount - 1;
    return _copyWith(
      status: wasLast ? SessionStatus.completed : SessionStatus.inProgress,
      currentIndex: wasLast ? currentIndex : currentIndex + 1,
      completedExerciseIds: completed,
    );
  }

  /// The same session in a new state.
  ///
  /// [status] is required because every transition changes it; a default of
  /// "whatever it was" would be a branch no transition takes.
  TrainingSession _copyWith({
    required SessionStatus status,
    int? currentIndex,
    List<String>? completedExerciseIds,
  }) =>
      TrainingSession(
        programDay: programDay,
        exerciseIds: exerciseIds,
        status: status,
        currentIndex: currentIndex ?? this.currentIndex,
        completedExerciseIds: completedExerciseIds ?? this.completedExerciseIds,
      );

  void _require(bool allowed, String action, String from) {
    if (!allowed) {
      throw StateError('Cannot $action $from (${status.name}).');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingSession &&
          other.programDay == programDay &&
          listEquals(other.exerciseIds, exerciseIds) &&
          other.status == status &&
          other.currentIndex == currentIndex &&
          listEquals(other.completedExerciseIds, completedExerciseIds);

  @override
  int get hashCode => Object.hash(
        programDay,
        Object.hashAll(exerciseIds),
        status,
        currentIndex,
        Object.hashAll(completedExerciseIds),
      );

  @override
  String toString() => 'TrainingSession(day $programDay, ${status.name}, '
      '${completedExerciseIds.length}/$exerciseCount)';
}
