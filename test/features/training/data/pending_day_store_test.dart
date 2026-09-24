import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/progress/domain/models/calendar_day.dart';
import 'package:hitup/features/training/data/pending_day_store.dart';
import 'package:hitup/features/training/domain/training_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

TrainingSession _session({int programDay = 4}) => TrainingSession(
      programDay: programDay,
      exerciseIds: const <String>['a', 'b'],
      status: SessionStatus.completed,
      currentIndex: 1,
      completedExerciseIds: const <String>['a'],
    );

PendingDay _day(
  int dayOfMonth, {
  String uid = 'uid-1',
  int programDay = 4,
  int seconds = 90,
}) =>
    PendingDay(
      uid: uid,
      session: _session(programDay: programDay),
      date: CalendarDay(2026, 9, dayOfMonth),
      elapsed: Duration(seconds: seconds),
    );

void main() {
  const PreferencesPendingDayStore store = PreferencesPendingDayStore();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('the device copy', () {
    test('is empty when nothing was kept', () async {
      expect(await store.load(), isEmpty);
    });

    test('reads back what was kept, every field', () async {
      await store.add(_day(18, seconds: 754));

      expect(await store.load(), <PendingDay>[_day(18, seconds: 754)]);
    });

    test('reads oldest first, whatever order the days were kept in', () async {
      await store.add(_day(18));
      await store.add(_day(16));
      await store.add(_day(17));

      expect(
        (await store.load()).map((PendingDay d) => d.date.day),
        <int>[16, 17, 18],
      );
    });

    test('keeps the first session of a date, as the account does', () async {
      await store.add(_day(18, programDay: 4));
      await store.add(_day(18, programDay: 5));

      expect(await store.load(), <PendingDay>[_day(18, programDay: 4)]);
    });

    test("keeps two accounts' days on the same date apart", () async {
      await store.add(_day(18));
      await store.add(_day(18, uid: 'uid-2'));

      expect(await store.load(), hasLength(2));
    });

    test("forgets only that account's day on that date", () async {
      await store.add(_day(17));
      await store.add(_day(18));
      await store.add(_day(18, uid: 'uid-2'));

      // A different session on the same date still names the same day.
      await store.remove(_day(18, programDay: 9));

      expect(await store.load(), <PendingDay>[
        _day(17),
        _day(18, uid: 'uid-2'),
      ]);
    });

    test('leaves nothing behind once the last day is forgotten', () async {
      await store.add(_day(18));
      await store.remove(_day(18));

      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      expect(preferences.containsKey(PreferencesPendingDayStore.key), isFalse);
    });

    test('reads what it cannot make sense of as nothing', () async {
      for (final String saved in <String>[
        'not json',
        '{"a": 1}',
        '[1]',
        jsonEncode(<Object>[
          <String, Object>{'uid': 'uid-1'},
        ]),
      ]) {
        SharedPreferences.setMockInitialValues(<String, Object>{
          PreferencesPendingDayStore.key: saved,
        });
        expect(await store.load(), isEmpty, reason: saved);
      }
    });
  });

  group('the stored form', () {
    Map<String, dynamic> stored(PendingDay day) =>
        jsonDecode(jsonEncode(pendingDayToJson(day))) as Map<String, dynamic>;

    test('round-trips', () {
      expect(
        pendingDayFromJson(stored(_day(18, seconds: 61))),
        _day(18, seconds: 61),
      );
    });

    test('keeps the date as the day it names, not a moment', () {
      expect(stored(_day(8))['date'], '2026-09-08');
    });

    test('refuses a day with no account, negative time or no real date', () {
      for (final MapEntry<String, Object> broken in <MapEntry<String, Object>>[
        const MapEntry<String, Object>('uid', ''),
        const MapEntry<String, Object>('elapsedSeconds', -1),
        const MapEntry<String, Object>('date', '2026-02-30'),
        const MapEntry<String, Object>('session', 'x'),
      ]) {
        final Map<String, dynamic> json = stored(_day(18))
          ..[broken.key] = broken.value;
        expect(
          () => pendingDayFromJson(json),
          throwsFormatException,
          reason: broken.key,
        );
      }
    });
  });

  test('two pending days are the same day by account and date alone', () {
    expect(_day(18).isSameDayAs(_day(18, programDay: 7, seconds: 5)), isTrue);
    expect(_day(18).isSameDayAs(_day(17)), isFalse);
    expect(_day(18).isSameDayAs(_day(18, uid: 'uid-2')), isFalse);
    expect(_day(18), isNot(_day(18, seconds: 5)));
    expect(_day(18).hashCode, _day(18).hashCode);
    expect(_day(18).toString(), contains('2026-09-18'));
  });
}
