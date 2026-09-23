import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/progress/domain/models/calendar_day.dart';
import 'package:hitup/features/progress/domain/models/training_history_entry.dart';
import 'package:hitup/features/progress/domain/repositories/user_progress_repository.dart';
import 'package:hitup/features/progress/domain/streak.dart';
import 'package:hitup/features/training/application/training_day_recorder.dart';
import 'package:hitup/features/training/domain/training_session.dart';

/// A progress repository that keeps state the way the real one does, so a
/// run that stops halfway can be retried and its result read back.
///
/// Each of the three steps can be made to fail once, standing in for the app
/// being killed or a transaction that could not reach the server.
class _FakeProgress implements UserProgressRepository {
  /// History entries by date, as they were saved.
  final Map<CalendarDay, TrainingCompletion> history =
      <CalendarDay, TrainingCompletion>{};

  int programDay = 4;
  int totalMinutes = 0;
  int currentStreak = 2;
  int longestStreak = 5;
  CalendarDay? lastTrainingDate;

  /// Writes that changed something, and every call in order.
  int writes = 0;
  final List<String> calls = <String>[];

  bool failSave = false;
  bool failAdvance = false;
  bool failStreak = false;

  @override
  Future<TrainingSaveResult> saveTrainingCompletion(
    String uid,
    TrainingCompletion completion,
  ) async {
    calls.add('save');
    if (failSave) {
      failSave = false;
      throw StateError('save failed');
    }
    if (history.containsKey(completion.date)) {
      return TrainingSaveResult.alreadySaved;
    }
    history[completion.date] = completion;
    totalMinutes += completion.durationMinutes;
    writes++;
    return TrainingSaveResult.saved;
  }

  @override
  Future<TrainingHistoryEntry?> getTrainingDay(
    String uid,
    CalendarDay date,
  ) async {
    calls.add('read entry');
    final TrainingCompletion? stored = history[date];
    return stored == null
        ? null
        : TrainingHistoryEntry(
            date: stored.date,
            programDay: stored.programDay,
            completedExerciseIds: stored.completedExerciseIds,
            durationMinutes: stored.durationMinutes,
            completedAt: null,
          );
  }

  @override
  Future<int> advanceProgramDay(String uid, {required int completedDay}) async {
    calls.add('advance $completedDay');
    if (failAdvance) {
      failAdvance = false;
      throw StateError('advance failed');
    }
    if (programDay == completedDay) {
      programDay++;
      writes++;
    }
    return programDay;
  }

  @override
  Future<StreakUpdate> updateStreak(String uid, CalendarDay today) async {
    calls.add('streak');
    if (failStreak) {
      failStreak = false;
      throw StateError('streak failed');
    }
    final StreakUpdate update = advanceStreak(
      today: today,
      lastTrainingDate: lastTrainingDate,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
    );
    if (update.changed) {
      currentStreak = update.currentStreak;
      longestStreak = update.longestStreak;
      lastTrainingDate = update.lastTrainingDate;
      writes++;
    }
    return update;
  }

  @override
  Future<int> getCurrentProgramDay(String uid) async {
    calls.add('read day');
    return programDay;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Says a day is already saved, then has no entry for it.
class _GoneAfterSave implements UserProgressRepository {
  final List<String> calls = <String>[];

  @override
  Future<TrainingSaveResult> saveTrainingCompletion(
    String uid,
    TrainingCompletion completion,
  ) async {
    calls.add('save');
    return TrainingSaveResult.alreadySaved;
  }

  @override
  Future<TrainingHistoryEntry?> getTrainingDay(
    String uid,
    CalendarDay date,
  ) async {
    calls.add('read entry');
    return null;
  }

  @override
  Future<int> getCurrentProgramDay(String uid) async {
    calls.add('read day');
    return 4;
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
    progress = _FakeProgress()..lastTrainingDate = today.previous;
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

      expect(progress.calls, <String>['save', 'advance 4', 'streak']);
      expect(progress.history[today]!.programDay, 4);
      expect(
        progress.history[today]!.completedExerciseIds,
        <String>['a', 'b'],
      );
      expect(progress.totalMinutes, 13);
      expect(progress.programDay, 5);
      expect(progress.currentStreak, 3);
      expect(progress.lastTrainingDate, today);
      expect(result.wasRecorded, isTrue);
      expect(result.programDay, 5);
      expect(result.streak!.currentStreak, 3);
    });

    test('only the completed exercises are recorded', () async {
      await record(session: _finished(completed: <String>['a']));

      expect(progress.history[today]!.completedExerciseIds, <String>['a']);
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
        progress.history.clear();
        await record(elapsed: elapsed);
        expect(
          progress.history[today]!.durationMinutes,
          minutes,
          reason: '${elapsed.inSeconds}s',
        );
      }
    });
  });

  group('a day left half-recorded is finished on retry (HIT-100)', () {
    test('step 2 failed: the retry advances the day and counts the streak',
        () async {
      progress.failAdvance = true;
      await expectLater(record(), throwsA(isA<StateError>()));

      // The entry is there, the rest is not.
      expect(progress.history.containsKey(today), isTrue);
      expect(progress.programDay, 4);
      expect(progress.currentStreak, 2);

      final TrainingDayRecord retry = await record();

      expect(retry.wasRecorded, isFalse);
      expect(progress.programDay, 5);
      expect(progress.currentStreak, 3);
      expect(progress.lastTrainingDate, today);
      expect(retry.programDay, 5);
      expect(retry.streak!.currentStreak, 3);
      // The minutes were counted once, with the entry.
      expect(progress.totalMinutes, 13);
    });

    test(
        'step 3 failed: the retry counts the streak and does not advance '
        'the day twice', () async {
      progress.failStreak = true;
      await expectLater(record(), throwsA(isA<StateError>()));

      expect(progress.programDay, 5);
      expect(progress.currentStreak, 2);

      await record();

      expect(progress.programDay, 5, reason: 'advanced once, not twice');
      expect(progress.currentStreak, 3);
      expect(progress.lastTrainingDate, today);
    });

    test("the retry uses the stored day, not the new session's", () async {
      // Day 4 trained this morning and fully recorded. Day 5 trained this
      // evening on the same date: there is one entry per date, so day 5 has
      // no entry of its own and must not move the user past it.
      await record();
      expect(progress.programDay, 5);

      final TrainingDayRecord second = await record(
        session: _finished(programDay: 5),
      );

      expect(progress.calls.where((String c) => c == 'advance 5'), isEmpty);
      expect(
        progress.calls.where((String c) => c == 'advance 4'),
        hasLength(2),
      );
      expect(progress.programDay, 5);
      expect(second.programDay, 5);
      expect(progress.history[today]!.programDay, 4);
    });

    test('a fully recorded day completed again writes nothing', () async {
      await record();
      final int writesAfterFirst = progress.writes;

      final TrainingDayRecord again = await record();

      expect(progress.writes, writesAfterFirst);
      expect(again.wasRecorded, isFalse);
      expect(again.streak!.changed, isFalse);
      expect(progress.programDay, 5);
      expect(progress.currentStreak, 3);
      expect(progress.totalMinutes, 13);
    });

    test('an entry refused as saved but gone on the server ends quietly',
        () async {
      // Refused as already there, then deleted before it could be read back.
      // There is no day to finish recording, so nothing moves.
      final _GoneAfterSave gone = _GoneAfterSave();
      final TrainingDayRecord result = await TrainingDayRecorder(gone).record(
        uid: 'uid-1',
        session: _finished(),
        today: today,
        elapsed: const Duration(minutes: 13),
      );

      expect(result.wasRecorded, isFalse);
      expect(result.streak, isNull);
      expect(result.programDay, 4);
      expect(gone.calls, <String>['save', 'read entry', 'read day']);
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
      await expectLater(
        record(session: _finished(completed: const <String>[])),
        throwsArgumentError,
      );
      expect(progress.calls, isEmpty);
    });
  });

  group('when the first write fails', () {
    test('nothing after it runs', () async {
      // The programme day and the streak would otherwise say a day was
      // trained that was never recorded.
      progress.failSave = true;

      await expectLater(record(), throwsA(isA<StateError>()));
      expect(progress.calls, <String>['save']);
      expect(progress.programDay, 4);
      expect(progress.currentStreak, 2);
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
