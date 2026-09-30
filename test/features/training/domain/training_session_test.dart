import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/domain/training_session.dart';

Exercise _exercise(String id) => Exercise(
      id: id,
      title: id,
      presentationType: ExercisePresentationType.breathing,
      durationSeconds: 60,
      instructions: 'Nefes al',
    );

TodayTraining _today(List<String> ids, {int programDay = 3}) => TodayTraining(
      programDay: programDay,
      day: ProgramDay(
        day: programDay,
        title: 'Gun $programDay',
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

TrainingSession _session(List<String> ids) =>
    TrainingSession.forToday(_today(ids));

void main() {
  group('a new session', () {
    test('starts before the first exercise, with nothing done', () {
      final TrainingSession session = _session(<String>['a', 'b', 'c']);

      expect(session.status, SessionStatus.notStarted);
      expect(session.programDay, 3);
      expect(session.exerciseIds, <String>['a', 'b', 'c']);
      expect(session.currentIndex, 0);
      expect(session.currentExerciseId, 'a');
      expect(session.completedExerciseIds, isEmpty);
      expect(session.progress, 0);
      expect(session.isFullyCompleted, isFalse);
      expect(session.isResumable, isFalse);
    });

    test('a day with nothing to run cannot become a session', () {
      // A finished programme, or a day whose exercises this build cannot
      // render. The screen checks isEmpty before offering to start.
      expect(
        () => TrainingSession.forToday(
          const TodayTraining.programFinished(programDay: 15),
        ),
        throwsArgumentError,
      );
      // The message matters: an empty day and an index out of range both
      // throw, and only the message says which mistake was made.
      expect(
        () => _session(const <String>[]),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message,
            'message',
            contains('at least one exercise'),
          ),
        ),
      );
    });

    test('an index outside the day, or a day below one, is refused', () {
      for (final int index in <int>[1, -1]) {
        expect(
          () => TrainingSession(
            programDay: 1,
            exerciseIds: const <String>['a'],
            status: SessionStatus.inProgress,
            currentIndex: index,
            completedExerciseIds: const <String>[],
          ),
          throwsArgumentError,
          reason: 'index $index',
        );
      }
      expect(
        () => TrainingSession(
          programDay: 0,
          exerciseIds: const <String>['a'],
          status: SessionStatus.notStarted,
          currentIndex: 0,
          completedExerciseIds: const <String>[],
        ),
        throwsArgumentError,
      );
    });
  });

  group('running through a day', () {
    test('completing an exercise moves to the next one', () {
      final TrainingSession session =
          _session(<String>['a', 'b', 'c']).start().completeCurrentExercise();

      expect(session.status, SessionStatus.inProgress);
      expect(session.currentExerciseId, 'b');
      expect(session.completedExerciseIds, <String>['a']);
      expect(session.progress, closeTo(1 / 3, 0.001));
    });

    test('completing the last one completes the session', () {
      TrainingSession session = _session(<String>['a', 'b']).start();
      session = session.completeCurrentExercise().completeCurrentExercise();

      expect(session.status, SessionStatus.completed);
      expect(session.completedExerciseIds, <String>['a', 'b']);
      expect(session.isFullyCompleted, isTrue);
      expect(session.progress, 1);
      // The index stays where it stopped, so a summary can name the exercise.
      expect(session.currentExerciseId, 'b');
    });

    test('a skipped exercise is passed but not recorded', () {
      TrainingSession session = _session(<String>['a', 'b', 'c']).start();
      session = session.skipCurrentExercise().completeCurrentExercise();

      expect(session.currentExerciseId, 'c');
      expect(session.completedExerciseIds, <String>['b']);
      expect(session.isFullyCompleted, isFalse);
    });

    test('skipping the last one still ends the session, unfinished', () {
      TrainingSession session = _session(<String>['a', 'b']).start();
      session = session.completeCurrentExercise().skipCurrentExercise();

      expect(session.status, SessionStatus.completed);
      expect(session.completedExerciseIds, <String>['a']);
      expect(session.isFullyCompleted, isFalse);
    });

    test('pausing keeps the exercise, resuming carries on from it', () {
      TrainingSession session = _session(<String>['a', 'b']).start();
      session = session.completeCurrentExercise().pause();

      expect(session.status, SessionStatus.paused);
      expect(session.currentExerciseId, 'b');
      expect(session.isResumable, isTrue);

      session = session.resume();
      expect(session.status, SessionStatus.inProgress);
      expect(session.currentExerciseId, 'b');
    });

    test('finishing early keeps what was done', () {
      TrainingSession session =
          _session(<String>['a', 'b', 'c']).start().completeCurrentExercise();
      session = session.finish();

      expect(session.status, SessionStatus.completed);
      expect(session.completedExerciseIds, <String>['a']);
      expect(session.isFullyCompleted, isFalse);
      expect(session.isResumable, isFalse);
    });

    test('a double tap on complete records the exercise once', () {
      // The same exercise cannot be current twice in a row, but a screen that
      // fires the callback twice before rebuilding would ask for it.
      final TrainingSession session = TrainingSession(
        programDay: 1,
        exerciseIds: const <String>['a', 'b'],
        status: SessionStatus.inProgress,
        currentIndex: 0,
        completedExerciseIds: const <String>['a'],
      ).completeCurrentExercise();

      expect(session.completedExerciseIds, <String>['a']);
      expect(session.currentExerciseId, 'b');
    });
  });

  group('illegal transitions', () {
    TrainingSession inState(SessionStatus status) => TrainingSession(
          programDay: 1,
          exerciseIds: const <String>['a', 'b'],
          status: status,
          currentIndex: 0,
          completedExerciseIds: const <String>[],
        );

    test('starting something already started', () {
      expect(() => inState(SessionStatus.inProgress).start(), throwsStateError);
      expect(() => inState(SessionStatus.paused).start(), throwsStateError);
      expect(() => inState(SessionStatus.completed).start(), throwsStateError);
    });

    test('pausing what is not running', () {
      expect(() => inState(SessionStatus.notStarted).pause(), throwsStateError);
      expect(() => inState(SessionStatus.paused).pause(), throwsStateError);
      expect(() => inState(SessionStatus.completed).pause(), throwsStateError);
    });

    test('resuming what is not paused', () {
      expect(
        () => inState(SessionStatus.notStarted).resume(),
        throwsStateError,
      );
      expect(
        () => inState(SessionStatus.inProgress).resume(),
        throwsStateError,
      );
      expect(() => inState(SessionStatus.completed).resume(), throwsStateError);
    });

    test('advancing a session that is not running', () {
      for (final SessionStatus status in <SessionStatus>[
        SessionStatus.notStarted,
        SessionStatus.paused,
        SessionStatus.completed,
      ]) {
        expect(
          () => inState(status).completeCurrentExercise(),
          throwsStateError,
          reason: status.name,
        );
        expect(
          () => inState(status).skipCurrentExercise(),
          throwsStateError,
          reason: status.name,
        );
      }
    });

    test('finishing what is already over', () {
      expect(() => inState(SessionStatus.completed).finish(), throwsStateError);
      // Finishing from anywhere else is allowed: a user can leave before
      // starting the first exercise.
      expect(
        inState(SessionStatus.notStarted).finish().status,
        SessionStatus.completed,
      );
      expect(
        inState(SessionStatus.paused).finish().status,
        SessionStatus.completed,
      );
    });

    test('every state answers what it allows, so a screen can ask first', () {
      expect(inState(SessionStatus.notStarted).canStart, isTrue);
      expect(inState(SessionStatus.notStarted).canPause, isFalse);
      expect(inState(SessionStatus.inProgress).canAdvance, isTrue);
      expect(inState(SessionStatus.paused).canResume, isTrue);
      expect(inState(SessionStatus.paused).canAdvance, isFalse);
      expect(inState(SessionStatus.completed).canFinish, isFalse);
    });

    test('only a started session that is not over can be resumed', () {
      expect(inState(SessionStatus.notStarted).isResumable, isFalse);
      expect(inState(SessionStatus.inProgress).isResumable, isTrue);
      expect(inState(SessionStatus.paused).isResumable, isTrue);
      expect(inState(SessionStatus.completed).isResumable, isFalse);
    });
  });

  group('as a value', () {
    test('compares by every field, and prints where it is', () {
      TrainingSession session({
        int day = 1,
        List<String> ids = const <String>['a', 'b'],
        SessionStatus status = SessionStatus.inProgress,
        int index = 0,
        List<String> completed = const <String>['a'],
      }) =>
          TrainingSession(
            programDay: day,
            exerciseIds: ids,
            status: status,
            currentIndex: index,
            completedExerciseIds: completed,
          );

      expect(session(), session());
      expect(session().hashCode, session().hashCode);
      // Equal lists, not the same list, are the same session.
      expect(
        session(ids: <String>['a', 'b'], completed: <String>['a']),
        session(),
      );
      expect(session(day: 2), isNot(session()));
      expect(session(ids: const <String>['a', 'c']), isNot(session()));
      expect(session(status: SessionStatus.paused), isNot(session()));
      expect(session(index: 1), isNot(session()));
      expect(session(completed: const <String>[]), isNot(session()));
      expect(session().toString(), 'TrainingSession(day 1, inProgress, 1/2)');
    });

    test('the lists it hands out cannot be changed from outside', () {
      final TrainingSession session = _session(<String>['a', 'b']);

      expect(() => session.exerciseIds.add('c'), throwsUnsupportedError);
      expect(
        () => session.completedExerciseIds.add('a'),
        throwsUnsupportedError,
      );
    });

    test('the lists it is given are copied, not kept', () {
      final List<String> ids = <String>['a', 'b'];
      final List<String> completed = <String>['a'];
      final TrainingSession session = TrainingSession(
        programDay: 1,
        exerciseIds: ids,
        status: SessionStatus.inProgress,
        currentIndex: 1,
        completedExerciseIds: completed,
      );

      ids.add('c');
      completed.add('b');

      expect(session.exerciseIds, <String>['a', 'b']);
      expect(session.completedExerciseIds, <String>['a']);
      expect(() => session.exerciseIds.add('c'), throwsUnsupportedError);
      expect(
        () => session.completedExerciseIds.add('b'),
        throwsUnsupportedError,
      );
    });
  });
}
