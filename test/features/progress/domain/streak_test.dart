import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/progress/domain/models/calendar_day.dart';
import 'package:hitup/features/progress/domain/streak.dart';

void main() {
  final CalendarDay today = CalendarDay(2026, 9, 17);

  StreakUpdate after({
    CalendarDay? last,
    int current = 0,
    int longest = 0,
    CalendarDay? on,
  }) =>
      advanceStreak(
        today: on ?? today,
        lastTrainingDate: last,
        currentStreak: current,
        longestStreak: longest,
      );

  group('the rule', () {
    test('the first training ever starts the streak at one', () {
      final StreakUpdate update = after();

      expect(update.currentStreak, 1);
      expect(update.longestStreak, 1);
      expect(update.lastTrainingDate, today);
      expect(update.changed, isTrue);
    });

    test('training the next day grows it', () {
      final StreakUpdate update = after(
        last: today.previous,
        current: 3,
        longest: 5,
      );

      expect(update.currentStreak, 4);
      expect(update.longestStreak, 5);
      expect(update.lastTrainingDate, today);
      expect(update.changed, isTrue);
    });

    test('training again the same day changes nothing', () {
      // Two sessions in a day are two sessions, not two days.
      final StreakUpdate update = after(last: today, current: 4, longest: 6);

      expect(update.currentStreak, 4);
      expect(update.longestStreak, 6);
      expect(update.lastTrainingDate, today);
      expect(update.changed, isFalse);
    });

    test('a missed day starts again at one', () {
      for (final int gap in <int>[2, 3, 30, 400]) {
        final StreakUpdate update = after(
          last: today.addDays(-gap),
          current: 9,
          longest: 12,
        );

        expect(update.currentStreak, 1, reason: '$gap days');
        expect(update.longestStreak, 12, reason: '$gap days');
        expect(update.changed, isTrue);
      }
    });

    test('the longest streak rises with the current one, and never falls', () {
      final StreakUpdate grown = after(
        last: today.previous,
        current: 7,
        longest: 7,
      );
      expect(grown.currentStreak, 8);
      expect(grown.longestStreak, 8);

      final StreakUpdate reset = after(
        last: today.addDays(-4),
        current: 7,
        longest: 20,
      );
      expect(reset.currentStreak, 1);
      expect(reset.longestStreak, 20);
    });

    test('a last day in the future leaves the streak alone', () {
      // A traveller crossing a date line, or a device whose clock was wrong.
      // The user did train; losing a run to a clock is the worse answer.
      final StreakUpdate update = after(
        last: today.next,
        current: 5,
        longest: 9,
      );

      expect(update.currentStreak, 5);
      expect(update.longestStreak, 9);
      expect(update.lastTrainingDate, today.next);
      expect(update.changed, isFalse);
    });

    test('a stored streak of zero with yesterday counts today as the first',
        () {
      // A document that disagrees with itself. Counting today as day one is
      // the only answer that cannot claim two days from one.
      final StreakUpdate update = after(last: today.previous, longest: 3);

      expect(update.currentStreak, 1);
      expect(update.longestStreak, 3);
    });

    test('a negative streak is a caller bug, not a value', () {
      expect(
        () => after(current: -1),
        throwsArgumentError,
      );
      expect(
        () => after(longest: -2),
        throwsArgumentError,
      );
    });
  });

  group('across the calendar', () {
    test('a streak runs over a month end', () {
      final CalendarDay first = CalendarDay(2026, 8, 31);
      final StreakUpdate update = advanceStreak(
        today: CalendarDay(2026, 9, 1),
        lastTrainingDate: first,
        currentStreak: 2,
        longestStreak: 2,
      );

      expect(update.currentStreak, 3);
      expect(update.lastTrainingDate, CalendarDay(2026, 9, 1));
    });

    test('and over a year end, and a leap day', () {
      expect(
        advanceStreak(
          today: CalendarDay(2027, 1, 1),
          lastTrainingDate: CalendarDay(2026, 12, 31),
          currentStreak: 10,
          longestStreak: 10,
        ).currentStreak,
        11,
      );
      expect(
        advanceStreak(
          today: CalendarDay(2028, 3, 1),
          lastTrainingDate: CalendarDay(2028, 2, 29),
          currentStreak: 1,
          longestStreak: 1,
        ).currentStreak,
        2,
      );
    });

    test('day arithmetic crosses months, years and leap days', () {
      expect(CalendarDay(2026, 8, 31).next, CalendarDay(2026, 9, 1));
      expect(CalendarDay(2026, 1, 1).previous, CalendarDay(2025, 12, 31));
      expect(CalendarDay(2028, 2, 28).next, CalendarDay(2028, 2, 29));
      expect(CalendarDay(2027, 2, 28).next, CalendarDay(2027, 3, 1));
      expect(CalendarDay(2026, 9, 17).addDays(0), CalendarDay(2026, 9, 17));
      expect(CalendarDay(2026, 9, 17).addDays(-17), CalendarDay(2026, 8, 31));
      expect(
        CalendarDay(2026, 9, 17).daysUntil(CalendarDay(2026, 9, 20)),
        3,
      );
      expect(
        CalendarDay(2026, 9, 20).daysUntil(CalendarDay(2026, 9, 17)),
        -3,
      );
      expect(
        CalendarDay(2026, 3, 28).daysUntil(CalendarDay(2026, 3, 30)),
        2,
        reason: 'days, not hours: this is the weekend Turkey moves its clocks',
      );
    });
  });

  group('the update as a value', () {
    test('compares by every field and prints what it is', () {
      StreakUpdate update({int current = 2, bool changed = true}) =>
          StreakUpdate(
            currentStreak: current,
            longestStreak: 5,
            lastTrainingDate: today,
            changed: changed,
          );

      expect(update(), update());
      expect(update().hashCode, update().hashCode);
      expect(update(current: 3), isNot(update()));
      expect(update(changed: false), isNot(update()));
      expect(update().toString(), contains('longest 5'));
      expect(update(changed: false).toString(), contains('unchanged'));
    });
  });
}
