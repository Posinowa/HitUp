import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_messages.dart';
import 'package:hitup/core/theme/app_theme.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/presentation/renderers/breathing_renderer.dart';

// Expected text is written out, not asked of the labels.

/// In two, hold two, out two, twice over.
const BreathingConfig _config = BreathingConfig(
  inhaleSeconds: 2,
  holdSeconds: 2,
  exhaleSeconds: 2,
  cycles: 2,
);

void main() {
  Future<void> show(
    WidgetTester tester, {
    BreathingConfig? config = _config,
    ValueNotifier<bool>? running,
    bool stillness = false,
  }) async {
    final ValueNotifier<bool> isRunning = running ?? ValueNotifier<bool>(true);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: stillness),
          child: Scaffold(
            body: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: isRunning,
                builder: (BuildContext context, bool value, Widget? _) =>
                    BreathingView(config: config, running: value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// How wide the breathing circle is drawn.
  double circleWidth(WidgetTester tester) => tester
      .getSize(
        find.descendant(
          of: find.byType(BreathingView),
          matching: find.byType(DecoratedBox),
        ),
      )
      .width;

  /// The view in a room of [room], with the app's theme, whose line heights
  /// the layout reads, at [textScale].
  Future<void> showIn(
    WidgetTester tester,
    Size room, {
    double textScale = 1,
    ValueNotifier<bool>? running,
  }) async {
    final ValueNotifier<bool> isRunning = running ?? ValueNotifier<bool>(true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: room,
              child: ValueListenableBuilder<bool>(
                valueListenable: isRunning,
                builder: (BuildContext context, bool value, Widget? _) =>
                    BreathingView(config: _config, running: value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// A finder for the circle.
  Finder circle() => find.descendant(
        of: find.byType(BreathingView),
        matching: find.byType(DecoratedBox),
      );

  testWidgets('walks the phases of a cycle, and counts the cycles',
      (WidgetTester tester) async {
    await show(tester);

    expect(find.text('Al'), findsOneWidget);
    expect(find.text('Tur 1 / 2'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Tut'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Ver'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Al'), findsOneWidget);
    expect(find.text('Tur 2 / 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the circle grows on the in-breath and shrinks on the out',
      (WidgetTester tester) async {
    await show(tester);

    final double atStart = circleWidth(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    final double nearFull = circleWidth(tester);
    expect(nearFull, greaterThan(atStart));

    // Held: the circle stays where the in-breath left it.
    await tester.pump(const Duration(seconds: 1));
    expect(circleWidth(tester), closeTo(200, 0.5));

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Ver'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(circleWidth(tester), lessThan(nearFull));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('where the device asks for less motion, the circle stays still',
      (WidgetTester tester) async {
    await show(tester, stillness: true);

    final double atStart = circleWidth(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(circleWidth(tester), atStart);
    // The phase and its count still carry the exercise.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Tut'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stops with the session and carries on from where it stopped',
      (WidgetTester tester) async {
    final ValueNotifier<bool> running = ValueNotifier<bool>(true);
    addTearDown(running.dispose);
    await show(tester, running: running);
    await tester.pump(const Duration(seconds: 1));

    running.value = false;
    await tester.pump();
    expect(find.text('Duraklatıldı'), findsOneWidget);
    await tester.pump(const Duration(minutes: 2));
    expect(find.text('Tur 1 / 2'), findsOneWidget);

    running.value = true;
    await tester.pump();
    // One second of the in-breath was left when it stopped.
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('Tut'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('says when every cycle is done, and can be run again',
      (WidgetTester tester) async {
    await show(tester);

    await tester.pump(const Duration(seconds: 12));

    expect(find.text('Nefes çalışması tamam'), findsOneWidget);
    // Nothing moves once it is done.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Nefes çalışması tamam'), findsOneWidget);

    await tester.tap(find.text('Tekrar'));
    await tester.pump();
    expect(find.text('Tur 1 / 2'), findsOneWidget);
    expect(find.text('Nefes çalışması tamam'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Tut'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'paused with the circle at its smallest, at enlarged text, '
      'nothing overflows', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final ValueNotifier<bool> running = ValueNotifier<bool>(true);
    addTearDown(running.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: running,
              builder: (BuildContext context, bool value, Widget? _) =>
                  // A long out-breath, so the circle is at its smallest
                  // when the longest word is shown.
                  BreathingView(
                config: const BreathingConfig(
                  inhaleSeconds: 1,
                  holdSeconds: 0,
                  exhaleSeconds: 9,
                  cycles: 1,
                ),
                running: value,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 9900));

    running.value = false;
    await tester.pump();
    expect(find.text('Duraklatıldı'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with room, the circle is above the words at its largest',
      (WidgetTester tester) async {
    await showIn(tester, const Size(342, 391));
    // Held, the circle is at the full size of its square.
    await tester.pump(const Duration(milliseconds: 2100));

    expect(find.text('Tut'), findsOneWidget);
    expect(circleWidth(tester), closeTo(200, 0.5));
    expect(
      tester.getCenter(circle()).dy,
      lessThan(tester.getCenter(find.text('Tut')).dy),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with less room, the circle shrinks so the words stay in view',
      (WidgetTester tester) async {
    // At 130% text the words take 126.7: 266 less that and 16 leaves 123.3.
    await showIn(tester, const Size(342, 266), textScale: 1.3);
    await tester.pump(const Duration(milliseconds: 2100));

    expect(circleWidth(tester), closeTo(123.3, 0.5));
    expect(find.text('Tut').hitTestable(), findsOneWidget);
    expect(find.text('Tur 1 / 2').hitTestable(), findsOneWidget);
    expect(
      tester.getCenter(circle()).dy,
      lessThan(tester.getCenter(find.text('Tut')).dy),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with too little room, the circle moves beside the words',
      (WidgetTester tester) async {
    // The smallest room the exercise screen leaves: 320x568 at 130% text.
    await showIn(tester, const Size(272, 128), textScale: 1.3);
    await tester.pump(const Duration(milliseconds: 2100));

    expect(find.text('Tut').hitTestable(), findsOneWidget);
    expect(find.text('2').hitTestable(), findsOneWidget);
    expect(find.text('Tur 1 / 2').hitTestable(), findsOneWidget);
    expect(
      tester.getCenter(circle()).dx,
      lessThan(tester.getCenter(find.text('Tut')).dx),
    );
    expect(tester.getSize(circle()).height, lessThanOrEqualTo(128));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a circle that would be small above the words goes beside them',
      (WidgetTester tester) async {
    // The words take 99.3 at normal text: 230 less that and 16 leaves 114.7,
    // under the 120 a circle above them needs.
    await showIn(tester, const Size(342, 230));
    await tester.pump(const Duration(milliseconds: 2100));

    expect(
      tester.getCenter(circle()).dx,
      lessThan(tester.getCenter(find.text('Tut')).dx),
    );
    // Beside the words it stays modest, even with width to spare.
    expect(circleWidth(tester), closeTo(140, 0.5));
    expect(find.text('Tur 1 / 2').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'paused beside the circle, words wider than the room wrap rather than '
      'overflow', (WidgetTester tester) async {
    // The test font's glyphs are a full em wide, so at 130% "Duraklatıldı"
    // is wider than this whole room, as real text is at the largest sizes.
    final ValueNotifier<bool> running = ValueNotifier<bool>(true);
    addTearDown(running.dispose);
    await showIn(
      tester,
      const Size(272, 128),
      textScale: 1.3,
      running: running,
    );
    running.value = false;
    await tester.pump();

    expect(find.text('Duraklatıldı'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'done in too little room, the end and the button to start again '
      'take its place', (WidgetTester tester) async {
    await showIn(tester, const Size(400, 160));
    await tester.pump(const Duration(seconds: 12));

    expect(find.text('Nefes çalışması tamam').hitTestable(), findsOneWidget);
    expect(find.text('Tekrar').hitTestable(), findsOneWidget);
    // Nothing is left for the circle to show.
    expect(circle(), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reads out what the circle shows and the seconds left in it',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final ValueNotifier<bool> running = ValueNotifier<bool>(true);
    addTearDown(running.dispose);
    await show(tester, running: running);

    expect(find.semantics.byLabel('Al, 2 saniye'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.semantics.byLabel('Al, 1 saniye'), findsOneWidget);

    // Paused, it says so, as the screen does.
    running.value = false;
    await tester.pump();
    expect(find.semantics.byLabel('Duraklatıldı, 1 saniye'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    handle.dispose();
  });

  testWidgets('a pattern that holds for no time skips the hold',
      (WidgetTester tester) async {
    await show(
      tester,
      config: const BreathingConfig(
        inhaleSeconds: 2,
        holdSeconds: 0,
        exhaleSeconds: 2,
        cycles: 1,
      ),
    );

    expect(find.text('Al'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Ver'), findsOneWidget);
    expect(find.text('Tut'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('another pattern starts from its own first breath',
      (WidgetTester tester) async {
    final ValueNotifier<BreathingConfig> shown =
        ValueNotifier<BreathingConfig>(_config);
    addTearDown(shown.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<BreathingConfig>(
              valueListenable: shown,
              builder: (BuildContext context, BreathingConfig value, _) =>
                  BreathingView(config: value, running: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Tut'), findsOneWidget);

    shown.value = const BreathingConfig(
      inhaleSeconds: 3,
      holdSeconds: 1,
      exhaleSeconds: 3,
      cycles: 4,
    );
    await tester.pump();

    expect(find.text('Al'), findsOneWidget);
    expect(find.text('Tur 1 / 4'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an exercise with no breathing pattern is a content mistake',
      (WidgetTester tester) async {
    await show(tester, config: null);

    expect(
      find.text(failureMessagesTr[FailureCode.contentMalformed]!),
      findsOneWidget,
    );
    expect(find.text('Al'), findsNothing);
  });
}
