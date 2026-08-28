import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/failure.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_messages.dart';
import 'package:hitup/core/theme/app_theme.dart';
import 'package:hitup/core/widgets/async_state_views.dart';

void main() {
  const String rawError = '[cloud_firestore/unavailable] backend unreachable.';

  const NetworkFailure offline = NetworkFailure(
    code: FailureCode.networkOffline,
    technicalDetail: rawError,
  );
  const AuthFailure wrongPassword = AuthFailure(
    code: FailureCode.authInvalidCredentials,
    technicalDetail: rawError,
  );

  String copyFor(Failure failure) => failureMessagesTr[failure.code]!;

  Widget host(Widget child) =>
      MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));

  group('ErrorView', () {
    testWidgets('shows the mapped sentence and never the raw error', (
      tester,
    ) async {
      await tester.pumpWidget(host(const ErrorView(failure: offline)));

      expect(find.text(copyFor(offline)), findsOneWidget);
      expect(find.textContaining('cloud_firestore'), findsNothing);
      expect(find.textContaining(rawError), findsNothing);
    });

    testWidgets('draws the message on the error surface, not on the alert tone',
        (
      tester,
    ) async {
      await tester.pumpWidget(host(const ErrorView(failure: offline)));

      final ColorScheme colors = AppTheme.light().colorScheme;

      final DecoratedBox panel = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      final BoxDecoration decoration = panel.decoration as BoxDecoration;

      expect(decoration.color, colors.errorContainer);

      // The full-strength tone belongs on the edge and the icon, where nothing
      // is written over it. Checking only that a border exists would let it be
      // drawn in the surface colour, which is the same as having none: the
      // panel would stop reading as a problem at a glance.
      final Border border = decoration.border! as Border;
      expect(border.top.color, colors.error);

      final Icon icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, colors.error);

      final Text message = tester.widget<Text>(find.text(copyFor(offline)));
      expect(message.style?.color, colors.onErrorContainer);
    });

    testWidgets('the retry label stays readable on the error surface', (
      tester,
    ) async {
      // A scheme whose error roles are visibly unlike the defaults, so a button
      // that inherited its colour instead of taking the token cannot pass by
      // coincidence. Painted with errorContainer, the label would be the
      // surface colour on the surface: invisible.
      const ColorScheme scheme = ColorScheme.light(
        errorContainer: Color(0xFF7A0010),
        onErrorContainer: Color(0xFFFFDAD6),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, colorScheme: scheme),
          home: Scaffold(
            body: ErrorView(failure: offline, onRetry: () {}),
          ),
        ),
      );

      final TextButton retry = tester.widget<TextButton>(
        find.widgetWithText(TextButton, FailureLabelsTr.retry),
      );
      expect(
        retry.style?.foregroundColor?.resolve(<WidgetState>{}),
        scheme.onErrorContainer,
      );
    });

    testWidgets('offers retry when retrying could help', (tester) async {
      int retried = 0;
      await tester.pumpWidget(
        host(ErrorView(failure: offline, onRetry: () => retried++)),
      );

      await tester.tap(find.text(FailureLabelsTr.retry));
      await tester.pumpAndSettle();

      expect(retried, 1);
    });

    testWidgets('offers no retry when retrying cannot help', (tester) async {
      await tester.pumpWidget(
        host(ErrorView(failure: wrongPassword, onRetry: () {})),
      );

      expect(find.text(copyFor(wrongPassword)), findsOneWidget);
      expect(find.text(FailureLabelsTr.retry), findsNothing);
    });

    testWidgets('offers no retry without a callback', (tester) async {
      await tester.pumpWidget(host(const ErrorView(failure: offline)));

      expect(find.text(FailureLabelsTr.retry), findsNothing);
    });
  });

  group('EmptyView', () {
    testWidgets('is not dressed in error colours', (tester) async {
      // Having done nothing yet is not a failure. A new user's first screen
      // must not look broken.
      await tester.pumpWidget(
        host(const EmptyView(message: 'Henüz bir antrenman yok.')),
      );

      final ColorScheme colors = AppTheme.light().colorScheme;
      final Text message = tester.widget<Text>(
        find.text('Henüz bir antrenman yok.'),
      );

      expect(message.style?.color, isNot(colors.onErrorContainer));
      expect(find.byType(ErrorView), findsNothing);
    });

    testWidgets('draws the illustration only when one is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const EmptyView(message: 'Henüz bir antrenman yok.')),
      );
      expect(
        find.byType(Icon),
        findsNothing,
        reason: 'no icon was supplied, so none should be drawn',
      );

      await tester.pumpWidget(
        host(
          const EmptyView(
            message: 'Henüz bir antrenman yok.',
            icon: Icons.self_improvement,
          ),
        ),
      );

      final Icon icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.self_improvement);
      // The outline tone, not the error tone: an empty state is not a fault.
      expect(icon.color, AppTheme.light().colorScheme.outline);
      expect(find.text('Henüz bir antrenman yok.'), findsOneWidget);
    });
  });

  group('LoadingView', () {
    testWidgets('shows a progress indicator', (tester) async {
      await tester.pumpWidget(host(const LoadingView()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
