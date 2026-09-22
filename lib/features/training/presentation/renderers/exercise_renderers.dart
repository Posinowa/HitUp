import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import 'countdown_renderer.dart';
import 'exercise_renderer.dart';
import 'rive_renderer.dart';

/// The renderers this build has (HIT-028).
///
/// The types not listed fall back to [PlainExerciseRenderer]. Each later
/// renderer issue (breathing, Rive, letters, tongue twisters and the rest)
/// adds its line here.
final Provider<ExerciseRendererRegistry> exerciseRendererRegistryProvider =
    Provider<ExerciseRendererRegistry>(
  (Ref ref) => ExerciseRendererRegistry(
    const <ExercisePresentationType, ExerciseRenderer>{
      ExercisePresentationType.text: PlainExerciseRenderer(),
      ExercisePresentationType.timer: CountdownRenderer(),
      // Both are Rive files; articulation is the mouth, lip, tongue and jaw
      // drills, which content names apart from other Rive exercises.
      ExercisePresentationType.rive: RiveExerciseRenderer(),
      ExercisePresentationType.articulation: RiveExerciseRenderer(),
    },
    fallback: const PlainExerciseRenderer(),
  ),
);
