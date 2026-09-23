import 'package:flutter/material.dart';

import '../../domain/models/models.dart';

/// What a renderer is given to draw an exercise with.
@immutable
class ExerciseRenderContext {
  /// Creates a context.
  const ExerciseRenderContext({
    required this.exercise,
    required this.remaining,
    required this.isRunning,
  });

  /// The exercise on screen.
  final Exercise exercise;

  /// Time left on it. Zero once its time is up.
  final Duration remaining;

  /// False while the session is paused, so an animated renderer can hold
  /// still instead of carrying on without the user.
  final bool isRunning;
}

/// Draws the body of one kind of exercise inside the exercise screen
/// (HIT-028).
///
/// The screen draws everything every exercise shares: the title, the
/// instructions, the time, the controls. A renderer draws only what its
/// presentation type adds, and is chosen by that type, never by an exercise
/// id (`CONTENT_SCHEMA.md`). Adding an exercise is a content change; adding a
/// kind of exercise is one renderer and one line in
/// `exerciseRendererRegistryProvider`.
abstract interface class ExerciseRenderer {
  /// Builds the body for the exercise in [context].
  Widget build(BuildContext buildContext, ExerciseRenderContext context);
}

/// Picks the renderer for a presentation type.
class ExerciseRendererRegistry {
  /// Creates a registry of [renderers], falling back to [fallback] for any
  /// type without one.
  ExerciseRendererRegistry(
    Map<ExercisePresentationType, ExerciseRenderer> renderers, {
    required this.fallback,
  }) : _renderers =
            Map<ExercisePresentationType, ExerciseRenderer>.unmodifiable(
          renderers,
        );

  final Map<ExercisePresentationType, ExerciseRenderer> _renderers;

  /// What a type with no renderer of its own gets.
  ///
  /// A fallback rather than an error: a day whose breathing renderer has not
  /// landed yet still runs, on its title and instructions, instead of
  /// stopping at an exercise the user could have done anyway.
  final ExerciseRenderer fallback;

  /// The renderer for [type].
  ExerciseRenderer rendererFor(ExercisePresentationType type) =>
      _renderers[type] ?? fallback;
}

/// The exercise as its title and instructions alone, which the screen
/// already shows. Adds nothing.
///
/// What `text` means, and what every type gets until its own renderer
/// lands.
class PlainExerciseRenderer implements ExerciseRenderer {
  /// Creates the renderer.
  const PlainExerciseRenderer();

  @override
  Widget build(BuildContext buildContext, ExerciseRenderContext context) =>
      const SizedBox.shrink();
}
