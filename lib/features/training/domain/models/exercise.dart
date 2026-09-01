import 'package:flutter/foundation.dart';

import 'exercise_config.dart';
import 'exercise_presentation_type.dart';
import 'json_reader.dart';
import 'media_reference.dart';

/// Reads one type specific config block.
///
/// Every `fromJson` on an [ExerciseConfig] subclass already has this shape, so
/// the table below can name them directly instead of restating the call.
typedef _ConfigReader = ExerciseConfig Function(
  Map<String, dynamic> json, {
  required String ownerId,
});

/// One exercise, as defined in `assets/content/exercises.json`.
///
/// An exercise says what to show, for how long, and how to present it. It never
/// says where its media lives, and a screen never branches on its [id]. Both
/// rules exist so adding an exercise is a content change, not a code change.
@immutable
class Exercise {
  /// Creates an exercise.
  ///
  /// Prefer [Exercise.fromJson] for content. This constructor is for tests and
  /// fixtures, and does not check the pairing rule.
  const Exercise({
    required this.id,
    required this.title,
    required this.presentationType,
    required this.durationSeconds,
    required this.instructions,
    this.media,
    this.config,
  });

  /// Reads an exercise from its JSON object.
  ///
  /// Throws a [FormatException] when a required field is missing or wrongly
  /// typed, or when the type specific config does not match the presentation
  /// type. It does **not** throw on an unrecognised presentation type: that
  /// yields [ExercisePresentationType.unknown] so a newer content file can ship
  /// to an older client and cost one exercise rather than the whole day. Callers
  /// filter with [isRenderable].
  factory Exercise.fromJson(Map<String, dynamic> json) {
    // Read the id first, with a placeholder owner, so every later failure can
    // name the exercise it came from.
    final String id = json.requireString('id', ownerId: '<exercise>');

    // Through the reader, and after the id is read, so a wrong type names
    // both the field and the exercise. Absent and unrecognised are the
    // forward-compatibility case and land on `unknown`, which gets the
    // exercise skipped rather than failing the whole file; a wrong type is a
    // content bug and should say so.
    final ExercisePresentationType presentationType =
        ExercisePresentationType.fromWireName(
      json.optionalString('presentationType', ownerId: id),
    );

    final Map<String, dynamic>? mediaJson = json.optionalObject(
      'media',
      ownerId: id,
    );

    return Exercise(
      id: id,
      title: json.requireString('title', ownerId: id),
      presentationType: presentationType,
      durationSeconds: json.requireIntAtLeast(
        'durationSeconds',
        1,
        ownerId: id,
      ),
      instructions: json.requireString('instructions', ownerId: id),
      media: mediaJson == null
          ? null
          : MediaReference.fromJson(mediaJson, ownerId: id),
      config: _readConfig(json, id: id, presentationType: presentationType),
    );
  }

  /// Reads the single type specific config block, enforcing the pairing rule.
  ///
  /// The schema allows at most one block per exercise, and it must be the one
  /// its presentation type calls for. Checking that here means a renderer can
  /// trust the pair it is handed instead of re-deriving the rule and deciding
  /// for itself what to do when it does not hold.
  static ExerciseConfig? _readConfig(
    Map<String, dynamic> json, {
    required String id,
    required ExercisePresentationType presentationType,
  }) {
    // One entry per config block: the field name, the presentation type it
    // belongs to, and how to read it. All three are written once, on one line,
    // because they are one fact. Splitting the reader into a switch elsewhere
    // would let a ninth block be added here and nowhere else, and the compiler
    // could not say so; it would surface at runtime, on real content.
    const Map<String, (ExercisePresentationType, _ConfigReader)> blocks =
        <String, (ExercisePresentationType, _ConfigReader)>{
      'breathing': (
        ExercisePresentationType.breathing,
        BreathingConfig.fromJson,
      ),
      'letter': (ExercisePresentationType.letter, LetterConfig.fromJson),
      'tongueTwister': (
        ExercisePresentationType.tongueTwister,
        TongueTwisterConfig.fromJson,
      ),
      'emphasis': (ExercisePresentationType.emphasis, EmphasisConfig.fromJson),
      'intonation': (
        ExercisePresentationType.intonation,
        IntonationConfig.fromJson,
      ),
      'pause': (ExercisePresentationType.pause, PauseConfig.fromJson),
      'timedReading': (
        ExercisePresentationType.timedReading,
        TimedReadingConfig.fromJson,
      ),
      'speakingChallenge': (
        ExercisePresentationType.speakingChallenge,
        SpeakingChallengeConfig.fromJson,
      ),
    };

    if (presentationType == ExercisePresentationType.unknown) {
      // Nothing below this line can protect anything. An exercise of an
      // unknown type is skipped: it lands in `skippedIds`, `byId` returns null
      // for it, and no renderer ever sees it. Validating which config a
      // never-rendered exercise carries is not a check, it is a way to turn a
      // forward-compatible content change into a fatal one.
      //
      // The case that matters is a newer type that brought a block this build
      // *does* know, which content would do precisely to let older clients
      // degrade gracefully: a new `breathingAdvanced` keeping its `breathing`
      // block alongside. Falling through would compare `breathing` against
      // `unknown`, throw, and take the whole file down with it through
      // `ExerciseLibrary.fromJson`. One exercise the client was meant to skip
      // would cost the entire day.
      return null;
    }

    final List<String> present =
        blocks.keys.where((String field) => json.containsKey(field)).toList();

    if (present.length > 1) {
      throw FormatException(
        'An exercise carries at most one type specific config, '
        '"$id" carries ${present.join(", ")}',
      );
    }

    if (present.isEmpty) {
      return null;
    }

    final String field = present.single;
    final (ExercisePresentationType expected, _ConfigReader read) =
        blocks[field]!;
    if (expected != presentationType) {
      throw FormatException(
        'Config block "$field" belongs to ${expected.wireName}, '
        'but "$id" is ${presentationType.wireName}',
      );
    }

    return read(json.requireObject(field, ownerId: id), ownerId: id);
  }

  /// Stable identifier. Never renamed, never reused; completion records point
  /// at it (HIT-052, HIT-053).
  final String id;

  /// Title shown to the user.
  final String title;

  /// How this exercise is presented.
  final ExercisePresentationType presentationType;

  /// How long the exercise runs.
  final int durationSeconds;

  /// What the user is asked to do.
  final String instructions;

  /// Media this exercise needs, if any. Resolved to a location elsewhere.
  final MediaReference? media;

  /// The type specific configuration, if this type calls for one.
  final ExerciseConfig? config;

  /// [durationSeconds] as a [Duration].
  Duration get duration => Duration(seconds: durationSeconds);

  /// Whether this build can present this exercise.
  ///
  /// False only for content naming a type this build does not know. A day
  /// should filter on this before rendering.
  bool get isRenderable => presentationType.isRenderable;

  /// Returns [config] when it is a [T], otherwise null.
  ///
  /// Lets a renderer ask for the shape it needs without casting:
  ///
  /// ```dart
  /// final BreathingConfig? breathing = exercise.configAs<BreathingConfig>();
  /// ```
  T? configAs<T extends ExerciseConfig>() {
    final ExerciseConfig? value = config;
    return value is T ? value : null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Exercise &&
          other.id == id &&
          other.title == title &&
          other.presentationType == presentationType &&
          other.durationSeconds == durationSeconds &&
          other.instructions == instructions &&
          other.media == media &&
          other.config == config;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        presentationType,
        durationSeconds,
        instructions,
        media,
        config,
      );

  @override
  String toString() =>
      'Exercise($id, ${presentationType.wireName}, ${durationSeconds}s)';
}
