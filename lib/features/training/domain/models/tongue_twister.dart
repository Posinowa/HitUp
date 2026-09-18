import 'package:flutter/foundation.dart';

import '../../../../core/text/turkish_case.dart';
import 'content_envelope.dart';
import 'json_reader.dart';

/// How hard a tongue twister is meant to be.
///
/// Stored as a string for the same reason presentation types are: an unknown
/// value stays readable in a log or a diff.
enum TongueTwisterDifficulty {
  /// Short, few consonant clusters.
  easy('easy'),

  /// The default working level.
  medium('medium'),

  /// Long, or dense with the target sound.
  hard('hard'),

  /// A level this build does not recognise.
  ///
  /// Never present in a content file. Unlike an unknown presentation type,
  /// which makes an exercise unrenderable, an unknown difficulty costs nothing:
  /// the twister is still a sentence and can still be spoken. It affects
  /// ordering and labelling, not whether the drill works, so the record is kept
  /// rather than skipped.
  unknown('unknown');

  const TongueTwisterDifficulty(this.wireName);

  /// The exact string used in the content files.
  final String wireName;

  /// Resolves [value] to a difficulty, falling back to [unknown].
  static TongueTwisterDifficulty fromWireName(String? value) {
    for (final TongueTwisterDifficulty difficulty in values) {
      if (difficulty.wireName == value) {
        return difficulty;
      }
    }
    return unknown;
  }
}

/// What a tongue twister trains.
enum TongueTwisterCategory {
  /// Aimed at one letter, named by [TongueTwister.targetLetter].
  letter('letter'),

  /// Aimed at pace and stress rather than a single sound.
  rhythm('rhythm'),

  /// Long enough that breath control is the point.
  breath('breath'),

  /// A category this build does not recognise. Kept, not skipped, for the same
  /// reason as [TongueTwisterDifficulty.unknown].
  unknown('unknown');

  const TongueTwisterCategory(this.wireName);

  /// The exact string used in the content files.
  final String wireName;

  /// Resolves [value] to a category, falling back to [unknown].
  static TongueTwisterCategory fromWireName(String? value) {
    for (final TongueTwisterCategory category in values) {
      if (category.wireName == value) {
        return category;
      }
    }
    return unknown;
  }
}

/// One tongue twister.
///
/// A `tongueTwister` exercise names one or more of these by id through
/// [TongueTwisterConfig.tongueTwisterIds].
@immutable
class TongueTwister {
  /// Creates a twister.
  const TongueTwister({
    required this.id,
    required this.text,
    required this.difficulty,
    required this.category,
    required this.recommendedDurationSeconds,
    this.targetLetter,
  });

  /// Parses one twister.
  factory TongueTwister.fromJson(Map<String, dynamic> json) {
    final String id = json.requireString('id', ownerId: '<tongueTwister>');

    return TongueTwister(
      id: id,
      text: json.requireString('text', ownerId: id),
      difficulty: TongueTwisterDifficulty.fromWireName(
        json.optionalString('difficulty', ownerId: id),
      ),
      category: TongueTwisterCategory.fromWireName(
        json.optionalString('category', ownerId: id),
      ),
      recommendedDurationSeconds: json.requireIntAtLeast(
        'recommendedDurationSeconds',
        1,
        ownerId: id,
      ),
      targetLetter: json.optionalString('targetLetter', ownerId: id),
    );
  }

  /// Stable identifier. Never renamed, never reused.
  final String id;

  /// The line to say, exactly as written.
  final String text;

  /// How hard it is meant to be.
  final TongueTwisterDifficulty difficulty;

  /// What it trains.
  final TongueTwisterCategory category;

  /// How long to spend on it, as a suggestion rather than a limit.
  final int recommendedDurationSeconds;

  /// The letter this twister targets, when it targets one.
  ///
  /// Null is a real answer, not a missing value: a rhythm or breath twister
  /// trains pace or breath control and is not about any single sound. Requiring
  /// it would reject two of the three twisters that ship today.
  ///
  /// This is the display form, matching [LetterLadder.letter] rather than
  /// [LetterLadder.key].
  final String? targetLetter;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TongueTwister &&
          other.id == id &&
          other.text == text &&
          other.difficulty == difficulty &&
          other.category == category &&
          other.recommendedDurationSeconds == recommendedDurationSeconds &&
          other.targetLetter == targetLetter;

  @override
  int get hashCode => Object.hash(
        id,
        text,
        difficulty,
        category,
        recommendedDurationSeconds,
        targetLetter,
      );

  @override
  String toString() => 'TongueTwister($id, ${category.wireName}, '
      '${difficulty.wireName})';
}

/// `assets/content/tongue_twisters.json`, parsed.
///
/// Reading the bytes off the asset bundle is the repository's job, which is why
/// nothing here touches `rootBundle`.
@immutable
class TongueTwisterLibrary {
  /// Creates a library.
  const TongueTwisterLibrary({
    required this.envelope,
    required this.tongueTwisters,
  });

  /// Parses the whole file.
  factory TongueTwisterLibrary.fromJson(Map<String, dynamic> json) {
    const String fileName = 'tongue_twisters.json';

    final ContentEnvelope envelope = ContentEnvelope.fromJson(
      json,
      ownerId: fileName,
    );
    envelope.ensureSupported(fileName);

    final List<TongueTwister> parsed = <TongueTwister>[];
    final Set<String> seen = <String>{};

    for (final Map<String, dynamic> item in json.requireObjectList(
      'tongueTwisters',
      ownerId: fileName,
    )) {
      final TongueTwister twister = TongueTwister.fromJson(item);

      // Ids are what exercises point at, so a duplicate would make which
      // twister runs depend on file order.
      if (!seen.add(twister.id)) {
        throw FormatException(
          'Duplicate tongue twister id "${twister.id}" in $fileName',
        );
      }

      parsed.add(twister);
    }

    return TongueTwisterLibrary(
      envelope: envelope,
      tongueTwisters: List<TongueTwister>.unmodifiable(parsed),
    );
  }

  /// The file's header.
  final ContentEnvelope envelope;

  /// Every twister in the file, in file order.
  final List<TongueTwister> tongueTwisters;

  /// Looks up a twister by [id], or null when the file does not have it.
  TongueTwister? byId(String id) {
    for (final TongueTwister twister in tongueTwisters) {
      if (twister.id == id) {
        return twister;
      }
    }
    return null;
  }

  /// Every twister in [category], in file order.
  ///
  /// Returns an empty list rather than null for a category with nothing in it,
  /// because "none of these yet" and "no such category" are the same thing to a
  /// screen listing them.
  List<TongueTwister> byCategory(TongueTwisterCategory category) =>
      where(category: category);

  /// Every twister aimed at [letter], in file order.
  ///
  /// The comparison folds case in Turkish, so `I` matches `ı` and `İ` matches
  /// `i` (`turkish_case.dart`). Content writes the letter in upper case and a
  /// screen may hold it either way; matching the wrong pair would silently
  /// return nothing.
  ///
  /// Twisters with no target letter, the rhythm and breath ones, never match.
  List<TongueTwister> byTargetLetter(String letter) =>
      where(targetLetter: letter);

  /// Every twister at [difficulty], in file order.
  List<TongueTwister> byDifficulty(TongueTwisterDifficulty difficulty) =>
      where(difficulty: difficulty);

  /// Every twister matching all of the given filters, in file order.
  ///
  /// An omitted filter does not narrow the result, so `where()` is the whole
  /// library. This is the one place the matching lives; the three lookups above
  /// are names for the common cases.
  List<TongueTwister> where({
    String? targetLetter,
    TongueTwisterDifficulty? difficulty,
    TongueTwisterCategory? category,
  }) =>
      List<TongueTwister>.unmodifiable(
        tongueTwisters.where((TongueTwister twister) {
          if (category != null && twister.category != category) {
            return false;
          }
          if (difficulty != null && twister.difficulty != difficulty) {
            return false;
          }
          if (targetLetter != null) {
            final String? own = twister.targetLetter;
            if (own == null || !turkishEqualsIgnoringCase(own, targetLetter)) {
              return false;
            }
          }
          return true;
        }),
      );

  /// The target letters the library has, folded to lower case, in file order
  /// and without repeats.
  ///
  /// What a letter picker lists, so a screen does not have to walk the library
  /// and fold the cases itself.
  List<String> get targetLetters {
    final List<String> letters = <String>[];
    for (final TongueTwister twister in tongueTwisters) {
      final String? letter = twister.targetLetter;
      if (letter == null) {
        continue;
      }
      final String folded = turkishLowerCase(letter);
      if (!letters.contains(folded)) {
        letters.add(folded);
      }
    }
    return List<String>.unmodifiable(letters);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TongueTwisterLibrary &&
          other.envelope == envelope &&
          listEquals(other.tongueTwisters, tongueTwisters);

  @override
  int get hashCode => Object.hash(envelope, Object.hashAll(tongueTwisters));

  @override
  String toString() =>
      'TongueTwisterLibrary(${tongueTwisters.length} tongue twisters)';
}
