import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/app.dart';
import 'package:hitup/core/widgets/damga_mark.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/onboarding/data/onboarding_store.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/startup_providers.dart';

/// An onboarding flag that answers when told to, or fails.
class _FakeOnboardingStore implements OnboardingStore {
  _FakeOnboardingStore({this.complete = true, this.error});

  bool complete;
  Object? error;
  int reads = 0;

  final Completer<void> _held = Completer<void>();

  /// Whether the read waits for [release] instead of answering at once.
  bool hold = false;

  void release() => _held.complete();

  @override
  Future<bool> isComplete() async {
    reads++;
    if (hold) {
      await _held.future;
    }
    if (error != null) {
      throw error!;
    }
    return complete;
  }

  @override
  Future<void> markComplete() async => complete = true;
}

/// Starts the app with startup's two answers under the test's control.
///
/// [auth] is a factory rather than a stream, because retrying re-listens: the
/// real `authStateChanges()` hands out a new stream each time it is called,
/// and a single-subscription stream reused here would fail on the second
/// listen for a reason the app does not have.
Future<void> _pumpApp(
  WidgetTester tester, {
  required OnboardingStore onboarding,
  required Stream<AuthUser?> Function() auth,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        onboardingStoreProvider.overrideWithValue(onboarding),
        authStateChangesProvider.overrideWith((Ref ref) => auth()),
      ],
      child: const HitUpApp(),
    ),
  );
  await tester.pump();
}

void main() {
  group('a cold start', () {
    testWidgets('lands on the splash before anything is known',
        (WidgetTester tester) async {
      final _FakeOnboardingStore onboarding = _FakeOnboardingStore()
        ..hold = true;

      await _pumpApp(
        tester,
        onboarding: onboarding,
        auth: () => const Stream<AuthUser?>.empty(),
      );

      expect(find.byType(DamgaMark), findsOneWidget);
      expect(find.text('HitUp'), findsOneWidget);
      // Nothing to say yet, so nothing is said.
      expect(find.text('Tekrar dene'), findsNothing);

      onboarding.release();
      await tester.pumpAndSettle();
    });

    testWidgets('goes to onboarding when the device has not seen it',
        (WidgetTester tester) async {
      await _pumpApp(
        tester,
        onboarding: _FakeOnboardingStore(complete: false),
        auth: () => Stream<AuthUser?>.value(null),
      );
      await tester.pumpAndSettle();

      expect(find.text('Onboarding'), findsOneWidget);
    });

    testWidgets('goes to login when onboarding is done and nobody is signed in',
        (WidgetTester tester) async {
      await _pumpApp(
        tester,
        onboarding: _FakeOnboardingStore(),
        auth: () => Stream<AuthUser?>.value(null),
      );
      await tester.pumpAndSettle();

      expect(find.text('Giriş'), findsOneWidget);
    });

    testWidgets('goes home when onboarding is done and a user is signed in',
        (WidgetTester tester) async {
      await _pumpApp(
        tester,
        onboarding: _FakeOnboardingStore(),
        auth: () => Stream<AuthUser?>.value(const AuthUser(uid: 'uid-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bugünün antrenmanı'), findsOneWidget);
    });

    testWidgets('waits for both answers, not just the first',
        (WidgetTester tester) async {
      // Auth answers immediately, the flag is held. Routing on what is known
      // so far would send a signed-in user home past onboarding they have not
      // seen.
      final _FakeOnboardingStore onboarding =
          _FakeOnboardingStore(complete: false)..hold = true;

      await _pumpApp(
        tester,
        onboarding: onboarding,
        auth: () => Stream<AuthUser?>.value(const AuthUser(uid: 'uid-1')),
      );
      await tester.pump();

      expect(find.byType(DamgaMark), findsOneWidget);
      expect(find.text('Bugünün antrenmanı'), findsNothing);

      onboarding.release();
      await tester.pumpAndSettle();
      expect(find.text('Onboarding'), findsOneWidget);
    });
  });

  group('when startup fails', () {
    testWidgets('the splash says so and offers to try again',
        (WidgetTester tester) async {
      final _FakeOnboardingStore onboarding =
          _FakeOnboardingStore(error: StateError('preferences are gone'));

      await _pumpApp(
        tester,
        onboarding: onboarding,
        auth: () => Stream<AuthUser?>.value(null),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('sorun oldu'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      // The failure itself is not put on screen.
      expect(find.textContaining('StateError'), findsNothing);
      expect(find.textContaining('preferences are gone'), findsNothing);
    });

    testWidgets('trying again asks the question again, and can succeed',
        (WidgetTester tester) async {
      final _FakeOnboardingStore onboarding =
          _FakeOnboardingStore(error: StateError('preferences are gone'));

      await _pumpApp(
        tester,
        onboarding: onboarding,
        auth: () => Stream<AuthUser?>.value(null),
      );
      await tester.pumpAndSettle();
      expect(onboarding.reads, 1);

      onboarding.error = null;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();

      expect(onboarding.reads, 2);
      expect(find.text('Giriş'), findsOneWidget);
    });

    testWidgets('trying again re-listens to the auth stream too',
        (WidgetTester tester) async {
      // Retrying has to ask both questions again. If it re-read only the flag,
      // an app that failed because auth was unreachable would keep failing
      // however many times the user tapped.
      int listens = 0;
      Stream<AuthUser?> auth() {
        listens++;
        return listens == 1
            ? Stream<AuthUser?>.error(StateError('auth is unreachable'))
            : Stream<AuthUser?>.value(null);
      }

      await _pumpApp(
        tester,
        onboarding: _FakeOnboardingStore(),
        auth: auth,
      );
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);

      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();

      expect(listens, 2);
      expect(find.text('Giriş'), findsOneWidget);
    });

    testWidgets('an auth failure is treated the same way',
        (WidgetTester tester) async {
      await _pumpApp(
        tester,
        onboarding: _FakeOnboardingStore(),
        auth: () => Stream<AuthUser?>.error(StateError('auth is unreachable')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tekrar dene'), findsOneWidget);
    });
  });

  group('the splash cannot wait forever', () {
    test('the flag read is given a deadline', () {
      // A held platform channel would otherwise leave the app on the splash
      // with nothing to tap. The timeout turns that into the error state,
      // which has a retry button.
      expect(startupTimeout, lessThanOrEqualTo(const Duration(seconds: 10)));
      expect(startupTimeout, greaterThan(const Duration(seconds: 1)));
    });

    testWidgets('and the deadline ends on the error state',
        (WidgetTester tester) async {
      await tester.runAsync(() async {});
      final _FakeOnboardingStore onboarding = _FakeOnboardingStore()
        ..hold = true;

      await _pumpApp(
        tester,
        onboarding: onboarding,
        auth: () => Stream<AuthUser?>.value(null),
      );

      // Fast forward past the deadline without waiting for it in real time.
      await tester.pump(startupTimeout + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Tekrar dene'), findsOneWidget);

      onboarding.release();
    });
  });
}
