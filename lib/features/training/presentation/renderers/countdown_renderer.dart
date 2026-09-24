import 'package:flutter/material.dart';

import 'exercise_renderer.dart';

/// The `timer` type: a countdown and nothing else (`CONTENT_SCHEMA.md`).
///
/// A ring that empties as the exercise's time runs out. The number itself is
/// in the screen's own time line, which a screen reader already reads, so the
/// ring is left out of the semantics tree rather than read twice.
class CountdownRenderer implements ExerciseRenderer {
  /// Creates the renderer.
  const CountdownRenderer();

  @override
  Widget build(BuildContext buildContext, ExerciseRenderContext context) {
    final ColorScheme colors = Theme.of(buildContext).colorScheme;
    final int total = context.exercise.durationSeconds;
    final int left = context.remaining.inSeconds.clamp(0, total);

    // Up to 160 across, and smaller where the screen leaves less room.
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160, maxHeight: 160),
        child: AspectRatio(
          aspectRatio: 1,
          child: CircularProgressIndicator(
            value: left / total,
            strokeWidth: 10,
            backgroundColor: colors.outline,
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
        ),
      ),
    );
  }
}
