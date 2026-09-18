import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/app_exception.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_mapper.dart';
import 'package:hitup/features/progress/data/firebase_user_progress_repository.dart';
import 'package:hitup/features/progress/data/progress_store.dart';
import 'package:hitup/features/progress/domain/models/calendar_day.dart';
import 'package:hitup/features/progress/domain/models/exercise_progress.dart';
import 'package:hitup/features/progress/domain/models/training_history_entry.dart';
import 'package:hitup/features/progress/domain/models/user_preferences.dart';
import 'package:hitup/features/progress/domain/models/user_profile.dart';
import 'package:hitup/features/progress/domain/streak.dart';

import '../../../support/firestore_rules.dart';

/// A store holding documents in memory, reachable or not, that records every
/// write and fails on request.
class _FakeStore implements ProgressStore {
  /// What the server holds.
  final Map<String, Map<String, Object?>> server =
      <String, Map<String, Object?>>{};

  /// What the local copy holds. Null for a path means "no cached answer".
  final Map<String, Map<String, Object?>?> cache =
      <String, Map<String, Object?>?>{};

  bool online = true;
  Object? commitError;
  Object? readError;

  /// When set, what [read] returns, whatever [online] says.
  StoredDocument? readResult;
  final List<List<StoredWrite>> commits = <List<StoredWrite>>[];
  final List<String> reads = <String>[];
  // Broadcast, so closing it in tearDown completes even when no test listened.
  final StreamController<StoredDocument> watched =
      StreamController<StoredDocument>.broadcast();
  String? lastCollection;
  String? lastDescendingBy;
  int? lastLimit;

  static String _id(String path) => path.split('/').last;

  @override
  Future<StoredDocument> read(String path) async {
    reads.add(path);
    if (readError != null) throw readError!;
    if (readResult != null) return readResult!;
    if (online) {
      final Map<String, Object?>? data = server[path];
      return StoredDocument(
        id: _id(path),
        exists: data != null,
        data: data ?? const <String, Object?>{},
        fromCache: false,
      );
    }
    final Map<String, Object?>? data = cache[path];
    return StoredDocument(
      id: _id(path),
      exists: data != null,
      data: data ?? const <String, Object?>{},
      fromCache: true,
    );
  }

  @override
  Future<StoredDocument?> readCached(String path) async {
    if (!cache.containsKey(path)) return null;
    final Map<String, Object?>? data = cache[path];
    return StoredDocument(
      id: _id(path),
      exists: data != null,
      data: data ?? const <String, Object?>{},
      fromCache: true,
    );
  }

  @override
  Stream<StoredDocument> watch(String path) => watched.stream;

  @override
  Future<StoredQuery> readCollection(
    String path, {
    String? descendingBy,
    int? limit,
  }) async {
    lastCollection = path;
    lastDescendingBy = descendingBy;
    lastLimit = limit;
    final Map<String, Map<String, Object?>?> source = online ? server : cache;
    final List<StoredDocument> docs = <StoredDocument>[
      for (final MapEntry<String, Map<String, Object?>?> e in source.entries)
        if (e.value != null &&
            e.key.startsWith('$path/') &&
            !e.key.substring(path.length + 1).contains('/'))
          StoredDocument(
            id: _id(e.key),
            exists: true,
            data: e.value!,
            fromCache: !online,
          ),
    ];
    return StoredQuery(documents: docs, fromCache: !online);
  }

  @override
  Future<void> commit(List<StoredWrite> writes) async {
    commits.add(writes);
    if (commitError != null) throw commitError!;
  }

  /// How many transactions were run, and what each one wrote.
  int transactions = 0;
  final List<Map<String, Object>> transactionWrites = <Map<String, Object>>[];
  Object? transactionError;

  @override
  Future<T> transaction<T>(
    Future<T> Function(StoredTransaction tx) body,
  ) async {
    transactions++;
    if (transactionError != null) throw transactionError!;
    return body(_FakeTransaction(this));
  }

  Future<void> close() => watched.close();
}

/// The reads and writes a transaction body makes, against the fake's server.
class _FakeTransaction implements StoredTransaction {
  _FakeTransaction(this.store);

  final _FakeStore store;

  @override
  Future<StoredDocument> read(String path) => store.read(path);

  @override
  void update(String path, Map<String, Object> fields) {
    store.transactionWrites.add(fields);
    // Applied at once, so a test can read back what the transaction wrote.
    store.server[path] = <String, Object?>{...?store.server[path], ...fields};
  }
}

FirebaseException _denied() => FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );

Map<String, Object?> _profileData({Object? lastTrainingDate}) =>
    <String, Object?>{
      'displayName': 'Ada',
      'email': 'ada@example.com',
      'createdAt': DateTime.utc(2026, 9, 1, 8),
      'currentProgramDay': 4,
      'totalTrainingMinutes': 87,
      'currentStreak': 3,
      'longestStreak': 5,
      if (lastTrainingDate != null) 'lastTrainingDate': lastTrainingDate,
    };

TrainingCompletion _completion({
  int programDay = 4,
  List<String> ids = const <String>['breathing_diaphragm_04', 'letter_i_01'],
  int minutes = 13,
}) =>
    TrainingCompletion(
      date: CalendarDay(2026, 9, 16),
      programDay: programDay,
      completedExerciseIds: ids,
      durationMinutes: minutes,
    );

/// Expects [body] to throw an [AppException] carrying [code].
Future<void> _expectCode(Future<Object?> Function() body, String code) async {
  try {
    await body();
  } on AppException catch (e) {
    expect(e.code, code, reason: e.toString());
    return;
  }
  fail('expected AppException($code)');
}

void main() {
  const String uid = 'uid-1';
  late _FakeStore store;
  late FirebaseUserProgressRepository repository;

  setUp(() {
    store = _FakeStore();
    repository = FirebaseUserProgressRepository(store);
  });

  tearDown(() => store.close());

  group('profile', () {
    test('maps every field of users/{uid}', () async {
      store.server['users/$uid'] = _profileData(lastTrainingDate: '2026-09-16');

      final UserProfile profile = await repository.getUserProfile(uid);

      expect(
        profile,
        UserProfile(
          uid: uid,
          displayName: 'Ada',
          email: 'ada@example.com',
          createdAt: DateTime.utc(2026, 9, 1, 8),
          currentProgramDay: 4,
          totalTrainingMinutes: 87,
          currentStreak: 3,
          longestStreak: 5,
          lastTrainingDate: CalendarDay(2026, 9, 16),
        ),
      );
      expect(await repository.getCurrentProgramDay(uid), 4);
    });

    test('an absent lastTrainingDate is "never trained"', () async {
      store.server['users/$uid'] = _profileData();
      final UserProfile profile = await repository.getUserProfile(uid);
      expect(profile.lastTrainingDate, isNull);
      expect(profile.hasNeverTrained, isTrue);
    });

    test('a createdAt still pending on the local copy reads as null', () async {
      store.server['users/$uid'] = _profileData()..remove('createdAt');
      expect((await repository.getUserProfile(uid)).createdAt, isNull);
    });

    test('missing on the server is not found', () async {
      await _expectCode(
        () => repository.getUserProfile(uid),
        FailureCode.dataNotFound,
      );
    });

    test('missing from the local copy while offline is offline, not missing',
        () async {
      store.online = false;
      await _expectCode(
        () => repository.getUserProfile(uid),
        FailureCode.networkOffline,
      );
    });

    test('a field of the wrong type is unusable data, named', () async {
      store.server['users/$uid'] = _profileData()..['currentStreak'] = '3';
      await _expectCode(
        () => repository.getUserProfile(uid),
        FailureCode.dataUnknown,
      );

      store.server['users/$uid'] = _profileData(lastTrainingDate: '16.09.2026');
      await _expectCode(
        () => repository.getUserProfile(uid),
        FailureCode.dataUnknown,
      );
    });

    test('the stream skips an empty local copy and reports a server miss',
        () async {
      final List<Object> seen = <Object>[];
      final StreamSubscription<UserProfile> sub =
          repository.watchUserProfile(uid).listen(
                seen.add,
                onError: (Object e) => seen.add(e),
              );

      StoredDocument doc({required bool exists, required bool fromCache}) =>
          StoredDocument(
            id: uid,
            exists: exists,
            data: exists ? _profileData() : const <String, Object?>{},
            fromCache: fromCache,
          );

      store.watched
        ..add(doc(exists: false, fromCache: true))
        ..add(doc(exists: true, fromCache: true))
        ..add(doc(exists: false, fromCache: false));
      await pumpEventQueue();
      await sub.cancel();

      expect(seen, hasLength(2));
      expect(seen.first, isA<UserProfile>());
      expect(
        seen.last,
        isA<AppException>().having(
          (AppException e) => e.code,
          'code',
          FailureCode.dataNotFound,
        ),
      );
    });
  });

  group('training history', () {
    test('reads newest first, limited, and maps each entry', () async {
      store.server['users/$uid/trainingHistory/2026-09-16'] = <String, Object?>{
        'trainingDate': '2026-09-16',
        'programDay': 4,
        'completedExerciseIds': <Object?>['a', 'b'],
        'durationMinutes': 13,
        'completedAt': DateTime.utc(2026, 9, 16, 9, 14),
      };

      final List<TrainingHistoryEntry> history =
          await repository.getTrainingHistory(uid, limit: 7);

      expect(store.lastCollection, 'users/$uid/trainingHistory');
      expect(store.lastDescendingBy, 'trainingDate');
      expect(store.lastLimit, 7);
      expect(history.single.date, CalendarDay(2026, 9, 16));
      expect(history.single.completedExerciseIds, <String>['a', 'b']);
      expect(history.single.completedAt, DateTime.utc(2026, 9, 16, 9, 14));
    });

    test('an empty list from the server is a user with no history', () async {
      expect(await repository.getTrainingHistory(uid), isEmpty);
    });

    test('an empty list from the local copy is offline, not "no history"',
        () async {
      store.online = false;
      await _expectCode(
        () => repository.getTrainingHistory(uid),
        FailureCode.networkOffline,
      );
    });

    test('a list with a non-string id is unusable data', () async {
      store.server['users/$uid/trainingHistory/2026-09-16'] = <String, Object?>{
        'trainingDate': '2026-09-16',
        'programDay': 4,
        'completedExerciseIds': <Object?>['a', 3],
        'durationMinutes': 13,
      };
      await _expectCode(
        () => repository.getTrainingHistory(uid),
        FailureCode.dataUnknown,
      );
    });

    test('a limit below 1 is refused', () {
      expect(
        () => repository.getTrainingHistory(uid, limit: 0),
        throwsArgumentError,
      );
    });
  });

  group('saving a training day', () {
    test('writes the entry and adds the minutes, in one batch', () async {
      final TrainingSaveResult result =
          await repository.saveTrainingCompletion(uid, _completion());

      expect(result, TrainingSaveResult.saved);
      final List<StoredWrite> batch = store.commits.single;
      expect(batch, hasLength(2));

      final StoredWrite entry = batch[0];
      expect(entry.mode, StoredWriteMode.set);
      expect(entry.path, 'users/$uid/trainingHistory/2026-09-16');
      expect(entry.fields, <String, Object>{
        'trainingDate': '2026-09-16',
        'programDay': 4,
        'completedExerciseIds': <String>[
          'breathing_diaphragm_04',
          'letter_i_01',
        ],
        'durationMinutes': 13,
        'completedAt': storedServerTime,
      });

      final StoredWrite totals = batch[1];
      expect(totals.mode, StoredWriteMode.update);
      expect(totals.path, 'users/$uid');
      expect(totals.fields, <String, Object>{
        'totalTrainingMinutes': const StoredIncrement(13),
      });
    });

    test('a day the local copy already holds writes nothing', () async {
      store.cache['users/$uid/trainingHistory/2026-09-16'] =
          <String, Object?>{};

      expect(
        await repository.saveTrainingCompletion(uid, _completion()),
        TrainingSaveResult.alreadySaved,
      );
      expect(store.commits, isEmpty);
    });

    test('a local copy that knows the day is not recorded still writes',
        () async {
      store.cache['users/$uid/trainingHistory/2026-09-16'] = null;

      expect(
        await repository.saveTrainingCompletion(uid, _completion()),
        TrainingSaveResult.saved,
      );
      expect(store.commits, hasLength(1));
    });

    test('a refusal for a day the server holds is "already saved"', () async {
      store.commitError = _denied();
      store.server['users/$uid/trainingHistory/2026-09-16'] = <String, Object?>{
        'trainingDate': '2026-09-16',
      };

      expect(
        await repository.saveTrainingCompletion(uid, _completion()),
        TrainingSaveResult.alreadySaved,
      );
    });

    test('a refusal for a day the server does not hold is thrown', () async {
      final FirebaseException denied = _denied();
      store.commitError = denied;

      await expectLater(
        repository.saveTrainingCompletion(uid, _completion()),
        throwsA(same(denied)),
      );
      expect(
        mapErrorToFailure(denied).code,
        FailureCode.permissionDenied,
      );
    });

    test('a refusal cannot be confirmed from the local copy alone', () async {
      // The pre-check found nothing, the write was refused, and the read back
      // could only reach the local copy. An entry there is not the server's
      // word, so the refusal stands.
      final FirebaseException denied = _denied();
      store.commitError = denied;
      store.readResult = const StoredDocument(
        id: '2026-09-16',
        exists: true,
        data: <String, Object?>{},
        fromCache: true,
      );

      await expectLater(
        repository.saveTrainingCompletion(uid, _completion()),
        throwsA(same(denied)),
      );
    });

    test('if reading back after a refusal fails, the refusal is thrown',
        () async {
      final FirebaseException denied = _denied();
      store.commitError = denied;
      store.readError = StateError('read failed');

      await expectLater(
        repository.saveTrainingCompletion(uid, _completion()),
        throwsA(same(denied)),
      );
    });

    test('any other failure is thrown as it is, without a read back', () async {
      final FirebaseException unavailable =
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      store.commitError = unavailable;

      await expectLater(
        repository.saveTrainingCompletion(uid, _completion()),
        throwsA(same(unavailable)),
      );
      expect(store.reads, isEmpty);
    });

    test('values the rules refuse are refused before writing', () async {
      final List<TrainingCompletion> bad = <TrainingCompletion>[
        _completion(programDay: 0),
        _completion(ids: const <String>[]),
        _completion(ids: List<String>.filled(51, 'a')),
        _completion(minutes: -1),
        _completion(minutes: 1441),
      ];
      for (final TrainingCompletion completion in bad) {
        expect(
          () => repository.saveTrainingCompletion(uid, completion),
          throwsArgumentError,
          reason: completion.toString(),
        );
      }
      expect(store.commits, isEmpty);

      // The limits themselves are allowed.
      await repository.saveTrainingCompletion(
        uid,
        _completion(ids: List<String>.filled(50, 'a'), minutes: 1440),
      );
      await repository.saveTrainingCompletion(uid, _completion(minutes: 0));
      expect(store.commits, hasLength(2));
    });
  });

  group('exercise completion', () {
    test('increments where stored and stamps the server time', () async {
      await repository.saveExerciseCompletion(uid, 'letter_i_01');

      final StoredWrite write = store.commits.single.single;
      expect(write.mode, StoredWriteMode.merge);
      expect(write.path, 'users/$uid/exerciseProgress/letter_i_01');
      expect(write.fields, <String, Object>{
        'exerciseId': 'letter_i_01',
        'completionCount': const StoredIncrement(1),
        'lastCompletedAt': storedServerTime,
      });
    });

    test('reads every record', () async {
      store.server['users/$uid/exerciseProgress/letter_i_01'] =
          <String, Object?>{
        'exerciseId': 'letter_i_01',
        'completionCount': 6,
        'lastCompletedAt': DateTime.utc(2026, 9, 16),
      };
      // A document in another user's tree is not part of this one.
      store.server['users/other/exerciseProgress/letter_i_01'] =
          <String, Object?>{'exerciseId': 'x', 'completionCount': 1};

      expect(await repository.getExerciseProgress(uid), <ExerciseProgress>[
        ExerciseProgress(
          exerciseId: 'letter_i_01',
          completionCount: 6,
          lastCompletedAt: DateTime.utc(2026, 9, 16),
        ),
      ]);
      expect(store.lastCollection, 'users/$uid/exerciseProgress');
    });

    test('an empty local copy offline is offline', () async {
      store.online = false;
      await _expectCode(
        () => repository.getExerciseProgress(uid),
        FailureCode.networkOffline,
      );
    });
  });

  group('the streak', () {
    Map<String, Object?> profileWith({
      Object? last,
      int current = 0,
      int longest = 0,
    }) =>
        _profileData(lastTrainingDate: last)
          ..['currentStreak'] = current
          ..['longestStreak'] = longest;

    test('counts today, in one transaction, and writes the three fields',
        () async {
      store.server['users/$uid'] = profileWith(
        last: '2026-09-16',
        current: 3,
        longest: 5,
      );

      final StreakUpdate update = await repository.updateStreak(
        uid,
        CalendarDay(2026, 9, 17),
      );

      expect(store.transactions, 1);
      expect(update.currentStreak, 4);
      expect(update.longestStreak, 5);
      expect(update.changed, isTrue);
      expect(store.transactionWrites.single, <String, Object>{
        'currentStreak': 4,
        'longestStreak': 5,
        'lastTrainingDate': '2026-09-17',
      });
      // No batch: a read-then-write cannot be one.
      expect(store.commits, isEmpty);
    });

    test('a day already counted writes nothing at all', () async {
      store.server['users/$uid'] = profileWith(
        last: '2026-09-17',
        current: 4,
        longest: 6,
      );

      final StreakUpdate update = await repository.updateStreak(
        uid,
        CalendarDay(2026, 9, 17),
      );

      expect(update.changed, isFalse);
      expect(update.currentStreak, 4);
      expect(store.transactions, 1);
      expect(store.transactionWrites, isEmpty);
    });

    test('a first training starts the streak and records the day', () async {
      store.server['users/$uid'] = profileWith();

      final StreakUpdate update = await repository.updateStreak(
        uid,
        CalendarDay(2026, 9, 17),
      );

      expect(update.currentStreak, 1);
      expect(update.longestStreak, 1);
      expect(
        store.server['users/$uid']!['lastTrainingDate'],
        '2026-09-17',
      );
    });

    test('a missed day starts again, and the longest streak stays', () async {
      store.server['users/$uid'] = profileWith(
        last: '2026-09-10',
        current: 7,
        longest: 9,
      );

      final StreakUpdate update = await repository.updateStreak(
        uid,
        CalendarDay(2026, 9, 17),
      );

      expect(update.currentStreak, 1);
      expect(update.longestStreak, 9);
      expect(store.transactionWrites.single['longestStreak'], 9);
    });

    test('a profile the server does not have is not found', () async {
      await _expectCode(
        () => repository.updateStreak(uid, CalendarDay(2026, 9, 17)),
        FailureCode.dataNotFound,
      );
    });

    test('an unreadable stored day is unusable data, not a reset', () async {
      // Resetting the streak because a field could not be read would punish
      // the user for a bug.
      store.server['users/$uid'] = profileWith(last: '17.09.2026');

      await _expectCode(
        () => repository.updateStreak(uid, CalendarDay(2026, 9, 17)),
        FailureCode.dataUnknown,
      );
      expect(store.transactionWrites, isEmpty);
    });

    test('a failed transaction is thrown, not swallowed', () async {
      final FirebaseException unavailable =
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      store.transactionError = unavailable;

      await expectLater(
        repository.updateStreak(uid, CalendarDay(2026, 9, 17)),
        throwsA(same(unavailable)),
      );
    });

    test('an id that would address another document is refused', () {
      expect(
        () => repository.updateStreak('a/b', CalendarDay(2026, 9, 17)),
        throwsArgumentError,
      );
      expect(store.transactions, 0);
    });
  });

  group('one training day', () {
    test('reads the entry for a date', () async {
      store.server['users/$uid/trainingHistory/2026-09-18'] = <String, Object?>{
        'trainingDate': '2026-09-18',
        'programDay': 4,
        'completedExerciseIds': <Object?>['a'],
        'durationMinutes': 13,
      };

      final TrainingHistoryEntry? entry = await repository.getTrainingDay(
        uid,
        CalendarDay(2026, 9, 18),
      );

      expect(entry!.programDay, 4);
      expect(entry.date, CalendarDay(2026, 9, 18));
      expect(store.reads, <String>['users/$uid/trainingHistory/2026-09-18']);
    });

    test('a date the server has no entry for is null', () async {
      expect(
        await repository.getTrainingDay(uid, CalendarDay(2026, 9, 18)),
        isNull,
      );
    });

    test('a date the local copy has never seen is offline, not missing',
        () async {
      store.online = false;
      await _expectCode(
        () => repository.getTrainingDay(uid, CalendarDay(2026, 9, 18)),
        FailureCode.networkOffline,
      );
    });

    test('an id that would address another document is refused', () {
      expect(
        () => repository.getTrainingDay('a/b', CalendarDay(2026, 9, 18)),
        throwsArgumentError,
      );
    });
  });

  group('the programme day', () {
    test('moves on when the user is still on the day they finished', () async {
      store.server['users/$uid'] = _profileData()..['currentProgramDay'] = 4;

      expect(await repository.advanceProgramDay(uid, completedDay: 4), 5);
      expect(store.transactions, 1);
      expect(store.transactionWrites.single, <String, Object>{
        'currentProgramDay': 5,
      });
    });

    test('does not move when they already moved on', () async {
      // A second device that already advanced, or the same day finished twice.
      store.server['users/$uid'] = _profileData()..['currentProgramDay'] = 6;

      expect(await repository.advanceProgramDay(uid, completedDay: 4), 6);
      expect(store.transactionWrites, isEmpty);
    });

    test('does not move backwards for an older day', () async {
      store.server['users/$uid'] = _profileData()..['currentProgramDay'] = 2;

      expect(await repository.advanceProgramDay(uid, completedDay: 5), 2);
      expect(store.transactionWrites, isEmpty);
    });

    test('a day below one, or a bad uid, is refused before anything', () {
      expect(
        () => repository.advanceProgramDay(uid, completedDay: 0),
        throwsArgumentError,
      );
      expect(
        () => repository.advanceProgramDay('a/b', completedDay: 1),
        throwsArgumentError,
      );
      expect(store.transactions, 0);
    });

    test('a profile the server does not have is not found', () async {
      await _expectCode(
        () => repository.advanceProgramDay(uid, completedDay: 1),
        FailureCode.dataNotFound,
      );
    });
  });

  group('preferences', () {
    test('reads settings, with and without a reminder time', () async {
      store.server['users/$uid/preferences/settings'] = <String, Object?>{
        'reminderEnabled': true,
        'reminderTime': '19:30',
        'soundEnabled': true,
        'hapticEnabled': false,
      };
      expect(
        await repository.getPreferences(uid),
        UserPreferences(
          reminderEnabled: true,
          reminderTime: ReminderTime(19, 30),
          soundEnabled: true,
          hapticEnabled: false,
        ),
      );

      store.server['users/$uid/preferences/settings']!.remove('reminderTime');
      expect((await repository.getPreferences(uid)).reminderTime, isNull);
    });

    test('a missing settings document is not found', () async {
      await _expectCode(
        () => repository.getPreferences(uid),
        FailureCode.dataNotFound,
      );
    });

    test('an update replaces the document, so a cleared time is removed',
        () async {
      await repository.updatePreferences(
        uid,
        const UserPreferences(
          reminderEnabled: false,
          reminderTime: null,
          soundEnabled: false,
          hapticEnabled: true,
        ),
      );
      final StoredWrite write = store.commits.single.single;
      expect(write.mode, StoredWriteMode.set);
      expect(write.path, 'users/$uid/preferences/settings');
      expect(write.fields, <String, Object>{
        'reminderEnabled': false,
        'soundEnabled': false,
        'hapticEnabled': true,
      });

      await repository.updatePreferences(
        uid,
        UserPreferences(
          reminderEnabled: true,
          reminderTime: ReminderTime(7, 5),
          soundEnabled: true,
          hapticEnabled: true,
        ),
      );
      expect(store.commits.last.single.fields['reminderTime'], '07:05');
    });
  });

  group('ids that would address another document', () {
    test('are refused before anything is read or written', () {
      for (final String bad in <String>['', 'a/b', '../other']) {
        expect(() => repository.getUserProfile(bad), throwsArgumentError);
        expect(() => repository.watchUserProfile(bad), throwsArgumentError);
        expect(
          () => repository.saveExerciseCompletion(uid, bad),
          throwsArgumentError,
        );
        expect(
          () => repository.saveTrainingCompletion(bad, _completion()),
          throwsArgumentError,
        );
        expect(
          () => repository.updatePreferences(
            bad,
            const UserPreferences(
              reminderEnabled: false,
              reminderTime: null,
              soundEnabled: true,
              hapticEnabled: true,
            ),
          ),
          throwsArgumentError,
        );
      }
      expect(store.commits, isEmpty);
      expect(store.reads, isEmpty);
    });
  });

  group('every field written is one the rules allow', () {
    Future<Set<String>> fieldsWrittenTo(String collection) async {
      store.commits.clear();
      await repository.saveTrainingCompletion(uid, _completion());
      await repository.saveExerciseCompletion(uid, 'a');
      await repository.updatePreferences(
        uid,
        UserPreferences(
          reminderEnabled: true,
          reminderTime: ReminderTime(7, 5),
          soundEnabled: true,
          hapticEnabled: true,
        ),
      );
      return <String>{
        for (final List<StoredWrite> batch in store.commits)
          for (final StoredWrite write in batch)
            if (RegExp('^users/[^/]+$collection\$').hasMatch(write.path))
              ...write.fields.keys,
      };
    }

    test('users', () async {
      expect(
        rulesFieldsOf('isValidUser'),
        containsAll(await fieldsWrittenTo('')),
      );
    });

    test('trainingHistory', () async {
      final Set<String> written =
          await fieldsWrittenTo('/trainingHistory/[^/]+');
      // The rules require every history field, so all of them must be written.
      expect(written, rulesFieldsOf('isValidHistory'));
    });

    test('exerciseProgress', () async {
      final Set<String> written =
          await fieldsWrittenTo('/exerciseProgress/[^/]+');
      expect(written, rulesFieldsOf('isValidProgress'));
    });

    test('preferences', () async {
      final Set<String> written =
          await fieldsWrittenTo('/preferences/settings');
      expect(written, rulesFieldsOf('isValidPreferences'));
    });
  });
}
