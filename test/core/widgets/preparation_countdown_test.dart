import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/theme/app_theme.dart';
import 'package:hitup/core/widgets/preparation_countdown.dart';

/// Tests for the preparation countdown (HIT-049).
///
/// Everything here runs on the test clock. `tester.pump(Duration)` advances the
/// timers the controller creates, so a three second countdown takes no real
/// time and the assertions are about ticks rather than about wall clock luck.
void main() {
  /// Gives the test a fake clock without rendering the widget under test, for
  /// the cases that are about the controller alone.
  Future<void> emptyFrame(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  Widget host(Widget child) =>
      MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));

  group('PreparationCountdownController', () {
    testWidgets('starts idle and reports the full duration', (tester) async {
      await emptyFrame(tester);
      final PreparationCountdownController controller =
          PreparationCountdownController(seconds: 3);

      expect(controller.status, PreparationCountdownStatus.idle);
      expect(controller.secondsRemaining, 3);
      expect(controller.isRunning, isFalse);
      expect(controller.progress, 0.0);

      controller.dispose();
    });

    testWidgets('counts down one second at a time', (tester) async {
      await emptyFrame(tester);
      final PreparationCountdownController controller =
          PreparationCountdownController(seconds: 3)..start();

      expect(controller.secondsRemaining, 3);
      expect(controller.isRunning, isTrue);

      await tester.pump(const Duration(seconds: 1));
      expect(controller.secondsRemaining, 2);

      await tester.pump(const Duration(seconds: 1));
      expect(controller.secondsRemaining, 1);

      // Disposed inside the body, not in a tear down: the binding checks for
      // pending timers before tear downs run, so a countdown left ticking here
      // would fail the test for the wrong reason.
      controller.dispose();
    });

    testWidgets('completes exactly at its own duration', (tester) async {
      // A three second countdown must take three seconds, not two and not
      // four. Off by one here means the task starts before the speaker is
      // ready, or after they have already begun.
      await emptyFrame(tester);
      final PreparationCountdownController controller =
          PreparationCountdownController(seconds: 3)..start();

      await tester.pump(const Duration(seconds: 2));
      expect(controller.status, PreparationCountdownStatus.running);

      await tester.pump(const Duration(seconds: 1));
      expect(controller.status, PreparationCountdownStatus.completed);
      expect(controller.secondsRemaining, 0);
      expect(controller.progress, 1.0);

      controller.dispose();
    });

    testWidgets('stops ticking once complete', (tester) async {
      await emptyFrame(tester);
      final PreparationCountdownController controller =
          PreparationCountdownController(seconds: 1)..start();

      await tester.pump(const Duration(seconds: 1));
      expect(controller.status, PreparationCountdownStatus.completed);

      // Nothing should keep counting into negative numbers.
      await tester.pump(const Duration(seconds: 5));
      expect(controller.secondsRemaining, 0);
      expect(controller.status, PreparationCountdownStatus.completed);

      controller.dispose();
    });

    testWidgets('cancelling stops it and is terminal', (tester) async {
      await emptyFrame(tester);
      final PreparationCountdownController controller =
          PreparationCountdownController(seconds: 5)..start();

      await tester.pump(const Duration(seconds: 2));
      controller.cancel();

      expect(controller.status, PreparationCountdownStatus.cancelled);
      expect(controller.isRunning, isFalse);

      final int atCancel = controller.secondsRemaining;
      await tester.pump(const Duration(seconds: 3));
      expect(
        controller.secondsRemaining,
        atCancel,
        reason: 'a cancelled countdown must not keep ticking',
      );

      // Restarting is deliberately not supported; the caller makes a new one.
      controller.start();
      expect(controller.status, PreparationCountdownStatus.cancelled);

      controller.dispose();
    });

    testWidgets('cancelling after completion does not rewrite the outcome', (
      tester,
    ) async {
      await emptyFrame(tester);
      final PreparationCountdownController controller =
          PreparationCountdownController(seconds: 1)..start();

      await tester.pump(const Duration(seconds: 1));
      controller.cancel();

      expect(controller.status, PreparationCountdownStatus.completed);

      controller.dispose();
    });

    testWidgets('a disposed controller leaves no timer running', (
      tester,
    ) async {
      // A periodic timer outlives its owner unless stopped, and the test
      // binding fails the test if one is still pending at the end.
      await emptyFrame(tester);
      PreparationCountdownController(seconds: 60)
        ..start()
        ..dispose();

      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('PreparationCountdown widget', () {
    testWidgets('shows the starting number and counts down on screen', (
      tester,
    ) async {
      await tester.pumpWidget(host(const PreparationCountdown(seconds: 3)));

      expect(find.text('3'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('reports completion once', (tester) async {
      int completed = 0;
      await tester.pumpWidget(
        host(PreparationCountdown(seconds: 2, onCompleted: () => completed++)),
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(completed, 1);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(completed, 1, reason: 'the callback must not fire again');
    });

    testWidgets('the cancel button reports cancellation, not completion', (
      tester,
    ) async {
      int completed = 0;
      int cancelled = 0;
      await tester.pumpWidget(
        host(
          PreparationCountdown(
            seconds: 5,
            onCompleted: () => completed++,
            onCancelled: () => cancelled++,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text(PreparationCountdownLabelsTr.cancel));
      await tester.pump();
      await tester.pump();

      expect(cancelled, 1);
      expect(completed, 0);
    });

    testWidgets('no cancel button when the caller does not want one', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const PreparationCountdown(seconds: 3, cancelLabel: null)),
      );

      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('waits for start when autoStart is off', (tester) async {
      await tester.pumpWidget(
        host(const PreparationCountdown(seconds: 3, autoStart: false)),
      );

      await tester.pump(const Duration(seconds: 2));
      expect(
        find.text('3'),
        findsOneWidget,
        reason: 'nothing should tick before the caller starts it',
      );
    });

    testWidgets('shows the optional label above the number', (tester) async {
      await tester.pumpWidget(
        host(
          const PreparationCountdown(seconds: 3, label: 'Konuşmaya hazırlan'),
        ),
      );

      expect(find.text('Konuşmaya hazırlan'), findsOneWidget);
    });

    testWidgets('takes its colours from the theme, not from literals', (
      tester,
    ) async {
      await tester.pumpWidget(host(const PreparationCountdown(seconds: 3)));

      final ColorScheme colors = AppTheme.light().colorScheme;
      final Text number = tester.widget<Text>(find.text('3'));
      final CircularProgressIndicator ring =
          tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );

      expect(number.style?.color, colors.primary);
      expect(ring.backgroundColor, colors.outline);
    });

    testWidgets('announces each number to a screen reader', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const PreparationCountdown(seconds: 3)));

      expect(
        find.bySemanticsLabel(
          PreparationCountdownLabelsTr.secondsRemaining(3),
        ),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(
        find.bySemanticsLabel(
          PreparationCountdownLabelsTr.secondsRemaining(2),
        ),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
