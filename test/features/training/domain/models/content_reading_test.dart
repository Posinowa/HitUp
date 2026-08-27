import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/training/domain/models/content_envelope.dart';
import 'package:hitup/features/training/domain/models/json_reader.dart';

/// Tests for the layer that reads curriculum JSON safely (HIT-022).
///
/// Nothing here knows about exercises. This layer's whole job is to turn a
/// decoded map into typed values, and to fail with a sentence someone can act
/// on when it cannot. That is testable, and worth testing, without any model on
/// top of it.
void main() {
  const String owner = 'sample_exercise_01';

  group('required strings', () {
    test('reads a value that is there', () {
      expect(
        <String, dynamic>{'title': 'Başlık'}.requireString(
          'title',
          ownerId: owner,
        ),
        'Başlık',
      );
    });

    test('a missing field names both the field and the owner', () {
      // The whole reason this layer exists: "type 'Null' is not a subtype of
      // type 'String'" does not say which of thirteen exercises is wrong.
      expect(
        () => <String, dynamic>{}.requireString('title', ownerId: owner),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('title'), contains(owner)),
          ),
        ),
      );
    });

    test('an empty string is treated as missing', () {
      // An exercise with an empty title renders as a blank card, which reads
      // as a rendering bug rather than the content mistake it is.
      expect(
        () => <String, dynamic>{'title': ''}.requireString(
          'title',
          ownerId: owner,
        ),
        throwsFormatException,
      );
    });

    test('a wrong type is rejected', () {
      expect(
        () => <String, dynamic>{'title': 42}.requireString(
          'title',
          ownerId: owner,
        ),
        throwsFormatException,
      );
    });

    test('the message carries the value that was actually there', () {
      // Without the offending value, someone reading the log knows a field is
      // wrong but not what is in it, and has to open the file to find out.
      expect(
        () => <String, dynamic>{'title': 42}.requireString(
          'title',
          ownerId: owner,
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('int'), contains('42')),
          ),
        ),
      );

      // Absent reads as "nothing" rather than as the word null, which is what
      // a person would say about a field that is not there.
      expect(
        () => <String, dynamic>{}.requireString('title', ownerId: owner),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('nothing'),
          ),
        ),
      );
    });
  });

  group('optional strings', () {
    test('absent reads as null', () {
      expect(
        <String, dynamic>{}.optionalString('stateMachine', ownerId: owner),
        isNull,
      );
    });

    test('present but wrongly typed still throws', () {
      // Absent and malformed are different problems and must not merge into
      // one silent null.
      expect(
        () => <String, dynamic>{'stateMachine': 7}.optionalString(
          'stateMachine',
          ownerId: owner,
        ),
        throwsFormatException,
      );
    });
  });

  group('integers', () {
    test('reads a whole number', () {
      expect(
        <String, dynamic>{'durationSeconds': 30}.requireInt(
          'durationSeconds',
          ownerId: owner,
        ),
        30,
      );
    });

    test('a double is rejected even with no fraction', () {
      // Durations and repetition counts are counts. Accepting 4.0 invites 4.5.
      expect(
        () => <String, dynamic>{'durationSeconds': 30.0}.requireInt(
          'durationSeconds',
          ownerId: owner,
        ),
        throwsFormatException,
      );
    });

    test('a numeric string is rejected', () {
      expect(
        () => <String, dynamic>{'durationSeconds': '30'}.requireInt(
          'durationSeconds',
          ownerId: owner,
        ),
        throwsFormatException,
      );
    });

    test('a minimum is enforced and reported with both numbers', () {
      expect(
        () => <String, dynamic>{'cycles': 0}.requireIntAtLeast(
          'cycles',
          1,
          ownerId: owner,
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('at least 1'), contains('0')),
          ),
        ),
      );
    });

    test('a value exactly at the minimum passes', () {
      expect(
        <String, dynamic>{'cycles': 1}.requireIntAtLeast(
          'cycles',
          1,
          ownerId: owner,
        ),
        1,
      );
    });
  });

  group('lists', () {
    test('reads a list of strings', () {
      expect(
        <String, dynamic>{
          'ids': <dynamic>['tt_r_01', 'tt_s_01'],
        }.requireStringList('ids', ownerId: owner),
        <String>['tt_r_01', 'tt_s_01'],
      );
    });

    test('an empty list is rejected unless the caller allows it', () {
      // A config carrying a list of ids needs at least one. An empty list
      // renders as an exercise that does nothing.
      expect(
        () => <String, dynamic>{'ids': <dynamic>[]}.requireStringList(
          'ids',
          ownerId: owner,
        ),
        throwsFormatException,
      );
      expect(
        <String, dynamic>{'ids': <dynamic>[]}.requireStringList(
          'ids',
          ownerId: owner,
          allowEmpty: true,
        ),
        isEmpty,
      );
    });

    test('one bad item rejects the whole list', () {
      expect(
        () => <String, dynamic>{
          'ids': <dynamic>['tt_r_01', 7],
        }.requireStringList('ids', ownerId: owner),
        throwsFormatException,
      );
    });

    test('an empty item is reported as its own kind of mistake', () {
      // Narrower than the message for a field that is not a list: there the
      // shape is wrong, here the shape is right and one entry is not. Telling
      // someone their list is not a list, when the real problem is a blank
      // entry inside it, sends them looking in the wrong place.
      expect(
        () => <String, dynamic>{
          'ids': <dynamic>['tt_r_01', ''],
        }.requireStringList('ids', ownerId: owner),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('a list of non empty strings'),
          ),
        ),
      );

      expect(
        () => <String, dynamic>{'ids': 'tt_r_01'}.requireStringList(
          'ids',
          ownerId: owner,
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(
              contains('a list of strings'),
              isNot(contains('non empty')),
            ),
          ),
        ),
      );
    });

    test('the returned list cannot be modified', () {
      // Content is read once and shared. A caller that could mutate it would
      // be changing what every other caller sees.
      final List<String> ids = <String, dynamic>{
        'ids': <dynamic>['tt_r_01'],
      }.requireStringList('ids', ownerId: owner);

      expect(() => ids.add('tt_s_01'), throwsUnsupportedError);
    });

    test('a field that is not a list at all is rejected', () {
      // Distinct from a list containing a bad item: here the field itself is
      // the wrong shape, and the message should say so rather than talk about
      // the items it does not have.
      for (final Object bad in <Object>[
        'x',
        5,
        <String, dynamic>{'k': 1}
      ]) {
        final Map<String, dynamic> json = <String, dynamic>{'a': bad};

        expect(
          () => json.requireStringList('a', ownerId: owner),
          throwsA(
            isA<FormatException>().having(
              (FormatException e) => e.message,
              'message',
              allOf(contains('a list of strings'), contains(owner)),
            ),
          ),
          reason: 'strings, given ${bad.runtimeType}',
        );
        expect(
          () => json.requireIntList('a', ownerId: owner),
          throwsFormatException,
          reason: 'ints, given ${bad.runtimeType}',
        );
        expect(
          () => json.requireObjectList('a', ownerId: owner),
          throwsFormatException,
          reason: 'objects, given ${bad.runtimeType}',
        );
      }
    });

    test('an absent field is rejected the same way as a wrong shaped one', () {
      const Map<String, dynamic> json = <String, dynamic>{};

      expect(
        () => json.requireStringList('a', ownerId: owner),
        throwsFormatException,
      );
      expect(
        () => json.requireIntList('a', ownerId: owner),
        throwsFormatException,
      );
      expect(
        () => json.requireObjectList('a', ownerId: owner),
        throwsFormatException,
      );
    });

    test('reads a list of integers and rejects a mixed one', () {
      expect(
        <String, dynamic>{
          'indexes': <dynamic>[0, 3],
        }.requireIntList('indexes', ownerId: owner),
        <int>[0, 3],
      );
      expect(
        () => <String, dynamic>{
          'indexes': <dynamic>[0, '3'],
        }.requireIntList('indexes', ownerId: owner),
        throwsFormatException,
      );
    });

    test('every list reader returns something a caller cannot modify', () {
      // All three go through one helper for exactly this reason. Written out
      // separately, the object reader had already stopped doing it while the
      // other two still did.
      final Map<String, dynamic> json = <String, dynamic>{
        'strings': <dynamic>['tt_r_01'],
        'ints': <dynamic>[0],
        'objects': <dynamic>[
          <String, dynamic>{'wordIndex': 0},
        ],
      };

      expect(
        () => json.requireStringList('strings', ownerId: owner).clear(),
        throwsUnsupportedError,
      );
      expect(
        () => json.requireIntList('ints', ownerId: owner).clear(),
        throwsUnsupportedError,
      );
      expect(
        () => json.requireObjectList('objects', ownerId: owner).clear(),
        throwsUnsupportedError,
      );
    });

    test('a list of integers rejects a double the same way a field does', () {
      // Same reasoning as requireInt: these are counts, and accepting 4.0
      // invites 4.5. The rule has to hold inside a list too.
      expect(
        () => <String, dynamic>{
          'indexes': <dynamic>[0, 3.0],
        }.requireIntList('indexes', ownerId: owner),
        throwsFormatException,
      );
    });

    test('a list of objects rejects a loosely typed map', () {
      // jsonDecode always produces Map<String, dynamic>, so anything looser
      // came from somewhere else and the reader should not quietly accept it.
      expect(
        () => <String, dynamic>{
          'contour': <dynamic>[
            <dynamic, dynamic>{'wordIndex': 0}
          ],
        }.requireObjectList('contour', ownerId: owner),
        throwsFormatException,
      );
    });

    test('an empty list says which field and which owner', () {
      // The message is the whole point of this layer. "empty" on its own
      // sends someone hunting through five files.
      expect(
        () => <String, dynamic>{'ids': <dynamic>[]}.requireStringList(
          'ids',
          ownerId: owner,
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('ids'), contains(owner), contains('non empty')),
          ),
        ),
      );
    });

    test('reads a list of objects and rejects a mixed one', () {
      expect(
        <String, dynamic>{
          'contour': <dynamic>[
            <String, dynamic>{'wordIndex': 0},
          ],
        }.requireObjectList('contour', ownerId: owner),
        hasLength(1),
      );
      expect(
        () => <String, dynamic>{
          'contour': <dynamic>['not an object'],
        }.requireObjectList('contour', ownerId: owner),
        throwsFormatException,
      );
    });
  });

  group('nested objects', () {
    test('reads an object and rejects a non object', () {
      expect(
        <String, dynamic>{
          'media': <String, dynamic>{'kind': 'rive'},
        }.requireObject('media', ownerId: owner),
        <String, dynamic>{'kind': 'rive'},
      );
      expect(
        () => <String, dynamic>{'media': 'rive'}.requireObject(
          'media',
          ownerId: owner,
        ),
        throwsFormatException,
      );
    });

    test('an optional object may be absent but not malformed', () {
      expect(
        <String, dynamic>{}.optionalObject('media', ownerId: owner),
        isNull,
      );
      expect(
        () => <String, dynamic>{'media': 5}.optionalObject(
          'media',
          ownerId: owner,
        ),
        throwsFormatException,
      );
    });
  });

  group('the content files that actually ship', () {
    // Everything above works on maps built by hand. This group reads the real
    // files, because the layer is only useful if it survives what jsonDecode
    // actually produces: nested objects arrive as Map<String, dynamic> rather
    // than Map<dynamic, dynamic>, and the type checks depend on that.
    const Map<String, String> files = <String, String>{
      'exercises.json': 'exercises',
      'letters.json': 'letters',
      'program.json': 'days',
      'tongue_twisters.json': 'tongueTwisters',
      'speaking_challenges.json': 'challenges',
    };

    Map<String, dynamic> read(String name) {
      final File file = File('assets/content/$name');
      expect(file.existsSync(), isTrue, reason: '$name must ship');
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    }

    test('every shipped file carries a readable envelope', () {
      files.forEach((String name, String _) {
        final ContentEnvelope envelope = ContentEnvelope.fromJson(
          read(name),
          ownerId: name,
        );

        expect(envelope.isSupported, isTrue, reason: '$name schema version');
        expect(envelope.locale, 'tr-TR', reason: '$name locale');
        expect(
          envelope.status,
          ContentStatus.placeholder,
          reason: '$name is not approved content yet; HIT-080 flips this',
        );
        expect(
          () => envelope.ensureSupported(name),
          returnsNormally,
          reason: '$name must be parseable by this build',
        );
      });
    });

    test('every shipped file has a readable root array', () {
      // The root array is read through requireObjectList, so this is where a
      // type mismatch between jsonDecode and the reader would show up.
      files.forEach((String name, String rootKey) {
        final List<Map<String, dynamic>> records = read(
          name,
        ).requireObjectList(rootKey, ownerId: name);

        expect(records, isNotEmpty, reason: '$name.$rootKey');
        expect(
          () => records.clear(),
          throwsUnsupportedError,
          reason: '$name records must not be mutable',
        );
      });
    });
  });

  group('the content envelope', () {
    Map<String, dynamic> envelopeJson({String schemaVersion = '1.0.0'}) =>
        <String, dynamic>{
          'schemaVersion': schemaVersion,
          'contentVersion': '0.1.0',
          'status': 'placeholder',
          'locale': 'tr-TR',
        };

    test('reads every field', () {
      final ContentEnvelope envelope = ContentEnvelope.fromJson(
        envelopeJson(),
        ownerId: 'exercises.json',
      );

      expect(envelope.schemaVersion, '1.0.0');
      expect(envelope.contentVersion, '0.1.0');
      expect(envelope.status, ContentStatus.placeholder);
      expect(envelope.locale, 'tr-TR');
      expect(envelope.schemaMajor, 1);
    });

    test('an unknown status falls back instead of throwing', () {
      // Same forward-compatibility rule as everywhere else: a newer content
      // file must not be unreadable to an older build.
      final ContentEnvelope envelope = ContentEnvelope.fromJson(
        envelopeJson()..['status'] = 'under_review',
        ownerId: 'exercises.json',
      );

      expect(envelope.status, ContentStatus.unknown);
    });

    test('the supported major version is accepted at any minor or patch', () {
      // Minor bumps are additive. Refusing them would make every field
      // addition a forced app update.
      for (final String version in <String>['1.0.0', '1.4.2', '1.99.0']) {
        expect(
          ContentEnvelope.fromJson(
            envelopeJson(schemaVersion: version),
            ownerId: 'exercises.json',
          ).isSupported,
          isTrue,
          reason: '$version should be readable',
        );
      }
    });

    test('a different major version is refused', () {
      // A major bump renames or removes fields, so an older parser would build
      // quietly wrong models rather than fail.
      final ContentEnvelope envelope = ContentEnvelope.fromJson(
        envelopeJson(schemaVersion: '2.0.0'),
        ownerId: 'exercises.json',
      );

      expect(envelope.isSupported, isFalse);
      expect(
        () => envelope.ensureSupported('exercises.json'),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('Unsupported schemaVersion'), contains('2.0.0')),
          ),
        ),
      );
    });

    test('a version that is not semver is refused rather than guessed at', () {
      final ContentEnvelope envelope = ContentEnvelope.fromJson(
        envelopeJson(schemaVersion: 'draft'),
        ownerId: 'exercises.json',
      );

      expect(envelope.schemaMajor, isNull);
      expect(envelope.isSupported, isFalse);
    });

    test('a supported version passes the guard silently', () {
      expect(
        () => ContentEnvelope.fromJson(
          envelopeJson(),
          ownerId: 'exercises.json',
        ).ensureSupported('exercises.json'),
        returnsNormally,
      );
    });

    test('every required field is genuinely required', () {
      // Each one dropped in turn, so a field quietly gaining a default cannot
      // pass unnoticed. A content file missing its locale is a file nobody
      // decided the language of.
      for (final String field in <String>[
        'schemaVersion',
        'contentVersion',
        'locale',
      ]) {
        final Map<String, dynamic> json = envelopeJson()..remove(field);

        expect(
          () => ContentEnvelope.fromJson(json, ownerId: 'exercises.json'),
          throwsA(
            isA<FormatException>().having(
              (FormatException e) => e.message,
              'message',
              contains(field),
            ),
          ),
          reason: '$field must not have a fallback',
        );
      }
    });

    test('envelopes compare by content', () {
      final ContentEnvelope a = ContentEnvelope.fromJson(
        envelopeJson(),
        ownerId: 'exercises.json',
      );
      final ContentEnvelope b = ContentEnvelope.fromJson(
        envelopeJson(),
        ownerId: 'exercises.json',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);

      // Each field checked separately, so equality cannot quietly stop
      // reading one of them.
      final Map<String, Map<String, dynamic>> variants =
          <String, Map<String, dynamic>>{
        'schemaVersion': envelopeJson(schemaVersion: '1.1.0'),
        'contentVersion': envelopeJson()..['contentVersion'] = '0.2.0',
        'status': envelopeJson()..['status'] = 'approved',
        'locale': envelopeJson()..['locale'] = 'en-US',
      };

      variants.forEach((String field, Map<String, dynamic> json) {
        final ContentEnvelope other = ContentEnvelope.fromJson(
          json,
          ownerId: 'exercises.json',
        );

        expect(a, isNot(other), reason: '$field is part of the identity');
        // Not required by the hashCode contract, which permits collisions,
        // but a constant hash would make every envelope collide and is what
        // this catches.
        expect(
          a.hashCode,
          isNot(other.hashCode),
          reason: '$field should reach the hash',
        );
      });
    });

    test('its description names the versions, the status and the locale', () {
      // Only a diagnostic, but it is what a log line will carry when someone
      // is working out why a content file was refused.
      final ContentEnvelope envelope = ContentEnvelope.fromJson(
        envelopeJson(),
        ownerId: 'exercises.json',
      );

      expect(
        envelope.toString(),
        allOf(
          contains('1.0.0'),
          contains('0.1.0'),
          contains('placeholder'),
          contains('tr-TR'),
        ),
      );
    });

    test('a malformed envelope names the file it came from', () {
      expect(
        () => ContentEnvelope.fromJson(
          <String, dynamic>{
            'contentVersion': '0.1.0',
            'status': 'placeholder',
            'locale': 'tr-TR',
          },
          ownerId: 'letters.json',
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            allOf(contains('schemaVersion'), contains('letters.json')),
          ),
        ),
      );
    });
  });
}
