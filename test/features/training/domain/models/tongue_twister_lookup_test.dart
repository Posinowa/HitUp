import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/text/turkish_case.dart';
import 'package:hitup/features/training/domain/models/models.dart';

const ContentEnvelope _envelope = ContentEnvelope(
  schemaVersion: '1.0.0',
  contentVersion: '1.0.0',
  status: ContentStatus.placeholder,
  locale: 'tr-TR',
);

TongueTwister _twister(
  String id, {
  String? letter,
  TongueTwisterDifficulty difficulty = TongueTwisterDifficulty.medium,
  TongueTwisterCategory category = TongueTwisterCategory.letter,
}) =>
    TongueTwister(
      id: id,
      text: '$id metni',
      difficulty: difficulty,
      category: category,
      recommendedDurationSeconds: 30,
      targetLetter: letter,
    );

TongueTwisterLibrary _library(List<TongueTwister> twisters) =>
    TongueTwisterLibrary(envelope: _envelope, tongueTwisters: twisters);

void main() {
  final TongueTwisterLibrary library = _library(<TongueTwister>[
    _twister('tt_r_01', letter: 'R'),
    _twister('tt_r_02', letter: 'r', difficulty: TongueTwisterDifficulty.hard),
    _twister('tt_s_01', letter: 'Ş', difficulty: TongueTwisterDifficulty.easy),
    _twister('tt_i_01', letter: 'I'),
    _twister('tt_i_02', letter: 'İ'),
    _twister(
      'tt_ritim_01',
      category: TongueTwisterCategory.rhythm,
      difficulty: TongueTwisterDifficulty.easy,
    ),
    _twister('tt_nefes_01', category: TongueTwisterCategory.breath),
  ]);

  List<String> ids(List<TongueTwister> twisters) =>
      twisters.map((TongueTwister t) => t.id).toList();

  /// The content file as it ships, so the lookups are checked against real
  /// letters rather than only the fixture above.
  Map<String, dynamic> readContentFile(String name) {
    final File file = File('assets/content/$name');
    expect(file.existsSync(), isTrue, reason: '$name must ship in the bundle');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  group('by target letter', () {
    test('matches either case, in file order', () {
      expect(ids(library.byTargetLetter('R')), <String>['tt_r_01', 'tt_r_02']);
      expect(ids(library.byTargetLetter('r')), <String>['tt_r_01', 'tt_r_02']);
      expect(ids(library.byTargetLetter('ş')), <String>['tt_s_01']);
    });

    test('keeps the Turkish i letters apart', () {
      // The whole reason the fold is Turkish: I and i are different letters,
      // and a drill for one must not answer a request for the other.
      expect(ids(library.byTargetLetter('I')), <String>['tt_i_01']);
      expect(ids(library.byTargetLetter('ı')), <String>['tt_i_01']);
      expect(ids(library.byTargetLetter('İ')), <String>['tt_i_02']);
      expect(ids(library.byTargetLetter('i')), <String>['tt_i_02']);
    });

    test('a letter nothing trains gives an empty list, not null', () {
      expect(library.byTargetLetter('Z'), isEmpty);
    });

    test('twisters with no target letter never match one', () {
      for (final String letter in <String>['R', 'ş', 'i', 'z']) {
        expect(
          ids(library.byTargetLetter(letter)),
          isNot(contains('tt_ritim_01')),
          reason: letter,
        );
      }
    });
  });

  group('by difficulty and category', () {
    test('difficulty filters across categories', () {
      expect(
        ids(library.byDifficulty(TongueTwisterDifficulty.easy)),
        <String>['tt_s_01', 'tt_ritim_01'],
      );
      expect(
        ids(library.byDifficulty(TongueTwisterDifficulty.hard)),
        <String>['tt_r_02'],
      );
      expect(library.byDifficulty(TongueTwisterDifficulty.unknown), isEmpty);
    });

    test('category still works, now through the same matching', () {
      expect(
        ids(library.byCategory(TongueTwisterCategory.rhythm)),
        <String>['tt_ritim_01'],
      );
      expect(library.byCategory(TongueTwisterCategory.unknown), isEmpty);
    });
  });

  group('combined', () {
    test('every filter has to match', () {
      expect(
        ids(
          library.where(
            targetLetter: 'r',
            difficulty: TongueTwisterDifficulty.hard,
          ),
        ),
        <String>['tt_r_02'],
      );
      expect(
        library.where(
          targetLetter: 'r',
          difficulty: TongueTwisterDifficulty.easy,
        ),
        isEmpty,
      );
      expect(
        ids(
          library.where(
            category: TongueTwisterCategory.letter,
            difficulty: TongueTwisterDifficulty.easy,
          ),
        ),
        <String>['tt_s_01'],
      );
    });

    test('no filter is the whole library, in file order', () {
      expect(ids(library.where()), ids(library.tongueTwisters));
    });

    test('the result cannot be modified by a caller', () {
      expect(
        () => library.where().add(_twister('tt_x')),
        throwsUnsupportedError,
      );
    });
  });

  group('the letters on offer', () {
    test('are folded, unique, in file order, and skip the letterless', () {
      expect(library.targetLetters, <String>['r', 'ş', 'ı', 'i']);
    });

    test('a library with no letter drills offers none', () {
      final TongueTwisterLibrary rhythmOnly = _library(<TongueTwister>[
        _twister('tt_ritim_01', category: TongueTwisterCategory.rhythm),
      ]);
      expect(rhythmOnly.targetLetters, isEmpty);
    });
  });

  group('the shipped file', () {
    test('every letter it offers finds at least one twister', () {
      final TongueTwisterLibrary shipped = TongueTwisterLibrary.fromJson(
        readContentFile('tongue_twisters.json'),
      );

      expect(shipped.targetLetters, isNotEmpty);
      for (final String letter in shipped.targetLetters) {
        expect(
          shipped.byTargetLetter(letter),
          isNotEmpty,
          reason: 'no twister for "$letter"',
        );
        // Asking in upper case has to find the same ones. Upper-cased the
        // Turkish way: Dart's own would turn "i" into "I", a different letter,
        // and the lookup would then correctly find nothing.
        expect(
          ids(shipped.byTargetLetter(turkishUpperCase(letter))),
          ids(shipped.byTargetLetter(letter)),
          reason: letter,
        );
      }
    });

    test('every difficulty the file uses is reachable', () {
      final TongueTwisterLibrary shipped = TongueTwisterLibrary.fromJson(
        readContentFile('tongue_twisters.json'),
      );

      final Set<TongueTwisterDifficulty> used =
          shipped.tongueTwisters.map((TongueTwister t) => t.difficulty).toSet();
      expect(used, isNotEmpty);
      for (final TongueTwisterDifficulty difficulty in used) {
        expect(
          shipped.byDifficulty(difficulty),
          isNotEmpty,
          reason: difficulty.wireName,
        );
      }
    });
  });
}
