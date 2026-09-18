import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure_code.dart';
import '../../../core/errors/failure_mapper.dart';
import '../domain/models/calendar_day.dart';
import '../domain/models/exercise_progress.dart';
import '../domain/models/training_history_entry.dart';
import '../domain/models/user_preferences.dart';
import '../domain/models/user_profile.dart';
import '../domain/streak.dart' as domain;
import '../domain/repositories/user_progress_repository.dart';
import 'progress_store.dart';

/// [UserProgressRepository] over Cloud Firestore, through a [ProgressStore].
///
/// Paths and field names follow `FIRESTORE_MODEL.md`, and every write is one
/// `firestore.rules` accepts.
class FirebaseUserProgressRepository implements UserProgressRepository {
  /// Creates a repository over [store].
  FirebaseUserProgressRepository(this._store);

  final ProgressStore _store;

  @override
  Stream<UserProfile> watchUserProfile(String uid) {
    _requireSegment(uid, 'uid');
    return _store
        .watch(_userPath(uid))
        // Offline with nothing cached, the SDK reports the document as missing
        // from the cache. That says nothing yet, so it is not passed on.
        .where((StoredDocument doc) => doc.exists || !doc.fromCache)
        .map((StoredDocument doc) => _profileFrom(uid, doc));
  }

  @override
  Future<UserProfile> getUserProfile(String uid) async {
    _requireSegment(uid, 'uid');
    return _profileFrom(uid, await _store.read(_userPath(uid)));
  }

  @override
  Future<int> getCurrentProgramDay(String uid) async =>
      (await getUserProfile(uid)).currentProgramDay;

  @override
  Future<List<TrainingHistoryEntry>> getTrainingHistory(
    String uid, {
    int? limit,
  }) async {
    _requireSegment(uid, 'uid');
    if (limit != null && limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'must be at least 1');
    }
    final StoredQuery result = await _store.readCollection(
      '${_userPath(uid)}/trainingHistory',
      descendingBy: 'trainingDate',
      limit: limit,
    );
    _requireFetched(result, 'training history');
    return result.documents.map(_historyFrom).toList(growable: false);
  }

  @override
  Future<List<ExerciseProgress>> getExerciseProgress(String uid) async {
    _requireSegment(uid, 'uid');
    final StoredQuery result =
        await _store.readCollection('${_userPath(uid)}/exerciseProgress');
    _requireFetched(result, 'exercise progress');
    return result.documents.map(_progressFrom).toList(growable: false);
  }

  @override
  Future<void> saveExerciseCompletion(String uid, String exerciseId) {
    _requireSegment(uid, 'uid');
    _requireSegment(exerciseId, 'exerciseId');
    return _store.commit(<StoredWrite>[
      StoredWrite(
        StoredWriteMode.merge,
        '${_userPath(uid)}/exerciseProgress/$exerciseId',
        <String, Object>{
          'exerciseId': exerciseId,
          'completionCount': const StoredIncrement(1),
          'lastCompletedAt': storedServerTime,
        },
      ),
    ]);
  }

  @override
  Future<TrainingSaveResult> saveTrainingCompletion(
    String uid,
    TrainingCompletion completion,
  ) async {
    _requireSegment(uid, 'uid');
    _requireValid(completion);
    final String historyPath =
        '${_userPath(uid)}/trainingHistory/${completion.date.key}';

    // The local copy answers at once and offline. If it already holds today,
    // there is nothing to write, and writing anyway would only come back as a
    // refusal once the device is online.
    final StoredDocument? cached = await _store.readCached(historyPath);
    if (cached != null && cached.exists) {
      return TrainingSaveResult.alreadySaved;
    }

    try {
      await _store.commit(<StoredWrite>[
        // A set on an existing entry is an update, which the rules refuse, so
        // a second completion of the same day cannot overwrite the first.
        StoredWrite(StoredWriteMode.set, historyPath, <String, Object>{
          'trainingDate': completion.date.key,
          'programDay': completion.programDay,
          'completedExerciseIds': List<String>.unmodifiable(
            completion.completedExerciseIds,
          ),
          'durationMinutes': completion.durationMinutes,
          'completedAt': storedServerTime,
        }),
        // In the same batch, so a refused entry takes its minutes with it.
        StoredWrite(StoredWriteMode.update, _userPath(uid), <String, Object>{
          'totalTrainingMinutes': StoredIncrement(completion.durationMinutes),
        }),
      ]);
      return TrainingSaveResult.saved;
    } catch (error, stackTrace) {
      if (await _refusedBecauseAlreadySaved(error, historyPath)) {
        return TrainingSaveResult.alreadySaved;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<domain.StreakUpdate> updateStreak(String uid, CalendarDay today) {
    _requireSegment(uid, 'uid');
    return _store.transaction<domain.StreakUpdate>(
      (StoredTransaction tx) async {
        final StoredDocument doc = await tx.read(_userPath(uid));
        _requireExists(doc, 'profile');
        final _Reader read = _Reader(doc);
        final String? stored = read.optionalString('lastTrainingDate');

        final domain.StreakUpdate update = domain.advanceStreak(
          today: today,
          lastTrainingDate:
              stored == null ? null : read.parsed(stored, CalendarDay.parse),
          currentStreak: read.integer('currentStreak'),
          longestStreak: read.integer('longestStreak'),
        );

        // Nothing to write for a day already counted. Writing the same values
        // again would still cost a round trip and still race another device.
        if (update.changed) {
          tx.update(_userPath(uid), <String, Object>{
            'currentStreak': update.currentStreak,
            'longestStreak': update.longestStreak,
            'lastTrainingDate': update.lastTrainingDate.key,
          });
        }
        return update;
      },
    );
  }

  @override
  Future<int> advanceProgramDay(String uid, {required int completedDay}) {
    _requireSegment(uid, 'uid');
    if (completedDay < 1) {
      throw ArgumentError.value(
        completedDay,
        'completedDay',
        'must be at least 1',
      );
    }
    return _store.transaction<int>((StoredTransaction tx) async {
      final StoredDocument doc = await tx.read(_userPath(uid));
      _requireExists(doc, 'profile');
      final int current = _Reader(doc).integer('currentProgramDay');

      // Only the day they are on moves them forward. Finishing an older day
      // again, or a second device that already advanced, leaves it alone.
      if (current != completedDay) {
        return current;
      }
      final int next = current + 1;
      tx.update(_userPath(uid), <String, Object>{'currentProgramDay': next});
      return next;
    });
  }

  @override
  Future<UserPreferences> getPreferences(String uid) async {
    _requireSegment(uid, 'uid');
    final StoredDocument doc = await _store.read(_preferencesPath(uid));
    _requireExists(doc, 'preferences');
    final _Reader read = _Reader(doc);
    final String? time = read.optionalString('reminderTime');
    return UserPreferences(
      reminderEnabled: read.boolean('reminderEnabled'),
      reminderTime: time == null ? null : read.parsed(time, ReminderTime.parse),
      soundEnabled: read.boolean('soundEnabled'),
      hapticEnabled: read.boolean('hapticEnabled'),
    );
  }

  @override
  Future<void> updatePreferences(String uid, UserPreferences preferences) {
    _requireSegment(uid, 'uid');
    return _store.commit(<StoredWrite>[
      // A full set, not a merge: a reminder time the user cleared has to
      // disappear from the document, not linger from an earlier write.
      StoredWrite(StoredWriteMode.set, _preferencesPath(uid), <String, Object>{
        'reminderEnabled': preferences.reminderEnabled,
        if (preferences.reminderTime != null)
          'reminderTime': preferences.reminderTime!.key,
        'soundEnabled': preferences.soundEnabled,
        'hapticEnabled': preferences.hapticEnabled,
      }),
    ]);
  }

  /// Whether a failed history write failed only because the day is already
  /// recorded.
  ///
  /// The rules refuse any write to an existing entry, and that refusal is a
  /// permission error, the same one a signed-out user would get. So the
  /// refusal alone proves nothing: the entry is read back, and only if the
  /// server confirms it exists is the refusal "already saved". This happens
  /// when the local copy did not know about the entry, for instance when the
  /// day was completed on another device.
  Future<bool> _refusedBecauseAlreadySaved(Object error, String path) async {
    if (mapErrorToFailure(error).code != FailureCode.permissionDenied) {
      return false;
    }
    try {
      final StoredDocument doc = await _store.read(path);
      return doc.exists && !doc.fromCache;
    } catch (_) {
      // The original error is the one worth reporting.
      return false;
    }
  }

  static String _userPath(String uid) => 'users/$uid';

  static String _preferencesPath(String uid) =>
      '${_userPath(uid)}/preferences/settings';

  /// A value used as one path segment must be one segment.
  ///
  /// An id with a slash in it would address a different document than the one
  /// named, so it is refused rather than passed on for the rules to catch.
  static void _requireSegment(String value, String name) {
    if (value.isEmpty || value.contains('/')) {
      throw ArgumentError.value(value, name, 'must be a single path segment');
    }
  }

  static void _requireValid(TrainingCompletion completion) {
    final List<String> ids = completion.completedExerciseIds;
    if (completion.programDay < 1) {
      throw ArgumentError.value(
        completion.programDay,
        'programDay',
        'must be at least 1',
      );
    }
    if (ids.isEmpty || ids.length > TrainingCompletion.maxExercises) {
      throw ArgumentError.value(
        ids.length,
        'completedExerciseIds',
        'must list 1 to ${TrainingCompletion.maxExercises} exercises',
      );
    }
    if (completion.durationMinutes < 0 ||
        completion.durationMinutes > TrainingCompletion.maxDurationMinutes) {
      throw ArgumentError.value(
        completion.durationMinutes,
        'durationMinutes',
        'must be 0 to ${TrainingCompletion.maxDurationMinutes}',
      );
    }
  }

  /// A missing document is only "not found" when the server said so.
  static void _requireExists(StoredDocument doc, String what) {
    if (doc.exists) {
      return;
    }
    if (doc.fromCache) {
      throw AppException(
        'No $what in the local copy and the server could not be reached',
        code: FailureCode.networkOffline,
      );
    }
    throw AppException('No $what document', code: FailureCode.dataNotFound);
  }

  /// An empty list from the local copy may only mean it was never fetched.
  static void _requireFetched(StoredQuery result, String what) {
    if (result.fromCache && result.documents.isEmpty) {
      throw AppException(
        'No $what in the local copy and the server could not be reached',
        code: FailureCode.networkOffline,
      );
    }
  }

  static UserProfile _profileFrom(String uid, StoredDocument doc) {
    _requireExists(doc, 'profile');
    final _Reader read = _Reader(doc);
    final String? lastDay = read.optionalString('lastTrainingDate');
    return UserProfile(
      uid: uid,
      displayName: read.string('displayName'),
      email: read.string('email'),
      createdAt: read.optionalTime('createdAt'),
      currentProgramDay: read.integer('currentProgramDay'),
      totalTrainingMinutes: read.integer('totalTrainingMinutes'),
      currentStreak: read.integer('currentStreak'),
      longestStreak: read.integer('longestStreak'),
      lastTrainingDate:
          lastDay == null ? null : read.parsed(lastDay, CalendarDay.parse),
    );
  }

  static TrainingHistoryEntry _historyFrom(StoredDocument doc) {
    final _Reader read = _Reader(doc);
    return TrainingHistoryEntry(
      date: read.parsed(read.string('trainingDate'), CalendarDay.parse),
      programDay: read.integer('programDay'),
      completedExerciseIds: read.strings('completedExerciseIds'),
      durationMinutes: read.integer('durationMinutes'),
      completedAt: read.optionalTime('completedAt'),
    );
  }

  static ExerciseProgress _progressFrom(StoredDocument doc) {
    final _Reader read = _Reader(doc);
    return ExerciseProgress(
      exerciseId: read.string('exerciseId'),
      completionCount: read.integer('completionCount'),
      lastCompletedAt: read.optionalTime('lastCompletedAt'),
    );
  }
}

/// Reads typed fields from a stored document.
///
/// A field of the wrong type is a document the rules should never have let
/// through, or one written before a model change. Either way it is data this
/// build cannot use, reported as `FailureCode.dataUnknown` with the document
/// and field named, rather than a `TypeError` somewhere in a widget.
class _Reader {
  _Reader(this._doc);

  final StoredDocument _doc;

  String string(String field) => _as<String>(field);

  int integer(String field) => _as<int>(field);

  bool boolean(String field) => _as<bool>(field);

  String? optionalString(String field) =>
      _doc.data[field] == null ? null : _as<String>(field);

  /// Null while a server timestamp is still pending, which the local copy
  /// reports as a missing value.
  DateTime? optionalTime(String field) =>
      _doc.data[field] == null ? null : _as<DateTime>(field);

  List<String> strings(String field) {
    final Object? value = _doc.data[field];
    if (value is List && value.every((Object? item) => item is String)) {
      return List<String>.unmodifiable(value.cast<String>());
    }
    throw _malformed(field, value);
  }

  T parsed<T>(String value, T Function(String) parse) {
    try {
      return parse(value);
    } on FormatException {
      throw AppException(
        'Unreadable value "$value" in ${_doc.id}',
        code: FailureCode.dataUnknown,
      );
    }
  }

  T _as<T>(String field) {
    final Object? value = _doc.data[field];
    if (value is T) {
      return value;
    }
    throw _malformed(field, value);
  }

  AppException _malformed(String field, Object? value) => AppException(
        'Field "$field" in ${_doc.id} is ${value.runtimeType}',
        code: FailureCode.dataUnknown,
      );
}
