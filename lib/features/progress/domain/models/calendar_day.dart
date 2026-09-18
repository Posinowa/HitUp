import 'package:flutter/foundation.dart';

/// A day on the user's own calendar, with no time and no timezone.
///
/// `FIRESTORE_MODEL.md` stores the days that matter for the streak as
/// `"yyyy-MM-dd"` strings rather than timestamps, so that "same day, next day,
/// or a gap" is a comparison of two days and never a timezone conversion. This
/// is that string as a value, so the rest of the app cannot build a malformed
/// one or compare two by accident as text.
@immutable
class CalendarDay implements Comparable<CalendarDay> {
  const CalendarDay._(this.year, this.month, this.day);

  /// Creates a day, refusing one that does not exist.
  ///
  /// `CalendarDay(2026, 2, 30)` throws rather than rolling over into March, the
  /// way `DateTime` would.
  factory CalendarDay(int year, int month, int day) {
    // DateTime rolls an invalid day into the next or previous month, so a
    // month or year that changed on the way through means the day was invalid.
    final DateTime probe = DateTime.utc(year, month, day);
    if (year < 0 || year > 9999 || probe.year != year || probe.month != month) {
      throw ArgumentError('Not a calendar day: $year-$month-$day');
    }
    return CalendarDay._(year, month, day);
  }

  /// The day [moment] falls on in the device's timezone.
  ///
  /// A `DateTime` in UTC is converted first, so the result is the day the user
  /// saw on their own clock, which is the day the streak has to count.
  factory CalendarDay.fromDateTime(DateTime moment) {
    final DateTime local = moment.toLocal();
    return CalendarDay._(local.year, local.month, local.day);
  }

  /// Reads the stored `"yyyy-MM-dd"` form.
  ///
  /// Throws a [FormatException] for anything else, including a well formed
  /// string naming a day that does not exist.
  factory CalendarDay.parse(String key) {
    final RegExpMatch? match =
        RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
    if (match == null) {
      throw FormatException('Expected yyyy-MM-dd', key);
    }
    try {
      return CalendarDay(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    } on ArgumentError {
      throw FormatException('Not a calendar day', key);
    }
  }

  /// Four digit year.
  final int year;

  /// 1 to 12.
  final int month;

  /// 1 to 31, valid for [month].
  final int day;

  /// The stored form, `"yyyy-MM-dd"`, which is also a history document id.
  String get key => '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(CalendarDay other) => key.compareTo(other.key);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarDay &&
          other.year == year &&
          other.month == month &&
          other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => key;
}
