import 'package:flutter/foundation.dart';

import 'calendar_day.dart';

/// A user's profile and the totals kept on it, as `users/{uid}` holds them.
@immutable
class UserProfile {
  /// Creates a profile.
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.createdAt,
    required this.currentProgramDay,
    required this.totalTrainingMinutes,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastTrainingDate,
  });

  /// The account id, which is also the document id.
  final String uid;

  /// May be empty: registration does not require a name.
  final String displayName;

  /// The email the account was registered with.
  final String email;

  /// When the account was created, by the server's clock.
  ///
  /// Null only in the moment between registration and the server confirming
  /// the write, when a screen reading the local copy sees the time still
  /// pending.
  final DateTime? createdAt;

  /// The day of the programme the user is on. 1 for a new account.
  final int currentProgramDay;

  /// Minutes trained, over every completed session.
  final int totalTrainingMinutes;

  /// Consecutive days trained, ending with [lastTrainingDate].
  final int currentStreak;

  /// The longest run of consecutive days so far.
  final int longestStreak;

  /// The last day the user trained, or null if they never have.
  final CalendarDay? lastTrainingDate;

  /// True until the first completed training.
  bool get hasNeverTrained => lastTrainingDate == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          other.uid == uid &&
          other.displayName == displayName &&
          other.email == email &&
          other.createdAt == createdAt &&
          other.currentProgramDay == currentProgramDay &&
          other.totalTrainingMinutes == totalTrainingMinutes &&
          other.currentStreak == currentStreak &&
          other.longestStreak == longestStreak &&
          other.lastTrainingDate == lastTrainingDate;

  @override
  int get hashCode => Object.hash(
        uid,
        displayName,
        email,
        createdAt,
        currentProgramDay,
        totalTrainingMinutes,
        currentStreak,
        longestStreak,
        lastTrainingDate,
      );

  /// Names the profile by uid only, for the same reason `AuthUser` does: the
  /// email and the name are personal data and do not belong in a log line.
  @override
  String toString() => 'UserProfile($uid)';
}
