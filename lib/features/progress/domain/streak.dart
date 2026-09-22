import 'package:flutter/foundation.dart';

import 'models/calendar_day.dart';

/// The streak, and the one rule that moves it (HIT-054).
///
/// A pure function over four numbers and two days, so every case below is
/// testable without Firebase, without a clock and without a device.
///
/// **What counts.** Completing the day's training. Opening the app does not,
/// and neither does starting a session and leaving it; the only caller is the
/// one that records a finished training day (HIT-053).
@immutable
class StreakUpdate {
  /// Creates an update.
  const StreakUpdate({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastTrainingDate,
    required this.changed,
  });

  /// The run of consecutive days ending on [lastTrainingDate].
  final int currentStreak;

  /// The longest run so far, which never goes down.
  final int longestStreak;

  /// The last day counted.
  final CalendarDay lastTrainingDate;

  /// Whether this is different from what was stored.
  ///
  /// False for a day already counted, which is the case a caller should write
  /// nothing for rather than write the same values again.
  final bool changed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakUpdate &&
          other.currentStreak == currentStreak &&
          other.longestStreak == longestStreak &&
          other.lastTrainingDate == lastTrainingDate &&
          other.changed == changed;

  @override
  int get hashCode =>
      Object.hash(currentStreak, longestStreak, lastTrainingDate, changed);

  @override
  String toString() => 'StreakUpdate($currentStreak, longest $longestStreak, '
      '$lastTrainingDate${changed ? '' : ', unchanged'})';
}

/// The streak after training was completed on [today].
///
/// The rule, in full:
///
/// - **First ever.** No last day: the streak is 1.
/// - **The next day.** Last day was yesterday: the streak grows by one.
/// - **The same day again.** Nothing changes, and [StreakUpdate.changed] is
///   false. Training twice in a day is two sessions, not two days.
/// - **A gap.** Any older last day: the streak starts again at 1. Yesterday
///   was missed, and a streak that survived a gap would not be a streak.
/// - **A day in the past.** Last day is *after* today, which a traveller
///   crossing a date line or a device whose clock was wrong can produce. The
///   streak is left alone rather than reset: the user did train, and losing a
///   run to a clock is a worse answer than keeping it.
///
/// The longest streak is the larger of what it was and what the current one
/// became. It never goes down, and the rules refuse a write where it would
/// (`firestore.rules`).
StreakUpdate advanceStreak({
  required CalendarDay today,
  required CalendarDay? lastTrainingDate,
  required int currentStreak,
  required int longestStreak,
}) {
  if (currentStreak < 0 || longestStreak < 0) {
    throw ArgumentError('A streak cannot be negative');
  }

  if (lastTrainingDate == today) {
    return StreakUpdate(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastTrainingDate: today,
      changed: false,
    );
  }

  if (lastTrainingDate != null && lastTrainingDate.compareTo(today) > 0) {
    return StreakUpdate(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastTrainingDate: lastTrainingDate,
      changed: false,
    );
  }

  // Yesterday continues the run; anything older starts it again. A stored
  // streak of 0 with a last day of yesterday is a document that disagrees
  // with itself, and it needs no special case: adding one to nothing is the
  // same 1 that starting again gives.
  final bool continues =
      lastTrainingDate != null && lastTrainingDate.next == today;
  final int next = continues ? currentStreak + 1 : 1;

  return StreakUpdate(
    currentStreak: next,
    longestStreak: next > longestStreak ? next : longestStreak,
    lastTrainingDate: today,
    changed: true,
  );
}
