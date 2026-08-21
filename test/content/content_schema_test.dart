import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Validates the local curriculum files under `assets/content/` against
/// `docs/architecture/CONTENT_SCHEMA.md` (HIT-012).
///
/// This test deliberately uses no Dart domain models. Parsing content into
/// models, and testing that, belongs to HIT-022. The question here is narrower:
/// does the JSON on disk match the documented schema.
void main() {
  const contentDir = 'assets/content';

  const presentationTypes = <String>{
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
  };

  /// The one config block each presentation type may carry.
  /// Types absent from this map carry none.
  const configBlockFor = <String, String>{
    'audio': 'media',
    'breathing': 'breathing',
    'rive': 'media',
    'articulation': 'media',
    'letter': 'letter',
    'tongueTwister': 'tongueTwister',
    'emphasis': 'emphasis',
    'intonation': 'intonation',
    'pause': 'pause',
    'timedReading': 'timedReading',
    'speakingChallenge': 'speakingChallenge',
  };

  const allConfigBlocks = <String>{
    'media',
    'breathing',
    'letter',
    'tongueTwister',
    'emphasis',
    'intonation',
    'pause',
    'timedReading',
    'speakingChallenge',
  };

  const mediaKinds = <String>{'rive', 'audio', 'image'};
  const difficulties = <String>{'easy', 'medium', 'hard'};
  const twisterCategories = <String>{'letter', 'rhythm', 'breath'};
  const contourDirections = <String>{'rise', 'fall', 'flat'};
  const statuses = <String>{'placeholder', 'approved'};

  final idPattern = RegExp(r'^[a-z0-9_]+$');
  final semverPattern = RegExp(r'^\d+\.\d+\.\d+$');
  final whitespace = RegExp(r'\s+');

  Map<String, dynamic> read(String name) {
    final file = File('$contentDir/$name');
    if (!file.existsSync()) {
      fail('$contentDir/$name is missing');
    }
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  final program = read('program.json');
  final exercisesFile = read('exercises.json');
  final lettersFile = read('letters.json');
  final twistersFile = read('tongue_twisters.json');
  final challengesFile = read('speaking_challenges.json');

  final files = <String, Map<String, dynamic>>{
    'program.json': program,
    'exercises.json': exercisesFile,
    'letters.json': lettersFile,
    'tongue_twisters.json': twistersFile,
    'speaking_challenges.json': challengesFile,
  };

  List<Map<String, dynamic>> rows(Map<String, dynamic> file, String key) =>
      (file[key] as List<dynamic>).cast<Map<String, dynamic>>();

  final exercises = rows(exercisesFile, 'exercises');
  final letters = rows(lettersFile, 'letters');
  final twisters = rows(twistersFile, 'tongueTwisters');
  final challenges = rows(challengesFile, 'challenges');

  final exerciseIds = exercises.map((e) => e['id'] as String).toSet();
  final letterKeys = letters.map((e) => e['key'] as String).toSet();
  final twisterIds = twisters.map((e) => e['id'] as String).toSet();
  final challengeIds = challenges.map((e) => e['id'] as String).toSet();

  group('envelope', () {
    files.forEach((name, file) {
      test('$name carries a valid envelope', () {
        expect(
          file['schemaVersion'],
          matches(semverPattern),
          reason: '$name schemaVersion must be semver',
        );
        expect(
          file['contentVersion'],
          matches(semverPattern),
          reason: '$name contentVersion must be semver',
        );
        expect(
          statuses,
          contains(file['status']),
          reason: '$name status must be placeholder or approved',
        );
        expect(
          file['locale'],
          'tr-TR',
          reason: '$name locale must be tr-TR for MVP',
        );
      });
    });
  });

  group('identifiers', () {
    test('exercise ids are unique and well formed', () {
      expect(exerciseIds.length, exercises.length, reason: 'duplicate id');
      for (final id in exerciseIds) {
        expect(id, matches(idPattern), reason: 'bad exercise id: $id');
      }
    });

    test('letter keys are unique and well formed', () {
      expect(letterKeys.length, letters.length, reason: 'duplicate key');
      for (final key in letterKeys) {
        expect(key, matches(idPattern), reason: 'bad letter key: $key');
      }
    });

    test('every example word actually contains its target letter', () {
      // Caught a real bug: "Tutucu" and "Yer" (from the note "Yer tutucu",
      // Turkish for "placeholder") had leaked into the word lists as if
      // they were examples, for letters they don't even contain.
      //
      // toLowerCase() is fine for the letters currently in this file. It is
      // NOT Turkish-aware for I/ı/İ/i, so if a letter entry for one of those
      // is ever added, this check needs a proper Turkish case fold instead.
      for (final letter in letters) {
        final target = (letter['letter'] as String).toLowerCase();
        final words = (letter['words'] as List<dynamic>).cast<String>();
        for (final word in words) {
          expect(
            word.toLowerCase(),
            contains(target),
            reason: '${letter['key']}: "$word" has no "$target"',
          );
        }
      }
    });

    test('tongue twister ids are unique and prefixed tt_', () {
      expect(twisterIds.length, twisters.length, reason: 'duplicate id');
      for (final id in twisterIds) {
        expect(id, matches(idPattern), reason: 'bad twister id: $id');
        expect(id, startsWith('tt_'), reason: 'twister id needs tt_: $id');
      }
    });

    test('speaking challenge ids are unique and prefixed sc_', () {
      expect(challengeIds.length, challenges.length, reason: 'duplicate id');
      for (final id in challengeIds) {
        expect(id, matches(idPattern), reason: 'bad challenge id: $id');
        expect(id, startsWith('sc_'), reason: 'challenge id needs sc_: $id');
      }
    });
  });

  group('exercises', () {
    test('every exercise has the required fields', () {
      for (final exercise in exercises) {
        final id = exercise['id'];
        expect(exercise['title'], isA<String>(), reason: '$id title');
        expect(exercise['instructions'], isA<String>(), reason: '$id copy');
        expect(exercise['durationSeconds'], isA<int>(), reason: '$id duration');
        expect(
          exercise['durationSeconds'] as int,
          greaterThan(0),
          reason: '$id durationSeconds must be positive',
        );
      }
    });

    test('every presentationType is a documented value', () {
      for (final exercise in exercises) {
        expect(
          presentationTypes,
          contains(exercise['presentationType']),
          reason: 'undocumented type on ${exercise['id']}',
        );
      }
    });

    test('the sample set covers every presentation type', () {
      final used = exercises.map((e) => e['presentationType']).toSet();
      expect(
        used,
        containsAll(presentationTypes),
        reason: 'sample content must exercise every documented type',
      );
    });

    test('each exercise carries at most one matching config block', () {
      for (final exercise in exercises) {
        final id = exercise['id'];
        final type = exercise['presentationType'] as String;
        final expected = configBlockFor[type];
        final present = allConfigBlocks.where(exercise.containsKey).toList();

        if (expected == null) {
          expect(present, isEmpty, reason: '$id ($type) needs no config block');
        } else {
          expect(present, [expected], reason: '$id ($type) block mismatch');
        }
      }
    });

    test('media references use a key, never a path', () {
      for (final exercise in exercises) {
        final media = exercise['media'] as Map<String, dynamic>?;
        if (media == null) continue;
        final id = exercise['id'];

        expect(mediaKinds, contains(media['kind']), reason: '$id media kind');
        expect(
          media['key'],
          matches(idPattern),
          reason: '$id media key must be a bare key, no folder or extension',
        );
        if (media['kind'] != 'rive') {
          expect(
            media.containsKey('stateMachine'),
            isFalse,
            reason: '$id stateMachine belongs to rive media only',
          );
        }
      }
    });

    test('word indexes stay inside their own text', () {
      void checkIndexes(String id, String text, Iterable<int> indexes) {
        final wordCount = text.trim().split(whitespace).length;
        for (final index in indexes) {
          expect(
            index,
            inInclusiveRange(0, wordCount - 1),
            reason: '$id index $index is outside its text',
          );
        }
      }

      for (final exercise in exercises) {
        final id = exercise['id'] as String;

        final emphasis = exercise['emphasis'] as Map<String, dynamic>?;
        if (emphasis != null) {
          checkIndexes(
            id,
            emphasis['text'] as String,
            (emphasis['emphasisWordIndexes'] as List<dynamic>).cast<int>(),
          );
        }

        final pause = exercise['pause'] as Map<String, dynamic>?;
        if (pause != null) {
          checkIndexes(
            id,
            pause['text'] as String,
            (pause['pauseAfterWordIndexes'] as List<dynamic>).cast<int>(),
          );
        }

        final intonation = exercise['intonation'] as Map<String, dynamic>?;
        if (intonation != null) {
          final contour = (intonation['contour'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
          checkIndexes(
            id,
            intonation['text'] as String,
            contour.map((point) => point['wordIndex'] as int),
          );
          for (final point in contour) {
            expect(
              contourDirections,
              contains(point['direction']),
              reason: '$id contour direction',
            );
          }
        }
      }
    });
  });

  group('enumerations', () {
    test('tongue twister difficulty and category are documented values', () {
      for (final twister in twisters) {
        final id = twister['id'];
        expect(
          difficulties,
          contains(twister['difficulty']),
          reason: '$id difficulty',
        );
        expect(
          twisterCategories,
          contains(twister['category']),
          reason: '$id category',
        );
      }
    });
  });

  group('cross file references', () {
    test('program day exercise ids all resolve', () {
      final days = rows(program, 'days');
      expect(days, isNotEmpty, reason: 'program has no days');

      for (final day in days) {
        expect(day['day'], isA<int>(), reason: 'day number');
        expect(
          day['estimatedMinutes'] as int,
          greaterThan(0),
          reason: 'day ${day['day']} estimatedMinutes',
        );

        final ids = (day['exerciseIds'] as List<dynamic>).cast<String>();
        expect(ids, isNotEmpty, reason: 'day ${day['day']} has no exercises');
        for (final id in ids) {
          expect(
            exerciseIds,
            contains(id),
            reason: 'day ${day['day']} points at unknown exercise $id',
          );
        }
      }
    });

    test('every referenced letter, twister and challenge exists', () {
      for (final exercise in exercises) {
        final id = exercise['id'];

        final letter = exercise['letter'] as Map<String, dynamic>?;
        if (letter != null) {
          expect(
            letterKeys,
            contains(letter['letterKey']),
            reason: '$id points at unknown letter ${letter['letterKey']}',
          );
        }

        final twister = exercise['tongueTwister'] as Map<String, dynamic>?;
        if (twister != null) {
          final ids =
              (twister['tongueTwisterIds'] as List<dynamic>).cast<String>();
          expect(ids, isNotEmpty, reason: '$id lists no twisters');
          for (final twisterId in ids) {
            expect(
              twisterIds,
              contains(twisterId),
              reason: '$id points at unknown twister $twisterId',
            );
          }
        }

        final speaking = exercise['speakingChallenge'] as Map<String, dynamic>?;
        if (speaking != null) {
          expect(
            challengeIds,
            contains(speaking['challengeId']),
            reason: '$id points at unknown challenge',
          );
        }
      }
    });

    test('every exercise is reachable from the program', () {
      final scheduled = <String>{
        for (final day in rows(program, 'days'))
          ...(day['exerciseIds'] as List<dynamic>).cast<String>(),
      };
      expect(
        scheduled,
        containsAll(exerciseIds),
        reason: 'some exercises are defined but never scheduled',
      );
    });
  });
}
