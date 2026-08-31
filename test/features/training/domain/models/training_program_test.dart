import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/training/domain/models/models.dart';

/// Tests for the training program models (HIT-023).
///
/// The program is the spine of the app: a user's `currentProgramDay` is a
/// number in this file, and "today's training" is a lookup into it. Most of
/// what is checked here is about that number staying trustworthy.
///
/// The real `assets/content/program.json` is parsed rather than a fixture, for
/// the same reason as the exercise tests: a fixture drifts, and the case worth
/// catching is content changing until the models stop matching it.
void main() {
  Map<String, dynamic> readFile(String name) {
    final File file = File('assets/content/$name');
    expect(file.existsSync(), isTrue, reason: '$name must ship');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  Map<String, dynamic> validDay({
    int day = 1,
    List<String> ids = const <String>['intro_text_01'],
    int minutes = 5,
  }) =>
      <String, dynamic>{
        'day': day,
        'title': 'Gün $day',
        'estimatedMinutes': minutes,
        'exerciseIds': ids,
      };

  Map<String, dynamic> programWith(List<Map<String, dynamic>> days) =>
      <String, dynamic>{
        'schemaVersion': '1.0.0',
        'contentVersion': '0.1.0',
        'status': 'placeholder',
        'locale': 'tr-TR',
        'programId': 'hitup_mvp',
        'title': 'Program',
        'days': days,
      };

  group('the shipped program.json', () {
    test('parses and carries its identity', () {
      final TrainingProgram program = TrainingProgram.fromJson(
        readFile('program.json'),
      );

      expect(program.programId, isNotEmpty);
      expect(program.title, isNotEmpty);
      expect(program.days, isNotEmpty);
      expect(program.envelope.status, ContentStatus.placeholder);
    });

    test('day numbers run from one with no gaps', () {
      // currentProgramDay indexes into this. A gap would make "tomorrow" mean
      // something different depending on where you asked from.
      final TrainingProgram program = TrainingProgram.fromJson(
        readFile('program.json'),
      );

      expect(
        program.days.map((ProgramDay d) => d.day),
        List<int>.generate(program.dayCount, (int i) => i + 1),
      );
    });

    test('every exercise a day names exists in the exercise library', () {
      // The cross file reference the schema promises. Broken, a day would
      // silently run short on a device with no way to recover.
      final TrainingProgram program = TrainingProgram.fromJson(
        readFile('program.json'),
      );
      final ExerciseLibrary library = ExerciseLibrary.fromJson(
        readFile('exercises.json'),
      );

      for (final ProgramDay day in program.days) {
        final ResolvedDay resolved = day.resolve(library);

        expect(
          resolved.missingIds,
          isEmpty,
          reason: 'day ${day.day} references ids the library does not have',
        );
        expect(resolved.isComplete, isTrue);
        expect(resolved.exercises, hasLength(day.exerciseCount));
      }
    });

    test('the authored estimate is in the same country as the real total', () {
      // The two are authored separately and can drift. This is not an exact
      // match on purpose: the estimate is a human rounding, not a sum. It
      // catches an estimate that has stopped describing the day at all.
      final TrainingProgram program = TrainingProgram.fromJson(
        readFile('program.json'),
      );
      final ExerciseLibrary library = ExerciseLibrary.fromJson(
        readFile('exercises.json'),
      );

      for (final ProgramDay day in program.days) {
        final Duration actual = day.resolve(library).actualDuration;
        final Duration estimate = day.estimatedDuration;

        expect(
          actual.inSeconds,
          lessThanOrEqualTo(estimate.inSeconds * 3),
          reason:
              'day ${day.day} is estimated at ${estimate.inMinutes} minutes '
              'but its exercises add up to ${actual.inSeconds} seconds',
        );
      }
    });
  });

  group('a day', () {
    test('numbers its exercises from one, and indexes them from zero', () {
      // A screen shows "2 / 5"; a list is indexed from 0. Holding both means
      // no caller has to do the off by one itself.
      final ProgramDay day = ProgramDay.fromJson(
        validDay(ids: <String>['a_01', 'b_01', 'c_01']),
      );

      expect(day.exerciseRefs.map((DayExerciseRef r) => r.position), <int>[
        1,
        2,
        3,
      ]);
      expect(
        day.exerciseRefs.map((DayExerciseRef r) => r.index),
        <int>[0, 1, 2],
      );
      expect(day.exerciseIds, <String>['a_01', 'b_01', 'c_01']);
      expect(day.exerciseCount, 3);
    });

    test('the same exercise twice in one day is rejected', () {
      // Almost certainly a copy paste, and it would show as "2 / 5" and
      // "4 / 5" being the same drill.
      expect(
        () => ProgramDay.fromJson(validDay(ids: <String>['a_01', 'a_01'])),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('a_01'), contains('twice')),
          ),
        ),
      );
    });

    test('a day with no exercises is rejected', () {
      expect(
        () => ProgramDay.fromJson(validDay(ids: <String>[])),
        throwsFormatException,
      );
    });

    test('a day number below one is rejected', () {
      expect(
        () => ProgramDay.fromJson(validDay(day: 0)),
        throwsFormatException,
      );
    });

    test('an estimate of zero minutes is rejected', () {
      expect(
        () => ProgramDay.fromJson(validDay(minutes: 0)),
        throwsFormatException,
      );
    });

    test('a missing field names the day it came from', () {
      final Map<String, dynamic> json = validDay(day: 7)..remove('title');

      expect(
        () => ProgramDay.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('title'), contains('day 7')),
          ),
        ),
      );
    });

    test('the exercise list cannot be modified by a caller', () {
      final ProgramDay day = ProgramDay.fromJson(validDay());

      expect(() => day.exerciseRefs.clear(), throwsUnsupportedError);
      expect(() => day.exerciseIds.clear(), throwsUnsupportedError);
    });

    test('days compare by content, including exercise order', () {
      final ProgramDay a = ProgramDay.fromJson(
        validDay(ids: <String>['a_01', 'b_01']),
      );
      final ProgramDay b = ProgramDay.fromJson(
        validDay(ids: <String>['a_01', 'b_01']),
      );
      final ProgramDay reordered = ProgramDay.fromJson(
        validDay(ids: <String>['b_01', 'a_01']),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(reordered), reason: 'order is what the day teaches');
      expect(a, isNot(ProgramDay.fromJson(validDay(minutes: 6))));
      expect(a, isNot(ProgramDay.fromJson(validDay(day: 2))));
    });

    test('each field on its own is enough to break equality', () {
      // The test above varies the day number through `validDay`, which also
      // rewrites the title. So it passes whether or not `day` is part of `==`:
      // the two objects still differ by title either way. These vary one field
      // at a time, which is what actually pins the day number down.
      Map<String, dynamic> dayJson({
        int number = 1,
        String title = 'Aynı başlık',
        int minutes = 5,
        List<String> ids = const <String>['a_01'],
      }) =>
          <String, dynamic>{
            'day': number,
            'title': title,
            'estimatedMinutes': minutes,
            'exerciseIds': ids,
          };

      final ProgramDay base = ProgramDay.fromJson(dayJson());

      expect(base, ProgramDay.fromJson(dayJson()));
      expect(base.hashCode, ProgramDay.fromJson(dayJson()).hashCode);
      expect(base, isNot(ProgramDay.fromJson(dayJson(number: 2))));
      expect(base, isNot(ProgramDay.fromJson(dayJson(title: 'Başka'))));
      expect(base, isNot(ProgramDay.fromJson(dayJson(minutes: 6))));
      expect(base, isNot(ProgramDay.fromJson(dayJson(ids: <String>['b_01']))));
    });
  });

  group('resolving a day against the library', () {
    ExerciseLibrary library() =>
        ExerciseLibrary.fromJson(readFile('exercises.json'));

    test('an id the library does not have is reported, not thrown', () {
      // A day that lost one exercise should still run the rest. The caller
      // decides what to do about the gap.
      final ProgramDay day = ProgramDay.fromJson(
        validDay(ids: <String>['intro_text_01', 'no_such_exercise_99']),
      );

      final ResolvedDay resolved = day.resolve(library());

      expect(resolved.exercises, hasLength(1));
      expect(resolved.missingIds, <String>['no_such_exercise_99']);
      expect(resolved.isComplete, isFalse);
      expect(resolved.isEmpty, isFalse);
    });

    test('a day where nothing resolves says so', () {
      final ProgramDay day = ProgramDay.fromJson(
        validDay(ids: <String>['nope_01', 'nope_02']),
      );

      final ResolvedDay resolved = day.resolve(library());

      expect(resolved.isEmpty, isTrue);
      expect(resolved.missingIds, hasLength(2));
      expect(resolved.actualDuration, Duration.zero);
    });

    test('resolved exercises keep the order the day listed them', () {
      final ProgramDay day = ProgramDay.fromJson(
        validDay(ids: <String>['letter_r_01', 'intro_text_01']),
      );

      expect(
        day.resolve(library()).exercises.map((Exercise e) => e.id),
        <String>['letter_r_01', 'intro_text_01'],
      );
    });

    test('the actual duration is the sum of what resolved', () {
      final ExerciseLibrary lib = library();
      final ProgramDay day = ProgramDay.fromJson(
        validDay(ids: <String>['intro_text_01', 'letter_r_01']),
      );

      final Duration expected = lib.byId('intro_text_01')!.duration +
          lib.byId('letter_r_01')!.duration;

      expect(day.resolve(lib).actualDuration, expected);
    });

    test('resolved lists cannot be modified', () {
      final ResolvedDay resolved = ProgramDay.fromJson(
        validDay(),
      ).resolve(library());

      expect(() => resolved.exercises.clear(), throwsUnsupportedError);
      expect(() => resolved.missingIds.clear(), throwsUnsupportedError);
    });
  });

  group('a program', () {
    test('sorts its days rather than trusting file order', () {
      // `days.first` has to be day one no matter how the file was edited.
      final TrainingProgram program = TrainingProgram.fromJson(
        programWith(<Map<String, dynamic>>[
          validDay(day: 3),
          validDay(day: 1),
          validDay(day: 2),
        ]),
      );

      expect(program.days.map((ProgramDay d) => d.day), <int>[1, 2, 3]);
      expect(program.days.first.day, 1);
      expect(program.lastDay, 3);
      expect(program.dayCount, 3);
    });

    test('a repeated day number is rejected', () {
      expect(
        () => TrainingProgram.fromJson(
          programWith(<Map<String, dynamic>>[validDay(), validDay()]),
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('twice'),
          ),
        ),
      );
    });

    test('a gap in the day numbers is rejected', () {
      expect(
        () => TrainingProgram.fromJson(
          programWith(<Map<String, dynamic>>[
            validDay(day: 1),
            validDay(day: 3),
          ]),
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('no gaps'), contains('2')),
          ),
        ),
      );
    });

    test('a program that does not start at day one is rejected', () {
      expect(
        () => TrainingProgram.fromJson(
          programWith(<Map<String, dynamic>>[
            validDay(day: 2),
            validDay(day: 3),
          ]),
        ),
        throwsFormatException,
      );
    });

    test('dayFor finds a day and returns null for one that is not there', () {
      final TrainingProgram program = TrainingProgram.fromJson(
        programWith(<Map<String, dynamic>>[validDay(day: 1), validDay(day: 2)]),
      );

      expect(program.dayFor(2)?.day, 2);
      expect(program.dayFor(9), isNull);
      expect(program.dayFor(0), isNull);
    });

    test('the total estimate adds up its days', () {
      final TrainingProgram program = TrainingProgram.fromJson(
        programWith(<Map<String, dynamic>>[
          validDay(day: 1, minutes: 5),
          validDay(day: 2, minutes: 7),
        ]),
      );

      expect(program.totalEstimatedDuration, const Duration(minutes: 12));
    });

    test('lastDay is the highest day number, not how many days there are', () {
      // A parsed program runs 1..N with no gaps, so `days.length` and
      // `days.last.day` are the same number in every test above and either
      // implementation passes them all. The constructor does not enforce the
      // run, which is the one place the two can disagree.
      final TrainingProgram real = TrainingProgram.fromJson(
        readFile('program.json'),
      );
      final TrainingProgram sparse = TrainingProgram(
        envelope: real.envelope,
        programId: 'sparse',
        title: 'Aralıklı',
        days: const <ProgramDay>[
          ProgramDay(
            day: 5,
            title: 'Beşinci gün',
            estimatedMinutes: 5,
            exerciseRefs: <DayExerciseRef>[],
          ),
        ],
      );

      expect(sparse.dayCount, 1);
      expect(sparse.lastDay, 5);

      final TrainingProgram empty = TrainingProgram(
        envelope: real.envelope,
        programId: 'empty',
        title: 'Boş',
        days: const <ProgramDay>[],
      );

      expect(
        empty.lastDay,
        0,
        reason: 'no days means no last day, not a crash',
      );
    });

    test('an unsupported schema version stops before any day is read', () {
      final Map<String, dynamic> json = programWith(<Map<String, dynamic>>[
        validDay(),
      ])
        ..['schemaVersion'] = '2.0.0';

      expect(() => TrainingProgram.fromJson(json), throwsFormatException);
    });

    test('the day list cannot be modified by a caller', () {
      final TrainingProgram program = TrainingProgram.fromJson(
        programWith(<Map<String, dynamic>>[validDay()]),
      );

      expect(() => program.days.clear(), throwsUnsupportedError);
    });

    test('programs compare by content', () {
      TrainingProgram build({
        String id = 'hitup_mvp',
        String title = 'Program',
      }) =>
          TrainingProgram.fromJson(
            programWith(<Map<String, dynamic>>[validDay()])
              ..['programId'] = id
              ..['title'] = title,
          );

      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build(id: 'other')));
      expect(build(), isNot(build(title: 'Başka')));
    });
  });

  group('resolved days compare by content', () {
    ExerciseLibrary library() =>
        ExerciseLibrary.fromJson(readFile('exercises.json'));

    ResolvedDay resolveIds(List<String> ids) =>
        ProgramDay.fromJson(validDay(ids: ids)).resolve(library());

    test('same exercises and same gaps are equal', () {
      // Worth having because a screen holding this in Riverpod state should
      // not rebuild when the same day resolves to the same thing twice.
      final ResolvedDay a = resolveIds(<String>['intro_text_01']);
      final ResolvedDay b = resolveIds(<String>['intro_text_01']);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different exercise or a different gap breaks equality', () {
      final ResolvedDay a = resolveIds(<String>['intro_text_01']);

      expect(a, isNot(resolveIds(<String>['letter_r_01'])));
      expect(
        a,
        isNot(resolveIds(<String>['intro_text_01', 'no_such_99'])),
        reason: 'the missing ids are part of the result',
      );

      // Equal objects having equal hashes is satisfied by returning a
      // constant, so it says nothing on its own. Unequal ones needing
      // different hashes is what makes this a Map key that works.
      expect(a.hashCode, isNot(resolveIds(<String>['letter_r_01']).hashCode));
      expect(
        a.hashCode,
        isNot(resolveIds(<String>['intro_text_01', 'no_such_99']).hashCode),
      );
    });
  });

  group('descriptions', () {
    // Diagnostics, but they are what a log line carries when someone is
    // working out why a day did not render.
    test('each model says what it is', () {
      final ExerciseLibrary library = ExerciseLibrary.fromJson(
        readFile('exercises.json'),
      );
      final ProgramDay day = ProgramDay.fromJson(
        validDay(day: 2, ids: <String>['intro_text_01', 'no_such_99']),
      );
      final TrainingProgram program = TrainingProgram.fromJson(
        programWith(<Map<String, dynamic>>[validDay()]),
      );

      expect(
        day.exerciseRefs.first.toString(),
        allOf(contains('intro_text_01'), contains('1')),
      );
      expect(day.toString(), allOf(contains('2'), contains('2 exercises')));
      expect(
        day.resolve(library).toString(),
        allOf(contains('1 exercises'), contains('1 missing')),
      );
      expect(
        program.toString(),
        allOf(contains('hitup_mvp'), contains('1 days')),
      );
    });
  });

  group('progression', () {
    TrainingProgram threeDays() => TrainingProgram.fromJson(
          programWith(<Map<String, dynamic>>[
            validDay(day: 1),
            validDay(day: 2),
            validDay(day: 3),
          ]),
        );

    test('you can revisit what you have reached', () {
      final TrainingProgram program = threeDays();

      expect(program.isDayUnlocked(1, currentProgramDay: 2), isTrue);
      expect(program.isDayUnlocked(2, currentProgramDay: 2), isTrue);
    });

    test('you cannot reach ahead of where you are', () {
      final TrainingProgram program = threeDays();

      expect(program.isDayUnlocked(3, currentProgramDay: 2), isFalse);
    });

    test('a day the program does not have is never unlocked', () {
      // Even with a currentProgramDay past the end, which is what a user who
      // finished the program will have.
      final TrainingProgram program = threeDays();

      expect(program.isDayUnlocked(4, currentProgramDay: 9), isFalse);
      expect(program.isDayUnlocked(0, currentProgramDay: 9), isFalse);
    });

    test('day one is open to a user who has just started', () {
      // currentProgramDay starts at 1 per FIRESTORE_MODEL.md, so a brand new
      // profile must be able to open the first day.
      final TrainingProgram program = threeDays();

      expect(program.isDayUnlocked(1, currentProgramDay: 1), isTrue);
      expect(program.isDayUnlocked(2, currentProgramDay: 1), isFalse);
    });
  });
}
