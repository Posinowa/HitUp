import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../progress/domain/models/calendar_day.dart';
import '../domain/training_session.dart';
import 'session_store.dart';

/// A finished training day that has not been recorded on the account yet
/// (HIT-028).
///
/// Holds everything the recording needs, taken when the day ended: whose day
/// it was, the date it ended on and how long it was worked. Recording it
/// later, on the next launch or with the next day, has to use those, not the
/// clock at that moment; a day recorded under the date it was retried on
/// would count towards the wrong day of the streak.
@immutable
class PendingDay {
  /// Creates a pending day.
  const PendingDay({
    required this.uid,
    required this.session,
    required this.date,
    required this.elapsed,
  });

  /// The account the day belongs to.
  final String uid;

  /// The finished session.
  final TrainingSession session;

  /// The date the day ended on.
  final CalendarDay date;

  /// How long the day was worked.
  final Duration elapsed;

  /// Whether [other] is the same account's day on the same date.
  ///
  /// There is one history entry per date, so that is what makes two pending
  /// days the same day, whatever their sessions.
  bool isSameDayAs(PendingDay other) => other.uid == uid && other.date == date;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingDay &&
          other.uid == uid &&
          other.session == session &&
          other.date == date &&
          other.elapsed == elapsed;

  @override
  int get hashCode => Object.hash(uid, session, date, elapsed);

  @override
  String toString() => 'PendingDay($uid, ${date.key}, $session)';
}

/// The finished days on the device that are not recorded yet.
abstract interface class PendingDayStore {
  /// Every pending day, oldest first.
  Future<List<PendingDay>> load();

  /// Adds [day], unless the same account already has a pending day on that
  /// date.
  ///
  /// The first one is kept, matching the account: a date has one history
  /// entry, and the first session recorded for it is the one that stays.
  Future<void> add(PendingDay day);

  /// Forgets the pending day of [day]'s account on [day]'s date.
  Future<void> remove(PendingDay day);
}

/// [PendingDayStore] over the device's preferences.
class PreferencesPendingDayStore implements PendingDayStore {
  /// Creates a store.
  const PreferencesPendingDayStore();

  /// The key the pending days are stored under.
  static const String key = 'pending_training_days';

  @override
  Future<List<PendingDay>> load() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return _read(preferences);
  }

  @override
  Future<void> add(PendingDay day) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<PendingDay> days = _read(preferences);
    if (days.any(day.isSameDayAs)) {
      return;
    }
    await _write(preferences, <PendingDay>[...days, day]);
  }

  @override
  Future<void> remove(PendingDay day) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<PendingDay> days = _read(preferences);
    await _write(
      preferences,
      days.where((PendingDay kept) => !kept.isSameDayAs(day)).toList(),
    );
  }

  List<PendingDay> _read(SharedPreferences preferences) {
    final String? saved = preferences.getString(key);
    if (saved == null) {
      return <PendingDay>[];
    }
    try {
      final List<dynamic> list = jsonDecode(saved) as List<dynamic>;
      return <PendingDay>[
        for (final Object? item in list)
          pendingDayFromJson(item! as Map<String, dynamic>),
      ]..sort((PendingDay a, PendingDay b) => a.date.compareTo(b.date));
    } on Object catch (error) {
      // What cannot be read cannot be recorded; guessing at it could record
      // a day that did not happen. Logged, and read as nothing.
      debugPrint('HIT-028: pending days could not be read. Cause: $error');
      return <PendingDay>[];
    }
  }

  Future<void> _write(
    SharedPreferences preferences,
    List<PendingDay> days,
  ) async {
    if (days.isEmpty) {
      await preferences.remove(key);
      return;
    }
    await preferences.setString(
      key,
      jsonEncode(<Map<String, Object?>>[
        for (final PendingDay day in days) pendingDayToJson(day),
      ]),
    );
  }
}

/// [day] as the map that is stored.
Map<String, Object?> pendingDayToJson(PendingDay day) => <String, Object?>{
      'uid': day.uid,
      'session': sessionToJson(day.session),
      'date': day.date.key,
      'elapsedSeconds': day.elapsed.inSeconds,
    };

/// A pending day read back from [json].
///
/// Throws a [FormatException] for anything it cannot make one of.
PendingDay pendingDayFromJson(Map<String, dynamic> json) {
  T require<T>(String field) {
    final Object? value = json[field];
    if (value is T) {
      return value;
    }
    throw FormatException('Pending day field "$field" is ${value.runtimeType}');
  }

  final String uid = require<String>('uid');
  if (uid.isEmpty) {
    throw const FormatException('Pending day has no account');
  }
  final int seconds = require<int>('elapsedSeconds');
  if (seconds < 0) {
    throw FormatException('Pending day took $seconds seconds');
  }
  return PendingDay(
    uid: uid,
    session: sessionFromJson(require<Map<String, dynamic>>('session')),
    date: CalendarDay.parse(require<String>('date')),
    elapsed: Duration(seconds: seconds),
  );
}
