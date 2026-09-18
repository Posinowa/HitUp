import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/progress/domain/models/calendar_day.dart';
import 'package:hitup/features/progress/domain/models/training_history_entry.dart';
import 'package:hitup/features/progress/domain/repositories/user_progress_repository.dart';
import 'package:hitup/features/progress/domain/streak.dart';
import 'package:hitup/features/training/application/training_day_recorder.dart';
import 'package:hitup/features/training/domain/training_session.dart';

/// A progress repository that records the order it was called in.
class _FakeProgress implements UserProgressRepository {
  TrainingSaveResult saveResult = TrainingSaveResult.saved;
  Object? saveError;
  int programDay = 4;
  TrainingCompletion? saved;
  int? advancedFrom;
  CalendarDay? streakDay;

  /// Every call, in order, so a test can check what ran and what did not.
  final List<String> calls = <String>[];

  @override
  Future<TrainingSaveResult> saveTrainingCompletion(
    String uid,
    TrainingCompletion completion,
  ) async {
    calls.add('save');
    saved = completion;
    if (saveError != null) {
      throw saveError!;
    }
    return saveResult;
  }

  @override
  Future<int> advanceProgramDay(String uid, {required int completedDay}) async {
    calls.add('advance');
    advancedFrom = completedDay;
    return programDay + 1;
  }

  @override
  Future<StreakUpdate> updateStreak(String uid, CalendarDay today) async {
    calls.add('streak');
    streakDay = today;
    return StreakUpdate(
      currentStreak: 3,
      longestStreak: 5,
      lastTrainingDate: today,
      changed: true,
    );
  }

  @override
  Future<int> getCurrentProgramDay(String uid) async {
    calls.add('read day');
    return programDay;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

TrainingSession _finished({
  List<String> completed = const <String>['a', 'b'],
  int programDay = 4,
}) =>
    TrainingSession(
      programDay: programDay,
      exerciseIds: const <String>['a', 'b'],
      status: SessionStatus.completed,
      currentIndex: 1,
      completedExerciseIds: completed,
    );

void main() {
  final CalendarDay today = CalendarDay(2026, 9, 18);
  late _FakeProgress progress;
  late TrainingDayRecorder recorder;

  setUp(() {
    progress = _FakeProgress();
    recorder = TrainingDayRecorder(progress);
  });

  Future<TrainingDayRecord> record({
    TrainingSession? session,
    Duration elapsed = const Duration(minutes: 13),
  }) =>
      recorder.record(
        uid: 'uid-1',
        session: session ?? _finished(),
        today: today,
        elapsed: elapsed,
      );

  group('recording a finished day', () {
    test('writes the day, moves the programme on, counts the streak', () async {
      final TrainingDayRecord result = await record();

      expect(progress.calls, <String>['save', 'advance', 'streak']);
      expect(progress.saved!.date, today);
      expect(progress.saved!.programDay, 4);
      expect(progress.saved!.completedExerciseIds, <String>['a', 'b']);
      expect(progress.saved!.durationMinutes, 13);
      expect(progress.advancedFrom, 4);
      expect(progress.streakDay, today);
      expect(result.wasRecorded, isTrue);
      expect(result.programDay, 5);
      expect(result.streak!.currentStreak, 3);
    });

    test('only the completed exercises are recorded', () async {
      await record(session: _finished(completed: <String>['a']));

      expect(progress.saved!.completedExerciseIds, <String>['a']);
    });

    test('minutes are rounded up, because a short session still took one',
        () async {
      for (final (Duration elapsed, int minutes) in const <(Duration, int)>[
        (Duration.zero, 0),
        (Duration(seconds: 1), 1),
        (Duration(seconds: 40), 1),
        (Duration(seconds: 60), 1),
        (Duration(seconds: 61), 2),
        (Duration(minutes: 13, seconds: 20), 14),
      ]) {
        await record(elapsed: elapsed);
        expect(
          progress.saved!.durationMinutes,
          minutes,
          reason: '${elapsed.inSeconds}s',
        );
      }
    });
  });

  group('a day that was already recorded', () {
    setUp(() => progress.saveResult = TrainingSaveResult.alreadySaved);

    test('is not counted a second time', () async {
      // Its minutes, its programme day and its streak all went in with it.
      final TrainingDayRecord result = await record();

      expect(progress.calls, <String>['save', 'read day']);
      expect(result.wasRecorded, isFalse);
      expect(result.streak, isNull);
      expect(result.programDay, 4);
    });
  });

  group('what is refused', () {
    test('a session that is not over', () async {
      for (final SessionStatus status in <SessionStatus>[
        SessionStatus.notStarted,
        SessionStatus.inProgress,
        SessionStatus.paused,
      ]) {
        await expectLater(
          record(
            session: TrainingSession(
              programDay: 4,
              exerciseIds: const <String>['a'],
              status: status,
              currentIndex: 0,
              completedExerciseIds: const <String>['a'],
            ),
          ),
          throwsArgumentError,
          reason: status.name,
        );
      }
      expect(progress.calls, isEmpty);
    });

    test('a day where nothing was completed', () async {
      // Skipping everything is not a training day, and the rules refuse an
      // entry with an empty list anyway.
      await expectLater(
        record(session: _finished(completed: const <String>[])),
        throwsArgumentError,
      );
      expect(progress.calls, isEmpty);
    });
  });

  group('when a write fails', () {
    test('the day failing stops the rest', () async {
      // Nothing after the history entry may run: the programme day and the
      // streak would then say a day was trained that was never recorded.
      progress.saveError = StateError('no network');

      await expectLater(record(), throwsA(isA<StateError>()));
      expect(progress.calls, <String>['save']);
    });
  });

  group('the record as a value', () {
    test('compares by every field and prints what happened', () {
      TrainingDayRecord result({int day = 5}) => TrainingDayRecord(
            result: TrainingSaveResult.saved,
            programDay: day,
            streak: StreakUpdate(
              currentStreak: 1,
              longestStreak: 1,
              lastTrainingDate: today,
              changed: true,
            ),
          );

      expect(result(), result());
      expect(result().hashCode, result().hashCode);
      expect(result(day: 6), isNot(result()));
      expect(result().toString(), contains('saved'));
      expect(result().toString(), contains('day 5'));
    });
  });
}
