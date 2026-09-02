import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/training/domain/breathing/breathing.dart';
import 'package:hitup/features/training/domain/models/models.dart';

/// The pattern the shipped content uses: four in, two held, six out, five times.
const BreathingConfig standard = BreathingConfig(
  inhaleSeconds: 4,
  holdSeconds: 2,
  exhaleSeconds: 6,
  cycles: 5,
);

/// Short enough to run to the end in a handful of advances.
const BreathingConfig brief = BreathingConfig(
  inhaleSeconds: 1,
  holdSeconds: 1,
  exhaleSeconds: 1,
  cycles: 2,
);

void main() {
  group('BreathingEngine at rest', () {
    test('it starts at the beginning, running and unfinished', () {
      final BreathingEngine engine = BreathingEngine(config: standard);

      expect(engine.elapsed, Duration.zero);
      expect(engine.isPaused, isFalse);
      expect(engine.isComplete, isFalse);
      expect(engine.snapshot.phase, BreathingPhase.inhale);
      expect(engine.snapshot.cycle, 1);
    });

    test('it exposes the pattern and the schedule it runs', () {
      final BreathingEngine engine = BreathingEngine(config: standard);

      expect(engine.config, standard);
      expect(engine.timeline, const BreathingTimeline(standard));
      expect(engine.timeline.totalDuration, const Duration(seconds: 60));
    });

    test('toString names the pattern and the position', () {
      final BreathingEngine engine = BreathingEngine(config: standard);
      engine.advance(const Duration(seconds: 3));

      expect(
        engine.toString(),
        'BreathingEngine(BreathingConfig(4/2/6 x5), at 3000ms)',
      );
    });

    test('toString says so while paused', () {
      final BreathingEngine engine = BreathingEngine(config: standard)..pause();

      expect(engine.toString(), contains('paused'));
    });
  });

  group('BreathingEngine.advance', () {
    test('it moves the position forward', () {
      final BreathingEngine engine = BreathingEngine(config: standard);

      engine.advance(const Duration(seconds: 2));

      expect(engine.elapsed, const Duration(seconds: 2));
      expect(engine.snapshot.phase, BreathingPhase.inhale);
      expect(engine.snapshot.phaseProgress, 0.5);
    });

    test('advances add up rather than replacing each other', () {
      final BreathingEngine engine = BreathingEngine(config: standard);

      engine
        ..advance(const Duration(seconds: 2))
        ..advance(const Duration(seconds: 3));

      expect(engine.elapsed, const Duration(seconds: 5));
      expect(engine.snapshot.phase, BreathingPhase.hold);
    });

    test('rewinding is a caller bug, not a way to seek', () {
      final BreathingEngine engine = BreathingEngine(config: standard);

      expect(
        () => engine.advance(const Duration(seconds: -1)),
        throwsArgumentError,
      );
      expect(engine.elapsed, Duration.zero);
    });

    test('the position stops at the end rather than running past it', () {
      final BreathingEngine engine = BreathingEngine(config: brief);

      engine.advance(const Duration(hours: 1));

      expect(engine.elapsed, const Duration(seconds: 6));
      expect(engine.isComplete, isTrue);
    });

    test('advancing a finished engine leaves it where it finished', () {
      final BreathingEngine engine = BreathingEngine(config: brief);
      engine.advance(const Duration(seconds: 6));

      engine.advance(const Duration(seconds: 5));

      expect(engine.elapsed, const Duration(seconds: 6));
      expect(engine.snapshot.isComplete, isTrue);
    });

    test('an engine with no callbacks advances without complaint', () {
      final BreathingEngine engine = BreathingEngine(config: brief);

      engine.advance(const Duration(seconds: 6));

      expect(engine.isComplete, isTrue);
    });
  });

  group('BreathingEngine pausing', () {
    test('a paused engine ignores the time it is given', () {
      final BreathingEngine engine = BreathingEngine(config: standard);
      engine.advance(const Duration(seconds: 2));

      engine.pause();
      engine.advance(const Duration(seconds: 30));

      expect(engine.isPaused, isTrue);
      expect(engine.elapsed, const Duration(seconds: 2));
    });

    test('resuming takes time again from where it stopped', () {
      final BreathingEngine engine = BreathingEngine(config: standard);
      engine
        ..advance(const Duration(seconds: 2))
        ..pause()
        ..advance(const Duration(seconds: 30))
        ..resume()
        ..advance(const Duration(seconds: 1));

      expect(engine.isPaused, isFalse);
      expect(engine.elapsed, const Duration(seconds: 3));
    });

    test('a pause fires no phase change of its own', () {
      final List<BreathingSnapshot> seen = <BreathingSnapshot>[];
      final BreathingEngine engine = BreathingEngine(
        config: standard,
        onPhaseChanged: seen.add,
      );

      engine
        ..advance(const Duration(seconds: 2))
        ..pause()
        ..advance(const Duration(seconds: 30))
        ..resume();

      expect(seen, isEmpty);
    });
  });

  group('BreathingEngine phase reporting', () {
    test('crossing into a phase reports the phase arrived in', () {
      final List<BreathingSnapshot> seen = <BreathingSnapshot>[];
      final BreathingEngine engine = BreathingEngine(
        config: standard,
        onPhaseChanged: seen.add,
      );

      engine.advance(const Duration(seconds: 4));

      expect(seen, hasLength(1));
      expect(seen.single.phase, BreathingPhase.hold);
      expect(seen.single.cycle, 1);
      expect(seen.single.elapsedInPhase, Duration.zero);
    });

    test('moving within a phase reports nothing', () {
      final List<BreathingSnapshot> seen = <BreathingSnapshot>[];
      final BreathingEngine engine = BreathingEngine(
        config: standard,
        onPhaseChanged: seen.add,
      );

      engine
        ..advance(const Duration(seconds: 1))
        ..advance(const Duration(seconds: 1))
        ..advance(const Duration(seconds: 1));

      expect(engine.snapshot.phase, BreathingPhase.inhale);
      expect(seen, isEmpty);
    });

    test('a whole cycle reports each phase once, in order', () {
      final List<BreathingPhase> seen = <BreathingPhase>[];
      final BreathingEngine engine = BreathingEngine(
        config: standard,
        onPhaseChanged: (BreathingSnapshot s) => seen.add(s.phase),
      );

      for (int i = 0; i < 12; i++) {
        engine.advance(const Duration(seconds: 1));
      }

      expect(
        seen,
        <BreathingPhase>[
          BreathingPhase.hold,
          BreathingPhase.exhale,
          BreathingPhase.inhale,
        ],
      );
    });

    test('a new cycle in the same phase is still reported', () {
      // The only case that tells the cycle half of the check apart from the
      // phase half. Stepping 2s to 14s lands on the inhale of cycle two from
      // the inhale of cycle one: the phase is unchanged and a report is still
      // owed, because the user has started a new breath.
      final List<BreathingSnapshot> seen = <BreathingSnapshot>[];
      final BreathingEngine engine = BreathingEngine(
        config: standard,
        onPhaseChanged: seen.add,
      );

      engine.advance(const Duration(seconds: 2));
      expect(engine.snapshot.phase, BreathingPhase.inhale);
      expect(seen, isEmpty);

      engine.advance(const Duration(seconds: 12));

      expect(seen, hasLength(1));
      expect(seen.single.phase, BreathingPhase.inhale);
      expect(seen.single.cycle, 2);
    });

    test('one advance over several phases reports only where it landed', () {
      // A delta this long means the app was suspended. Replaying the cues for
      // phases already in the past would sound breaths the user never took.
      final List<BreathingSnapshot> seen = <BreathingSnapshot>[];
      final BreathingEngine engine = BreathingEngine(
        config: standard,
        onPhaseChanged: seen.add,
      );

      engine.advance(const Duration(seconds: 7));

      expect(seen, hasLength(1));
      expect(seen.single.phase, BreathingPhase.exhale);
      expect(seen.single.cycle, 1);
    });

    test('a pattern with no hold never reports one', () {
      const BreathingConfig noHold = BreathingConfig(
        inhaleSeconds: 1,
        holdSeconds: 0,
        exhaleSeconds: 1,
        cycles: 3,
      );
      final List<BreathingPhase> seen = <BreathingPhase>[];
      final BreathingEngine engine = BreathingEngine(
        config: noHold,
        onPhaseChanged: (BreathingSnapshot s) => seen.add(s.phase),
      );

      for (int i = 0; i < 60; i++) {
        engine.advance(const Duration(milliseconds: 100));
      }

      expect(seen, isNot(contains(BreathingPhase.hold)));
      expect(seen, contains(BreathingPhase.exhale));
    });
  });

  group('BreathingEngine completion', () {
    test('it runs the number of cycles the pattern asks for', () {
      final List<int> cycles = <int>[];
      final BreathingEngine engine = BreathingEngine(
        config: standard,
        onPhaseChanged: (BreathingSnapshot s) => cycles.add(s.cycle),
      );

      // Bounded rather than `while (!engine.isComplete)`. The pattern needs
      // sixty of these advances, so a limit of a hundred leaves room to be
      // wrong and still stop. An unbounded loop over a broken `isComplete`
      // does not fail, it hangs, and a hung suite says far less than a red one.
      for (int i = 0; i < 100 && !engine.isComplete; i++) {
        engine.advance(const Duration(seconds: 1));
      }

      expect(engine.isComplete, isTrue);
      expect(engine.elapsed, const Duration(seconds: 60));
      expect(cycles.last, 5);
      expect(engine.snapshot.cycle, 5);
      expect(engine.snapshot.isComplete, isTrue);
    });

    test('finishing is reported once, not on every later advance', () {
      int finished = 0;
      final BreathingEngine engine = BreathingEngine(
        config: brief,
        onComplete: () => finished++,
      );

      engine
        ..advance(const Duration(seconds: 6))
        ..advance(const Duration(seconds: 1))
        ..advance(const Duration(seconds: 1));

      expect(finished, 1);
    });

    test('finishing is not reported before the last cycle ends', () {
      int finished = 0;
      final BreathingEngine engine = BreathingEngine(
        config: brief,
        onComplete: () => finished++,
      );

      engine.advance(
        const Duration(seconds: 6) - const Duration(microseconds: 1),
      );

      expect(engine.isComplete, isFalse);
      expect(finished, 0);
    });
  });

  group('BreathingEngine.reset', () {
    test('it returns to the start of the first cycle', () {
      final BreathingEngine engine = BreathingEngine(config: standard);
      engine.advance(const Duration(seconds: 30));

      engine.reset();

      expect(engine.elapsed, Duration.zero);
      expect(engine.snapshot.phase, BreathingPhase.inhale);
      expect(engine.snapshot.cycle, 1);
    });

    test('it clears a pause, so a reset engine is ready to run', () {
      final BreathingEngine engine = BreathingEngine(config: standard)..pause();

      engine.reset();
      engine.advance(const Duration(seconds: 1));

      expect(engine.isPaused, isFalse);
      expect(engine.elapsed, const Duration(seconds: 1));
    });

    test('it fires neither callback', () {
      final List<BreathingSnapshot> seen = <BreathingSnapshot>[];
      int finished = 0;
      final BreathingEngine engine = BreathingEngine(
        config: brief,
        onPhaseChanged: seen.add,
        onComplete: () => finished++,
      );
      engine.advance(const Duration(seconds: 6));
      seen.clear();
      finished = 0;

      engine.reset();

      expect(seen, isEmpty);
      expect(finished, 0);
    });

    test('a reset engine can finish again and report it again', () {
      int finished = 0;
      final BreathingEngine engine = BreathingEngine(
        config: brief,
        onComplete: () => finished++,
      );
      engine.advance(const Duration(seconds: 6));

      engine.reset();
      engine.advance(const Duration(seconds: 6));

      expect(finished, 2);
    });

    test('after a reset the first phase change is not reported early', () {
      final List<BreathingSnapshot> seen = <BreathingSnapshot>[];
      final BreathingEngine engine = BreathingEngine(
        config: standard,
        onPhaseChanged: seen.add,
      );
      engine.advance(const Duration(seconds: 30));
      engine.reset();
      seen.clear();

      engine.advance(const Duration(seconds: 1));

      expect(seen, isEmpty);
      expect(engine.snapshot.phase, BreathingPhase.inhale);
    });
  });
}
