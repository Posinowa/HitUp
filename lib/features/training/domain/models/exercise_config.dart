import 'package:flutter/foundation.dart';

import 'json_reader.dart';

/// Marker for the type specific configuration an exercise can carry.
///
/// An exercise holds **at most one** of these, and if it holds one it must match
/// its presentation type. `text` and `timer` carry none. The pairing is checked
/// when an exercise is parsed, not left to each renderer to rediscover.
@immutable
sealed class ExerciseConfig {
  const ExerciseConfig();
}

/// Timing for a guided breathing cycle.
class BreathingConfig extends ExerciseConfig {
  /// Creates a breathing configuration.
  const BreathingConfig({
    required this.inhaleSeconds,
    required this.holdSeconds,
    required this.exhaleSeconds,
    required this.cycles,
  });

  /// Reads the configuration from its JSON object.
  factory BreathingConfig.fromJson(
    Map<String, dynamic> json, {
    required String ownerId,
  }) =>
      BreathingConfig(
        inhaleSeconds:
            json.requireIntAtLeast('inhaleSeconds', 1, ownerId: ownerId),
        // Hold may legitimately be zero: not every breathing pattern pauses at the
        // top. Inhale and exhale may not, because a phase of zero seconds is not a
        // pattern, it is a content mistake.
        holdSeconds: json.requireIntAtLeast('holdSeconds', 0, ownerId: ownerId),
        exhaleSeconds:
            json.requireIntAtLeast('exhaleSeconds', 1, ownerId: ownerId),
        cycles: json.requireIntAtLeast('cycles', 1, ownerId: ownerId),
      );

  /// Seconds spent breathing in.
  final int inhaleSeconds;

  /// Seconds spent holding. May be zero.
  final int holdSeconds;

  /// Seconds spent breathing out.
  final int exhaleSeconds;

  /// How many times the cycle repeats.
  final int cycles;

  /// How long one full cycle takes.
  Duration get cycleDuration =>
      Duration(seconds: inhaleSeconds + holdSeconds + exhaleSeconds);

  /// How long every cycle takes together.
  ///
  /// Worth comparing against the exercise's own `durationSeconds`: the two are
  /// authored separately and can drift apart.
  Duration get totalDuration => cycleDuration * cycles;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BreathingConfig &&
          other.inhaleSeconds == inhaleSeconds &&
          other.holdSeconds == holdSeconds &&
          other.exhaleSeconds == exhaleSeconds &&
          other.cycles == cycles;

  @override
  int get hashCode =>
      Object.hash(inhaleSeconds, holdSeconds, exhaleSeconds, cycles);

  @override
  String toString() =>
      'BreathingConfig($inhaleSeconds/$holdSeconds/$exhaleSeconds x$cycles)';
}

/// A pointer into the Turkish letter ladders.
class LetterConfig extends ExerciseConfig {
  /// Creates a letter configuration.
  const LetterConfig({required this.letterKey, required this.repetitions});

  /// Reads the configuration from its JSON object.
  factory LetterConfig.fromJson(
    Map<String, dynamic> json, {
    required String ownerId,
  }) =>
      LetterConfig(
        letterKey: json.requireString('letterKey', ownerId: ownerId),
        repetitions: json.requireIntAtLeast('repetitions', 1, ownerId: ownerId),
      );

  /// Key of the ladder in `letters.json`.
  ///
  /// The ladder itself is not held here. Resolving an id to its content is the
  /// repository's job (HIT-024), which keeps this model loadable on its own and
  /// keeps one file from having to be parsed before another.
  final String letterKey;

  /// How many times the ladder is worked through.
  final int repetitions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LetterConfig &&
          other.letterKey == letterKey &&
          other.repetitions == repetitions;

  @override
  int get hashCode => Object.hash(letterKey, repetitions);

  @override
  String toString() => 'LetterConfig($letterKey x$repetitions)';
}

/// A pointer into the tongue twister library.
class TongueTwisterConfig extends ExerciseConfig {
  /// Creates a tongue twister configuration.
  const TongueTwisterConfig({
    required this.tongueTwisterIds,
    required this.repetitions,
  });

  /// Reads the configuration from its JSON object.
  factory TongueTwisterConfig.fromJson(
    Map<String, dynamic> json, {
    required String ownerId,
  }) =>
      TongueTwisterConfig(
        tongueTwisterIds: json.requireStringList(
          'tongueTwisterIds',
          ownerId: ownerId,
        ),
        repetitions: json.requireIntAtLeast('repetitions', 1, ownerId: ownerId),
      );

  /// Ids of the twisters in `tongue_twisters.json`, in the order given.
  final List<String> tongueTwisterIds;

  /// How many times each twister is repeated.
  final int repetitions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TongueTwisterConfig &&
          listEquals(other.tongueTwisterIds, tongueTwisterIds) &&
          other.repetitions == repetitions;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(tongueTwisterIds), repetitions);

  @override
  String toString() =>
      'TongueTwisterConfig(${tongueTwisterIds.join(", ")} x$repetitions)';
}

/// Which direction the voice moves on a word.
enum ContourDirection {
  /// Pitch rises.
  rise('rise'),

  /// Pitch falls.
  fall('fall'),

  /// Pitch stays level.
  flat('flat'),

  /// A direction this build does not recognise.
  unknown('unknown');

  const ContourDirection(this.wireName);

  /// The exact string used in the content files.
  final String wireName;

  /// Resolves [value] to a direction, falling back to [unknown].
  static ContourDirection fromWireName(String? value) {
    for (final ContourDirection direction in values) {
      if (direction.wireName == value) {
        return direction;
      }
    }
    return unknown;
  }
}

/// One word of a sentence and the direction the voice takes on it.
@immutable
class IntonationPoint {
  /// Creates an intonation point.
  const IntonationPoint({required this.wordIndex, required this.direction});

  /// Reads a point from its JSON object.
  factory IntonationPoint.fromJson(
    Map<String, dynamic> json, {
    required String ownerId,
  }) =>
      IntonationPoint(
        wordIndex: json.requireIntAtLeast('wordIndex', 0, ownerId: ownerId),
        // Through the reader, like every other field. A bare cast turns a
        // wrong type into "type 'int' is not a subtype of type 'String?'",
        // which names neither the field nor the exercise it came from.
        direction: ContourDirection.fromWireName(
          json.optionalString('direction', ownerId: ownerId),
        ),
      );

  /// Zero based index into the whitespace split of the owning text.
  final int wordIndex;

  /// Which way the voice moves on that word.
  final ContourDirection direction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntonationPoint &&
          other.wordIndex == wordIndex &&
          other.direction == direction;

  @override
  int get hashCode => Object.hash(wordIndex, direction);

  @override
  String toString() => 'IntonationPoint($wordIndex: ${direction.wireName})';
}

/// Base for the configurations that mark up a sentence by word position.
///
/// Emphasis, intonation and pause all carry a sentence plus indexes into it.
/// Indexes are stored rather than marked up copy, so the sentence stays
/// readable, reusable, and out of a translator's way.
@immutable
sealed class TextMarkupConfig extends ExerciseConfig {
  const TextMarkupConfig({required this.text});

  /// The sentence being worked on.
  final String text;

  /// The sentence split on whitespace, which is what every index refers to.
  List<String> get words => List<String>.unmodifiable(
        text.split(RegExp(r'\s+'))
          ..removeWhere(
            (String word) => word.isEmpty,
          ),
      );

  /// Whether every index in [indexes] addresses a real word.
  ///
  /// An index past the end would silently mark nothing, which looks like a
  /// renderer bug rather than the content mistake it is.
  bool indexesAreInRange(List<int> indexes) {
    final int count = words.length;
    return indexes.every((int index) => index >= 0 && index < count);
  }
}

/// Words that carry the stress in a sentence.
class EmphasisConfig extends TextMarkupConfig {
  /// Creates an emphasis configuration.
  const EmphasisConfig({required super.text, required this.wordIndexes});

  /// Reads the configuration from its JSON object.
  factory EmphasisConfig.fromJson(
    Map<String, dynamic> json, {
    required String ownerId,
  }) {
    final EmphasisConfig config = EmphasisConfig(
      text: json.requireString('text', ownerId: ownerId),
      wordIndexes: json.requireIntList('emphasisWordIndexes', ownerId: ownerId),
    );
    if (!config.indexesAreInRange(config.wordIndexes)) {
      throw FormatException(
        'emphasisWordIndexes point past the end of the text in "$ownerId": '
        '${config.wordIndexes} against ${config.words.length} words',
      );
    }
    return config;
  }

  /// Zero based indexes into [words].
  final List<int> wordIndexes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmphasisConfig &&
          other.text == text &&
          listEquals(other.wordIndexes, wordIndexes);

  @override
  int get hashCode => Object.hash(text, Object.hashAll(wordIndexes));

  @override
  String toString() => 'EmphasisConfig(${wordIndexes.join(", ")})';
}

/// The pitch contour across a sentence.
class IntonationConfig extends TextMarkupConfig {
  /// Creates an intonation configuration.
  const IntonationConfig({required super.text, required this.contour});

  /// Reads the configuration from its JSON object.
  factory IntonationConfig.fromJson(
    Map<String, dynamic> json, {
    required String ownerId,
  }) {
    final IntonationConfig config = IntonationConfig(
      text: json.requireString('text', ownerId: ownerId),
      contour: List<IntonationPoint>.unmodifiable(
        json.requireObjectList('contour', ownerId: ownerId).map(
              (Map<String, dynamic> point) =>
                  IntonationPoint.fromJson(point, ownerId: ownerId),
            ),
      ),
    );
    final List<int> indexes =
        config.contour.map((IntonationPoint point) => point.wordIndex).toList();
    if (!config.indexesAreInRange(indexes)) {
      throw FormatException(
        'contour word indexes point past the end of the text in "$ownerId": '
        '$indexes against ${config.words.length} words',
      );
    }
    return config;
  }

  /// The marked words, in the order given.
  final List<IntonationPoint> contour;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntonationConfig &&
          other.text == text &&
          listEquals(other.contour, contour);

  @override
  int get hashCode => Object.hash(text, Object.hashAll(contour));

  @override
  String toString() => 'IntonationConfig(${contour.length} points)';
}

/// Where the speaker stops, and for how long.
class PauseConfig extends TextMarkupConfig {
  /// Creates a pause configuration.
  const PauseConfig({
    required super.text,
    required this.pauseAfterWordIndexes,
    required this.pauseMilliseconds,
  });

  /// Reads the configuration from its JSON object.
  factory PauseConfig.fromJson(
    Map<String, dynamic> json, {
    required String ownerId,
  }) {
    final PauseConfig config = PauseConfig(
      text: json.requireString('text', ownerId: ownerId),
      pauseAfterWordIndexes: json.requireIntList(
        'pauseAfterWordIndexes',
        ownerId: ownerId,
      ),
      pauseMilliseconds: json.requireIntAtLeast(
        'pauseMilliseconds',
        1,
        ownerId: ownerId,
      ),
    );
    if (!config.indexesAreInRange(config.pauseAfterWordIndexes)) {
      throw FormatException(
        'pauseAfterWordIndexes point past the end of the text in "$ownerId": '
        '${config.pauseAfterWordIndexes} against ${config.words.length} words',
      );
    }
    return config;
  }

  /// Zero based indexes of the words a pause follows.
  final List<int> pauseAfterWordIndexes;

  /// How long each pause lasts.
  final int pauseMilliseconds;

  /// [pauseMilliseconds] as a [Duration].
  Duration get pauseDuration => Duration(milliseconds: pauseMilliseconds);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PauseConfig &&
          other.text == text &&
          listEquals(other.pauseAfterWordIndexes, pauseAfterWordIndexes) &&
          other.pauseMilliseconds == pauseMilliseconds;

  @override
  int get hashCode => Object.hash(
        text,
        Object.hashAll(pauseAfterWordIndexes),
        pauseMilliseconds,
      );

  @override
  String toString() =>
      'PauseConfig(${pauseAfterWordIndexes.join(", ")} @${pauseMilliseconds}ms)';
}

/// A passage read against a pace target.
class TimedReadingConfig extends ExerciseConfig {
  /// Creates a timed reading configuration.
  const TimedReadingConfig({
    required this.text,
    required this.targetWordsPerMinute,
  });

  /// Reads the configuration from its JSON object.
  factory TimedReadingConfig.fromJson(
    Map<String, dynamic> json, {
    required String ownerId,
  }) =>
      TimedReadingConfig(
        text: json.requireString('text', ownerId: ownerId),
        targetWordsPerMinute: json.requireIntAtLeast(
          'targetWordsPerMinute',
          1,
          ownerId: ownerId,
        ),
      );

  /// The passage to read.
  final String text;

  /// The pace the reader is aiming for.
  final int targetWordsPerMinute;

  /// How many words the passage contains.
  int get wordCount =>
      text.split(RegExp(r'\s+')).where((String word) => word.isNotEmpty).length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimedReadingConfig &&
          other.text == text &&
          other.targetWordsPerMinute == targetWordsPerMinute;

  @override
  int get hashCode => Object.hash(text, targetWordsPerMinute);

  @override
  String toString() => 'TimedReadingConfig($targetWordsPerMinute wpm)';
}

/// A pointer into the speaking challenge library.
class SpeakingChallengeConfig extends ExerciseConfig {
  /// Creates a speaking challenge configuration.
  const SpeakingChallengeConfig({required this.challengeId});

  /// Reads the configuration from its JSON object.
  factory SpeakingChallengeConfig.fromJson(
    Map<String, dynamic> json, {
    required String ownerId,
  }) =>
      SpeakingChallengeConfig(
        challengeId: json.requireString('challengeId', ownerId: ownerId),
      );

  /// Id of the challenge in `speaking_challenges.json`.
  final String challengeId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeakingChallengeConfig && other.challengeId == challengeId;

  @override
  int get hashCode => challengeId.hashCode;

  @override
  String toString() => 'SpeakingChallengeConfig($challengeId)';
}
