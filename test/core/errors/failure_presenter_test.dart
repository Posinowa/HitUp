import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/failure.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_messages.dart';
import 'package:hitup/core/errors/failure_presenter.dart';

/// Proves the issue's third acceptance criterion at the widget level: what a
/// user actually sees is the mapped sentence, never the underlying exception.
void main() {
  const rawError = '[firebase_auth/wrong-password] The password is invalid.';

  const wrongPassword = AuthFailure(
    code: FailureCode.authInvalidCredentials,
    technicalDetail: rawError,
  );
  const offline = NetworkFailure(
    code: FailureCode.networkOffline,
    technicalDetail: rawError,
  );

  String copyFor(Failure failure) => failureMessagesTr[failure.code]!;

  Widget harness(void Function(BuildContext context) onTap) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onTap(context),
            child: const Text('trigger'),
          ),
        ),
      ),
    );
  }

  Future<void> trigger(WidgetTester tester) async {
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
  }

  group('snack bar', () {
    testWidgets('shows the sentence and never the raw error', (tester) async {
      await tester.pumpWidget(
        harness((context) => showFailureSnackBar(context, wrongPassword)),
      );
      await trigger(tester);

      expect(find.text(copyFor(wrongPassword)), findsOneWidget);
      expect(find.textContaining('firebase_auth'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining(rawError), findsNothing);
    });

    testWidgets('offers retry when retrying could help', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        harness(
          (context) => showFailureSnackBar(
            context,
            offline,
            onRetry: () => retried++,
          ),
        ),
      );
      await trigger(tester);

      expect(find.text(FailureLabelsTr.retry), findsOneWidget);
      await tester.tap(find.text(FailureLabelsTr.retry));
      await tester.pumpAndSettle();
      expect(retried, 1);
    });

    testWidgets('offers no retry when retrying cannot help', (tester) async {
      await tester.pumpWidget(
        harness(
          (context) =>
              showFailureSnackBar(context, wrongPassword, onRetry: () {}),
        ),
      );
      await trigger(tester);

      expect(find.text(copyFor(wrongPassword)), findsOneWidget);
      expect(find.text(FailureLabelsTr.retry), findsNothing);
    });

    testWidgets('offers no retry without a callback', (tester) async {
      await tester.pumpWidget(
        harness((context) => showFailureSnackBar(context, offline)),
      );
      await trigger(tester);

      expect(find.text(FailureLabelsTr.retry), findsNothing);
    });

    testWidgets('message and retry are painted with the same pair', (
      tester,
    ) async {
      // The scheme here sets onErrorContainer and onInverseSurface to visibly
      // different colours on purpose. In the app's real scheme both resolve to
      // white, so a test built on that would pass even if the message fell
      // back to Material's default snack bar pairing, which is what this test
      // exists to catch.
      const scheme = ColorScheme.light(
        errorContainer: Color(0xFF7A0010),
        onErrorContainer: Color(0xFFFFDAD6),
        inverseSurface: Color(0xFF2F312E),
        onInverseSurface: Color(0xFF00FF00),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, colorScheme: scheme),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFailureSnackBar(
                  context,
                  offline,
                  onRetry: () {},
                ),
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      );
      await trigger(tester);

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, scheme.errorContainer);

      final message = tester.widget<Text>(find.text(copyFor(offline)));
      expect(
        message.style?.color,
        scheme.onErrorContainer,
        reason: 'the message must pair with the background it sits on, not '
            'with Material default onInverseSurface',
      );

      final retry = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
      expect(retry.textColor, scheme.onErrorContainer);
    });
  });

  group('dialog', () {
    testWidgets('shows the sentence and never the raw error', (tester) async {
      await tester.pumpWidget(
        harness((context) => showFailureDialog(context, wrongPassword)),
      );
      await trigger(tester);

      expect(find.text(FailureLabelsTr.dialogTitle), findsOneWidget);
      expect(find.text(copyFor(wrongPassword)), findsOneWidget);
      expect(find.textContaining('firebase_auth'), findsNothing);
      expect(find.textContaining(rawError), findsNothing);
    });

    testWidgets('dismisses without retrying', (tester) async {
      await tester.pumpWidget(
        harness((context) => showFailureDialog(context, wrongPassword)),
      );
      await trigger(tester);

      expect(find.text(FailureLabelsTr.retry), findsNothing);
      await tester.tap(find.text(FailureLabelsTr.dismiss));
      await tester.pumpAndSettle();
      expect(find.text(copyFor(wrongPassword)), findsNothing);
    });

    testWidgets('retry closes the dialog and runs the callback', (
      tester,
    ) async {
      var retried = 0;
      await tester.pumpWidget(
        harness(
          (context) =>
              showFailureDialog(context, offline, onRetry: () => retried++),
        ),
      );
      await trigger(tester);

      await tester.tap(find.text(FailureLabelsTr.retry));
      await tester.pumpAndSettle();

      expect(retried, 1);
      expect(find.text(copyFor(offline)), findsNothing);
    });
  });
}
