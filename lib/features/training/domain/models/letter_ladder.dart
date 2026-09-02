import 'package:flutter/foundation.dart';

import 'content_envelope.dart';
import 'json_reader.dart';

/// One Turkish letter and the drill material for it.
///
/// A `letter` exercise names a ladder through [LetterConfig.letterKey]; this is
/// what that key points at. The exercise decides how many repetitions to run,
/// the ladder decides what is spoken.
@immutable
class LetterLadder {
  /// Creates a ladder.
  const LetterLadder({
    required this.key,
    required this.letter,
    required this.syllables,
    required this.words,
    this.notes,
  });

  /// Parses one ladder.
  factory LetterLadder.fromJson(Map<String, dynamic> json) {
    final String key = json.requireString('key', ownerId: '<letter>');

    return LetterLadder(
      key: key,
      letter: json.requireString('letter', ownerId: key),
      syllables: json.requireStringList('syllables', ownerId: key),
      words: json.requireStringList('words', ownerId: key),
      notes: json.optionalString('notes', ownerId: key),
    );
  }

  /// Stable identifier, ASCII only.
  ///
  /// Separate from [letter] on purpose. Turkish has letters that are awkward in
  /// a file name, an analytics event or a URL, so the key is the transliterated
  /// form: `s_cedilla` for Ş. Exercises reference the key, screens show the
  /// letter, and neither has to know about the other's constraints.
  final String key;

  /// The letter as it is shown to the user, in its own alphabet.
  final String letter;

  /// Syllables to run through, in the order given.
  ///
  /// Order is content, not presentation: a ladder climbs, and sorting these
  /// would flatten it.
  final List<String> syllables;

  /// Words that exercise the same letter, in the order given.
  final List<String> words;

  /// Editorial note about the ladder. Never shown to the user.
  final String? notes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LetterLadder &&
          other.key == key &&
          other.letter == letter &&
          listEquals(other.syllables, syllables) &&
          listEquals(other.words, words) &&
          other.notes == notes;

  @override
  int get hashCode => Object.hash(
        key,
        letter,
        Object.hashAll(syllables),
        Object.hashAll(words),
        notes,
      );

  @override
  String toString() => 'LetterLadder($key, ${syllables.length} syllables, '
      '${words.length} words)';
}

/// `assets/content/letters.json`, parsed.
///
/// Reading the bytes off the asset bundle is the repository's job, which is why
/// nothing here touches `rootBundle`. Handed a decoded map, this works the same
/// in a test, from an asset, or from a future remote source.
@immutable
class LetterLadderLibrary {
  /// Creates a library.
  const LetterLadderLibrary({required this.envelope, required this.ladders});

  /// Parses the whole file.
  factory LetterLadderLibrary.fromJson(Map<String, dynamic> json) {
    const String fileName = 'letters.json';

    final ContentEnvelope envelope = ContentEnvelope.fromJson(
      json,
      ownerId: fileName,
    );
    // Checked before any records are read, so an unsupported file fails on its
    // header rather than halfway through with a confusing field error.
    envelope.ensureSupported(fileName);

    final List<LetterLadder> parsed = <LetterLadder>[];
    final Set<String> seen = <String>{};

    for (final Map<String, dynamic> item in json.requireObjectList(
      'letters',
      ownerId: fileName,
    )) {
      final LetterLadder ladder = LetterLadder.fromJson(item);

      // A duplicate key would make two ladders answer to one exercise, and
      // which one won would depend on file order.
      if (!seen.add(ladder.key)) {
        throw FormatException(
          'Duplicate letter key "${ladder.key}" in $fileName',
        );
      }

      parsed.add(ladder);
    }

    return LetterLadderLibrary(
      envelope: envelope,
      ladders: List<LetterLadder>.unmodifiable(parsed),
    );
  }

  /// The file's header.
  final ContentEnvelope envelope;

  /// Every ladder in the file, in file order.
  final List<LetterLadder> ladders;

  /// Looks up a ladder by its [key], or null when the file does not have it.
  ///
  /// Null rather than throwing: a `letter` exercise naming a key this content
  /// version does not carry is a content mistake worth reporting, but it is the
  /// caller that knows whether it can drop the exercise or has to fail.
  LetterLadder? byKey(String key) {
    for (final LetterLadder ladder in ladders) {
      if (ladder.key == key) {
        return ladder;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LetterLadderLibrary &&
          other.envelope == envelope &&
          listEquals(other.ladders, ladders);

  @override
  int get hashCode => Object.hash(envelope, Object.hashAll(ladders));

  @override
  String toString() => 'LetterLadderLibrary(${ladders.length} ladders)';
}
