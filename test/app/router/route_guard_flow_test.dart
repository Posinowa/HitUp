import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/app.dart';
import 'package:hitup/app/shell/main_shell.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/auth/presentation/forgot_password_screen.dart';
import 'package:hitup/features/auth/presentation/login_screen.dart';
import 'package:hitup/features/auth/presentation/registration_screen.dart';
import 'package:hitup/features/onboarding/data/onboarding_store.dart';
import 'package:hitup/features/training/application/finished_day_recorder.dart';
import 'package:hitup/features/training/data/pending_day_store.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/startup_providers.dart';

import '../../support/fake_auth_repository.dart';

class _Onboarded implements OnboardingStore {
  @override
  Future<bool> isComplete() async => true;

  @override
  Future<void> markComplete() async {}
}

class _NothingPending implements PendingDayStore {
  @override
  Future<List<PendingDay>> load() async => const <PendingDay>[];

  @override
  Future<void> add(PendingDay day) async {}

  @override
  Future<void> remove(PendingDay day) async {}
}

/// The router follows the account from wherever the user is (HIT-020).
void main() {
  late StreamController<AuthUser?> account;

  setUp(() => account = StreamController<AuthUser?>.broadcast());
  tearDown(() => account.close());

  /// The app on a phone, with the account under the test's control, starting
  /// as [first].
  Future<void> open(WidgetTester tester, AuthUser? first) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onboardingStoreProvider.overrideWithValue(_Onboarded()),
          authStateChangesProvider.overrideWith((Ref ref) async* {
            yield first;
            yield* account.stream;
          }),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          pendingDayStoreProvider.overrideWithValue(_NothingPending()),
        ],
        child: const HitUpApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> become(WidgetTester tester, AuthUser? user) async {
    account.add(user);
    await tester.pumpAndSettle();
  }

  testWidgets('signing out, from inside the app, leads to login',
      (WidgetTester tester) async {
    await open(tester, const AuthUser(uid: 'uid-1'));
    expect(find.byType(MainShell), findsOneWidget);

    await become(tester, null);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
  });

  testWidgets('signing out from another tab leads to login as well',
      (WidgetTester tester) async {
    await open(tester, const AuthUser(uid: 'uid-1'));
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    await become(tester, null);

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('signing in, wherever it came from, leads home from login',
      (WidgetTester tester) async {
    await open(tester, null);
    expect(find.byType(LoginScreen), findsOneWidget);

    await become(tester, const AuthUser(uid: 'uid-1'));

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.text('Bugünün antrenmanı'), findsOneWidget);
  });

  testWidgets('the forgot-password screen leads home once signed in',
      (WidgetTester tester) async {
    await open(tester, null);
    await tester.tap(find.text('Şifremi unuttum'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);

    await become(tester, const AuthUser(uid: 'uid-1'));

    expect(find.byType(MainShell), findsOneWidget);
  });

  testWidgets(
      'registration is not taken away when its account signs in before its '
      'documents are written', (WidgetTester tester) async {
    await open(tester, null);
    await tester.ensureVisible(find.text('Kayıt ol'));
    await tester.tap(find.text('Kayıt ol'));
    await tester.pumpAndSettle();

    await become(tester, const AuthUser(uid: 'uid-1'));

    expect(find.byType(RegistrationScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
  });

  testWidgets('the account coming and going leaves login as it is',
      (WidgetTester tester) async {
    await open(tester, null);

    await become(tester, null);

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
