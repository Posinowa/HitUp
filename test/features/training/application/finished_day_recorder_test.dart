import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/progress/domain/models/calendar_day.dart';
import 'package:hitup/features/progress/domain/models/training_history_entry.dart';
import 'package:hitup/features/progress/domain/streak.dart';
import 'package:hitup/features/training/application/finished_day_recorder.dart';
import 'package:hitup/features/training/application/training_day_recorder.dart';
import 'package:hitup/features/training/data/pending_day_store.dart';
import 'package:hitup/features/training/domain/training_session.dart';
import 'package:hitup/shared/providers/auth_providers.dart';

/// Pending days in memory, with the store's rules: oldest first, the first
/// session of a date kept.
class _MemoryStore implements PendingDayStore {
  final List<PendingDay> days = <PendingDay>[];
  bool failRemove = false;

  @override
  Future<List<PendingDay>> load() async => List<PendingDay>.of(days)
    ..sort((PendingDay a, PendingDay b) => a.date.compareTo(b.date));

  @override
  Future<void> add(PendingDay day) async {
    if (!days.any(day.isSameDayAs)) {
      days.add(day);
    }
  }

  @override
  Future<void> remove(PendingDay day) async {
    if (failRemove) {
      throw StateError('remove failed');
    }
    days.removeWhere(day.isSameDayAs);
  }
}

/// Records the dates it was asked for, in order.
class _FakeRecorder implements TrainingDayRecorder {
  final List<(String, CalendarDay, int)> calls = <(String, CalendarDay, int)>[];

  /// Dates whose recording throws once.
  final Set<CalendarDay> failOn = <CalendarDay>{};

  /// When set, every call waits for it.
  Completer<void>? gate;

  @override
  Future<TrainingDayRecord> record({
    required String uid,
    required TrainingSession session,
    required CalendarDay today,
    required Duration elapsed,
  }) async {
    calls.add((uid, today, session.programDay));
    await gate?.future;
    if (failOn.remove(today)) {
      throw StateError('record failed');
    }
    return TrainingDayRecord(
      result: TrainingSaveResult.saved,
      programDay: session.programDay + 1,
      streak: StreakUpdate(
        currentStreak: today.day,
        longestStreak: today.day,
        lastTrainingDate: today,
        changed: true,
      ),
    );
  }
}

PendingDay _day(int dayOfMonth, {String uid = 'uid-1', int programDay = 4}) =>
    PendingDay(
      uid: uid,
      session: TrainingSession(
        programDay: programDay,
        exerciseIds: const <String>['a'],
        status: SessionStatus.completed,
        currentIndex: 0,
        completedExerciseIds: const <String>['a'],
      ),
      date: CalendarDay(2026, 9, dayOfMonth),
      elapsed: const Duration(minutes: 5),
    );

void main() {
  late _MemoryStore store;
  late _FakeRecorder recorder;
  late FinishedDayRecorder finished;

  setUp(() {
    store = _MemoryStore();
    recorder = _FakeRecorder();
    finished = FinishedDayRecorder(recorder: recorder, store: store);
  });

  List<int> recordedDates() =>
      recorder.calls.map(((String, CalendarDay, int) c) => c.$2.day).toList();

  group('recording a finished day', () {
    test('records it under its own date and forgets it', () async {
      final TrainingDayRecord record = await finished.record(_day(18));

      expect(recorder.calls, <(String, CalendarDay, int)>[
        ('uid-1', CalendarDay(2026, 9, 18), 4),
      ]);
      expect(record.streak!.lastTrainingDate, CalendarDay(2026, 9, 18));
      expect(store.days, isEmpty);
    });

    test('keeps it on the device when the recording fails', () async {
      recorder.failOn.add(CalendarDay(2026, 9, 18));

      await expectLater(finished.record(_day(18)), throwsStateError);

      expect(store.days, <PendingDay>[_day(18)]);
    });

    test("records the account's older pending days first, oldest first",
        () async {
      store.days.addAll(<PendingDay>[_day(16), _day(14)]);

      final TrainingDayRecord record = await finished.record(_day(18));

      expect(recordedDates(), <int>[14, 16, 18]);
      // What this call returns is its own day's recording.
      expect(record.streak!.lastTrainingDate, CalendarDay(2026, 9, 18));
      expect(store.days, isEmpty);
    });

    test("leaves another account's days alone", () async {
      store.days.add(_day(16, uid: 'uid-2'));

      await finished.record(_day(18));

      expect(recordedDates(), <int>[18]);
      expect(store.days, <PendingDay>[_day(16, uid: 'uid-2')]);
    });

    test('an older day failing stops there and keeps both', () async {
      store.days.add(_day(16));
      recorder.failOn.add(CalendarDay(2026, 9, 16));

      await expectLater(finished.record(_day(18)), throwsStateError);

      expect(recordedDates(), <int>[16]);
      expect(store.days, containsAll(<PendingDay>[_day(16), _day(18)]));

      // Tried again, both go through, in order.
      await finished.record(_day(18));
      expect(recordedDates(), <int>[16, 16, 18]);
      expect(store.days, isEmpty);
    });

    test(
        'a second session on a pending date records the first, as the '
        'account would', () async {
      store.days.add(_day(18, programDay: 4));

      await finished.record(_day(18, programDay: 5));

      expect(recorder.calls.single.$3, 4);
      expect(store.days, isEmpty);
    });

    test('a day that cannot be forgotten is still reported as recorded',
        () async {
      store.failRemove = true;

      final TrainingDayRecord record = await finished.record(_day(18));

      expect(record.wasRecorded, isTrue);
      // Left pending, to be recorded again, which the recorder treats as
      // already done.
      expect(store.days, <PendingDay>[_day(18)]);
    });
  });

  group('recording what an earlier run left', () {
    test("records every one of the account's days, oldest first", () async {
      store.days.addAll(<PendingDay>[
        _day(17),
        _day(15),
        _day(16, uid: 'uid-2'),
      ]);

      final List<TrainingDayRecord> records =
          await finished.recordPending('uid-1');

      expect(recordedDates(), <int>[15, 17]);
      expect(
        records.map((TrainingDayRecord r) => r.streak!.lastTrainingDate.day),
        <int>[15, 17],
      );
      expect(store.days, <PendingDay>[_day(16, uid: 'uid-2')]);
    });

    test('with nothing left, records nothing', () async {
      expect(await finished.recordPending('uid-1'), isEmpty);
      expect(recorder.calls, isEmpty);
    });
  });

  group('one call at a time', () {
    test('a second call waits for the first, so no day is recorded twice',
        () async {
      recorder.gate = Completer<void>();

      final Future<TrainingDayRecord> first = finished.record(_day(17));
      await pumpEventQueue();
      final Future<TrainingDayRecord> second = finished.record(_day(18));
      await pumpEventQueue();

      // The second has not even been kept yet: it would otherwise be read,
      // and recorded, by the first.
      expect(store.days, <PendingDay>[_day(17)]);

      recorder.gate!.complete();
      await Future.wait(<Future<TrainingDayRecord>>[first, second]);

      expect(recordedDates(), <int>[17, 18]);
      expect(store.days, isEmpty);
    });

    test('a failed call does not stop the next', () async {
      recorder.failOn.add(CalendarDay(2026, 9, 17));

      final Future<TrainingDayRecord> first = finished.record(_day(17));
      final Future<List<TrainingDayRecord>> second =
          finished.recordPending('uid-1');

      await expectLater(first, throwsStateError);
      expect(await second, hasLength(1));
      expect(store.days, isEmpty);
    });
  });

  group('when someone signs in', () {
    late StreamController<AuthUser?> auth;
    late ProviderContainer container;
    late bool recorderBuilt;

    setUp(() {
      auth = StreamController<AuthUser?>.broadcast();
      addTearDown(auth.close);
      recorderBuilt = false;
      container = ProviderContainer(
        overrides: <Override>[
          authStateChangesProvider.overrideWith((Ref ref) => auth.stream),
          pendingDayStoreProvider.overrideWithValue(store),
          trainingDayRecorderProvider.overrideWith((Ref ref) {
            recorderBuilt = true;
            return recorder;
          }),
        ],
      );
      addTearDown(container.dispose);
      container.listen(pendingDaysProvider, (_, __) {});
    });

    Future<List<TrainingDayRecord>> settle() async {
      await pumpEventQueue();
      return container.read(pendingDaysProvider.future);
    }

    test("records that account's pending days", () async {
      store.days.addAll(<PendingDay>[_day(16), _day(15)]);

      auth.add(const AuthUser(uid: 'uid-1'));

      expect(await settle(), hasLength(2));
      expect(recordedDates(), <int>[15, 16]);
      expect(store.days, isEmpty);
    });

    test(
        'with nothing pending for the account, does not reach the account '
        'at all', () async {
      store.days.add(_day(16, uid: 'uid-2'));

      auth.add(const AuthUser(uid: 'uid-1'));

      expect(await settle(), isEmpty);
      expect(recorderBuilt, isFalse);
      expect(store.days, hasLength(1));
    });

    test('signed out, records nothing', () async {
      store.days.add(_day(16));

      auth.add(null);

      expect(await settle(), isEmpty);
      expect(recorder.calls, isEmpty);
    });

    test('runs again for the next account', () async {
      store.days.addAll(<PendingDay>[_day(15), _day(16, uid: 'uid-2')]);

      auth.add(const AuthUser(uid: 'uid-1'));
      await settle();
      auth.add(const AuthUser(uid: 'uid-2'));
      await settle();

      expect(
        recorder.calls.map(((String, CalendarDay, int) c) => c.$1),
        <String>['uid-1', 'uid-2'],
      );
      expect(store.days, isEmpty);
    });

    test('a failure is held, and the days stay pending', () async {
      store.days.add(_day(16));
      recorder.failOn.add(CalendarDay(2026, 9, 16));

      auth.add(const AuthUser(uid: 'uid-1'));
      await pumpEventQueue();

      expect(container.read(pendingDaysProvider).hasError, isTrue);
      expect(store.days, <PendingDay>[_day(16)]);
    });
  });
}
