import 'package:flutter/foundation.dart';

/// A wall clock time for the daily reminder, on the user's local clock.
@immutable
class ReminderTime {
  const ReminderTime._(this.hour, this.minute);

  /// Creates a time, refusing an hour or minute out of range.
  factory ReminderTime(int hour, int minute) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Not a time of day: $hour:$minute');
    }
    return ReminderTime._(hour, minute);
  }

  /// Reads the stored `"HH:mm"` form, 24 hour.
  factory ReminderTime.parse(String key) {
    final RegExpMatch? match =
        RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(key);
    if (match == null) {
      throw FormatException('Expected HH:mm', key);
    }
    return ReminderTime._(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
  }

  /// 0 to 23.
  final int hour;

  /// 0 to 59.
  final int minute;

  /// The stored form, `"HH:mm"`.
  String get key => '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => key;
}

/// The user's settings, as `users/{uid}/preferences/settings` holds them.
@immutable
class UserPreferences {
  /// Creates preferences.
  const UserPreferences({
    required this.reminderEnabled,
    required this.reminderTime,
    required this.soundEnabled,
    required this.hapticEnabled,
  });

  /// Whether the daily reminder is on.
  final bool reminderEnabled;

  /// When the reminder fires, or null if the user has never picked a time.
  final ReminderTime? reminderTime;

  /// Whether exercise sounds play.
  final bool soundEnabled;

  /// Whether exercises vibrate.
  final bool hapticEnabled;

  /// A copy with the given fields replaced.
  ///
  /// [clearReminderTime] removes the time, since passing null for
  /// [reminderTime] means "keep it".
  UserPreferences copyWith({
    bool? reminderEnabled,
    ReminderTime? reminderTime,
    bool clearReminderTime = false,
    bool? soundEnabled,
    bool? hapticEnabled,
  }) =>
      UserPreferences(
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderTime:
            clearReminderTime ? null : reminderTime ?? this.reminderTime,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPreferences &&
          other.reminderEnabled == reminderEnabled &&
          other.reminderTime == reminderTime &&
          other.soundEnabled == soundEnabled &&
          other.hapticEnabled == hapticEnabled;

  @override
  int get hashCode =>
      Object.hash(reminderEnabled, reminderTime, soundEnabled, hapticEnabled);

  @override
  String toString() => 'UserPreferences(reminder: $reminderEnabled '
      '${reminderTime ?? '-'}, sound: $soundEnabled, haptic: $hapticEnabled)';
}
