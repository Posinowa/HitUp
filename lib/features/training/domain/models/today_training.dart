import 'package:flutter/foundation.dart';

import 'exercise.dart';
import 'training_program.dart';

/// What the user is meant to train today, and what it was built from.
///
/// Produced by `TodayTrainingEngine`. A value, so a screen can be built from a
/// fixture and a test needs no Firebase and no asset bundle.
@immutable
class TodayTraining {
  /// A day with exercises to run.
  const TodayTraining({
    required this.programDay,
    required ProgramDay day,
    required ResolvedDay resolved,
    this.programDayAssumed = false,
  })  : _day = day,
        _resolved = resolved,
        isProgramFinished = false;

  /// Every day of the programme is behind the user.
  const TodayTraining.programFinished({
    required this.programDay,
    this.programDayAssumed = false,
  })  : _day = null,
        _resolved = const ResolvedDay(
          exercises: <Exercise>[],
          missingIds: <String>[],
        ),
        isProgramFinished = true;

  /// The day of the programme this is, counting from one.
  ///
  /// The day the engine actually used. That is the profile's
  /// `currentProgramDay`, except where it could not be read or was below one.
  final int programDay;

  /// True when [programDay] was assumed rather than read.
  ///
  /// The engine falls back to day one when the profile cannot be reached, so
  /// the app still has something to show offline before a first sync. A screen
  /// can say so instead of presenting an assumed day as the user's own.
  final bool programDayAssumed;

  /// True when the programme has no day [programDay] because it is over.
  final bool isProgramFinished;

  final ProgramDay? _day;
  final ResolvedDay _resolved;

  /// The day's plan, or null when [isProgramFinished].
  ProgramDay? get day => _day;

  /// The exercises to run, in order. Empty when [isProgramFinished].
  List<Exercise> get exercises => _resolved.exercises;

  /// Exercise ids the day names that this build could not find.
  ///
  /// A day that lost one exercise to a newer content file still runs the rest,
  /// so these are reported rather than thrown (`CONTENT_SCHEMA.md`).
  List<String> get missingExerciseIds => _resolved.missingIds;

  /// The sum of the exercises' own durations.
  ///
  /// What the session will actually take, exercise time only. It can be
  /// shorter than [estimatedDuration], which is the day's own figure and
  /// includes the pauses between exercises.
  Duration get totalDuration => _resolved.actualDuration;

  /// The day's own estimate, or zero when [isProgramFinished].
  Duration get estimatedDuration => _day?.estimatedDuration ?? Duration.zero;

  /// True when there is nothing to run: the programme is over, or every
  /// exercise the day names is missing from this build.
  bool get isEmpty => exercises.isEmpty;

  /// True when every exercise the day names was found.
  bool get isComplete => missingExerciseIds.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodayTraining &&
          other.programDay == programDay &&
          other.programDayAssumed == programDayAssumed &&
          other.isProgramFinished == isProgramFinished &&
          other._day == _day &&
          other._resolved == _resolved;

  @override
  int get hashCode => Object.hash(
        programDay,
        programDayAssumed,
        isProgramFinished,
        _day,
        _resolved,
      );

  @override
  String toString() => isProgramFinished
      ? 'TodayTraining(day $programDay, programme finished)'
      : 'TodayTraining(day $programDay, ${exercises.length} exercises)';
}
