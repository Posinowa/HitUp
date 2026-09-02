import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/training/domain/breathing/breathing.dart';
import 'package:hitup/features/training/domain/models/models.dart';

/// The pattern the shipped content actually uses, so the numbers below are the
/// ones a user meets rather than ones chosen to make the arithmetic easy.
const BreathingConfig standard = BreathingConfig(
  inhaleSeconds: 4,
  holdSeconds: 2,
  exhaleSeconds: 6,
  cycles: 5,
);

/// A pattern with no hold, which is the case the phase lookup can get wrong
/// without any test noticing: a zero length hold must be skipped, not entered.
const BreathingConfig noHold = BreathingConfig(
  inhaleSeconds: 3,
  holdSeconds: 0,
  exhaleSeconds: 5,
  cycles: 2,
);

/// One microsecond, the smallest step a [Duration] can take.
const Duration tick = Duration(microseconds: 1);

/// A snapshot with one field changed, for the identity tests below.
BreathingSnapshot snapshot({
  BreathingPhase phase = BreathingPhase.hold,
  int cycle = 2,
  Duration elapsedInPhase = const Duration(seconds: 1),
  Duration phaseDuration = const Duration(seconds: 2),
  bool isComplete = false,
}) =>
    BreathingSnapshot(
      phase: phase,
      cycle: cycle,
      elapsedInPhase: elapsedInPhase,
      phaseDuration: phaseDuration,
      isComplete: isComplete,
    );

void main() {
  group('BreathingTimeline durations', () {
    test('a cycle is the three phases added up', () {
      expect(
        const BreathingTimeline(standard).cycleDuration,
        const Duration(seconds: 12),
      );
    });

    test('the whole exercise is every cycle', () {
      expect(
        const BreathingTimeline(standard).totalDuration,
        const Duration(seconds: 60),
      );
    });
  });

  group('BreathingTimeline.snapshotAt', () {
    const BreathingTimeline timeline = BreathingTimeline(standard);

    test('time before the start is a caller bug, not an edge', () {
      expect(
        () => timeline.snapshotAt(const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });

    test('the exercise opens on an inhale in the first cycle', () {
      final BreathingSnapshot s = timeline.snapshotAt(Duration.zero);

      expect(s.phase, BreathingPhase.inhale);
      expect(s.cycle, 1);
      expect(s.elapsedInPhase, Duration.zero);
      expect(s.phaseDuration, const Duration(seconds: 4));
      expect(s.remainingInPhase, const Duration(seconds: 4));
      expect(s.phaseProgress, 0.0);
      expect(s.isComplete, isFalse);
    });

    test('the instant before a boundary still belongs to the phase ending', () {
      final BreathingSnapshot s =
          timeline.snapshotAt(const Duration(seconds: 4) - tick);

      expect(s.phase, BreathingPhase.inhale);
      expect(s.remainingInPhase, tick);
    });

    test('a boundary belongs to the phase starting, not the one ending', () {
      // Four seconds of inhaling are finished at exactly four seconds, so this
      // instant is the first of the hold rather than the last of the inhale.
      final BreathingSnapshot s =
          timeline.snapshotAt(const Duration(seconds: 4));

      expect(s.phase, BreathingPhase.hold);
      expect(s.elapsedInPhase, Duration.zero);
      expect(s.phaseDuration, const Duration(seconds: 2));
    });

    test('the exhale starts once the hold is spent', () {
      final BreathingSnapshot s =
          timeline.snapshotAt(const Duration(seconds: 6));

      expect(s.phase, BreathingPhase.exhale);
      expect(s.elapsedInPhase, Duration.zero);
      expect(s.phaseDuration, const Duration(seconds: 6));
    });

    test('a cycle boundary opens the next cycle on an inhale', () {
      final BreathingSnapshot s =
          timeline.snapshotAt(const Duration(seconds: 12));

      expect(s.phase, BreathingPhase.inhale);
      expect(s.cycle, 2);
      expect(s.elapsedInPhase, Duration.zero);
    });

    test('the cycle number counts from one, not zero', () {
      expect(timeline.snapshotAt(const Duration(seconds: 48)).cycle, 5);
      expect(timeline.snapshotAt(const Duration(seconds: 47)).cycle, 4);
    });

    test('progress through a phase is the fraction of it spent', () {
      final BreathingSnapshot s =
          timeline.snapshotAt(const Duration(seconds: 2));

      expect(s.phase, BreathingPhase.inhale);
      expect(s.phaseProgress, 0.5);
      expect(s.remainingInPhase, const Duration(seconds: 2));
    });

    test('mid phase in a later cycle reports that cycle, not the first', () {
      final BreathingSnapshot s =
          timeline.snapshotAt(const Duration(seconds: 31));

      expect(s.cycle, 3);
      expect(s.phase, BreathingPhase.exhale);
      expect(s.elapsedInPhase, const Duration(seconds: 1));
    });

    test('the end is complete rather than the last instant of an exhale', () {
      final BreathingSnapshot s =
          timeline.snapshotAt(const Duration(seconds: 60));

      expect(s.isComplete, isTrue);
      expect(s.phase, BreathingPhase.exhale);
      expect(s.cycle, 5);
      expect(s.phaseProgress, 1.0);
      expect(s.remainingInPhase, Duration.zero);
    });

    test('time past the end reads the same as the end', () {
      expect(
        timeline.snapshotAt(const Duration(minutes: 5)),
        timeline.snapshotAt(const Duration(seconds: 60)),
      );
    });

    test('the instant before the end is still running', () {
      final BreathingSnapshot s =
          timeline.snapshotAt(const Duration(seconds: 60) - tick);

      expect(s.isComplete, isFalse);
      expect(s.cycle, 5);
      expect(s.phase, BreathingPhase.exhale);
    });
  });

  group('BreathingTimeline with no hold', () {
    const BreathingTimeline timeline = BreathingTimeline(noHold);

    test('the inhale boundary goes straight to the exhale', () {
      final BreathingSnapshot s =
          timeline.snapshotAt(const Duration(seconds: 3));

      expect(s.phase, BreathingPhase.exhale);
      expect(s.elapsedInPhase, Duration.zero);
      expect(s.phaseDuration, const Duration(seconds: 5));
    });

    test('the hold never appears anywhere in the run', () {
      // Swept rather than sampled: a zero length hold that is entered for a
      // single instant would be invisible to any one point a test could pick.
      final Set<BreathingPhase> seen = <BreathingPhase>{};
      for (int ms = 0; ms < timeline.totalDuration.inMilliseconds; ms++) {
        seen.add(timeline.snapshotAt(Duration(milliseconds: ms)).phase);
      }

      expect(seen, isNot(contains(BreathingPhase.hold)));
      expect(seen, contains(BreathingPhase.inhale));
      expect(seen, contains(BreathingPhase.exhale));
    });
  });

  group('BreathingSnapshot value semantics', () {
    test('equal snapshots are equal and hash alike', () {
      expect(snapshot(), snapshot());
      expect(snapshot().hashCode, snapshot().hashCode);

      final BreathingSnapshot same = snapshot();
      expect(same, same);
    });

    test('the phase is part of the identity', () {
      final BreathingSnapshot other = snapshot(phase: BreathingPhase.exhale);

      expect(snapshot(), isNot(other));
      expect(snapshot().hashCode, isNot(other.hashCode));
    });

    test('the cycle is part of the identity', () {
      final BreathingSnapshot other = snapshot(cycle: 3);

      expect(snapshot(), isNot(other));
      expect(snapshot().hashCode, isNot(other.hashCode));
    });

    test('the position within the phase is part of the identity', () {
      final BreathingSnapshot other =
          snapshot(elapsedInPhase: const Duration(milliseconds: 500));

      expect(snapshot(), isNot(other));
      expect(snapshot().hashCode, isNot(other.hashCode));
    });

    test('the length of the phase is part of the identity', () {
      final BreathingSnapshot other =
          snapshot(phaseDuration: const Duration(seconds: 3));

      expect(snapshot(), isNot(other));
      expect(snapshot().hashCode, isNot(other.hashCode));
    });

    test('being finished is part of the identity', () {
      final BreathingSnapshot other = snapshot(isComplete: true);

      expect(snapshot(), isNot(other));
      expect(snapshot().hashCode, isNot(other.hashCode));
    });

    test('a snapshot is not equal to another type', () {
      expect(snapshot(), isNot(const Object()));
    });

    test('toString names the phase, the cycle and the position', () {
      expect(
        snapshot().toString(),
        'BreathingSnapshot(hold, cycle 2, 1000/2000ms)',
      );
    });

    test('toString says so when the exercise is finished', () {
      expect(
        const BreathingTimeline(standard)
            .snapshotAt(const Duration(seconds: 60))
            .toString(),
        contains('complete'),
      );
    });
  });

  group('BreathingTimeline value semantics', () {
    test('timelines over the same pattern are equal and hash alike', () {
      const BreathingTimeline a = BreathingTimeline(standard);
      const BreathingTimeline b = BreathingTimeline(standard);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, a);
    });

    test('a different pattern is a different timeline', () {
      expect(
        const BreathingTimeline(standard),
        isNot(const BreathingTimeline(noHold)),
      );
      expect(
        const BreathingTimeline(standard).hashCode,
        isNot(const BreathingTimeline(noHold).hashCode),
      );
    });

    test('a timeline is not equal to another type', () {
      expect(const BreathingTimeline(standard), isNot(const Object()));
    });

    test('toString carries the pattern', () {
      expect(
        const BreathingTimeline(standard).toString(),
        'BreathingTimeline(BreathingConfig(4/2/6 x5))',
      );
    });
  });
}
