import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/training_session.dart';

/// Keeps an unfinished session on the device, so the home screen can offer to
/// carry on with it (HIT-026).
///
/// The device, not Firestore: a half-finished session is not progress, it is
/// where someone was when the phone rang. Persisting it to the account would
/// mean two devices arguing about which half-session is current, and
/// `FIRESTORE_MODEL.md` has no place for one.
abstract interface class SessionStore {
  /// The saved session, or null when there is none or it cannot be read.
  Future<TrainingSession?> load();

  /// Saves [session], replacing whatever was there.
  Future<void> save(TrainingSession session);

  /// Forgets the saved session.
  Future<void> clear();
}

/// [SessionStore] over the device's preferences.
class PreferencesSessionStore implements SessionStore {
  /// Creates a store.
  const PreferencesSessionStore();

  /// The key the session is stored under.
  static const String key = 'training_session';

  @override
  Future<TrainingSession?> load() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? saved = preferences.getString(key);
    if (saved == null) {
      return null;
    }
    try {
      return sessionFromJson(jsonDecode(saved) as Map<String, dynamic>);
    } on Object catch (error) {
      // A session that cannot be read is a convenience lost, not a failure to
      // report: the user starts the day again. Left in place rather than
      // deleted, so the next version of the app can still make sense of it.
      debugPrint('HIT-026: a saved session could not be read. Cause: $error');
      return null;
    }
  }

  @override
  Future<void> save(TrainingSession session) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(sessionToJson(session)));
  }

  @override
  Future<void> clear() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}

/// [session] as the map that is stored.
Map<String, Object?> sessionToJson(TrainingSession session) =>
    <String, Object?>{
      'programDay': session.programDay,
      'exerciseIds': session.exerciseIds,
      'status': session.status.name,
      'currentIndex': session.currentIndex,
      'completedExerciseIds': session.completedExerciseIds,
    };

/// A session read back from [json].
///
/// Throws a [FormatException] for anything it cannot make a session of,
/// including a status this build does not know: a newer app may have added
/// one, and guessing which state that was is worse than starting the day
/// again.
TrainingSession sessionFromJson(Map<String, dynamic> json) {
  T require<T>(String field) {
    final Object? value = json[field];
    if (value is T) {
      return value;
    }
    throw FormatException('Session field "$field" is ${value.runtimeType}');
  }

  List<String> strings(String field) {
    final List<dynamic> value = require<List<dynamic>>(field);
    if (value.every((Object? item) => item is String)) {
      return value.cast<String>();
    }
    throw FormatException('Session field "$field" is not a list of ids');
  }

  final String status = require<String>('status');
  return TrainingSession(
    programDay: require<int>('programDay'),
    exerciseIds: strings('exerciseIds'),
    status: SessionStatus.values.firstWhere(
      (SessionStatus candidate) => candidate.name == status,
      orElse: () => throw FormatException('Unknown session status "$status"'),
    ),
    currentIndex: require<int>('currentIndex'),
    completedExerciseIds: strings('completedExerciseIds'),
  );
}
