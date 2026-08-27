import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/training/domain/models/models.dart';

/// Tests for the three content files an exercise points at (HIT-024).
///
/// The exercise models cover `exercises.json`. These cover what its configs
/// reference: a letter ladder, a tongue twister and a speaking challenge. The
/// exercise says "run ladder r three times"; this is the layer that knows what
/// ladder r contains.
///
/// The real files under `assets/content/` are parsed here rather than fixture
/// copies. A fixture drifts from the shipped file, and the case worth catching
/// is exactly the one where content changes and the models stop matching it.
void main() {
  Map<String, dynamic> readContentFile(String name) {
    final File file = File('assets/content/$name');
    expect(file.existsSync(), isTrue, reason: '$name must ship in the bundle');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  Map<String, dynamic> envelope() => <String, dynamic>{
        'schemaVersion': '1.0.0',
        'contentVersion': '0.1.0',
        'status': 'placeholder',
        'locale': 'tr-TR',
      };

  Map<String, dynamic> fileWith(String key, List<Map<String, dynamic>> items) =>
      <String, dynamic>{...envelope(), key: items};

  Map<String, dynamic> validLadder({String key = 'r'}) => <String, dynamic>{
        'key': key,
        'letter': 'R',
        'syllables': <String>['RA', 'RE'],
        'words': <String>['Yer'],
      };

  Map<String, dynamic> validTwister({String id = 'tt_r_01'}) =>
      <String, dynamic>{
        'id': id,
        'text': 'Bir tekerleme.',
        'difficulty': 'easy',
        'category': 'letter',
        'recommendedDurationSeconds': 60,
        'targetLetter': 'R',
      };

  Map<String, dynamic> validChallenge({String id = 'sc_intro_60'}) =>
      <String, dynamic>{
        'id': id,
        'title': 'Tanıtım',
        'prompt': 'Kendini tanıt.',
        'durationSeconds': 60,
        'preparationSeconds': 3,
      };

  group('the shipped letters.json', () {
    test('parses, and every ladder is usable', () {
      final LetterLadderLibrary library = LetterLadderLibrary.fromJson(
        readContentFile('letters.json'),
      );

      expect(library.ladders, isNotEmpty);
      for (final LetterLadder ladder in library.ladders) {
        expect(ladder.key, isNotEmpty, reason: 'a ladder needs a key');
        expect(ladder.letter, isNotEmpty,
            reason: '${ladder.key} needs a glyph');
        expect(
          ladder.syllables,
          isNotEmpty,
          reason: '${ladder.key} has nothing to say',
        );
        expect(
          ladder.words,
          isNotEmpty,
          reason: '${ladder.key} has no words',
        );
      }
    });

    test('keys stay ASCII even when the letter does not', () {
      // The key ends up in file names, analytics events and URLs. Ş is a real
      // Turkish letter and a poor identifier, which is why the two fields are
      // separate; this checks the file actually keeps that separation.
      final LetterLadderLibrary library = LetterLadderLibrary.fromJson(
        readContentFile('letters.json'),
      );

      for (final LetterLadder ladder in library.ladders) {
        expect(
          ladder.key,
          matches(RegExp(r'^[a-z0-9_]+$')),
          reason: '"${ladder.key}" is not safe as an identifier',
        );
      }

      final LetterLadder? cedilla = library.byKey('s_cedilla');
      expect(cedilla, isNotNull, reason: 'the non-ASCII example must survive');
      expect(cedilla!.letter, isNot(cedilla.key));
    });
  });

  group('the shipped tongue_twisters.json', () {
    test('parses, and every twister is speakable', () {
      final TongueTwisterLibrary library = TongueTwisterLibrary.fromJson(
        readContentFile('tongue_twisters.json'),
      );

      expect(library.tongueTwisters, isNotEmpty);
      for (final TongueTwister twister in library.tongueTwisters) {
        expect(twister.text, isNotEmpty, reason: '${twister.id} has no line');
        expect(
          twister.recommendedDurationSeconds,
          greaterThan(0),
          reason: '${twister.id} would be over before it began',
        );
      }
    });

    test('a twister that trains no single letter says so with null', () {
      // Rhythm and breath twisters are not about one sound. Requiring
      // targetLetter would reject two of the three that ship today, so this is
      // the case that keeps it optional.
      final TongueTwisterLibrary library = TongueTwisterLibrary.fromJson(
        readContentFile('tongue_twisters.json'),
      );

      final Iterable<TongueTwister> letterDrills = library.byCategory(
        TongueTwisterCategory.letter,
      );
      final Iterable<TongueTwister> others = library.tongueTwisters.where(
        (TongueTwister t) => t.category != TongueTwisterCategory.letter,
      );

      expect(letterDrills, isNotEmpty);
      expect(others, isNotEmpty, reason: 'the file must exercise both shapes');
      for (final TongueTwister twister in letterDrills) {
        expect(
          twister.targetLetter,
          isNotNull,
          reason: '${twister.id} is a letter drill with no letter',
        );
      }
    });

    test('no shipped record falls back to unknown', () {
      // The fallback exists for content newer than the app. Reaching it on
      // today's file means the file and the enum have already drifted apart.
      final TongueTwisterLibrary library = TongueTwisterLibrary.fromJson(
        readContentFile('tongue_twisters.json'),
      );

      for (final TongueTwister twister in library.tongueTwisters) {
        expect(
          twister.difficulty,
          isNot(TongueTwisterDifficulty.unknown),
          reason: '${twister.id} has a difficulty this build cannot name',
        );
        expect(
          twister.category,
          isNot(TongueTwisterCategory.unknown),
          reason: '${twister.id} has a category this build cannot name',
        );
      }
    });
  });

  group('the shipped speaking_challenges.json', () {
    test('parses, and every challenge leaves time to speak', () {
      final SpeakingChallengeLibrary library =
          SpeakingChallengeLibrary.fromJson(
        readContentFile('speaking_challenges.json'),
      );

      expect(library.challenges, isNotEmpty);
      for (final SpeakingChallenge challenge in library.challenges) {
        expect(challenge.prompt, isNotEmpty);
        expect(challenge.durationSeconds, greaterThan(0));
        expect(challenge.preparationSeconds, greaterThanOrEqualTo(0));
        expect(challenge.totalSeconds, greaterThan(challenge.durationSeconds));
      }
    });
  });

  group('exercises and the content they point at', () {
    // The whole point of these three files is that an exercise can name a
    // record in one of them. A reference that resolves to nothing is an
    // exercise that opens and shows a blank card, which reads as a rendering
    // bug rather than the content mistake it is.
    late ExerciseLibrary exercises;
    late LetterLadderLibrary letters;
    late TongueTwisterLibrary twisters;
    late SpeakingChallengeLibrary challenges;

    setUp(() {
      exercises = ExerciseLibrary.fromJson(readContentFile('exercises.json'));
      letters = LetterLadderLibrary.fromJson(readContentFile('letters.json'));
      twisters = TongueTwisterLibrary.fromJson(
        readContentFile('tongue_twisters.json'),
      );
      challenges = SpeakingChallengeLibrary.fromJson(
        readContentFile('speaking_challenges.json'),
      );
    });

    test('the models resolve every reference an exercise makes', () {
      // `test/content/content_schema_test.dart` already checks that the ids in
      // exercises.json appear in the other files. It works on raw maps and
      // answers a different question: is the content internally consistent.
      // This one goes through the model layer instead, so it also fails when
      // `configAs`, `byKey` or `byId` stop finding what is there.
      //
      // Each arm counts what it checked. Without that, an exercises.json that
      // lost all its letter drills would leave this test green while proving
      // nothing.
      int ladderRefs = 0;
      int twisterRefs = 0;
      int challengeRefs = 0;

      for (final Exercise exercise in exercises.exercises) {
        final LetterConfig? letter = exercise.configAs<LetterConfig>();
        if (letter != null) {
          ladderRefs++;
          expect(
            letters.byKey(letter.letterKey),
            isNotNull,
            reason: '${exercise.id} wants ladder "${letter.letterKey}", '
                'letters.json does not have it',
          );
        }

        final TongueTwisterConfig? twister =
            exercise.configAs<TongueTwisterConfig>();
        if (twister != null) {
          for (final String id in twister.tongueTwisterIds) {
            twisterRefs++;
            expect(
              twisters.byId(id),
              isNotNull,
              reason: '${exercise.id} wants twister "$id", '
                  'tongue_twisters.json does not have it',
            );
          }
        }

        final SpeakingChallengeConfig? speaking =
            exercise.configAs<SpeakingChallengeConfig>();
        if (speaking != null) {
          challengeRefs++;
          expect(
            challenges.byId(speaking.challengeId),
            isNotNull,
            reason: '${exercise.id} wants challenge '
                '"${speaking.challengeId}", speaking_challenges.json does not '
                'have it',
          );
        }
      }

      expect(ladderRefs, greaterThan(0), reason: 'no letter drill checked');
      expect(twisterRefs, greaterThan(0), reason: 'no twister checked');
      expect(challengeRefs, greaterThan(0), reason: 'no challenge checked');
    });

    test('a letter drill targets a letter the ladders know', () {
      // targetLetter is the display glyph, so it should match a ladder's
      // letter rather than its key. A twister aimed at a letter with no ladder
      // is a drill the app cannot build a warm-up for.
      final Set<String> glyphs =
          letters.ladders.map((LetterLadder ladder) => ladder.letter).toSet();

      for (final TongueTwister twister
          in twisters.byCategory(TongueTwisterCategory.letter)) {
        expect(
          glyphs,
          contains(twister.targetLetter),
          reason: '${twister.id} targets "${twister.targetLetter}", '
              'letters.json has $glyphs',
        );
      }
    });
  });

  group('a malformed letters file', () {
    test('a ladder without a key names the file, not the field alone', () {
      expect(
        () => LetterLadderLibrary.fromJson(
          fileWith('letters', <Map<String, dynamic>>[
            validLadder()..remove('key'),
          ]),
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('key'),
          ),
        ),
      );
    });

    test('an empty syllable or word list is rejected', () {
      // Both lists are what the drill actually says out loud. Either one empty
      // is a ladder that renders as a card with nothing on it.
      expect(
        () => LetterLadderLibrary.fromJson(
          fileWith('letters', <Map<String, dynamic>>[
            validLadder()..['syllables'] = <String>[],
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => LetterLadderLibrary.fromJson(
          fileWith('letters', <Map<String, dynamic>>[
            validLadder()..['words'] = <String>[],
          ]),
        ),
        throwsFormatException,
      );
    });

    test('two ladders with one key are rejected', () {
      expect(
        () => LetterLadderLibrary.fromJson(
          fileWith('letters', <Map<String, dynamic>>[
            validLadder(),
            validLadder(),
          ]),
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('Duplicate'), contains('letters.json')),
          ),
        ),
      );
    });

    test('an unsupported schema fails on the header', () {
      final Map<String, dynamic> json = fileWith(
        'letters',
        <Map<String, dynamic>>[validLadder()],
      )..['schemaVersion'] = '2.0.0';

      expect(() => LetterLadderLibrary.fromJson(json), throwsFormatException);
    });
  });

  group('a malformed tongue twister file', () {
    test('a twister with no text is rejected', () {
      expect(
        () => TongueTwisterLibrary.fromJson(
          fileWith('tongueTwisters', <Map<String, dynamic>>[
            validTwister()..['text'] = '',
          ]),
        ),
        throwsFormatException,
      );
    });

    test('a duration of zero is rejected', () {
      expect(
        () => TongueTwisterLibrary.fromJson(
          fileWith('tongueTwisters', <Map<String, dynamic>>[
            validTwister()..['recommendedDurationSeconds'] = 0,
          ]),
        ),
        throwsFormatException,
      );
    });

    test('two twisters with one id are rejected', () {
      expect(
        () => TongueTwisterLibrary.fromJson(
          fileWith('tongueTwisters', <Map<String, dynamic>>[
            validTwister(),
            validTwister(),
          ]),
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

    test('an unknown difficulty or category is kept, not dropped', () {
      // Unlike a presentation type, neither of these decides whether the drill
      // works. A newer content file that adds "expert" must still be speakable
      // on this build.
      final TongueTwisterLibrary library = TongueTwisterLibrary.fromJson(
        fileWith('tongueTwisters', <Map<String, dynamic>>[
          validTwister()
            ..['difficulty'] = 'expert'
            ..['category'] = 'projection',
        ]),
      );

      expect(library.tongueTwisters, hasLength(1));
      expect(
        library.tongueTwisters.single.difficulty,
        TongueTwisterDifficulty.unknown,
      );
      expect(
        library.tongueTwisters.single.category,
        TongueTwisterCategory.unknown,
      );
      expect(library.tongueTwisters.single.text, isNotEmpty);
    });

    test('a missing difficulty is unknown rather than an error', () {
      final TongueTwisterLibrary library = TongueTwisterLibrary.fromJson(
        fileWith('tongueTwisters', <Map<String, dynamic>>[
          validTwister()..remove('difficulty'),
        ]),
      );

      expect(
        library.tongueTwisters.single.difficulty,
        TongueTwisterDifficulty.unknown,
      );
    });

    test('a difficulty that is not a string is still an error', () {
      // Absent is a schema allowance; wrong-typed is a content mistake, and
      // collapsing the two would hide the second.
      expect(
        () => TongueTwisterLibrary.fromJson(
          fileWith('tongueTwisters', <Map<String, dynamic>>[
            validTwister()..['difficulty'] = 3,
          ]),
        ),
        throwsFormatException,
      );
    });

    test('a null targetLetter is read as absent, not as an error', () {
      final TongueTwisterLibrary library = TongueTwisterLibrary.fromJson(
        fileWith('tongueTwisters', <Map<String, dynamic>>[
          validTwister()..['targetLetter'] = null,
        ]),
      );

      expect(library.tongueTwisters.single.targetLetter, isNull);
    });
  });

  group('a malformed speaking challenge file', () {
    test('a challenge with no prompt is rejected', () {
      expect(
        () => SpeakingChallengeLibrary.fromJson(
          fileWith('challenges', <Map<String, dynamic>>[
            validChallenge()..remove('prompt'),
          ]),
        ),
        throwsFormatException,
      );
    });

    test('a duration of zero is rejected but no preparation is fine', () {
      expect(
        () => SpeakingChallengeLibrary.fromJson(
          fileWith('challenges', <Map<String, dynamic>>[
            validChallenge()..['durationSeconds'] = 0,
          ]),
        ),
        throwsFormatException,
      );

      final SpeakingChallengeLibrary library =
          SpeakingChallengeLibrary.fromJson(
        fileWith('challenges', <Map<String, dynamic>>[
          validChallenge()..['preparationSeconds'] = 0,
        ]),
      );
      expect(library.challenges.single.preparationSeconds, 0);
      expect(library.challenges.single.totalSeconds, 60);
    });

    test('a missing preparation time is an error, not a zero', () {
      expect(
        () => SpeakingChallengeLibrary.fromJson(
          fileWith('challenges', <Map<String, dynamic>>[
            validChallenge()..remove('preparationSeconds'),
          ]),
        ),
        throwsFormatException,
      );
    });

    test('two challenges with one id are rejected', () {
      expect(
        () => SpeakingChallengeLibrary.fromJson(
          fileWith('challenges', <Map<String, dynamic>>[
            validChallenge(),
            validChallenge(),
          ]),
        ),
        throwsFormatException,
      );
    });
  });

  group('lookups', () {
    test('each library finds what it has and returns null for what it does not',
        () {
      final LetterLadderLibrary letters = LetterLadderLibrary.fromJson(
        fileWith('letters', <Map<String, dynamic>>[
          validLadder(),
          validLadder(key: 's_cedilla'),
        ]),
      );
      expect(letters.byKey('s_cedilla')?.key, 's_cedilla');
      expect(letters.byKey('r')?.key, 'r');
      expect(letters.byKey('nope'), isNull);

      final TongueTwisterLibrary twisters = TongueTwisterLibrary.fromJson(
        fileWith('tongueTwisters', <Map<String, dynamic>>[
          validTwister(),
          validTwister(id: 'tt_r_02'),
        ]),
      );
      expect(twisters.byId('tt_r_02')?.id, 'tt_r_02');
      expect(twisters.byId('tt_r_01')?.id, 'tt_r_01');
      expect(twisters.byId('nope'), isNull);

      final SpeakingChallengeLibrary challenges =
          SpeakingChallengeLibrary.fromJson(
        fileWith('challenges', <Map<String, dynamic>>[
          validChallenge(),
          validChallenge(id: 'sc_topic_90'),
        ]),
      );
      expect(challenges.byId('sc_topic_90')?.id, 'sc_topic_90');
      expect(challenges.byId('sc_intro_60')?.id, 'sc_intro_60');
      expect(challenges.byId('nope'), isNull);
    });

    test('byCategory returns only that category, and an empty list otherwise',
        () {
      final TongueTwisterLibrary library = TongueTwisterLibrary.fromJson(
        fileWith('tongueTwisters', <Map<String, dynamic>>[
          validTwister(),
          validTwister(id: 'tt_ritim_01')
            ..['category'] = 'rhythm'
            ..['targetLetter'] = null,
        ]),
      );

      expect(
        library.byCategory(TongueTwisterCategory.letter).single.id,
        'tt_r_01',
      );
      expect(
        library.byCategory(TongueTwisterCategory.rhythm).single.id,
        'tt_ritim_01',
      );
      expect(library.byCategory(TongueTwisterCategory.breath), isEmpty);
    });

    test('the lists a library hands out cannot be edited', () {
      // Content is read once and shared. A caller able to mutate this would be
      // changing what every other caller sees.
      final TongueTwisterLibrary library = TongueTwisterLibrary.fromJson(
        fileWith('tongueTwisters', <Map<String, dynamic>>[validTwister()]),
      );

      expect(() => library.tongueTwisters.clear(), throwsUnsupportedError);
      expect(
        () => library.byCategory(TongueTwisterCategory.letter).clear(),
        throwsUnsupportedError,
      );

      // Each library builds its own list, so one of them being unmodifiable
      // says nothing about the other two.
      final LetterLadderLibrary letters = LetterLadderLibrary.fromJson(
        fileWith('letters', <Map<String, dynamic>>[validLadder()]),
      );
      expect(() => letters.ladders.clear(), throwsUnsupportedError);

      final SpeakingChallengeLibrary challenges =
          SpeakingChallengeLibrary.fromJson(
        fileWith('challenges', <Map<String, dynamic>>[validChallenge()]),
      );
      expect(() => challenges.challenges.clear(), throwsUnsupportedError);
    });
  });

  group('value semantics', () {
    test('same content is equal, any difference is not', () {
      const LetterLadder ladder = LetterLadder(
        key: 'r',
        letter: 'R',
        syllables: <String>['RA'],
        words: <String>['Yer'],
      );

      expect(
        ladder,
        const LetterLadder(
          key: 'r',
          letter: 'R',
          syllables: <String>['RA'],
          words: <String>['Yer'],
        ),
      );
      expect(
        ladder,
        isNot(
          const LetterLadder(
            key: 'r',
            letter: 'R',
            syllables: <String>['RE'],
            words: <String>['Yer'],
          ),
        ),
      );
      expect(
        ladder,
        isNot(
          const LetterLadder(
            key: 'r',
            letter: 'R',
            syllables: <String>['RA'],
            words: <String>['Yer'],
            notes: 'note',
          ),
        ),
      );
      expect(ladder, ladder);
    });

    test('a twister compares every field, the last one included', () {
      const TongueTwister base = TongueTwister(
        id: 'tt_r_01',
        text: 'Bir.',
        difficulty: TongueTwisterDifficulty.easy,
        category: TongueTwisterCategory.letter,
        recommendedDurationSeconds: 60,
        targetLetter: 'R',
      );

      expect(
        base,
        const TongueTwister(
          id: 'tt_r_01',
          text: 'Bir.',
          difficulty: TongueTwisterDifficulty.easy,
          category: TongueTwisterCategory.letter,
          recommendedDurationSeconds: 60,
          targetLetter: 'R',
        ),
      );
      expect(
        base,
        isNot(
          const TongueTwister(
            id: 'tt_r_01',
            text: 'Bir.',
            difficulty: TongueTwisterDifficulty.easy,
            category: TongueTwisterCategory.letter,
            recommendedDurationSeconds: 60,
            targetLetter: 'S',
          ),
        ),
      );
      expect(
        base,
        isNot(
          const TongueTwister(
            id: 'tt_r_01',
            text: 'Bir.',
            difficulty: TongueTwisterDifficulty.hard,
            category: TongueTwisterCategory.letter,
            recommendedDurationSeconds: 60,
            targetLetter: 'R',
          ),
        ),
      );
    });

    test('a challenge compares every field, the last one included', () {
      const SpeakingChallenge base = SpeakingChallenge(
        id: 'sc_intro_60',
        title: 'Tanıtım',
        prompt: 'Kendini tanıt.',
        durationSeconds: 60,
        preparationSeconds: 3,
      );

      expect(
        base,
        const SpeakingChallenge(
          id: 'sc_intro_60',
          title: 'Tanıtım',
          prompt: 'Kendini tanıt.',
          durationSeconds: 60,
          preparationSeconds: 3,
        ),
      );
      expect(
        base,
        isNot(
          const SpeakingChallenge(
            id: 'sc_intro_60',
            title: 'Tanıtım',
            prompt: 'Kendini tanıt.',
            durationSeconds: 60,
            preparationSeconds: 5,
          ),
        ),
      );
    });

    test('a library compares its envelope as well as its records', () {
      final LetterLadderLibrary base = LetterLadderLibrary.fromJson(
        fileWith('letters', <Map<String, dynamic>>[validLadder()]),
      );
      final Map<String, dynamic> newer = fileWith(
        'letters',
        <Map<String, dynamic>>[validLadder()],
      )..['contentVersion'] = '0.2.0';

      expect(
        base,
        LetterLadderLibrary.fromJson(
          fileWith('letters', <Map<String, dynamic>>[validLadder()]),
        ),
      );
      expect(base, isNot(LetterLadderLibrary.fromJson(newer)));
      expect(base, base);
      expect(
        base,
        isNot(
          LetterLadderLibrary.fromJson(
            fileWith('letters', <Map<String, dynamic>>[
              validLadder(key: 'other'),
            ]),
          ),
        ),
      );
    });

    test('the other two libraries compare the same way', () {
      // Each library writes its own ==, so one library's test proves nothing
      // about the other two. These vary the envelope and the records
      // separately, which is what the equality actually branches on.
      final TongueTwisterLibrary twisters = TongueTwisterLibrary.fromJson(
        fileWith('tongueTwisters', <Map<String, dynamic>>[validTwister()]),
      );
      expect(
        twisters,
        TongueTwisterLibrary.fromJson(
          fileWith('tongueTwisters', <Map<String, dynamic>>[validTwister()]),
        ),
      );
      expect(twisters, twisters);
      expect(
        twisters,
        isNot(
          TongueTwisterLibrary.fromJson(
            fileWith('tongueTwisters', <Map<String, dynamic>>[
              validTwister(id: 'tt_other_01'),
            ]),
          ),
        ),
      );
      expect(
        twisters,
        isNot(
          TongueTwisterLibrary.fromJson(
            fileWith(
              'tongueTwisters',
              <Map<String, dynamic>>[validTwister()],
            )..['contentVersion'] = '0.2.0',
          ),
        ),
      );

      final SpeakingChallengeLibrary challenges =
          SpeakingChallengeLibrary.fromJson(
        fileWith('challenges', <Map<String, dynamic>>[validChallenge()]),
      );
      expect(
        challenges,
        SpeakingChallengeLibrary.fromJson(
          fileWith('challenges', <Map<String, dynamic>>[validChallenge()]),
        ),
      );
      expect(challenges, challenges);
      expect(
        challenges,
        isNot(
          SpeakingChallengeLibrary.fromJson(
            fileWith('challenges', <Map<String, dynamic>>[
              validChallenge(id: 'sc_other_60'),
            ]),
          ),
        ),
      );
      expect(
        challenges,
        isNot(
          SpeakingChallengeLibrary.fromJson(
            fileWith(
              'challenges',
              <Map<String, dynamic>>[validChallenge()],
            )..['contentVersion'] = '0.2.0',
          ),
        ),
      );

      // Different library types are never equal to one another.
      expect(twisters, isNot(challenges));
    });

    test('distinct records do not collapse onto one hash', () {
      final Set<int> hashes = <Object>{
        const LetterLadder(
          key: 'r',
          letter: 'R',
          syllables: <String>['RA'],
          words: <String>['Yer'],
        ),
        const LetterLadder(
          key: 's',
          letter: 'S',
          syllables: <String>['SA'],
          words: <String>['Ses'],
        ),
        const TongueTwister(
          id: 'a',
          text: 'Bir.',
          difficulty: TongueTwisterDifficulty.easy,
          category: TongueTwisterCategory.letter,
          recommendedDurationSeconds: 60,
        ),
        const TongueTwister(
          id: 'b',
          text: 'Bir.',
          difficulty: TongueTwisterDifficulty.easy,
          category: TongueTwisterCategory.letter,
          recommendedDurationSeconds: 60,
        ),
        const SpeakingChallenge(
          id: 'a',
          title: 'T',
          prompt: 'P',
          durationSeconds: 60,
          preparationSeconds: 3,
        ),
        const SpeakingChallenge(
          id: 'b',
          title: 'T',
          prompt: 'P',
          durationSeconds: 60,
          preparationSeconds: 3,
        ),
      }.map((Object o) => o.hashCode).toSet();

      expect(hashes, hasLength(6));
    });

    test('libraries do not collapse onto one hash either', () {
      final Set<int> hashes = <Object>{
        LetterLadderLibrary.fromJson(
          fileWith('letters', <Map<String, dynamic>>[validLadder()]),
        ),
        LetterLadderLibrary.fromJson(
          fileWith('letters', <Map<String, dynamic>>[validLadder(key: 'z')]),
        ),
        TongueTwisterLibrary.fromJson(
          fileWith('tongueTwisters', <Map<String, dynamic>>[validTwister()]),
        ),
        TongueTwisterLibrary.fromJson(
          fileWith('tongueTwisters', <Map<String, dynamic>>[
            validTwister(id: 'tt_z_01'),
          ]),
        ),
        SpeakingChallengeLibrary.fromJson(
          fileWith('challenges', <Map<String, dynamic>>[validChallenge()]),
        ),
        SpeakingChallengeLibrary.fromJson(
          fileWith('challenges', <Map<String, dynamic>>[
            validChallenge(id: 'sc_z_60'),
          ]),
        ),
      }.map((Object o) => o.hashCode).toSet();

      expect(hashes, hasLength(6));
    });
  });

  group('descriptions', () {
    test('each type says what it holds', () {
      expect(
        const LetterLadder(
          key: 'r',
          letter: 'R',
          syllables: <String>['RA', 'RE'],
          words: <String>['Yer'],
        ).toString(),
        allOf(contains('r'), contains('2'), contains('1')),
      );
      expect(
        const TongueTwister(
          id: 'tt_r_01',
          text: 'Bir.',
          difficulty: TongueTwisterDifficulty.hard,
          category: TongueTwisterCategory.breath,
          recommendedDurationSeconds: 60,
        ).toString(),
        allOf(contains('tt_r_01'), contains('breath'), contains('hard')),
      );
      expect(
        const SpeakingChallenge(
          id: 'sc_intro_60',
          title: 'T',
          prompt: 'P',
          durationSeconds: 60,
          preparationSeconds: 3,
        ).toString(),
        allOf(contains('sc_intro_60'), contains('60'), contains('3')),
      );
      expect(
        LetterLadderLibrary.fromJson(
          fileWith('letters', <Map<String, dynamic>>[validLadder()]),
        ).toString(),
        contains('1 ladder'),
      );
      expect(
        TongueTwisterLibrary.fromJson(
          fileWith('tongueTwisters', <Map<String, dynamic>>[validTwister()]),
        ).toString(),
        contains('1 tongue twister'),
      );
      expect(
        SpeakingChallengeLibrary.fromJson(
          fileWith('challenges', <Map<String, dynamic>>[validChallenge()]),
        ).toString(),
        contains('1 challenge'),
      );
    });

    test('every wire name round trips', () {
      for (final TongueTwisterDifficulty difficulty
          in TongueTwisterDifficulty.values) {
        expect(
          TongueTwisterDifficulty.fromWireName(difficulty.wireName),
          difficulty,
        );
      }
      for (final TongueTwisterCategory category
          in TongueTwisterCategory.values) {
        expect(TongueTwisterCategory.fromWireName(category.wireName), category);
      }
      expect(
        TongueTwisterDifficulty.fromWireName(null),
        TongueTwisterDifficulty.unknown,
      );
      expect(
        TongueTwisterCategory.fromWireName(null),
        TongueTwisterCategory.unknown,
      );
    });
  });
}
