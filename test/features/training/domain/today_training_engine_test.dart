import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/app_exception.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/features/progress/domain/repositories/user_progress_repository.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/domain/repositories/curriculum_repository.dart';
import 'package:hitup/features/training/domain/today_training_engine.dart';

const ContentEnvelope _envelope = ContentEnvelope(
  schemaVersion: '1.0.0',
  contentVersion: '1.0.0',
  status: ContentStatus.placeholder,
  locale: 'tr-TR',
);

Exercise _exercise(String id, {int seconds = 60}) => Exercise(
      id: id,
      title: id,
      presentationType: ExercisePresentationType.breathing,
      durationSeconds: seconds,
      instructions: 'Nefes al',
    );

ProgramDay _day(int number, List<String> ids, {int estimatedMinutes = 10}) =>
    ProgramDay(
      day: number,
      title: 'Gun $number',
      estimatedMinutes: estimatedMinutes,
      exerciseRefs: <DayExerciseRef>[
        for (int i = 0; i < ids.length; i++)
          DayExerciseRef(exerciseId: ids[i], position: i + 1),
      ],
    );

TrainingProgram _program(List<ProgramDay> days) => TrainingProgram(
      envelope: _envelope,
      programId: 'mvp',
      title: 'MVP',
      days: days,
    );

ExerciseLibrary _library(List<Exercise> exercises) => ExerciseLibrary(
      envelope: _envelope,
      exercises: exercises,
      skippedIds: const <String>[],
    );

/// A curriculum that hands back fixtures and counts the reads.
class _FakeCurriculum implements CurriculumRepository {
  _FakeCurriculum(this.program, this.library);

  final TrainingProgram program;
  final ExerciseLibrary library;
  int programReads = 0;

  @override
  Future<TrainingProgram> loadProgram() async {
    programReads++;
    return program;
  }

  @override
  Future<ExerciseLibrary> loadExercises() async => library;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A progress repository that answers with a day or fails on request.
class _FakeProgress implements UserProgressRepository {
  int day = 1;
  Object? error;
  final List<String> asked = <String>[];

  @override
  Future<int> getCurrentProgramDay(String uid) async {
    asked.add(uid);
    if (error != null) {
      throw error!;
    }
    return day;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  final TrainingProgram program = _program(<ProgramDay>[
    _day(1, <String>['breathing_01', 'letter_a_01']),
    _day(2, <String>['breathing_02'], estimatedMinutes: 6),
    _day(3, <String>['breathing_03', 'twister_01', 'letter_b_01']),
  ]);
  final ExerciseLibrary library = _library(<Exercise>[
    _exercise('breathing_01', seconds: 90),
    _exercise('letter_a_01', seconds: 120),
    _exercise('breathing_02', seconds: 45),
    _exercise('breathing_03'),
    _exercise('twister_01'),
    _exercise('letter_b_01'),
  ]);

  late _FakeCurriculum curriculum;
  late _FakeProgress progress;
  late TodayTrainingEngine engine;

  setUp(() {
    curriculum = _FakeCurriculum(program, library);
    progress = _FakeProgress();
    engine = TodayTrainingEngine(curriculum: curriculum, progress: progress);
  });

  group('the day the user is on', () {
    test('day one returns its exercises in order, with both totals', () {
      final TodayTraining today =
          engine.build(programDay: 1, program: program, library: library);

      expect(today.programDay, 1);
      expect(today.isProgramFinished, isFalse);
      expect(today.day?.title, 'Gun 1');
      expect(
        today.exercises.map((Exercise e) => e.id),
        <String>['breathing_01', 'letter_a_01'],
      );
      // 90 + 120 seconds of exercise inside a day estimated at 10 minutes.
      expect(today.totalDuration, const Duration(minutes: 3, seconds: 30));
      expect(today.estimatedDuration, const Duration(minutes: 10));
      expect(today.isComplete, isTrue);
      expect(today.isEmpty, isFalse);
      expect(today.programDayAssumed, isFalse);
      expect(today.toString(), 'TodayTraining(day 1, 2 exercises)');
    });

    test('a later day returns that day, not the first', () {
      final TodayTraining today =
          engine.build(programDay: 2, program: program, library: library);

      expect(today.programDay, 2);
      expect(today.exercises.single.id, 'breathing_02');
      expect(today.totalDuration, const Duration(seconds: 45));
      expect(today.estimatedDuration, const Duration(minutes: 6));
    });

    test('the same inputs always give the same result', () {
      final TodayTraining first =
          engine.build(programDay: 3, program: program, library: library);
      final TodayTraining second =
          engine.build(programDay: 3, program: program, library: library);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        first.exercises.map((Exercise e) => e.id),
        <String>['breathing_03', 'twister_01', 'letter_b_01'],
      );
    });

    test('an assumed day is not the same value as a read one', () {
      // Same day, same exercises, but one of them is a guess. A screen that
      // wants to say so needs the two to be distinguishable.
      final TodayTraining read = engine.build(
        programDay: 1,
        program: program,
        library: library,
      );
      final TodayTraining assumed = engine.build(
        programDay: 1,
        program: program,
        library: library,
        programDayAssumed: true,
      );

      expect(assumed, isNot(read));
      expect(assumed.hashCode, isNot(read.hashCode));
      expect(assumed.exercises, read.exercises);
    });
  });

  group('edges', () {
    test('an exercise this build cannot find is reported, the rest runs', () {
      final TodayTraining today = engine.build(
        programDay: 3,
        program: program,
        library: _library(<Exercise>[_exercise('twister_01')]),
      );

      expect(today.exercises.single.id, 'twister_01');
      expect(
        today.missingExerciseIds,
        <String>['breathing_03', 'letter_b_01'],
      );
      expect(today.isComplete, isFalse);
      expect(today.isEmpty, isFalse);
    });

    test('a day whose every exercise is missing is empty but not finished', () {
      final TodayTraining today = engine.build(
        programDay: 2,
        program: program,
        library: _library(const <Exercise>[]),
      );

      expect(today.isEmpty, isTrue);
      expect(today.isProgramFinished, isFalse);
      expect(today.missingExerciseIds, <String>['breathing_02']);
      expect(today.totalDuration, Duration.zero);
    });

    test('past the last day the programme is finished, not looped', () {
      final TodayTraining today =
          engine.build(programDay: 4, program: program, library: library);

      expect(today.isProgramFinished, isTrue);
      expect(today.programDay, 4);
      expect(today.day, isNull);
      expect(today.exercises, isEmpty);
      expect(today.isEmpty, isTrue);
      expect(today.estimatedDuration, Duration.zero);
      expect(today.totalDuration, Duration.zero);
      expect(today.toString(), contains('programme finished'));
    });

    test('a day below one starts at day one', () {
      for (final int stored in <int>[0, -3]) {
        final TodayTraining today = engine.build(
          programDay: stored,
          program: program,
          library: library,
        );
        expect(today.programDay, 1, reason: 'stored $stored');
        expect(today.exercises.first.id, 'breathing_01');
      }
    });

    test('a hole in the programme is a content failure, not a finished one',
        () {
      final TrainingProgram holed = _program(<ProgramDay>[
        _day(1, <String>['breathing_01']),
        _day(3, <String>['breathing_03']),
      ]);

      expect(
        () => engine.build(programDay: 2, program: holed, library: library),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.code,
            'code',
            FailureCode.contentMalformed,
          ),
        ),
      );
    });

    test('a programme with no days is a content failure', () {
      expect(
        () => engine.build(
          programDay: 1,
          program: _program(const <ProgramDay>[]),
          library: library,
        ),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.code,
            'code',
            FailureCode.contentMalformed,
          ),
        ),
      );
    });
  });

  group('reading the user\'s day', () {
    test('todayFor asks the repository for that user', () async {
      progress.day = 2;

      final TodayTraining today = await engine.todayFor('uid-1');

      expect(progress.asked, <String>['uid-1']);
      expect(today.programDay, 2);
      expect(today.exercises.single.id, 'breathing_02');
      expect(today.programDayAssumed, isFalse);
      expect(curriculum.programReads, 1);
    });

    test('an unreachable profile falls back to day one, marked as assumed',
        () async {
      progress.error = const AppException(
        'nothing cached',
        code: FailureCode.networkOffline,
      );

      final TodayTraining today = await engine.todayFor('uid-1');

      expect(today.programDay, TodayTrainingEngine.fallbackProgramDay);
      expect(today.programDay, 1);
      expect(today.programDayAssumed, isTrue);
      expect(today.exercises, hasLength(2));
    });

    test('a Firestore outage also falls back', () async {
      progress.error =
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

      final TodayTraining today = await engine.todayFor('uid-1');

      expect(today.programDayAssumed, isTrue);
      expect(today.programDay, 1);
    });

    test('a refusal is thrown, not hidden behind day one', () async {
      progress.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      await expectLater(
        engine.todayFor('uid-1'),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('a missing profile is thrown, not hidden behind day one', () async {
      progress.error = const AppException(
        'no profile',
        code: FailureCode.dataNotFound,
      );

      await expectLater(engine.todayFor('uid-1'), throwsA(isA<AppException>()));
    });
  });
}
