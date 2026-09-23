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

  /// The streak after the day was counted.
  ///
  /// Present on every call that found a day to record, including a repeat,
  /// where it comes back unchanged. Null only when the entry the save refused
  /// as already there turned out to be gone.
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
/// 2. **The programme day**, moved on only if the user is still on the day
///    recorded in step 1.
/// 3. **The streak**, counted for that day.
///
/// They are three operations rather than one, because Firestore has no
/// transaction across a batch and two read-decide-writes. So a run can stop
/// between them: the app is killed, or step 2 or 3 fails, and both are
/// transactions, which need the server.
///
/// **What makes that safe is that steps 2 and 3 run again** every time the
/// day is recorded, including when step 1 finds it already recorded (HIT-100).
/// Both are idempotent, so on a day that was fully recorded they write
/// nothing, and on a day left half-recorded they finish the job:
///
/// - The programme day advances only if the user is still on the stored
///   entry's day, so it cannot advance twice.
/// - The streak counts a day it has already counted as no change.
///
/// Step 2 reads the programme day from the **stored** entry, not from the
/// session. A second session on a date that is already recorded would
/// otherwise advance a day that has no history entry of its own
/// (`USER_PROGRESS.md`).
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

    // The programme day this date is recorded under. For a new entry that is
    // the session's; for one already there it is whatever was stored, which
    // may be a different session's if the user trained twice today.
    int recordedDay = session.programDay;
    if (result == TrainingSaveResult.alreadySaved) {
      final TrainingHistoryEntry? stored = await _progress.getTrainingDay(
        uid,
        today,
      );
      if (stored == null) {
        // Refused as already saved, yet the server has no entry: it was
        // deleted in between. There is no day to finish recording.
        return TrainingDayRecord(
          result: result,
          programDay: await _progress.getCurrentProgramDay(uid),
          streak: null,
        );
      }
      recordedDay = stored.programDay;
    }

    // Run on every call, not only the first. On a fully recorded day both
    // are no-ops; on a half-recorded one they are what finishes it.
    final int programDay = await _progress.advanceProgramDay(
      uid,
      completedDay: recordedDay,
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
