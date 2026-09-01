import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/training/domain/models/exercise_config.dart';
import 'package:hitup/features/training/domain/models/exercise_presentation_type.dart';
import 'package:hitup/features/training/domain/models/media_reference.dart';

/// Tests for the value types an exercise is built from (HIT-022).
///
/// The presentation type, the media reference, and the eight type specific
/// configs. Nothing here knows what an `Exercise` is: these are the pieces, and
/// they are worth getting right on their own before anything assembles them.
void main() {
  const String owner = 'sample_exercise_01';

  group('presentation types', () {
    test('every documented wire name resolves', () {
      // The wire names are content and can never change once shipped, so this
      // is the test that notices if one is renamed by accident.
      const List<String> documented = <String>[
        'text',
        'timer',
        'audio',
        'breathing',
        'rive',
        'articulation',
        'letter',
        'tongueTwister',
        'emphasis',
        'intonation',
        'pause',
        'timedReading',
        'speakingChallenge',
      ];

      for (final String name in documented) {
        final ExercisePresentationType type =
            ExercisePresentationType.fromWireName(name);
        expect(
          type,
          isNot(ExercisePresentationType.unknown),
          reason: '"$name" is documented in CONTENT_SCHEMA.md',
        );
        expect(type.wireName, name);
      }
    });

    test('an unrecognised name falls back instead of throwing', () {
      // Newer content must cost one exercise on an older client, never the
      // whole file.
      expect(
        ExercisePresentationType.fromWireName('hologram'),
        ExercisePresentationType.unknown,
      );
      expect(
        ExercisePresentationType.fromWireName(null),
        ExercisePresentationType.unknown,
      );
      expect(
        ExercisePresentationType.fromWireName(''),
        ExercisePresentationType.unknown,
      );
    });

    test('only unknown is unrenderable', () {
      for (final ExercisePresentationType type
          in ExercisePresentationType.values) {
        expect(
          type.isRenderable,
          type != ExercisePresentationType.unknown,
          reason: '${type.name} renderability',
        );
      }
    });
  });

  group('media references', () {
    test('reads a rive reference with its state machine', () {
      final MediaReference media = MediaReference.fromJson(
        <String, dynamic>{
          'kind': 'rive',
          'key': 'ux_lips',
          'stateMachine': 'LipStates',
        },
        ownerId: owner,
      );

      expect(media.kind, MediaKind.rive);
      expect(media.key, 'ux_lips');
      expect(media.stateMachine, 'LipStates');
    });

    test('a state machine is optional', () {
      final MediaReference media = MediaReference.fromJson(
        <String, dynamic>{
          'kind': 'audio',
          'key': 'placeholder_sample',
        },
        ownerId: owner,
      );

      expect(media.stateMachine, isNull);
    });

    test('an unknown kind falls back rather than throwing', () {
      expect(
        MediaReference.fromJson(
          <String, dynamic>{
            'kind': 'hologram',
            'key': 'sample',
          },
          ownerId: owner,
        ).kind,
        MediaKind.unknown,
      );
    });

    test('a kind that is not a string is an error, not an unknown', () {
      // Absent and unrecognised both mean unknown; that is forward
      // compatibility. A wrong type is a content bug and has to name the field
      // and the owner like every other reader does. Read with a bare cast this
      // threw "type 'int' is not a subtype of type 'String?'", which names
      // neither.
      expect(
        () => MediaReference.fromJson(
          <String, dynamic>{
            'kind': 3,
            'key': 'sample',
          },
          ownerId: owner,
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('kind'), contains(owner)),
          ),
        ),
      );
    });

    test('a key carrying a folder or an extension is rejected', () {
      // The key indirection is what lets media delivery change without
      // touching curriculum or screens. A path in a content file quietly
      // undoes that, so it fails at parse time rather than at resolve time.
      for (final String bad in <String>[
        'rive/ux_lips',
        'ux_lips.riv',
        'assets/audio/intro.mp3',
      ]) {
        expect(
          () => MediaReference.fromJson(
            <String, dynamic>{
              'kind': 'rive',
              'key': bad,
            },
            ownerId: owner,
          ),
          throwsA(
            isA<FormatException>().having(
              (FormatException e) => e.message,
              'message',
              allOf(contains('bare asset key'), contains(owner)),
            ),
          ),
          reason: '"$bad" should be rejected',
        );
      }
    });

    test('references compare by content', () {
      const MediaReference a = MediaReference(
        kind: MediaKind.rive,
        key: 'ux_lips',
        stateMachine: 'LipStates',
      );
      const MediaReference b = MediaReference(
        kind: MediaKind.rive,
        key: 'ux_lips',
        stateMachine: 'LipStates',
      );
      const MediaReference c = MediaReference(
        kind: MediaKind.audio,
        key: 'ux_lips',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c), reason: 'kind is part of the identity, not just key');
    });
  });

  group('breathing', () {
    test('reads a full cycle and derives its totals', () {
      final BreathingConfig config = BreathingConfig.fromJson(
        <String, dynamic>{
          'inhaleSeconds': 4,
          'holdSeconds': 2,
          'exhaleSeconds': 6,
          'cycles': 5,
        },
        ownerId: owner,
      );

      expect(config.cycleDuration, const Duration(seconds: 12));
      expect(config.totalDuration, const Duration(seconds: 60));
    });

    test('a hold of zero is allowed, an inhale of zero is not', () {
      // Not every breathing pattern pauses at the top. A phase of zero
      // seconds for inhale or exhale is not a pattern, it is a mistake.
      expect(
        BreathingConfig.fromJson(
          <String, dynamic>{
            'inhaleSeconds': 4,
            'holdSeconds': 0,
            'exhaleSeconds': 6,
            'cycles': 5,
          },
          ownerId: owner,
        ).holdSeconds,
        0,
      );
      expect(
        () => BreathingConfig.fromJson(
          <String, dynamic>{
            'inhaleSeconds': 0,
            'holdSeconds': 2,
            'exhaleSeconds': 6,
            'cycles': 5,
          },
          ownerId: owner,
        ),
        throwsFormatException,
      );
    });

    test('zero cycles is rejected', () {
      expect(
        () => BreathingConfig.fromJson(
          <String, dynamic>{
            'inhaleSeconds': 4,
            'holdSeconds': 2,
            'exhaleSeconds': 6,
            'cycles': 0,
          },
          ownerId: owner,
        ),
        throwsFormatException,
      );
    });
  });

  group('pointers into the other content files', () {
    test('a letter config carries the key and a repetition count', () {
      final LetterConfig config = LetterConfig.fromJson(
        <String, dynamic>{
          'letterKey': 'r',
          'repetitions': 3,
        },
        ownerId: owner,
      );

      expect(config.letterKey, 'r');
      expect(config.repetitions, 3);
    });

    test('a tongue twister config keeps its ids in order', () {
      final TongueTwisterConfig config = TongueTwisterConfig.fromJson(
        <String, dynamic>{
          'tongueTwisterIds': <dynamic>['tt_r_01', 'tt_s_01'],
          'repetitions': 2,
        },
        ownerId: owner,
      );

      expect(config.tongueTwisterIds, <String>['tt_r_01', 'tt_s_01']);
    });

    test('an empty twister list is rejected', () {
      // It would render as an exercise that does nothing.
      expect(
        () => TongueTwisterConfig.fromJson(
          <String, dynamic>{
            'tongueTwisterIds': <dynamic>[],
            'repetitions': 2,
          },
          ownerId: owner,
        ),
        throwsFormatException,
      );
    });

    test('a speaking challenge config carries one id', () {
      expect(
        SpeakingChallengeConfig.fromJson(
          <String, dynamic>{
            'challengeId': 'sc_intro_60',
          },
          ownerId: owner,
        ).challengeId,
        'sc_intro_60',
      );
    });

    test('order is part of the content, so it is part of equality', () {
      const TongueTwisterConfig a = TongueTwisterConfig(
        tongueTwisterIds: <String>['tt_r_01', 'tt_s_01'],
        repetitions: 2,
      );
      const TongueTwisterConfig b = TongueTwisterConfig(
        tongueTwisterIds: <String>['tt_s_01', 'tt_r_01'],
        repetitions: 2,
      );

      expect(a, isNot(b));
    });
  });

  group('sentences marked up by word position', () {
    test('the text splits into the words the indexes address', () {
      const EmphasisConfig config = EmphasisConfig(
        text: '  bir   iki üç  ',
        wordIndexes: <int>[0, 2],
      );

      expect(config.words, <String>['bir', 'iki', 'üç']);
      expect(config.indexesAreInRange(<int>[0, 2]), isTrue);
      expect(config.indexesAreInRange(<int>[3]), isFalse);
      expect(config.indexesAreInRange(<int>[-1]), isFalse);
    });

    test('an emphasis index past the end is rejected', () {
      // An index past the end silently marks nothing, which reads as a
      // renderer bug rather than the content mistake it is.
      expect(
        () => EmphasisConfig.fromJson(
          <String, dynamic>{
            'text': 'bir iki üç',
            'emphasisWordIndexes': <dynamic>[0, 9],
          },
          ownerId: owner,
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('past the end'),
          ),
        ),
      );
    });

    test('an intonation contour reads its points and range checks them', () {
      final IntonationConfig config = IntonationConfig.fromJson(
        <String, dynamic>{
          'text': 'bir iki üç dört',
          'contour': <dynamic>[
            <String, dynamic>{'wordIndex': 0, 'direction': 'rise'},
            <String, dynamic>{'wordIndex': 3, 'direction': 'fall'},
          ],
        },
        ownerId: owner,
      );

      expect(config.contour, hasLength(2));
      expect(config.contour.first.direction, ContourDirection.rise);
      expect(config.contour.last.direction, ContourDirection.fall);

      expect(
        () => IntonationConfig.fromJson(
          <String, dynamic>{
            'text': 'bir iki',
            'contour': <dynamic>[
              <String, dynamic>{'wordIndex': 7, 'direction': 'rise'},
            ],
          },
          ownerId: owner,
        ),
        throwsFormatException,
      );
    });

    test('an unknown contour direction falls back rather than throwing', () {
      final IntonationConfig config = IntonationConfig.fromJson(
        <String, dynamic>{
          'text': 'bir iki',
          'contour': <dynamic>[
            <String, dynamic>{'wordIndex': 0, 'direction': 'swoop'},
          ],
        },
        ownerId: owner,
      );

      expect(config.contour.single.direction, ContourDirection.unknown);
    });

    test('a direction that is not a string is an error, not an unknown', () {
      // Same rule as every other enum field: unknown covers absent and
      // unrecognised, a wrong type is a content mistake that names itself.
      expect(
        () => IntonationConfig.fromJson(
          <String, dynamic>{
            'text': 'bir iki',
            'contour': <dynamic>[
              <String, dynamic>{'wordIndex': 0, 'direction': 7},
            ],
          },
          ownerId: owner,
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('direction'),
          ),
        ),
      );
    });

    test('a pause config carries its indexes and a real duration', () {
      final PauseConfig config = PauseConfig.fromJson(
        <String, dynamic>{
          'text': 'bir iki üç dört',
          'pauseAfterWordIndexes': <dynamic>[1],
          'pauseMilliseconds': 400,
        },
        ownerId: owner,
      );

      expect(config.pauseAfterWordIndexes, <int>[1]);
      expect(config.pauseDuration, const Duration(milliseconds: 400));
    });

    test('a pause of zero milliseconds is rejected', () {
      expect(
        () => PauseConfig.fromJson(
          <String, dynamic>{
            'text': 'bir iki',
            'pauseAfterWordIndexes': <dynamic>[0],
            'pauseMilliseconds': 0,
          },
          ownerId: owner,
        ),
        throwsFormatException,
      );
    });
  });

  group('a count of zero is rejected wherever it renders as nothing', () {
    test('a letter ladder and a tongue twister both need one repetition', () {
      // Zero repetitions is valid JSON and a valid integer, so only the
      // minimum stops it. Without it the exercise opens and immediately ends.
      expect(
        () => LetterConfig.fromJson(
          <String, dynamic>{
            'letterKey': 'r',
            'repetitions': 0,
          },
          ownerId: owner,
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('at least 1'), contains('repetitions')),
          ),
        ),
      );
      expect(
        () => TongueTwisterConfig.fromJson(
          <String, dynamic>{
            'tongueTwisterIds': <dynamic>['tt_r_01'],
            'repetitions': 0,
          },
          ownerId: owner,
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('at least 1'),
          ),
        ),
      );
    });
  });

  group('a pause index past the end is rejected too', () {
    test('the same rule as emphasis and intonation', () {
      // Each of the three text markup configs checks its own indexes, so each
      // needs its own test; a shared base class is not a shared test.
      expect(
        () => PauseConfig.fromJson(
          <String, dynamic>{
            'text': 'bir iki',
            'pauseAfterWordIndexes': <dynamic>[0, 5],
            'pauseMilliseconds': 400,
          },
          ownerId: owner,
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('past the end'), contains(owner)),
          ),
        ),
      );
    });
  });

  group('timed reading', () {
    test('counts its own words rather than trusting a stored count', () {
      const TimedReadingConfig config = TimedReadingConfig(
        text: 'bir iki üç dört',
        targetWordsPerMinute: 140,
      );

      expect(config.wordCount, 4);
    });

    test('a target of zero is rejected', () {
      expect(
        () => TimedReadingConfig.fromJson(
          <String, dynamic>{
            'text': 'bir iki',
            'targetWordsPerMinute': 0,
          },
          ownerId: owner,
        ),
        throwsFormatException,
      );
    });

    test('a valid object reads back both fields', () {
      // The rejection test above never reaches the constructor, so without
      // this one nothing proves the reader wires the two fields at all, let
      // alone in the right order.
      final TimedReadingConfig config = TimedReadingConfig.fromJson(
        <String, dynamic>{'text': 'bir iki üç', 'targetWordsPerMinute': 140},
        ownerId: owner,
      );

      expect(config.text, 'bir iki üç');
      expect(config.targetWordsPerMinute, 140);
      expect(config.wordCount, 3);
    });
  });

  group('intonation points compare by content', () {
    test('same index and direction are equal, either difference is not', () {
      const IntonationPoint a = IntonationPoint(
        wordIndex: 1,
        direction: ContourDirection.rise,
      );

      expect(
        a,
        const IntonationPoint(wordIndex: 1, direction: ContourDirection.rise),
      );
      expect(
        a.hashCode,
        const IntonationPoint(
          wordIndex: 1,
          direction: ContourDirection.rise,
        ).hashCode,
      );
      expect(
        a,
        isNot(
          const IntonationPoint(
            wordIndex: 2,
            direction: ContourDirection.rise,
          ),
        ),
      );
      expect(
        a,
        isNot(
          const IntonationPoint(
            wordIndex: 1,
            direction: ContourDirection.fall,
          ),
        ),
      );
    });

    test('an intonation config compares its text and its contour', () {
      const IntonationConfig a = IntonationConfig(
        text: 'bir iki',
        contour: <IntonationPoint>[
          IntonationPoint(wordIndex: 0, direction: ContourDirection.rise),
        ],
      );

      expect(
        a,
        const IntonationConfig(
          text: 'bir iki',
          contour: <IntonationPoint>[
            IntonationPoint(wordIndex: 0, direction: ContourDirection.rise),
          ],
        ),
      );
      expect(
        a,
        isNot(
          const IntonationConfig(
            text: 'baska metin',
            contour: <IntonationPoint>[
              IntonationPoint(wordIndex: 0, direction: ContourDirection.rise),
            ],
          ),
        ),
      );
      expect(
        a,
        isNot(
          const IntonationConfig(
            text: 'bir iki',
            contour: <IntonationPoint>[
              IntonationPoint(wordIndex: 1, direction: ContourDirection.rise),
            ],
          ),
        ),
      );
    });

    test('a tongue twister config hashes its ids and its repetitions', () {
      const TongueTwisterConfig a = TongueTwisterConfig(
        tongueTwisterIds: <String>['tt_r_01'],
        repetitions: 2,
      );

      expect(
        a.hashCode,
        const TongueTwisterConfig(
          tongueTwisterIds: <String>['tt_r_01'],
          repetitions: 2,
        ).hashCode,
      );
      expect(
        a.hashCode,
        isNot(
          const TongueTwisterConfig(
            tongueTwisterIds: <String>['tt_r_01'],
            repetitions: 3,
          ).hashCode,
        ),
      );
    });

    test('the last field of each comparison still counts', () {
      // Equality short circuits on the first difference, so a test that only
      // ever varies the first field leaves the last one unchecked. These vary
      // the last.
      expect(
        const TongueTwisterConfig(
          tongueTwisterIds: <String>['tt_r_01'],
          repetitions: 2,
        ),
        isNot(
          const TongueTwisterConfig(
            tongueTwisterIds: <String>['tt_r_01'],
            repetitions: 3,
          ),
        ),
      );
      expect(
        const IntonationConfig(
          text: 'bir iki',
          contour: <IntonationPoint>[
            IntonationPoint(wordIndex: 0, direction: ContourDirection.rise),
          ],
        ).hashCode,
        const IntonationConfig(
          text: 'bir iki',
          contour: <IntonationPoint>[
            IntonationPoint(wordIndex: 0, direction: ContourDirection.rise),
          ],
        ).hashCode,
      );
      expect(
        const MediaReference(kind: MediaKind.audio, key: 'bir'),
        isNot(const MediaReference(kind: MediaKind.audio, key: 'iki')),
      );
      expect(
        const MediaReference(
          kind: MediaKind.rive,
          key: 'ux_lips',
          stateMachine: 'LipStates',
        ),
        isNot(
          const MediaReference(
            kind: MediaKind.rive,
            key: 'ux_lips',
            stateMachine: 'JawStates',
          ),
        ),
      );
    });

    test('different configs do not collapse onto one hash', () {
      // "equal values hash equally" is also true of a hash that returns a
      // constant, and a constant hash turns every map and set of these into a
      // linear scan. This checks the other half of the contract.
      const List<Object> distinct = <Object>[
        BreathingConfig(
          inhaleSeconds: 4,
          holdSeconds: 2,
          exhaleSeconds: 6,
          cycles: 5,
        ),
        BreathingConfig(
          inhaleSeconds: 5,
          holdSeconds: 2,
          exhaleSeconds: 6,
          cycles: 5,
        ),
        LetterConfig(letterKey: 'r', repetitions: 3),
        LetterConfig(letterKey: 's', repetitions: 3),
        TongueTwisterConfig(
          tongueTwisterIds: <String>['tt_r_01'],
          repetitions: 2,
        ),
        TongueTwisterConfig(
          tongueTwisterIds: <String>['tt_r_02'],
          repetitions: 2,
        ),
        EmphasisConfig(text: 'bir iki', wordIndexes: <int>[0]),
        EmphasisConfig(text: 'bir iki', wordIndexes: <int>[1]),
        IntonationConfig(
          text: 'bir iki',
          contour: <IntonationPoint>[
            IntonationPoint(wordIndex: 0, direction: ContourDirection.rise),
          ],
        ),
        IntonationConfig(
          text: 'bir iki',
          contour: <IntonationPoint>[
            IntonationPoint(wordIndex: 1, direction: ContourDirection.fall),
          ],
        ),
        IntonationPoint(wordIndex: 0, direction: ContourDirection.rise),
        IntonationPoint(wordIndex: 1, direction: ContourDirection.fall),
        PauseConfig(
          text: 'bir iki',
          pauseAfterWordIndexes: <int>[0],
          pauseMilliseconds: 400,
        ),
        PauseConfig(
          text: 'bir iki',
          pauseAfterWordIndexes: <int>[0],
          pauseMilliseconds: 500,
        ),
        TimedReadingConfig(text: 'bir iki', targetWordsPerMinute: 140),
        TimedReadingConfig(text: 'bir iki', targetWordsPerMinute: 150),
        SpeakingChallengeConfig(challengeId: 'sc_intro_60'),
        SpeakingChallengeConfig(challengeId: 'sc_intro_90'),
        MediaReference(kind: MediaKind.audio, key: 'bir'),
        MediaReference(kind: MediaKind.audio, key: 'iki'),
        MediaReference(
          kind: MediaKind.rive,
          key: 'ux_lips',
          stateMachine: 'LipStates',
        ),
        MediaReference(
          kind: MediaKind.rive,
          key: 'ux_lips',
          stateMachine: 'JawStates',
        ),
      ];

      expect(
        distinct.map((Object c) => c.hashCode).toSet(),
        hasLength(distinct.length),
      );
    });
  });

  group('descriptions', () {
    test('each config says what it is', () {
      // Diagnostics, but this is what a log line carries when a renderer was
      // handed something it did not expect.
      expect(
        const BreathingConfig(
          inhaleSeconds: 4,
          holdSeconds: 2,
          exhaleSeconds: 6,
          cycles: 5,
        ).toString(),
        allOf(contains('4'), contains('2'), contains('6'), contains('5')),
      );
      expect(
        const LetterConfig(letterKey: 'r', repetitions: 3).toString(),
        allOf(contains('r'), contains('3')),
      );
      expect(
        const TongueTwisterConfig(
          tongueTwisterIds: <String>['tt_r_01'],
          repetitions: 2,
        ).toString(),
        contains('tt_r_01'),
      );
      expect(
        const EmphasisConfig(
          text: 'bir iki',
          wordIndexes: <int>[1],
        ).toString(),
        contains('1'),
      );
      expect(
        const IntonationConfig(
          text: 'bir iki',
          contour: <IntonationPoint>[
            IntonationPoint(wordIndex: 0, direction: ContourDirection.rise),
          ],
        ).toString(),
        contains('1 points'),
      );
      expect(
        const IntonationPoint(
          wordIndex: 0,
          direction: ContourDirection.rise,
        ).toString(),
        allOf(contains('0'), contains('rise')),
      );
      expect(
        const PauseConfig(
          text: 'bir iki',
          pauseAfterWordIndexes: <int>[0],
          pauseMilliseconds: 400,
        ).toString(),
        allOf(contains('0'), contains('400')),
      );
      expect(
        const TimedReadingConfig(
          text: 'bir iki',
          targetWordsPerMinute: 140,
        ).toString(),
        contains('140'),
      );
      expect(
        const SpeakingChallengeConfig(challengeId: 'sc_intro_60').toString(),
        contains('sc_intro_60'),
      );
      expect(
        const MediaReference(
          kind: MediaKind.rive,
          key: 'ux_lips',
          stateMachine: 'LipStates',
        ).toString(),
        allOf(contains('rive'), contains('ux_lips'), contains('LipStates')),
      );
      expect(
        const MediaReference(kind: MediaKind.audio, key: 'intro').toString(),
        allOf(contains('audio'), contains('intro'), isNot(contains(', ,'))),
      );
    });
  });

  group('every config compares by content', () {
    test('same values are equal, one difference is not', () {
      const List<(ExerciseConfig, ExerciseConfig, ExerciseConfig)> cases =
          <(ExerciseConfig, ExerciseConfig, ExerciseConfig)>[
        (
          BreathingConfig(
            inhaleSeconds: 4,
            holdSeconds: 2,
            exhaleSeconds: 6,
            cycles: 5,
          ),
          BreathingConfig(
            inhaleSeconds: 4,
            holdSeconds: 2,
            exhaleSeconds: 6,
            cycles: 5,
          ),
          BreathingConfig(
            inhaleSeconds: 4,
            holdSeconds: 2,
            exhaleSeconds: 6,
            cycles: 6,
          ),
        ),
        (
          LetterConfig(letterKey: 'r', repetitions: 3),
          LetterConfig(letterKey: 'r', repetitions: 3),
          LetterConfig(letterKey: 'r', repetitions: 4),
        ),
        (
          EmphasisConfig(text: 'bir iki üç', wordIndexes: <int>[0]),
          EmphasisConfig(text: 'bir iki üç', wordIndexes: <int>[0]),
          EmphasisConfig(text: 'bir iki üç', wordIndexes: <int>[1]),
        ),
        (
          PauseConfig(
            text: 'bir iki üç',
            pauseAfterWordIndexes: <int>[1],
            pauseMilliseconds: 400,
          ),
          PauseConfig(
            text: 'bir iki üç',
            pauseAfterWordIndexes: <int>[1],
            pauseMilliseconds: 400,
          ),
          PauseConfig(
            text: 'bir iki üç',
            pauseAfterWordIndexes: <int>[1],
            pauseMilliseconds: 500,
          ),
        ),
        (
          TimedReadingConfig(text: 'bir iki', targetWordsPerMinute: 140),
          TimedReadingConfig(text: 'bir iki', targetWordsPerMinute: 140),
          TimedReadingConfig(text: 'bir iki', targetWordsPerMinute: 150),
        ),
        (
          SpeakingChallengeConfig(challengeId: 'sc_intro_60'),
          SpeakingChallengeConfig(challengeId: 'sc_intro_60'),
          SpeakingChallengeConfig(challengeId: 'sc_topic_90'),
        ),
      ];

      for (final (ExerciseConfig a, ExerciseConfig b, ExerciseConfig c)
          in cases) {
        expect(a, b, reason: '${a.runtimeType} should equal an identical one');
        expect(a.hashCode, b.hashCode, reason: '${a.runtimeType} hashCode');
        expect(a, isNot(c), reason: '${a.runtimeType} should differ');
      }
    });
  });
}
