import 'dart:async';

import 'package:hitup/core/errors/app_exception.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/features/progress/domain/models/calendar_day.dart';
import 'package:hitup/features/progress/domain/models/exercise_progress.dart';
import 'package:hitup/features/progress/domain/models/training_history_entry.dart';
import 'package:hitup/features/progress/domain/models/user_preferences.dart';
import 'package:hitup/features/progress/domain/models/user_profile.dart';
import 'package:hitup/features/progress/domain/repositories/user_progress_repository.dart';
import 'package:hitup/features/progress/domain/streak.dart';

/// A profile with the account's defaults, as registration leaves it, changed
/// where a test says.
UserProfile profileFor(
  String uid, {
  String displayName = 'Deniz Yılmaz',
  String email = 'deniz@example.com',
  DateTime? createdAt,
  int currentProgramDay = 1,
  int totalTrainingMinutes = 0,
  int currentStreak = 0,
  int longestStreak = 0,
  CalendarDay? lastTrainingDate,
}) =>
    UserProfile(
      uid: uid,
      displayName: displayName,
      email: email,
      createdAt: createdAt,
      currentProgramDay: currentProgramDay,
      totalTrainingMinutes: totalTrainingMinutes,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastTrainingDate: lastTrainingDate,
    );

/// A user's progress in memory, for screens.
///
/// The profile is a stream a test can push changes into. Each read can be
/// made to fail with [failWith], and [offline] makes reads fail as an empty
/// local copy does (`USER_PROGRESS.md`).
class FakeProgressRepository implements UserProgressRepository {
  /// Creates the repository with [profile].
  FakeProgressRepository(this._profile);

  UserProfile _profile;
  final StreamController<UserProfile> _changes =
      StreamController<UserProfile>.broadcast();

  /// Completed days, newest first.
  List<TrainingHistoryEntry> history = <TrainingHistoryEntry>[];

  /// Completions by exercise.
  List<ExerciseProgress> exercises = <ExerciseProgress>[];

  /// The settings.
  UserPreferences preferences = const UserPreferences(
    reminderEnabled: false,
    reminderTime: null,
    soundEnabled: true,
    hapticEnabled: true,
  );

  /// Thrown by every read while set.
  Object? failWith;

  /// Whether reads fail as an empty local copy does offline.
  bool offline = false;

  /// What was written, in order.
  final List<String> writes = <String>[];

  /// While set, recording a day waits for it, as a write does offline.
  Completer<void>? holdDays;

  /// The profile as it is now.
  UserProfile get profile => _profile;

  /// Changes the profile, as a write elsewhere would, and tells the stream.
  set profile(UserProfile value) {
    _profile = value;
    _changes.add(value);
  }

  void _read() {
    final Object? failure = failWith;
    if (failure != null) {
      throw failure;
    }
    if (offline) {
      throw const AppException(
        'Nothing in the local copy',
        code: FailureCode.networkOffline,
      );
    }
  }

  @override
  Stream<UserProfile> watchUserProfile(String uid) async* {
    _read();
    yield _profile;
    yield* _changes.stream;
  }

  @override
  Future<UserProfile> getUserProfile(String uid) async {
    _read();
    return _profile;
  }

  @override
  Future<int> getCurrentProgramDay(String uid) async {
    _read();
    return _profile.currentProgramDay;
  }

  @override
  Future<TrainingHistoryEntry?> getTrainingDay(
    String uid,
    CalendarDay date,
  ) async {
    _read();
    for (final TrainingHistoryEntry entry in history) {
      if (entry.date == date) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<List<TrainingHistoryEntry>> getTrainingHistory(
    String uid, {
    int? limit,
  }) async {
    _read();
    return limit == null ? history : history.take(limit).toList();
  }

  @override
  Future<List<ExerciseProgress>> getExerciseProgress(String uid) async {
    _read();
    return exercises;
  }

  @override
  Future<void> saveExerciseCompletion(String uid, String exerciseId) async {
    writes.add('exercise $exerciseId');
  }

  @override
  Future<TrainingSaveResult> saveTrainingCompletion(
    String uid,
    TrainingCompletion completion,
  ) async {
    writes.add('day ${completion.date.key}');
    await holdDays?.future;
    return TrainingSaveResult.saved;
  }

  @override
  Future<StreakUpdate> updateStreak(String uid, CalendarDay today) async {
    writes.add('streak ${today.key}');
    return StreakUpdate(
      currentStreak: _profile.currentStreak,
      longestStreak: _profile.longestStreak,
      lastTrainingDate: today,
      changed: false,
    );
  }

  @override
  Future<int> advanceProgramDay(String uid, {required int completedDay}) async {
    writes.add('advance $completedDay');
    return _profile.currentProgramDay;
  }

  @override
  Future<UserPreferences> getPreferences(String uid) async {
    _read();
    return preferences;
  }

  @override
  Future<void> updatePreferences(
    String uid,
    UserPreferences preferences,
  ) async {
    writes.add('preferences $preferences');
    this.preferences = preferences;
  }

  /// Closes the stream.
  Future<void> close() => _changes.close();
}
