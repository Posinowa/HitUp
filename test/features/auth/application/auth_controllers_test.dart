import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/analytics/analytics_event.dart';
import 'package:hitup/core/errors/failure.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/features/auth/application/password_reset_controller.dart';
import 'package:hitup/features/auth/application/registration_controller.dart';
import 'package:hitup/features/auth/application/sign_in_controller.dart';
import 'package:hitup/shared/providers/analytics_providers.dart';
import 'package:hitup/shared/providers/auth_providers.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/recording_analytics.dart';

void main() {
  late FakeAuthRepository auth;
  late RecordingAnalytics analytics;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository();
    analytics = RecordingAnalytics();
    container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(auth),
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
    );
  });

  tearDown(() => container.dispose());

  /// Keeps an auto-disposed controller alive, as a screen watching it does.
  void keep(ProviderListenable<Object?> provider) =>
      container.listen(provider, (_, __) {});

  Failure failureOf(AsyncValue<Object?> state) => state.error! as Failure;

  group('signing in', () {
    setUp(() => keep(signInControllerProvider));

    SignInController controller() =>
        container.read(signInControllerProvider.notifier);

    test('signs in with what was typed, and reports it', () async {
      await controller().submit(email: 'ali@ornek.com', password: 'abc123');

      expect(auth.calls, <String>['signIn ali@ornek.com abc123']);
      expect(container.read(signInControllerProvider).hasError, isFalse);
      expect(container.read(signInControllerProvider).isLoading, isFalse);
      expect(analytics.events, <AnalyticsEvent>[
        AnalyticsEvent.login(method: 'password'),
      ]);
    });

    test('a wrong password is a failure with its code, and not reported',
        () async {
      auth.error = FirebaseAuthException(code: 'wrong-password');

      await controller().submit(email: 'ali@ornek.com', password: 'yanlis');

      final AsyncValue<void> state = container.read(signInControllerProvider);
      expect(state.hasError, isTrue);
      expect(failureOf(state), isA<AuthFailure>());
      expect(failureOf(state).code, FailureCode.authInvalidCredentials);
      expect(analytics.events, isEmpty);
    });

    test('a dropped connection is a network failure, not a wrong password',
        () async {
      auth.error = FirebaseAuthException(code: 'network-request-failed');

      await controller().submit(email: 'ali@ornek.com', password: 'abc123');

      expect(
        failureOf(container.read(signInControllerProvider)),
        isA<NetworkFailure>(),
      );
    });

    test('is loading while it runs, and a second submit is ignored', () async {
      auth.hold = Completer<void>();

      final Future<void> first =
          controller().submit(email: 'ali@ornek.com', password: 'abc123');
      expect(container.read(signInControllerProvider).isLoading, isTrue);
      await controller().submit(email: 'ali@ornek.com', password: 'abc123');

      auth.hold!.complete();
      await first;
      expect(auth.calls, hasLength(1));
      expect(container.read(signInControllerProvider).isLoading, isFalse);
    });

    test('can be tried again after a failure', () async {
      auth.error = FirebaseAuthException(code: 'wrong-password');
      await controller().submit(email: 'ali@ornek.com', password: 'yanlis');
      auth.error = null;

      await controller().submit(email: 'ali@ornek.com', password: 'dogru123');

      expect(auth.calls, hasLength(2));
      expect(container.read(signInControllerProvider).hasError, isFalse);
    });
  });

  group('registering', () {
    setUp(() => keep(registrationControllerProvider));

    RegistrationController controller() =>
        container.read(registrationControllerProvider.notifier);

    test('trims the name, passes the rest as typed, and reports it', () async {
      await controller().submit(
        displayName: '  Emir Rende ',
        email: ' ali@ornek.com',
        password: ' kalem739 ',
      );

      // The email is the repository's to trim; the password is never trimmed.
      expect(auth.calls, <String>[
        'register [Emir Rende]  ali@ornek.com  kalem739 ',
      ]);
      expect(analytics.events, <AnalyticsEvent>[
        AnalyticsEvent.signUp(method: 'password'),
      ]);
    });

    test('an address already in use is a failure with its code', () async {
      auth.error = FirebaseAuthException(code: 'email-already-in-use');

      await controller().submit(
        displayName: 'Emir',
        email: 'ali@ornek.com',
        password: 'kalem739',
      );

      expect(
        failureOf(container.read(registrationControllerProvider)).code,
        FailureCode.authEmailInUse,
      );
      expect(analytics.events, isEmpty);
    });

    test('is loading while it runs, and a second submit is ignored', () async {
      auth.hold = Completer<void>();

      final Future<void> first = controller().submit(
        displayName: 'Emir',
        email: 'ali@ornek.com',
        password: 'kalem739',
      );
      // What the auth guard waits for (AUTH.md).
      expect(container.read(registrationControllerProvider).isLoading, isTrue);
      await controller().submit(
        displayName: 'Emir',
        email: 'ali@ornek.com',
        password: 'kalem739',
      );

      auth.hold!.complete();
      await first;
      expect(auth.calls, hasLength(1));
      expect(container.read(registrationControllerProvider).isLoading, isFalse);
    });
  });

  group('asking for a reset link', () {
    setUp(() => keep(passwordResetControllerProvider));

    PasswordResetController controller() =>
        container.read(passwordResetControllerProvider.notifier);

    AsyncValue<bool> state() => container.read(passwordResetControllerProvider);

    test('nothing is asked for at first, then a link was', () async {
      expect(state().value, isFalse);

      await controller().submit(email: 'ali@ornek.com');

      expect(auth.calls, <String>['reset ali@ornek.com']);
      expect(state().value, isTrue);
    });

    test('an address with no account gets the same answer as one with',
        () async {
      auth.error = FirebaseAuthException(code: 'user-not-found');

      await controller().submit(email: 'kimse@ornek.com');

      expect(state().hasError, isFalse);
      expect(state().value, isTrue);
    });

    test('other failures are failures', () async {
      for (final (String code, String failure) in <(String, String)>[
        ('network-request-failed', FailureCode.networkOffline),
        ('too-many-requests', FailureCode.authTooManyRequests),
        ('invalid-email', FailureCode.authInvalidEmail),
      ]) {
        auth.error = FirebaseAuthException(code: code);

        await controller().submit(email: 'ali@ornek.com');

        expect(state().hasError, isTrue, reason: code);
        expect(failureOf(state()).code, failure, reason: code);
      }
    });

    test(
        'is loading while it runs, a second submit is ignored, and it can '
        'be asked again once done', () async {
      auth.hold = Completer<void>();

      final Future<void> first = controller().submit(email: 'ali@ornek.com');
      expect(state().isLoading, isTrue);
      await controller().submit(email: 'ali@ornek.com');
      auth.hold!.complete();
      await first;
      expect(auth.calls, hasLength(1));

      auth.hold = null;
      await controller().submit(email: 'ali@ornek.com');
      expect(auth.calls, hasLength(2));
      expect(state().value, isTrue);
    });
  });
}
