import 'package:flutter/foundation.dart';

import 'content_envelope.dart';
import 'exercise.dart';
import 'json_reader.dart';

/// `assets/content/exercises.json`, parsed.
///
/// This is the model layer's view of the file: envelope plus exercises. Reading
/// the bytes off the asset bundle is the repository's job (HIT-024), which is
/// why nothing here touches `rootBundle`. Handed a decoded map, this works the
/// same in a test, from an asset, or from a future remote source.
@immutable
class ExerciseLibrary {
  /// Creates a library.
  const ExerciseLibrary({
    required this.envelope,
    required this.exercises,
    required this.skippedIds,
  });

  /// Parses the whole file.
  ///
  /// Exercises naming a presentation type this build does not recognise are
  /// left out of [exercises] and listed in [skippedIds] instead of throwing, so
  /// a content file written for a newer app still runs on this one. Anything
  /// else malformed is a content bug and throws.
  factory ExerciseLibrary.fromJson(Map<String, dynamic> json) {
    const String fileName = 'exercises.json';

    final ContentEnvelope envelope = ContentEnvelope.fromJson(
      json,
      ownerId: fileName,
    );
    // Checked before any records are read, so an unsupported file fails on its
    // header rather than halfway through with a confusing field error.
    envelope.ensureSupported(fileName);

    final List<Exercise> parsed = <Exercise>[];
    final List<String> skipped = <String>[];
    final Set<String> seen = <String>{};

    for (final Map<String, dynamic> item in json.requireObjectList(
      'exercises',
      ownerId: fileName,
    )) {
      final Exercise exercise = Exercise.fromJson(item);

      // Ids are what completion records point at, so a duplicate would make two
      // different exercises share one history. Cheaper to reject here than to
      // untangle later.
      if (!seen.add(exercise.id)) {
        throw FormatException(
          'Duplicate exercise id "${exercise.id}" in $fileName',
        );
      }

      if (exercise.isRenderable) {
        parsed.add(exercise);
      } else {
        skipped.add(exercise.id);
      }
    }

    return ExerciseLibrary(
      envelope: envelope,
      exercises: List<Exercise>.unmodifiable(parsed),
      skippedIds: List<String>.unmodifiable(skipped),
    );
  }

  /// The file's header.
  final ContentEnvelope envelope;

  /// Every exercise this build can present, in file order.
  final List<Exercise> exercises;

  /// Ids left out because their presentation type is unknown to this build.
  ///
  /// Exposed rather than swallowed: a screen can stay quiet about it while
  /// diagnostics can still report that a day is running short because the app
  /// is older than its content.
  final List<String> skippedIds;

  /// Looks up an exercise by id, or null when this build does not have it.
  ///
  /// Null covers both "no such id" and "skipped as unrenderable", because a
  /// caller can do nothing different about the two.
  Exercise? byId(String id) {
    for (final Exercise exercise in exercises) {
      if (exercise.id == id) {
        return exercise;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseLibrary &&
          other.envelope == envelope &&
          listEquals(other.exercises, exercises) &&
          listEquals(other.skippedIds, skippedIds);

  @override
  int get hashCode => Object.hash(
        envelope,
        Object.hashAll(exercises),
        Object.hashAll(skippedIds),
      );

  @override
  String toString() => 'ExerciseLibrary(${exercises.length} exercises, '
      '${skippedIds.length} skipped)';
}
