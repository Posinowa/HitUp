import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/failure_code.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../progress/domain/repositories/user_progress_repository.dart';
import 'models/models.dart';
import 'repositories/curriculum_repository.dart';

/// Builds today's training from the programme and the user's day (HIT-025).
///
/// Two inputs, no state: the bundled curriculum (`CurriculumRepository`) and
/// the day the user is on (`UserProgressRepository`). Same inputs, same
/// result; nothing here invents or shuffles content.
///
/// **There is no catch-up.** The day advances when a day is completed
/// (HIT-053), not when the calendar turns, so a user who misses a week returns
/// to the day they were on. Nothing is skipped and nothing piles up.
///
/// **When the programme is over**, that is `currentProgramDay` past the last
/// day, the result is [TodayTraining.programFinished]: no exercises, and
/// `isProgramFinished` true for the screen to act on. The engine does not loop
/// back to day one and does not repeat the last day, because either would tell
/// the user they have training left when they do not.
///
/// **Offline.** The programme is local, so it is always readable. The user's
/// day is not: before a first sync there is nothing cached. The engine then
/// assumes day one and marks it with `programDayAssumed`, so the app can start
/// rather than showing an error where a day should be. Any other failure, a
/// refusal or a malformed document, is thrown.
class TodayTrainingEngine {
  /// Creates an engine over the curriculum and the user's progress.
  const TodayTrainingEngine({
    required CurriculumRepository curriculum,
    required UserProgressRepository progress,
  })  : _curriculum = curriculum,
        _progress = progress;

  /// The day assumed when the user's own day cannot be read.
  static const int fallbackProgramDay = 1;

  final CurriculumRepository _curriculum;
  final UserProgressRepository _progress;

  /// Today's training for the user [uid].
  Future<TodayTraining> todayFor(String uid) async {
    final TrainingProgram program = await _curriculum.loadProgram();
    final ExerciseLibrary library = await _curriculum.loadExercises();
    final (int day, bool assumed) = await _programDay(uid);
    return build(
      programDay: day,
      program: program,
      library: library,
      programDayAssumed: assumed,
    );
  }

  /// Today's training from values already in hand.
  ///
  /// The whole decision, with nothing to await, which is what makes every case
  /// below testable from fixtures.
  TodayTraining build({
    required int programDay,
    required TrainingProgram program,
    required ExerciseLibrary library,
    bool programDayAssumed = false,
  }) {
    // A programme with no days is not a finished programme, it is a content
    // file that failed to deliver one. Checked before anything else, because
    // "past the last day" would otherwise be true of every day.
    if (program.days.isEmpty) {
      throw const AppException(
        'The programme has no days',
        code: FailureCode.contentMalformed,
      );
    }

    // A day below one cannot be trained. The rules allow 0 in a profile, and
    // the model says a new account starts at 1, so 0 means an old or odd
    // document rather than a state with its own meaning: start at day one.
    final int day = programDay < 1 ? 1 : programDay;

    if (day > program.lastDay) {
      return TodayTraining.programFinished(
        programDay: day,
        programDayAssumed: programDayAssumed,
      );
    }

    final ProgramDay? plan = program.dayFor(day);
    if (plan == null) {
      // Within the programme's range but absent: the programme file has a hole
      // in it. Reported as content, because no user action can fix it and the
      // curriculum test is what should have caught it.
      throw AppException(
        'The programme has no day $day, though it runs to ${program.lastDay}',
        code: FailureCode.contentMalformed,
      );
    }

    return TodayTraining(
      programDay: day,
      day: plan,
      resolved: plan.resolve(library),
      programDayAssumed: programDayAssumed,
    );
  }

  /// The user's day, and whether it had to be assumed.
  Future<(int, bool)> _programDay(String uid) async {
    try {
      return (await _progress.getCurrentProgramDay(uid), false);
    } catch (error) {
      final Failure failure = mapErrorToFailure(error);
      if (failure is NetworkFailure) {
        return (fallbackProgramDay, true);
      }
      rethrow;
    }
  }
}
