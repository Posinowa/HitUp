import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/progress/domain/models/calendar_day.dart';
import 'package:hitup/features/progress/domain/models/exercise_progress.dart';
import 'package:hitup/features/progress/domain/models/training_history_entry.dart';
import 'package:hitup/features/progress/domain/models/user_preferences.dart';
import 'package:hitup/features/progress/domain/models/user_profile.dart';

void main() {
  group('CalendarDay', () {
    test('reads and writes the stored yyyy-MM-dd form', () {
      final CalendarDay day = CalendarDay.parse('2026-09-07');
      expect(day.year, 2026);
      expect(day.month, 9);
      expect(day.day, 7);
      expect(day.key, '2026-09-07');
      expect(CalendarDay(987, 1, 2).key, '0987-01-02');
    });

    test('refuses a day that does not exist instead of rolling over', () {
      expect(() => CalendarDay(2026, 2, 29), throwsArgumentError);
      expect(() => CalendarDay(2026, 13, 1), throwsArgumentError);
      expect(() => CalendarDay(2026, 4, 31), throwsArgumentError);
      expect(CalendarDay(2028, 2, 29).key, '2028-02-29');
    });

    test('parse refuses every other shape, and impossible days', () {
      for (final String bad in <String>[
        '',
        '2026-9-07',
        '2026-09-7',
        '26-09-07',
        '2026/09/07',
        '2026-09-07T00:00',
        ' 2026-09-07',
        '2026-02-30',
        '2026-00-10',
      ]) {
        expect(
          () => CalendarDay.parse(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('a moment is placed on the local calendar, not the UTC one', () {
      // Near midnight on the side where UTC is already another day. East of
      // UTC that is just after midnight, west of it just before. A machine on
      // UTC itself has no such moment, so there the two calendars agree.
      final Duration offset = DateTime(2026, 9, 7, 12).timeZoneOffset;
      final DateTime local = offset.isNegative
          ? DateTime(2026, 9, 7, 23, 30)
          : DateTime(2026, 9, 7, 0, 30);
      expect(CalendarDay.fromDateTime(local), CalendarDay(2026, 9, 7));
      expect(CalendarDay.fromDateTime(local.toUtc()), CalendarDay(2026, 9, 7));
      if (offset != Duration.zero) {
        final DateTime utc = local.toUtc();
        expect(
          CalendarDay(utc.year, utc.month, utc.day),
          isNot(CalendarDay(2026, 9, 7)),
          reason: 'the chosen moment must fall on another day in UTC',
        );
      }
    });

    test('orders by date and compares by value', () {
      final List<CalendarDay> days = <CalendarDay>[
        CalendarDay(2026, 10, 1),
        CalendarDay(2025, 12, 31),
        CalendarDay(2026, 9, 30),
      ]..sort();
      expect(days.map((CalendarDay d) => d.key), <String>[
        '2025-12-31',
        '2026-09-30',
        '2026-10-01',
      ]);
      expect(CalendarDay(2026, 9, 7), CalendarDay.parse('2026-09-07'));
      expect(
        CalendarDay(2026, 9, 7).hashCode,
        CalendarDay.parse('2026-09-07').hashCode,
      );
      expect(CalendarDay(2026, 9, 7), isNot(CalendarDay(2026, 9, 8)));
    });
  });

  group('ReminderTime', () {
    test('reads and writes the stored HH:mm form', () {
      expect(ReminderTime.parse('07:05'), ReminderTime(7, 5));
      expect(ReminderTime(19, 30).key, '19:30');
      expect(ReminderTime(0, 0).key, '00:00');
    });

    test('refuses what the rules refuse', () {
      for (final String bad in <String>['24:00', '7:05', '07:60', '0705', '']) {
        expect(
          () => ReminderTime.parse(bad),
          throwsFormatException,
          reason: bad,
        );
      }
      expect(() => ReminderTime(24, 0), throwsArgumentError);
      expect(() => ReminderTime(12, -1), throwsArgumentError);
    });
  });

  group('value equality', () {
    // Built at run time, so equal values are separate instances.
    DateTime at() => DateTime.utc(2026, 9, 7, 9);

    test('profiles compare by every field', () {
      UserProfile profile({int streak = 2, CalendarDay? last}) => UserProfile(
            uid: 'u',
            displayName: 'Ada',
            email: 'ada@example.com',
            createdAt: at(),
            currentProgramDay: 3,
            totalTrainingMinutes: 40,
            currentStreak: streak,
            longestStreak: 5,
            lastTrainingDate: last,
          );
      expect(profile(), profile());
      expect(profile().hashCode, profile().hashCode);
      expect(profile(streak: 3), isNot(profile()));
      expect(profile(last: CalendarDay(2026, 9, 7)), isNot(profile()));
      expect(profile().hasNeverTrained, isTrue);
      expect(profile(last: CalendarDay(2026, 9, 7)).hasNeverTrained, isFalse);
    });

    test('a profile prints as its uid, without email or name', () {
      final String text = const UserProfile(
        uid: 'uid-7',
        displayName: 'Ada',
        email: 'ada@example.com',
        createdAt: null,
        currentProgramDay: 1,
        totalTrainingMinutes: 0,
        currentStreak: 0,
        longestStreak: 0,
        lastTrainingDate: null,
      ).toString();
      expect(text, contains('uid-7'));
      expect(text, isNot(contains('Ada')));
      expect(text, isNot(contains('example.com')));
    });

    test('history entries and completions compare their exercise lists', () {
      TrainingHistoryEntry entry(List<String> ids) => TrainingHistoryEntry(
            date: CalendarDay(2026, 9, 7),
            programDay: 1,
            completedExerciseIds: ids,
            durationMinutes: 10,
            completedAt: at(),
          );
      expect(entry(<String>['a', 'b']), entry(<String>['a', 'b']));
      expect(
        entry(<String>['a', 'b']).hashCode,
        entry(<String>['a', 'b']).hashCode,
      );
      expect(entry(<String>['a', 'b']), isNot(entry(<String>['b', 'a'])));

      TrainingCompletion completion(List<String> ids) => TrainingCompletion(
            date: CalendarDay(2026, 9, 7),
            programDay: 1,
            completedExerciseIds: ids,
            durationMinutes: 10,
          );
      expect(completion(<String>['a']), completion(<String>['a']));
      expect(completion(<String>['a']), isNot(completion(<String>['b'])));
    });

    test('exercise progress compares by every field', () {
      ExerciseProgress progress(int count) => ExerciseProgress(
            exerciseId: 'a',
            completionCount: count,
            lastCompletedAt: at(),
          );
      expect(progress(2), progress(2));
      expect(progress(2).hashCode, progress(2).hashCode);
      expect(progress(2), isNot(progress(3)));
    });

    test('history entries and completions hash their exercise lists alike', () {
      TrainingCompletion completion(List<String> ids) => TrainingCompletion(
            date: CalendarDay(2026, 9, 7),
            programDay: 1,
            completedExerciseIds: ids,
            durationMinutes: 10,
          );
      expect(
        completion(<String>['a', 'b']).hashCode,
        completion(<String>['a', 'b']).hashCode,
      );
    });

    test('values print what identifies them, and no more', () {
      expect(
        TrainingHistoryEntry(
          date: CalendarDay(2026, 9, 7),
          programDay: 4,
          completedExerciseIds: const <String>['a'],
          durationMinutes: 10,
          completedAt: null,
        ).toString(),
        'TrainingHistoryEntry(2026-09-07, day 4)',
      );
      expect(
        TrainingCompletion(
          date: CalendarDay(2026, 9, 7),
          programDay: 4,
          completedExerciseIds: const <String>['a'],
          durationMinutes: 10,
        ).toString(),
        'TrainingCompletion(2026-09-07, day 4)',
      );
      expect(
        const ExerciseProgress(
          exerciseId: 'letter_i_01',
          completionCount: 6,
          lastCompletedAt: null,
        ).toString(),
        'ExerciseProgress(letter_i_01, 6)',
      );
      expect(ReminderTime(7, 5).toString(), '07:05');
      expect(
        UserPreferences(
          reminderEnabled: true,
          reminderTime: ReminderTime(19, 30),
          soundEnabled: true,
          hapticEnabled: false,
        ).toString(),
        'UserPreferences(reminder: true 19:30, sound: true, haptic: false)',
      );
      expect(
        const UserPreferences(
          reminderEnabled: false,
          reminderTime: null,
          soundEnabled: true,
          hapticEnabled: true,
        ).toString(),
        contains('reminder: false -'),
      );
    });

    test('preferences copy, and clear the time only when asked', () {
      final UserPreferences base = UserPreferences(
        reminderEnabled: true,
        reminderTime: ReminderTime(19, 30),
        soundEnabled: true,
        hapticEnabled: false,
      );
      expect(base.copyWith(), base);
      expect(base.copyWith().hashCode, base.hashCode);
      expect(base.copyWith(soundEnabled: false).soundEnabled, isFalse);
      expect(base.copyWith(reminderEnabled: false).reminderTime, isNotNull);
      expect(base.copyWith(clearReminderTime: true).reminderTime, isNull);
      expect(
        base.copyWith(reminderTime: ReminderTime(8, 0)).reminderTime,
        ReminderTime(8, 0),
      );
    });
  });
}
