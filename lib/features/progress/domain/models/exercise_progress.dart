import 'package:flutter/foundation.dart';

/// How often one exercise has been completed, as
/// `users/{uid}/exerciseProgress/{exerciseId}` holds it.
@immutable
class ExerciseProgress {
  /// Creates a record.
  const ExerciseProgress({
    required this.exerciseId,
    required this.completionCount,
    required this.lastCompletedAt,
  });

  /// The id from `assets/content/exercises.json`, which is also the document id.
  final String exerciseId;

  /// Completions so far. Only ever grows.
  final int completionCount;

  /// When the server recorded the latest one. Null while it is pending.
  final DateTime? lastCompletedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseProgress &&
          other.exerciseId == exerciseId &&
          other.completionCount == completionCount &&
          other.lastCompletedAt == lastCompletedAt;

  @override
  int get hashCode => Object.hash(exerciseId, completionCount, lastCompletedAt);

  @override
  String toString() => 'ExerciseProgress($exerciseId, $completionCount)';
}
