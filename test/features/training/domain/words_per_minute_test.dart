import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/training/domain/words_per_minute.dart';

/// Tests for the reading pace calculation (HIT-047).
///
/// The issue asks for the normal case, the zero case, and the rounding rule to
/// be covered and documented. Each of those has its own group below.
void main() {
  group('the normal case', () {
    test('a minute of reading is the word count itself', () {
      expect(
        wordsPerMinute(wordCount: 150, elapsed: const Duration(minutes: 1)),
        150,
      );
    });

    test('half a minute doubles the pace', () {
      expect(
        wordsPerMinute(wordCount: 75, elapsed: const Duration(seconds: 30)),
        150,
      );
    });

    test('two minutes halves it', () {
      expect(
        wordsPerMinute(wordCount: 300, elapsed: const Duration(minutes: 2)),
        150,
      );
    });

    test('sub second precision is not thrown away', () {
      // Computed from microseconds rather than from `inSeconds`, which
      // truncates. The shorter the passage, the more that would distort the
      // answer.
      final int? a = wordsPerMinute(
        wordCount: 10,
        elapsed: const Duration(seconds: 10),
      );
      final int? b = wordsPerMinute(
        wordCount: 10,
        elapsed: const Duration(seconds: 10, milliseconds: 900),
      );

      expect(a, 60);
      expect(
        b,
        isNot(a),
        reason: '10.9 seconds is not the same read as 10 seconds',
      );
    });
  });

  group('the zero cases', () {
    test('no time elapsed has no answer, not a pace of zero', () {
      // Showing "0 wpm" here would tell the user they read nothing, when what
      // actually happened is that no time passed.
      expect(wordsPerMinute(wordCount: 10, elapsed: Duration.zero), isNull);
    });

    test('negative time has no answer either', () {
      expect(
        wordsPerMinute(
          wordCount: 10,
          elapsed: const Duration(seconds: -5),
        ),
        isNull,
      );
    });

    test('no words over real time is a real pace of zero', () {
      expect(
        wordsPerMinute(wordCount: 0, elapsed: const Duration(seconds: 30)),
        0,
      );
    });

    test('a negative word count is a caller bug, not an edge case', () {
      expect(
        () => wordsPerMinute(
          wordCount: -1,
          elapsed: const Duration(seconds: 30),
        ),
        throwsArgumentError,
      );
    });
  });

  group('the rounding rule', () {
    test('rounds to the nearest whole word per minute', () {
      // 100 words in 61 seconds is 98.36 wpm.
      expect(
        wordsPerMinute(wordCount: 100, elapsed: const Duration(seconds: 61)),
        98,
      );
      // 100 words in 59 seconds is 101.69 wpm.
      expect(
        wordsPerMinute(wordCount: 100, elapsed: const Duration(seconds: 59)),
        102,
      );
    });

    test('a half rounds away from zero', () {
      // 1 word in 8 seconds is exactly 7.5 wpm, so this is a real half rather
      // than a value that happens to sit near one.
      expect(
        wordsPerMinute(wordCount: 1, elapsed: const Duration(seconds: 8)),
        8,
      );
      // 7 words in 280 seconds is exactly 1.5 wpm.
      expect(
        wordsPerMinute(wordCount: 7, elapsed: const Duration(seconds: 280)),
        2,
      );
    });

    test('never returns a fraction dressed up as precision', () {
      final int? pace = wordsPerMinute(
        wordCount: 7,
        elapsed: const Duration(seconds: 13),
      );

      expect(pace, isA<int>());
      expect(pace, 32);
    });
  });

  group('comparing against a target', () {
    test('inside the tolerance counts as on target', () {
      // A reader who hits 139 against a target of 140 has not failed, and
      // telling them they have teaches them to distrust the feedback.
      expect(
        comparePace(actualWordsPerMinute: 139, targetWordsPerMinute: 140),
        PaceVerdict.onTarget,
      );
      expect(
        comparePace(actualWordsPerMinute: 140, targetWordsPerMinute: 140),
        PaceVerdict.onTarget,
      );
    });

    test('the tolerance edges are inclusive', () {
      // A tenth of 140 is 14, so 126 and 154 are the boundaries themselves.
      expect(
        comparePace(actualWordsPerMinute: 126, targetWordsPerMinute: 140),
        PaceVerdict.onTarget,
      );
      expect(
        comparePace(actualWordsPerMinute: 154, targetWordsPerMinute: 140),
        PaceVerdict.onTarget,
      );
    });

    test('outside the tolerance reads slow or fast', () {
      expect(
        comparePace(actualWordsPerMinute: 125, targetWordsPerMinute: 140),
        PaceVerdict.slow,
      );
      expect(
        comparePace(actualWordsPerMinute: 155, targetWordsPerMinute: 140),
        PaceVerdict.fast,
      );
    });

    test('a tighter tolerance narrows the band', () {
      expect(
        comparePace(
          actualWordsPerMinute: 135,
          targetWordsPerMinute: 140,
          tolerance: 0.01,
        ),
        PaceVerdict.slow,
      );
    });

    test('an unmeasurable pace stays unmeasurable', () {
      // Null must survive the comparison rather than becoming a verdict.
      expect(
        comparePace(actualWordsPerMinute: null, targetWordsPerMinute: 140),
        isNull,
      );
    });

    test('a target that is not positive is a caller bug', () {
      expect(
        () => comparePace(actualWordsPerMinute: 100, targetWordsPerMinute: 0),
        throwsArgumentError,
      );
      expect(
        () =>
            comparePace(actualWordsPerMinute: 100, targetWordsPerMinute: -140),
        throwsArgumentError,
      );
    });

    test('a negative tolerance is a caller bug', () {
      expect(
        () => comparePace(
          actualWordsPerMinute: 140,
          targetWordsPerMinute: 140,
          tolerance: -0.1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('end to end against a real exercise target', () {
    test('the shipped timed reading target is reachable and checkable', () {
      // reading_timed_01 in the content targets 140 wpm. A reader finishing a
      // 140 word passage in a minute should read as on target.
      const int target = 140;
      final int? pace = wordsPerMinute(
        wordCount: 140,
        elapsed: const Duration(minutes: 1),
      );

      expect(pace, target);
      expect(
        comparePace(
          actualWordsPerMinute: pace,
          targetWordsPerMinute: target,
        ),
        PaceVerdict.onTarget,
      );
    });
  });
}
