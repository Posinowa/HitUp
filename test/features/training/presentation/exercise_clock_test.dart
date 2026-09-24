import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/training/presentation/exercise_clock.dart';

void main() {
  // testWidgets for its fake clock: the periodic timer is driven by pump,
  // without waiting in real time.

  testWidgets('counts down the exercise and counts up the session',
      (WidgetTester tester) async {
    final ExerciseClock clock = ExerciseClock();

    clock
      ..showExercise(0, const Duration(seconds: 30))
      ..run();
    await tester.pump(const Duration(seconds: 3));

    expect(clock.remaining, const Duration(seconds: 27));
    expect(clock.elapsed, const Duration(seconds: 3));
    expect(clock.isRunning, isTrue);

    // Here, not in a tear-down: the framework checks for pending timers
    // before tear-downs run.
    clock.dispose();
  });

  testWidgets('stopped, it keeps what it counted and counts nothing more',
      (WidgetTester tester) async {
    final ExerciseClock clock = ExerciseClock();

    clock
      ..showExercise(0, const Duration(seconds: 30))
      ..run();
    await tester.pump(const Duration(seconds: 2));
    clock.stop();
    await tester.pump(const Duration(seconds: 10));

    expect(clock.remaining, const Duration(seconds: 28));
    expect(clock.elapsed, const Duration(seconds: 2));
    expect(clock.isRunning, isFalse);

    // Here, not in a tear-down: the framework checks for pending timers
    // before tear-downs run.
    clock.dispose();
  });

  testWidgets('running twice does not count twice',
      (WidgetTester tester) async {
    final ExerciseClock clock = ExerciseClock();

    clock
      ..showExercise(0, const Duration(seconds: 30))
      ..run()
      ..run();
    await tester.pump(const Duration(seconds: 1));

    expect(clock.elapsed, const Duration(seconds: 1));

    // Here, not in a tear-down: the framework checks for pending timers
    // before tear-downs run.
    clock.dispose();
  });

  testWidgets(
      'the same exercise again resets nothing; the next one resets only '
      'its own time', (WidgetTester tester) async {
    final ExerciseClock clock = ExerciseClock();

    clock
      ..showExercise(0, const Duration(seconds: 30))
      ..run();
    await tester.pump(const Duration(seconds: 4));

    clock.showExercise(0, const Duration(seconds: 30));
    expect(clock.remaining, const Duration(seconds: 26));

    clock.showExercise(1, const Duration(seconds: 20));
    expect(clock.remaining, const Duration(seconds: 20));
    expect(clock.elapsed, const Duration(seconds: 4));

    // Here, not in a tear-down: the framework checks for pending timers
    // before tear-downs run.
    clock.dispose();
  });

  testWidgets(
      "past the exercise's time, the countdown stays at zero and the "
      'session time goes on', (WidgetTester tester) async {
    final ExerciseClock clock = ExerciseClock();

    clock
      ..showExercise(0, const Duration(seconds: 2))
      ..run();
    await tester.pump(const Duration(seconds: 1));
    expect(clock.isTimeUp, isFalse);

    await tester.pump(const Duration(seconds: 4));

    expect(clock.remaining, Duration.zero);
    expect(clock.isTimeUp, isTrue);
    expect(clock.elapsed, const Duration(seconds: 5));

    // Here, not in a tear-down: the framework checks for pending timers
    // before tear-downs run.
    clock.dispose();
  });

  test('with no exercise shown, time is not up', () {
    final ExerciseClock clock = ExerciseClock();
    addTearDown(clock.dispose);

    expect(clock.remaining, Duration.zero);
    expect(clock.isTimeUp, isFalse);
  });

  testWidgets('tells its listeners on every change, and only then',
      (WidgetTester tester) async {
    final ExerciseClock clock = ExerciseClock();
    int notified = 0;
    clock.addListener(() => notified++);

    clock.showExercise(0, const Duration(seconds: 30));
    clock.showExercise(0, const Duration(seconds: 30));
    expect(notified, 1);

    clock.run();
    clock.run();
    expect(notified, 2);

    await tester.pump(const Duration(seconds: 2));
    expect(notified, 4);

    clock.stop();
    clock.stop();
    expect(notified, 5);

    // Here, not in a tear-down: the framework checks for pending timers
    // before tear-downs run.
    clock.dispose();
  });

  testWidgets('disposing a running clock leaves no timer behind',
      (WidgetTester tester) async {
    // The test framework fails a test that ends with a timer pending, so
    // this passing is the assertion.
    ExerciseClock()
      ..showExercise(0, const Duration(seconds: 30))
      ..run()
      ..dispose();
  });
}
