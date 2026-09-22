import 'package:flutter/foundation.dart';

import 'calendar_day.dart';

/// One completed training day, as `users/{uid}/trainingHistory/{day}` holds it.
@immutable
class TrainingHistoryEntry {
  /// Creates an entry.
  const TrainingHistoryEntry({
    required this.date,
    required this.programDay,
    required this.completedExerciseIds,
    required this.durationMinutes,
    required this.completedAt,
  });

  /// The user's calendar day, which is also the document id.
  final CalendarDay date;

  /// Which day of the programme was trained.
  final int programDay;

  /// Exercise ids from `assets/content/exercises.json`, in completion order.
  final List<String> completedExerciseIds;

  /// How long the session took.
  final int durationMinutes;

  /// When the server recorded it. Null while that write is still pending.
  final DateTime? completedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingHistoryEntry &&
          other.date == date &&
          other.programDay == programDay &&
          listEquals(other.completedExerciseIds, completedExerciseIds) &&
          other.durationMinutes == durationMinutes &&
          other.completedAt == completedAt;

  @override
  int get hashCode => Object.hash(
        date,
        programDay,
        Object.hashAll(completedExerciseIds),
        durationMinutes,
        completedAt,
      );

  @override
  String toString() => 'TrainingHistoryEntry($date, day $programDay)';
}

/// What a finished training day writes.
///
/// The limits are the ones `firestore.rules` enforces. A value outside them is
/// a bug in the caller, and would come back from the server as a permission
/// error that says nothing about which field was wrong, so the repository
/// refuses it before writing.
@immutable
class TrainingCompletion {
  /// Creates a completion.
  const TrainingCompletion({
    required this.date,
    required this.programDay,
    required this.completedExerciseIds,
    required this.durationMinutes,
  });

  /// The most exercises one entry may list.
  static const int maxExercises = 50;

  /// The longest session one entry may record: a whole day.
  static const int maxDurationMinutes = 1440;

  /// The user's calendar day the training was completed on.
  final CalendarDay date;

  /// Which day of the programme was trained. At least 1.
  final int programDay;

  /// At least one id, at most [maxExercises].
  final List<String> completedExerciseIds;

  /// From 0 to [maxDurationMinutes].
  final int durationMinutes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingCompletion &&
          other.date == date &&
          other.programDay == programDay &&
          listEquals(other.completedExerciseIds, completedExerciseIds) &&
          other.durationMinutes == durationMinutes;

  @override
  int get hashCode => Object.hash(
        date,
        programDay,
        Object.hashAll(completedExerciseIds),
        durationMinutes,
      );

  @override
  String toString() => 'TrainingCompletion($date, day $programDay)';
}

/// What saving a training day did.
enum TrainingSaveResult {
  /// The day is now recorded.
  saved,

  /// The day was already recorded, and nothing was written or counted again.
  ///
  /// Not an error: completing the same day twice is expected, and the model
  /// keeps one entry per day on purpose (`FIRESTORE_MODEL.md`).
  alreadySaved,
}
