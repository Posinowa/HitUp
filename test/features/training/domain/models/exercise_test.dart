import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/training/domain/models/models.dart';

/// Parsing tests for the exercise domain models (HIT-022).
///
/// `test/content/content_schema_test.dart` answers a different question: does
/// the JSON on disk match the documented schema. This one answers whether the
/// models read that JSON correctly, and whether they fail usefully when the
/// content is wrong.
///
/// The real `exercises.json` is parsed here rather than a fixture copy. A
/// fixture would drift from the shipped file, and the case worth catching is
/// exactly the one where content changes and the models stop matching it.
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
    });

    test('covers every presentation type the app can render', () {
      final ExerciseLibrary library = ExerciseLibrary.fromJson(
        readExercisesFile(),
      );

      final Set<ExercisePresentationType> present =
          library.exercises.map((Exercise e) => e.presentationType).toSet();
      final Set<ExercisePresentationType> renderable = ExercisePresentationType
          .values
          .where((ExercisePresentationType t) => t.isRenderable)
          .toSet();

      expect(
        present,
        renderable,
        reason: 'a type with no sample exercise has nothing to develop its '
            'renderer against',
      );
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

    test('media carrying types resolve a reference, the rest do not', () {
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

  group('presentation types', () {
    test('a known wire name resolves to its type', () {
      expect(
        ExercisePresentationType.fromWireName('breathing'),
        ExercisePresentationType.breathing,
      );
      expect(
        ExercisePresentationType.fromWireName('speakingChallenge'),
        ExercisePresentationType.speakingChallenge,
      );
    });

    test('an unknown wire name falls back instead of throwing', () {
      // The forward-compatibility rule: newer content must cost one exercise
      // on an older client, never the whole day.
      expect(
        ExercisePresentationType.fromWireName('hologram'),
        ExercisePresentationType.unknown,
      );
      expect(
        ExercisePresentationType.fromWireName(null),
        ExercisePresentationType.unknown,
      );
      expect(ExercisePresentationType.unknown.isRenderable, isFalse);
    });

    test('an exercise of an unknown type is skipped, not fatal', () {
      final ExerciseLibrary library =
          ExerciseLibrary.fromJson(<String, dynamic>{
        'schemaVersion': '1.0.0',
        'contentVersion': '0.1.0',
        'status': 'placeholder',
        'locale': 'tr-TR',
        'exercises': <Map<String, dynamic>>[
          validExercise(),
          validExercise(id: 'future_hologram_01', type: 'hologram'),
        ],
      });

      expect(library.exercises.map((Exercise e) => e.id), <String>[
        'sample_text_01',
      ]);
      expect(library.skippedIds, <String>['future_hologram_01']);
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

    test('text and timer carry no config', () {
      expect(Exercise.fromJson(validExercise()).config, isNull);
      expect(Exercise.fromJson(validExercise(type: 'timer')).config, isNull);
    });
  });

  group('malformed content', () {
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

    test('a duration of zero is rejected', () {
      final Map<String, dynamic> json = validExercise()
        ..['durationSeconds'] = 0;

      expect(() => Exercise.fromJson(json), throwsFormatException);
    });

    test('a duration given as a string is rejected', () {
      final Map<String, dynamic> json = validExercise()
        ..['durationSeconds'] = '30';

      expect(() => Exercise.fromJson(json), throwsFormatException);
    });

    test('a media key holding a path or an extension is rejected', () {
      // The key indirection is what lets HIT-013 move delivery without
      // touching content. A path in the file quietly undoes that.
      for (final String bad in <String>['rive/ux_lips', 'ux_lips.riv']) {
        final Map<String, dynamic> json = validExercise(type: 'rive')
          ..['media'] = <String, dynamic>{'kind': 'rive', 'key': bad};

        expect(
          () => Exercise.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (FormatException e) => e.message,
              'message',
              contains('bare asset key'),
            ),
          ),
          reason: '"$bad" should be rejected',
        );
      }
    });

    test('a word index past the end of its text is rejected', () {
      final Map<String, dynamic> json = validExercise(type: 'emphasis')
        ..['emphasis'] = <String, dynamic>{
          'text': 'bir iki üç',
          'emphasisWordIndexes': <int>[0, 9],
        };

      expect(
        () => Exercise.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('past the end'),
          ),
        ),
      );
    });

    test('a duplicate exercise id is rejected', () {
      // Completion records point at these ids, so two exercises sharing one
      // would share a history.
      expect(
        () => ExerciseLibrary.fromJson(<String, dynamic>{
          'schemaVersion': '1.0.0',
          'contentVersion': '0.1.0',
          'status': 'placeholder',
          'locale': 'tr-TR',
          'exercises': <Map<String, dynamic>>[
            validExercise(),
            validExercise(),
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('Duplicate'),
          ),
        ),
      );
    });
  });

  group('the envelope', () {
    test('a newer major schema version is refused', () {
      // A major bump renames or removes fields, so an older parser would build
      // quietly wrong models rather than fail. Better to stop at the header.
      expect(
        () => ExerciseLibrary.fromJson(<String, dynamic>{
          'schemaVersion': '2.0.0',
          'contentVersion': '0.1.0',
          'status': 'placeholder',
          'locale': 'tr-TR',
          'exercises': <Map<String, dynamic>>[validExercise()],
        }),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('Unsupported schemaVersion'),
          ),
        ),
      );
    });

    test('a newer minor schema version is accepted', () {
      // Minor bumps are additive; refusing them would make every field
      // addition a forced app update.
      final ExerciseLibrary library =
          ExerciseLibrary.fromJson(<String, dynamic>{
        'schemaVersion': '1.7.0',
        'contentVersion': '0.1.0',
        'status': 'placeholder',
        'locale': 'tr-TR',
        'exercises': <Map<String, dynamic>>[validExercise()],
      });

      expect(library.exercises, hasLength(1));
    });

    test('the shipped content is still marked placeholder', () {
      // Flipped to approved by HIT-080. Until then this is a reminder that the
      // wording in the app is not signed off.
      final ExerciseLibrary library = ExerciseLibrary.fromJson(
        readExercisesFile(),
      );

      expect(library.envelope.status, ContentStatus.placeholder);
      expect(library.envelope.locale, 'tr-TR');
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
      final Exercise b = Exercise.fromJson(
        validExercise()..['durationSeconds'] = 31,
      );

      expect(a, isNot(b));
    });

    test('configs compare by content, including their lists', () {
      const TongueTwisterConfig a = TongueTwisterConfig(
        tongueTwisterIds: <String>['tt_r_01', 'tt_s_01'],
        repetitions: 2,
      );
      const TongueTwisterConfig b = TongueTwisterConfig(
        tongueTwisterIds: <String>['tt_r_01', 'tt_s_01'],
        repetitions: 2,
      );
      const TongueTwisterConfig c = TongueTwisterConfig(
        tongueTwisterIds: <String>['tt_s_01', 'tt_r_01'],
        repetitions: 2,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c), reason: 'order is part of the content');
    });
  });

  group('convenience on the models', () {
    test('configAs returns the config only for a matching type', () {
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

    test('breathing totals are derived, not authored twice', () {
      const BreathingConfig config = BreathingConfig(
        inhaleSeconds: 4,
        holdSeconds: 2,
        exhaleSeconds: 6,
        cycles: 5,
      );

      expect(config.cycleDuration, const Duration(seconds: 12));
      expect(config.totalDuration, const Duration(seconds: 60));
    });

    test('text markup splits into the words its indexes address', () {
      const EmphasisConfig config = EmphasisConfig(
        text: '  bir   iki üç  ',
        wordIndexes: <int>[0, 2],
      );

      expect(config.words, <String>['bir', 'iki', 'üç']);
      expect(config.indexesAreInRange(<int>[0, 2]), isTrue);
      expect(config.indexesAreInRange(<int>[3]), isFalse);
    });

    test('a timed reading counts its own words', () {
      const TimedReadingConfig config = TimedReadingConfig(
        text: 'bir iki üç dört',
        targetWordsPerMinute: 140,
      );

      expect(config.wordCount, 4);
    });
  });
}
