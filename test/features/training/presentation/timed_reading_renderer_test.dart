import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_messages.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/domain/words_per_minute.dart';
import 'package:hitup/features/training/presentation/renderers/timed_reading_renderer.dart';

typedef _L = TimedReadingLabelsTr;

/// 60 words at a target of 120 a minute: half a minute is on target.
final TimedReadingConfig _config = TimedReadingConfig(
  text: List<String>.generate(60, (int i) => 'kelime$i').join(' '),
  targetWordsPerMinute: 120,
);

void main() {
  late DateTime now;

  setUp(() => now = DateTime(2026, 9, 22, 10));

  /// Shows [config], with the session running while [running] says so.
  Future<void> show(
    WidgetTester tester, {
    TimedReadingConfig? config,
    ValueNotifier<bool>? running,
  }) async {
    final ValueNotifier<bool> isRunning = running ?? ValueNotifier<bool>(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          readingClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: isRunning,
              builder: (BuildContext context, bool value, Widget? _) =>
                  TimedReadingView(config: config ?? _config, running: value),
            ),
          ),
        ),
      ),
    );
  }

  /// Moves the wall clock and the test's timers on by [by].
  Future<void> wait(WidgetTester tester, Duration by) async {
    now = now.add(by);
    await tester.pump(by);
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
  }

  testWidgets('shows the passage, the target and the length',
      (WidgetTester tester) async {
    await show(tester);

    expect(find.text(_config.text), findsOneWidget);
    expect(find.text(_L.target(120, 60)), findsOneWidget);
    expect(find.text(_L.start), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("the start button keeps its own width, not the room's",
      (WidgetTester tester) async {
    await show(tester);

    // The test screen is 800 wide. A button as wide as the room would look
    // like the exercise screen's own full-width Tamamla.
    expect(
      tester
          .getSize(find.widgetWithText(ElevatedButton, 'Okumaya başla'))
          .width,
      lessThan(400),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('times one reading and gives its pace against the target',
      (WidgetTester tester) async {
    await show(tester);

    await tap(tester, _L.start);
    await wait(tester, const Duration(seconds: 30));
    expect(find.text('0:30'), findsOneWidget);
    await tap(tester, _L.done);

    expect(find.text(_L.pace(120)), findsOneWidget);
    expect(find.text(_L.verdict(PaceVerdict.onTarget)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('another passage starts from its start button, with nothing read',
      (WidgetTester tester) async {
    final ValueNotifier<TimedReadingConfig> shown =
        ValueNotifier<TimedReadingConfig>(_config);
    addTearDown(shown.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          readingClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<TimedReadingConfig>(
              valueListenable: shown,
              builder: (BuildContext context, TimedReadingConfig value, _) =>
                  TimedReadingView(config: value, running: true),
            ),
          ),
        ),
      ),
    );
    await tap(tester, _L.start);
    await wait(tester, const Duration(seconds: 20));

    // 30 words at a target of 120 a minute.
    final TimedReadingConfig other = TimedReadingConfig(
      text: List<String>.generate(30, (int i) => 'söz$i').join(' '),
      targetWordsPerMinute: 120,
    );
    shown.value = other;
    await tester.pump();

    expect(find.text(other.text), findsOneWidget);
    expect(find.text(_L.start), findsOneWidget);
    // Read from nothing: the twenty seconds before are not counted.
    await tap(tester, _L.start);
    await wait(tester, const Duration(seconds: 15));
    await tap(tester, _L.done);
    expect(find.text(_L.pace(120)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('says when the reading was slower or faster than the target',
      (WidgetTester tester) async {
    // The words written out, not asked of the labels: a test that asks the
    // code what to expect would pass with slow and fast swapped.
    for (final (Duration took, int pace, String verdict)
        in const <(Duration, int, String)>[
      (Duration(seconds: 60), 60, 'Hedeften yavaş'),
      (Duration(seconds: 20), 180, 'Hedeften hızlı'),
      // 60 words in 32 seconds is 112.5, rounded to 113: within a tenth of
      // 120, so on target.
      (Duration(seconds: 32), 113, 'Hedefte'),
    ]) {
      await show(tester);
      await tap(tester, _L.start);
      await wait(tester, took);
      await tap(tester, _L.done);

      expect(find.text(_L.pace(pace)), findsOneWidget, reason: '$took');
      expect(find.text(verdict), findsOneWidget, reason: '$took');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('time the session spends paused is not reading time',
      (WidgetTester tester) async {
    final ValueNotifier<bool> running = ValueNotifier<bool>(true);
    addTearDown(running.dispose);
    await show(tester, running: running);

    await tap(tester, _L.start);
    await wait(tester, const Duration(seconds: 10));
    running.value = false;
    await tester.pump();
    expect(find.text(_L.paused), findsOneWidget);
    await wait(tester, const Duration(minutes: 5));
    running.value = true;
    await tester.pump();
    await wait(tester, const Duration(seconds: 20));
    await tap(tester, _L.done);

    // Thirty seconds read, not five and a half minutes.
    expect(find.text(_L.pace(120)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('started while the session is paused, it counts from resuming',
      (WidgetTester tester) async {
    final ValueNotifier<bool> running = ValueNotifier<bool>(false);
    addTearDown(running.dispose);
    await show(tester, running: running);

    await tap(tester, _L.start);
    await wait(tester, const Duration(minutes: 1));
    running.value = true;
    await tester.pump();
    await wait(tester, const Duration(seconds: 30));
    await tap(tester, _L.done);

    expect(find.text(_L.pace(120)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a reading with no time in it is not given a pace',
      (WidgetTester tester) async {
    await show(tester);

    await tap(tester, _L.start);
    await tap(tester, _L.done);

    expect(find.text(_L.notMeasured), findsOneWidget);
    expect(find.textContaining('Hedef'), findsOneWidget, reason: 'the target');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reading again starts from nothing', (WidgetTester tester) async {
    await show(tester);

    await tap(tester, _L.start);
    await wait(tester, const Duration(seconds: 60));
    await tap(tester, _L.done);
    expect(find.text(_L.pace(60)), findsOneWidget);

    await tap(tester, _L.again);
    await wait(tester, const Duration(seconds: 30));
    await tap(tester, _L.done);

    expect(find.text(_L.pace(120)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reads the time aloud while reading',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await show(tester);

    await tap(tester, _L.start);
    await wait(tester, const Duration(seconds: 7));

    expect(find.bySemanticsLabel(_L.took(7)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('an exercise with no reading config is a content mistake',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TimedReadingView(config: null, running: true),
          ),
        ),
      ),
    );

    expect(
      find.text(failureMessagesTr[FailureCode.contentMalformed]!),
      findsOneWidget,
    );
    expect(find.text(_L.start), findsNothing);
  });
}
