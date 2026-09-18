import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/progress/domain/repositories/user_progress_repository.dart';
import 'package:hitup/features/training/application/training_session_controller.dart';
import 'package:hitup/features/training/data/session_store.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/domain/training_session.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/progress_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A progress repository that records what completions it was told about.
class _FakeProgress implements UserProgressRepository {
  final List<(String, String)> completions = <(String, String)>[];
  Object? error;

  @override
  Future<void> saveExerciseCompletion(String uid, String exerciseId) async {
    completions.add((uid, exerciseId));
    if (error != null) {
      throw error!;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A session store in memory, which records what it was asked to do.
class _FakeSessionStore implements SessionStore {
  TrainingSession? saved;
  Object? loadError;
  int saves = 0;
  int clears = 0;

  @override
  Future<TrainingSession?> load() async {
    if (loadError != null) {
      throw loadError!;
    }
    return saved;
  }

  @override
  Future<void> save(TrainingSession session) async {
    saves++;
    saved = session;
  }

  @override
  Future<void> clear() async {
    clears++;
    saved = null;
  }
}

Exercise _exercise(String id) => Exercise(
      id: id,
      title: id,
      presentationType: ExercisePresentationType.breathing,
      durationSeconds: 60,
      instructions: 'Nefes al',
    );

TodayTraining _today(List<String> ids) => TodayTraining(
      programDay: 2,
      day: ProgramDay(
        day: 2,
        title: 'Gun 2',
        estimatedMinutes: 10,
        exerciseRefs: <DayExerciseRef>[
          for (int i = 0; i < ids.length; i++)
            DayExerciseRef(exerciseId: ids[i], position: i + 1),
        ],
      ),
      resolved: ResolvedDay(
        exercises: ids.map(_exercise).toList(),
        missingIds: const <String>[],
      ),
    );

void main() {
  late _FakeSessionStore store;
  late _FakeProgress progress;
  late ProviderContainer container;

  /// Builds the container, signed in as [uid] unless it is null.
  void buildContainer({String? uid = 'uid-1'}) {
    container = ProviderContainer(
      overrides: <Override>[
        sessionStoreProvider.overrideWithValue(store),
        userProgressRepositoryProvider.overrideWithValue(progress),
        authStateChangesProvider.overrideWith(
          (Ref ref) => Stream<AuthUser?>.value(
            uid == null ? null : AuthUser(uid: uid),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  setUp(() {
    store = _FakeSessionStore();
    progress = _FakeProgress();
    buildContainer();
  });

  TrainingSessionController controller() =>
      container.read(trainingSessionControllerProvider.notifier);

  TrainingSession? current() =>
      container.read(trainingSessionControllerProvider);

  group('holding a session', () {
    test('there is none until one is begun', () {
      expect(current(), isNull);
    });

    test('beginning starts it on the first exercise and saves it', () async {
      final TrainingSession session = controller().begin(
        _today(<String>['a', 'b']),
      );
      await pumpEventQueue();

      expect(session.status, SessionStatus.inProgress);
      expect(current(), session);
      expect(store.saved, session);
      expect(store.saves, 1);
    });

    test('every transition is written down', () async {
      controller().begin(_today(<String>['a', 'b']));
      controller().completeCurrentExercise();
      controller().pause();
      await pumpEventQueue();

      expect(store.saved!.status, SessionStatus.paused);
      expect(store.saved!.completedExerciseIds, <String>['a']);
      expect(store.saves, 3);
    });

    test('acting with no session in hand is a caller bug', () {
      expect(() => controller().pause(), throwsStateError);
      expect(() => controller().completeCurrentExercise(), throwsStateError);
      expect(() => controller().finish(), throwsStateError);
    });

    test('skipping and finishing go through it too', () async {
      controller().begin(_today(<String>['a', 'b', 'c']));
      controller().skipCurrentExercise();
      controller().completeCurrentExercise();
      controller().finish();
      await pumpEventQueue();

      expect(current()!.status, SessionStatus.completed);
      expect(current()!.completedExerciseIds, <String>['b']);
      expect(current()!.isFullyCompleted, isFalse);
      expect(store.saved, current());
    });

    test('an illegal transition still throws through the controller', () {
      controller().begin(_today(<String>['a']));

      expect(() => controller().resume(), throwsStateError);
    });

    test('discarding forgets it here and on the device', () async {
      controller().begin(_today(<String>['a']));
      await controller().discard();

      expect(current(), isNull);
      expect(store.saved, isNull);
      expect(store.clears, 1);
    });
  });

  group('resuming what was left', () {
    test('an unfinished session comes back', () async {
      store.saved = TrainingSession(
        programDay: 2,
        exerciseIds: const <String>['a', 'b'],
        status: SessionStatus.paused,
        currentIndex: 1,
        completedExerciseIds: const <String>['a'],
      );

      final TrainingSession? restored = await controller().restore();

      expect(restored, store.saved);
      expect(current(), store.saved);
    });

    test('a finished one is not offered', () async {
      // Left over from a run that ended without being cleared. Resuming it
      // would put the user back on a day they already finished.
      store.saved = TrainingSession(
        programDay: 2,
        exerciseIds: const <String>['a'],
        status: SessionStatus.completed,
        currentIndex: 0,
        completedExerciseIds: const <String>['a'],
      );

      expect(await controller().restore(), isNull);
      expect(current(), isNull);
    });

    test('nothing saved means nothing to resume', () async {
      expect(await controller().restore(), isNull);
      expect(current(), isNull);
    });
  });

  group('what is written to the device', () {
    test('a session survives a round trip through json', () {
      final TrainingSession session = TrainingSession(
        programDay: 4,
        exerciseIds: const <String>['a', 'b', 'c'],
        status: SessionStatus.paused,
        currentIndex: 2,
        completedExerciseIds: const <String>['a', 'b'],
      );

      expect(sessionFromJson(sessionToJson(session)), session);
    });

    test('a malformed record is refused rather than guessed at', () {
      final Map<String, Object?> good = sessionToJson(
        TrainingSession(
          programDay: 1,
          exerciseIds: const <String>['a'],
          status: SessionStatus.inProgress,
          currentIndex: 0,
          completedExerciseIds: const <String>[],
        ),
      );

      for (final MapEntry<String, Object?> broken in <String, Object?>{
        'programDay': 'one',
        'exerciseIds': <Object?>['a', 3],
        'status': 'flying',
        'currentIndex': null,
        'completedExerciseIds': 'a',
      }.entries) {
        expect(
          () => sessionFromJson(<String, dynamic>{
            ...good,
            broken.key: broken.value,
          }),
          throwsFormatException,
          reason: broken.key,
        );
      }
    });

    test('a status a newer app added is refused, not guessed', () {
      // Guessing which state that was is worse than starting the day again.
      expect(
        () => sessionFromJson(<String, dynamic>{
          'programDay': 1,
          'exerciseIds': <String>['a'],
          'status': 'rewinding',
          'currentIndex': 0,
          'completedExerciseIds': <String>[],
        }),
        throwsFormatException,
      );
    });
  });

  group('the device store itself', () {
    setUp(() {
      // The plugin's own in-memory stand-in, so the real store is exercised
      // rather than only the fake above.
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    const PreferencesSessionStore device = PreferencesSessionStore();

    TrainingSession session() => TrainingSession(
          programDay: 3,
          exerciseIds: const <String>['a', 'b'],
          status: SessionStatus.paused,
          currentIndex: 1,
          completedExerciseIds: const <String>['a'],
        );

    test('saves, reads back, and forgets', () async {
      expect(await device.load(), isNull);

      await device.save(session());
      expect(await device.load(), session());

      await device.clear();
      expect(await device.load(), isNull);
    });

    test('a later save replaces the earlier one', () async {
      await device.save(session());
      await device.save(session().resume());

      expect((await device.load())!.status, SessionStatus.inProgress);
    });

    test('a record it cannot read is no session, not a crash', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesSessionStore.key: 'not json at all',
      });
      expect(await device.load(), isNull);

      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesSessionStore.key: jsonEncode(<String, Object?>{
          'programDay': 1,
          'exerciseIds': <String>['a'],
          'status': 'rewinding',
          'currentIndex': 0,
          'completedExerciseIds': <String>[],
        }),
      });
      expect(await device.load(), isNull);
    });

    test('the unreadable record is left in place, not deleted', () async {
      // A later version of the app may still make sense of it.
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesSessionStore.key: 'not json at all',
      });
      await device.load();

      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      expect(preferences.getString(PreferencesSessionStore.key), isNotNull);
    });
  });

  group('counting completions on the account (HIT-052)', () {
    test('a completed exercise is counted, by id, for the signed-in user',
        () async {
      // The provider has to have emitted before the controller can read the
      // account off it, which is what a screen's own build would have done.
      container.listen(authStateChangesProvider, (_, __) {});
      await pumpEventQueue();

      controller().begin(_today(<String>['a', 'b']));
      controller().completeCurrentExercise();
      await pumpEventQueue();

      expect(progress.completions, <(String, String)>[('uid-1', 'a')]);
    });

    test('a skipped exercise is not counted', () async {
      container.listen(authStateChangesProvider, (_, __) {});
      await pumpEventQueue();

      controller().begin(_today(<String>['a', 'b']));
      controller().skipCurrentExercise();
      controller().completeCurrentExercise();
      await pumpEventQueue();

      expect(progress.completions, <(String, String)>[('uid-1', 'b')]);
    });

    test('a signed-out user still runs the session, nothing is counted',
        () async {
      buildContainer(uid: null);
      container.listen(authStateChangesProvider, (_, __) {});
      await pumpEventQueue();

      controller().begin(_today(<String>['a']));
      controller().completeCurrentExercise();
      await pumpEventQueue();

      expect(progress.completions, isEmpty);
      expect(current()!.completedExerciseIds, <String>['a']);
      expect(current()!.status, SessionStatus.completed);
    });

    test('a failed count does not fail the session', () async {
      // The exercise was done on the device. Whether the count reached the
      // server is a separate question, and not one the user is doing.
      progress.error = StateError('offline for good');
      container.listen(authStateChangesProvider, (_, __) {});
      await pumpEventQueue();

      controller().begin(_today(<String>['a', 'b']));
      controller().completeCurrentExercise();
      await pumpEventQueue();

      expect(current()!.currentExerciseId, 'b');
      expect(current()!.completedExerciseIds, <String>['a']);
      expect(store.saved, current());
    });
  });
}
