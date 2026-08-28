import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/training/domain/models/models.dart';

/// Tests for the exercise itself and the file it comes from (HIT-022).
///
/// The value types and the reading layer have their own suites; this one is
/// about what only appears once they are assembled: the pairing rule between a
/// presentation type and its config, and what happens to a whole file of them.
///
/// The real `assets/content/exercises.json` is parsed here rather than a
/// fixture copy. A fixture would drift from the shipped file, and the case
/// worth catching is exactly the one where content changes and the models stop
/// matching it.
void main() {
  Map<String, dynamic> readExercisesFile() {
    final File file = File('assets/content/exercises.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'exercises.json must ship in the bundle',
    );
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  /// A minimal valid exercise, for tests that mutate one thing about it.
  Map<String, dynamic> validExercise({
    String id = 'sample_text_01',
    String type = 'text',
  }) =>
      <String, dynamic>{
        'id': id,
        'title': 'Başlık',
        'presentationType': type,
        'durationSeconds': 30,
        'instructions': 'Yönerge',
      };

  Map<String, dynamic> fileWith(List<Map<String, dynamic>> exercises) =>
      <String, dynamic>{
        'schemaVersion': '1.0.0',
        'contentVersion': '0.1.0',
        'status': 'placeholder',
        'locale': 'tr-TR',
        'exercises': exercises,
      };

  group('the shipped exercises.json', () {
    test('parses without error', () {
      final ExerciseLibrary library = ExerciseLibrary.fromJson(
        readExercisesFile(),
      );

      expect(library.exercises, isNotEmpty);
      expect(
        library.skippedIds,
        isEmpty,
        reason: 'this build should recognise every type in its own content',
      );
      expect(library.envelope.status, ContentStatus.placeholder);
    });

    test('covers every presentation type the app can render', () {
      // A type with no sample exercise has nothing to develop its renderer
      // against, so this notices when one is added to the enum and forgotten
      // in the content.
      final ExerciseLibrary library = ExerciseLibrary.fromJson(
        readExercisesFile(),
      );

      final Set<ExercisePresentationType> present =
          library.exercises.map((Exercise e) => e.presentationType).toSet();
      final Set<ExercisePresentationType> renderable = ExercisePresentationType
          .values
          .where((ExercisePresentationType t) => t.isRenderable)
          .toSet();

      expect(present, renderable);
    });

    test('every exercise carries the config its type calls for', () {
      final ExerciseLibrary library = ExerciseLibrary.fromJson(
        readExercisesFile(),
      );

      const Map<ExercisePresentationType, Type> expected =
          <ExercisePresentationType, Type>{
        ExercisePresentationType.breathing: BreathingConfig,
        ExercisePresentationType.letter: LetterConfig,
        ExercisePresentationType.tongueTwister: TongueTwisterConfig,
        ExercisePresentationType.emphasis: EmphasisConfig,
        ExercisePresentationType.intonation: IntonationConfig,
        ExercisePresentationType.pause: PauseConfig,
        ExercisePresentationType.timedReading: TimedReadingConfig,
        ExercisePresentationType.speakingChallenge: SpeakingChallengeConfig,
      };

      for (final Exercise exercise in library.exercises) {
        final Type? wanted = expected[exercise.presentationType];
        if (wanted == null) {
          expect(
            exercise.config,
            isNull,
            reason: '${exercise.id} should carry no config block',
          );
        } else {
          expect(
            exercise.config.runtimeType,
            wanted,
            reason: '${exercise.id} should carry a $wanted',
          );
        }
      }
    });

    test('media carrying types resolve a reference', () {
      final ExerciseLibrary library = ExerciseLibrary.fromJson(
        readExercisesFile(),
      );

      const Set<ExercisePresentationType> needsMedia =
          <ExercisePresentationType>{
        ExercisePresentationType.audio,
        ExercisePresentationType.rive,
        ExercisePresentationType.articulation,
      };

      for (final Exercise exercise in library.exercises) {
        if (needsMedia.contains(exercise.presentationType)) {
          expect(
            exercise.media,
            isNotNull,
            reason: '${exercise.id} cannot render without media',
          );
        }
      }
    });

    test('byId finds a known exercise and returns null for a stranger', () {
      final ExerciseLibrary library = ExerciseLibrary.fromJson(
        readExercisesFile(),
      );
      final String knownId = library.exercises.first.id;

      expect(library.byId(knownId)?.id, knownId);
      expect(library.byId('no_such_exercise_99'), isNull);
    });
  });

  group('the pairing rule', () {
    test('a config block belonging to another type is rejected', () {
      final Map<String, dynamic> json = validExercise(type: 'letter')
        ..['breathing'] = <String, dynamic>{
          'inhaleSeconds': 4,
          'holdSeconds': 2,
          'exhaleSeconds': 6,
          'cycles': 5,
        };

      expect(
        () => Exercise.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('breathing'), contains('letter')),
          ),
        ),
      );
    });

    test('two config blocks at once are rejected', () {
      final Map<String, dynamic> json = validExercise(type: 'letter')
        ..['letter'] = <String, dynamic>{'letterKey': 'r', 'repetitions': 3}
        ..['pause'] = <String, dynamic>{
          'text': 'bir iki üç',
          'pauseAfterWordIndexes': <int>[1],
          'pauseMilliseconds': 400,
        };

      expect(
        () => Exercise.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('at most one'),
          ),
        ),
      );
    });

    test('the matching block is read into the right config type', () {
      final Exercise exercise = Exercise.fromJson(
        validExercise(type: 'breathing')
          ..['breathing'] = <String, dynamic>{
            'inhaleSeconds': 4,
            'holdSeconds': 2,
            'exhaleSeconds': 6,
            'cycles': 5,
          },
      );

      expect(exercise.configAs<BreathingConfig>(), isNotNull);
      expect(exercise.configAs<LetterConfig>(), isNull);
    });

    test('text and timer carry no config', () {
      expect(Exercise.fromJson(validExercise()).config, isNull);
      expect(Exercise.fromJson(validExercise(type: 'timer')).config, isNull);
    });
  });

  group('a malformed exercise', () {
    test('a presentationType that is not a string names the exercise', () {
      // Absent and unrecognised are the forward-compatibility case: the
      // exercise gets an unknown type and is skipped, and the rest of the file
      // still reads. A wrong type is a content bug, and read with a bare cast
      // it threw "type 'int' is not a subtype of type 'String?'", which names
      // neither the field nor which of thirteen exercises carries it.
      expect(
        () => Exercise.fromJson(validExercise()..['presentationType'] = 5),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('presentationType'), contains('sample_text_01')),
          ),
        ),
      );
    });

    test('a missing required field names the field and the exercise', () {
      final Map<String, dynamic> json = validExercise()..remove('instructions');

      expect(
        () => Exercise.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('instructions'), contains('sample_text_01')),
          ),
        ),
      );
    });

    test('a duration of zero or the wrong type is rejected', () {
      expect(
        () => Exercise.fromJson(validExercise()..['durationSeconds'] = 0),
        throwsFormatException,
      );
      expect(
        () => Exercise.fromJson(validExercise()..['durationSeconds'] = '30'),
        throwsFormatException,
      );
    });

    test('duration is exposed as a real Duration', () {
      expect(
        Exercise.fromJson(validExercise()).duration,
        const Duration(seconds: 30),
      );
    });
  });

  group('a whole file', () {
    test('an exercise of an unknown type is skipped, not fatal', () {
      // The forward-compatibility case at file level: newer content costs one
      // exercise on an older client, never the whole day.
      final ExerciseLibrary library = ExerciseLibrary.fromJson(
        fileWith(<Map<String, dynamic>>[
          validExercise(),
          validExercise(id: 'future_hologram_01', type: 'hologram'),
        ]),
      );

      expect(library.exercises.map((Exercise e) => e.id), <String>[
        'sample_text_01',
      ]);
      expect(library.skippedIds, <String>['future_hologram_01']);
      expect(library.byId('future_hologram_01'), isNull);
    });

    test('a duplicate exercise id is rejected', () {
      // Completion records point at these ids, so two exercises sharing one
      // would share a history.
      expect(
        () => ExerciseLibrary.fromJson(
          fileWith(<Map<String, dynamic>>[validExercise(), validExercise()]),
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('Duplicate'),
          ),
        ),
      );
    });

    test('an unsupported schema version stops before any record is read', () {
      // The guard belongs to the envelope, but this is where it has to bite:
      // an older parser would otherwise build quietly wrong models.
      final Map<String, dynamic> json =
          fileWith(<Map<String, dynamic>>[validExercise()])
            ..['schemaVersion'] = '2.0.0';

      expect(() => ExerciseLibrary.fromJson(json), throwsFormatException);
    });

    test('the exercise list cannot be modified by a caller', () {
      final ExerciseLibrary library = ExerciseLibrary.fromJson(
        readExercisesFile(),
      );

      expect(
        () => library.exercises.removeLast(),
        throwsUnsupportedError,
      );
    });
  });

  group('a library is a value too', () {
    test('the same file read twice gives two equal libraries', () {
      final ExerciseLibrary a = ExerciseLibrary.fromJson(
        fileWith(<Map<String, dynamic>>[validExercise()]),
      );
      final ExerciseLibrary b = ExerciseLibrary.fromJson(
        fileWith(<Map<String, dynamic>>[validExercise()]),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, a);
    });

    test('each of the three parts counts', () {
      final ExerciseLibrary base = ExerciseLibrary.fromJson(
        fileWith(<Map<String, dynamic>>[validExercise()]),
      );

      // A different envelope, same exercises.
      final Map<String, dynamic> otherVersion = fileWith(
        <Map<String, dynamic>>[validExercise()],
      )..['contentVersion'] = '0.2.0';
      expect(base, isNot(ExerciseLibrary.fromJson(otherVersion)));

      // A different exercise list, same envelope.
      expect(
        base,
        isNot(
          ExerciseLibrary.fromJson(
            fileWith(<Map<String, dynamic>>[validExercise(id: 'other_01')]),
          ),
        ),
      );

      // The same readable exercise, but one unreadable one skipped alongside
      // it. Equality has to notice, or a library that quietly dropped an
      // exercise would compare equal to one that did not.
      final ExerciseLibrary withSkip = ExerciseLibrary.fromJson(
        fileWith(<Map<String, dynamic>>[
          validExercise(),
          validExercise(id: 'skipped_01', type: 'somethingNewer'),
        ]),
      );
      expect(withSkip.skippedIds, <String>['skipped_01']);
      expect(withSkip.exercises, hasLength(1));
      expect(base, isNot(withSkip));
      expect(base.hashCode, isNot(withSkip.hashCode));
    });

    test('distinct libraries do not collapse onto one hash', () {
      final Set<int> hashes = <ExerciseLibrary>{
        ExerciseLibrary.fromJson(
          fileWith(<Map<String, dynamic>>[validExercise()]),
        ),
        ExerciseLibrary.fromJson(
          fileWith(<Map<String, dynamic>>[validExercise(id: 'other_01')]),
        ),
        ExerciseLibrary.fromJson(
          fileWith(<Map<String, dynamic>>[
            validExercise(),
            validExercise(id: 'skipped_01', type: 'somethingNewer'),
          ]),
        ),
      }.map((ExerciseLibrary l) => l.hashCode).toSet();

      expect(hashes, hasLength(3));
    });

    test('a library and an exercise say what they hold', () {
      final ExerciseLibrary library = ExerciseLibrary.fromJson(
        fileWith(<Map<String, dynamic>>[
          validExercise(),
          validExercise(id: 'skipped_01', type: 'somethingNewer'),
        ]),
      );

      expect(
        library.toString(),
        allOf(contains('1 exercise'), contains('1 skipped')),
      );
      expect(
        Exercise.fromJson(validExercise()).toString(),
        allOf(
          contains('sample_text_01'),
          contains('text'),
          contains('30'),
        ),
      );
    });

    test('byId finds what is there and returns nothing for what is not', () {
      final ExerciseLibrary library = ExerciseLibrary.fromJson(
        fileWith(<Map<String, dynamic>>[
          validExercise(),
          validExercise(id: 'second_01'),
        ]),
      );

      expect(library.byId('second_01')?.id, 'second_01');
      expect(library.byId('sample_text_01')?.id, 'sample_text_01');
      expect(library.byId('not_here_01'), isNull);
    });
  });

  group('value semantics', () {
    test('two exercises with the same content are equal', () {
      final Exercise a = Exercise.fromJson(validExercise());
      final Exercise b = Exercise.fromJson(validExercise());

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a difference anywhere breaks equality', () {
      final Exercise a = Exercise.fromJson(validExercise());

      expect(
        a,
        isNot(Exercise.fromJson(validExercise()..['durationSeconds'] = 31)),
      );
      expect(a, isNot(Exercise.fromJson(validExercise(id: 'other_01'))));
    });

    test('the config is part of the identity', () {
      Exercise withCycles(int cycles) => Exercise.fromJson(
            validExercise(type: 'breathing')
              ..['breathing'] = <String, dynamic>{
                'inhaleSeconds': 4,
                'holdSeconds': 2,
                'exhaleSeconds': 6,
                'cycles': cycles,
              },
          );

      expect(withCycles(5), withCycles(5));
      expect(withCycles(5), isNot(withCycles(6)));
    });
  });
}
