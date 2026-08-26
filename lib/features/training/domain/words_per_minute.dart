/// Reading pace, in words per minute.
///
/// A pure function with no state and no dependencies, so the timed reading
/// exercise (HIT-046) and anything else that measures pace can call it without
/// owning a controller, and so its edge cases are testable on their own.
library;

/// Words per minute for [wordCount] words read in [elapsed].
///
/// Returns null when the pace cannot be computed rather than inventing a
/// number. That happens only when [elapsed] is zero or negative, where the true
/// answer is infinite, not large. A caller showing "0 wpm" there would be
/// telling the user they read nothing, when what actually happened is that no
/// time passed.
///
/// Zero words over real time is a different case and is a real answer: it
/// returns 0, because reading nothing for thirty seconds genuinely is a pace of
/// zero.
///
/// **Rounding.** The result is rounded to the nearest whole word per minute,
/// with halves going away from zero, which is what `double.round()` does. Pace
/// is shown to a person and compared against a target that is itself a whole
/// number; carrying a fraction would suggest a precision the measurement does
/// not have, since [elapsed] comes from a stopwatch the user started and
/// stopped by hand.
///
/// Throws an [ArgumentError] when [wordCount] is negative, which is not an edge
/// case to round off but a caller bug worth surfacing where it happens.
///
/// ```dart
/// wordsPerMinute(wordCount: 150, elapsed: const Duration(minutes: 1)); // 150
/// wordsPerMinute(wordCount: 75, elapsed: const Duration(seconds: 30)); // 150
/// wordsPerMinute(wordCount: 10, elapsed: Duration.zero);               // null
/// ```
int? wordsPerMinute({required int wordCount, required Duration elapsed}) {
  if (wordCount < 0) {
    throw ArgumentError.value(
      wordCount,
      'wordCount',
      'A word count cannot be negative',
    );
  }
  if (elapsed <= Duration.zero) {
    return null;
  }

  // Computed from microseconds rather than from `elapsed.inSeconds`, which
  // truncates: a 90 second read would otherwise be indistinguishable from a
  // 90.9 second one, and the shorter the passage the more that distortion
  // shows up in the result.
  final double minutes =
      elapsed.inMicroseconds / Duration.microsecondsPerMinute;
  return (wordCount / minutes).round();
}

/// How a measured pace compares with the pace an exercise asked for.
enum PaceVerdict {
  /// Slower than the target, outside the tolerance.
  slow,

  /// Within tolerance of the target.
  onTarget,

  /// Faster than the target, outside the tolerance.
  fast,
}

/// Compares [actualWordsPerMinute] against [targetWordsPerMinute].
///
/// [tolerance] is a fraction of the target, defaulting to a tenth. A tolerance
/// exists because reading pace is not a value anyone hits exactly, and an
/// exercise that calls 139 against a target of 140 "too slow" teaches the user
/// to distrust the feedback rather than to slow down.
///
/// Returns null when [actualWordsPerMinute] is null, so the "no pace could be
/// measured" case stays distinguishable from a verdict all the way through.
PaceVerdict? comparePace({
  required int? actualWordsPerMinute,
  required int targetWordsPerMinute,
  double tolerance = 0.1,
}) {
  if (targetWordsPerMinute <= 0) {
    throw ArgumentError.value(
      targetWordsPerMinute,
      'targetWordsPerMinute',
      'A pace target must be positive',
    );
  }
  if (tolerance < 0) {
    throw ArgumentError.value(
      tolerance,
      'tolerance',
      'A tolerance cannot be negative',
    );
  }
  if (actualWordsPerMinute == null) {
    return null;
  }

  final double margin = targetWordsPerMinute * tolerance;
  if (actualWordsPerMinute < targetWordsPerMinute - margin) {
    return PaceVerdict.slow;
  }
  if (actualWordsPerMinute > targetWordsPerMinute + margin) {
    return PaceVerdict.fast;
  }
  return PaceVerdict.onTarget;
}
