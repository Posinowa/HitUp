import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/progress_providers.dart';
import '../../progress/domain/models/calendar_day.dart';
import '../../progress/domain/models/training_history_entry.dart';
import '../../progress/domain/repositories/user_progress_repository.dart';
import '../../progress/domain/streak.dart';
import '../domain/training_session.dart';

/// What recording a finished day did (HIT-053).
@immutable
class TrainingDayRecord {
  /// Creates a record.
  const TrainingDayRecord({
    required this.result,
    required this.programDay,
    required this.streak,
  });

  /// Whether the day was written or was already there.
  final TrainingSaveResult result;

  /// The day of the programme the user is on afterwards.
  final int programDay;

  /// The streak after the day was counted, or null when nothing was counted
  /// because the day was already recorded.
  final StreakUpdate? streak;

  /// True when this call is what recorded the day.
  bool get wasRecorded => result == TrainingSaveResult.saved;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingDayRecord &&
          other.result == result &&
          other.programDay == programDay &&
          other.streak == streak;

  @override
  int get hashCode => Object.hash(result, programDay, streak);

  @override
  String toString() =>
      'TrainingDayRecord(${result.name}, day $programDay, $streak)';
}

/// Records a finished training day on the account (HIT-053).
///
/// Three writes that belong together, in an order that cannot leave a lie
/// behind:
///
/// 1. **The day itself**, with its minutes, as one batch the rules accept.
///    A day already recorded stops here: nothing after this runs twice.
/// 2. **The programme day**, moved on only if the user is still on the day
///    they just finished.
/// 3. **The streak**, counted for that day.
///
/// They are three operations rather than one, because Firestore has no
/// transaction across a batch and two read-decide-writes. The order is what
/// makes a half-finished run safe: the history entry is the record of the day,
/// and the two that follow are both idempotent, so running them again after a
/// failure changes nothing (`USER_PROGRESS.md`).
class TrainingDayRecorder {
  /// Creates a recorder over [progress].
  const TrainingDayRecorder(this._progress);

  final UserProgressRepository _progress;

  /// Records [session] as finished on [today].
  ///
  /// [elapsed] is how long the session took, which the session itself does not
  /// know: it holds no clock, so the screen that ran it passes what it
  /// measured (HIT-028).
  ///
  /// Throws an [ArgumentError] when the session is not over or has nothing
  /// completed. A day with no completed exercise is not a training day, and
  /// the rules refuse an entry with an empty list.
  Future<TrainingDayRecord> record({
    required String uid,
    required TrainingSession session,
    required CalendarDay today,
    required Duration elapsed,
  }) async {
    if (session.status != SessionStatus.completed) {
      throw ArgumentError.value(
        session.status.name,
        'session',
        'only a finished session is recorded',
      );
    }
    if (session.completedExerciseIds.isEmpty) {
      throw ArgumentError.value(
        session,
        'session',
        'a day with no completed exercise is not a training day',
      );
    }

    final TrainingSaveResult result = await _progress.saveTrainingCompletion(
      uid,
      TrainingCompletion(
        date: today,
        programDay: session.programDay,
        completedExerciseIds: session.completedExerciseIds,
        // Rounded up: a session of forty seconds took a minute of someone's
        // day, and a total that counts it as zero is the one number a user
        // can immediately tell is wrong.
        durationMinutes: elapsed.inSeconds <= 0
            ? 0
            : (elapsed.inSeconds / Duration.secondsPerMinute).ceil(),
      ),
    );

    if (result == TrainingSaveResult.alreadySaved) {
      // The day is already in the history, so its minutes, its programme day
      // and its streak were all counted with it.
      return TrainingDayRecord(
        result: result,
        programDay: await _progress.getCurrentProgramDay(uid),
        streak: null,
      );
    }

    final int programDay = await _progress.advanceProgramDay(
      uid,
      completedDay: session.programDay,
    );
    final StreakUpdate streak = await _progress.updateStreak(uid, today);

    return TrainingDayRecord(
      result: result,
      programDay: programDay,
      streak: streak,
    );
  }
}

/// Records finished training days.
final Provider<TrainingDayRecorder> trainingDayRecorderProvider =
    Provider<TrainingDayRecorder>(
  (Ref ref) => TrainingDayRecorder(ref.watch(userProgressRepositoryProvider)),
);
