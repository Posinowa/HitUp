import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/app.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_messages.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/auth/presentation/auth_form_parts.dart';
import 'package:hitup/features/auth/presentation/auth_labels.dart';
import 'package:hitup/features/auth/presentation/forgot_password_screen.dart';
import 'package:hitup/features/auth/presentation/login_screen.dart';
import 'package:hitup/features/auth/presentation/registration_screen.dart';
import 'package:hitup/features/onboarding/data/onboarding_store.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/startup_providers.dart';

import '../../../support/fake_auth_repository.dart';

// Expected copy is written out, not asked of the labels, so a wording change
// is a decision a test notices.

class _Onboarded implements OnboardingStore {
  @override
  Future<bool> isComplete() async => true;

  @override
  Future<void> markComplete() async {}
}

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());

  /// The whole app on a 390 by 844 phone, signed out, which opens on the
  /// login screen.
  Future<void> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onboardingStoreProvider.overrideWithValue(_Onboarded()),
          authStateChangesProvider.overrideWith(
            (Ref ref) => Stream<AuthUser?>.value(null),
          ),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: const HitUpApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> type(WidgetTester tester, String label, String text) =>
      tester.enterText(field(label), text);

  Future<void> press(WidgetTester tester, String label) async {
    await tapInView(tester, find.widgetWithText(ElevatedButton, label));
    await tester.pumpAndSettle();
  }

  EditableText editable(WidgetTester tester, String label) =>
      tester.widget<EditableText>(
        find.descendant(of: field(label), matching: find.byType(EditableText)),
      );

  /// What the password manager was told about the form, in order: true to
  /// save what was typed, false to forget it.
  List<Object?> autofillEnds(WidgetTester tester) => <Object?>[
        for (final MethodCall call in tester.testTextInput.log)
          if (call.method == 'TextInput.finishAutofillContext') call.arguments,
      ];

  bool pressable(WidgetTester tester, String label) =>
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, label).first,
          )
          .onPressed !=
      null;

  group('logging in', () {
    testWidgets('sends nothing until both fields are right',
        (WidgetTester tester) async {
      await openApp(tester);

      await press(tester, 'Giriş yap');
      expect(find.text('Bu alan boş bırakılamaz.'), findsNWidgets(2));

      await type(tester, 'E-posta', 'ali@ornek');
      await tester.pump();
      // Checked as it is edited once a submit was tried.
      expect(find.text('E-posta adresi geçerli görünmüyor.'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets(
        'signs in with any password that was typed, closes the button while '
        'it works, then opens the app', (WidgetTester tester) async {
      await openApp(tester);
      auth.hold = Completer<void>();

      await type(tester, 'E-posta', ' ali@ornek.com ');
      await type(tester, 'Şifre', 'abc123');
      await tapInView(tester, find.widgetWithText(ElevatedButton, 'Giriş yap'));
      await tester.pump();

      expect(find.bySemanticsLabel('Giriş yapılıyor'), findsOneWidget);
      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(editable(tester, 'E-posta').readOnly, isTrue);

      auth.hold!.complete();
      await tester.pumpAndSettle();

      expect(auth.calls, <String>['signIn  ali@ornek.com  abc123']);
      expect(find.text('Bugünün antrenmanı'), findsOneWidget);
    });

    testWidgets('a refused password stays here and says so, with no retry',
        (WidgetTester tester) async {
      await openApp(tester);
      auth.error = FirebaseAuthException(code: 'wrong-password');

      await type(tester, 'E-posta', 'ali@ornek.com');
      await type(tester, 'Şifre', 'yanlis-sifre');
      await press(tester, 'Giriş yap');

      expect(
        find.text(failureMessagesTr[FailureCode.authInvalidCredentials]!),
        findsOneWidget,
      );
      expect(find.byType(SnackBarAction), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(pressable(tester, 'Giriş yap'), isTrue);
    });

    testWidgets('a dropped connection offers to try again, which does',
        (WidgetTester tester) async {
      await openApp(tester);
      auth.error = FirebaseAuthException(code: 'network-request-failed');

      await type(tester, 'E-posta', 'ali@ornek.com');
      await type(tester, 'Şifre', 'abc123');
      await press(tester, 'Giriş yap');
      expect(find.byType(SnackBarAction), findsOneWidget);

      auth.error = null;
      await tapInView(tester, find.text('Tekrar dene'));
      await tester.pumpAndSettle();

      expect(auth.calls, hasLength(2));
      expect(find.text('Bugünün antrenmanı'), findsOneWidget);
    });

    testWidgets('only a sign-in that worked is offered for saving',
        (WidgetTester tester) async {
      await openApp(tester);
      auth.error = FirebaseAuthException(code: 'wrong-password');
      await type(tester, 'E-posta', 'ali@ornek.com');
      await type(tester, 'Şifre', 'yanlis-sifre');
      await press(tester, 'Giriş yap');
      expect(autofillEnds(tester), isNot(contains(true)));

      auth.error = null;
      await type(tester, 'Şifre', 'dogru-sifre');
      await press(tester, 'Giriş yap');
      expect(autofillEnds(tester), contains(true));
    });

    testWidgets('the password can be shown and hidden again',
        (WidgetTester tester) async {
      await openApp(tester);

      expect(editable(tester, 'Şifre').obscureText, isTrue);
      await tapInView(tester, find.byTooltip('Şifreyi göster'));
      await tester.pump();
      expect(editable(tester, 'Şifre').obscureText, isFalse);
      await tapInView(tester, find.byTooltip('Şifreyi gizle'));
      await tester.pump();
      expect(editable(tester, 'Şifre').obscureText, isTrue);
    });

    testWidgets('autofill knows an address and an existing password',
        (WidgetTester tester) async {
      await openApp(tester);

      expect(
        editable(tester, 'E-posta').autofillHints,
        <String>[AutofillHints.email],
      );
      expect(
        editable(tester, 'Şifre').autofillHints,
        <String>[AutofillHints.password],
      );
    });

    testWidgets('the forgot link takes the address along',
        (WidgetTester tester) async {
      await openApp(tester);

      await type(tester, 'E-posta', ' ali@ornek.com ');
      await tapInView(tester, find.text('Şifremi unuttum'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(editable(tester, 'E-posta').controller.text, 'ali@ornek.com');
    });
  });

  group('registering', () {
    Future<void> openRegistration(WidgetTester tester) async {
      await openApp(tester);
      await tapInView(tester, find.text('Kayıt ol'));
      await tester.pumpAndSettle();
      expect(find.byType(RegistrationScreen), findsOneWidget);
    }

    Future<void> fill(
      WidgetTester tester, {
      String name = 'Emir',
      String email = 'emir@ornek.com',
      String password = 'kirmizi kalem',
      String? repetition,
    }) async {
      await type(tester, 'Adınız', name);
      await type(tester, 'E-posta', email);
      await type(tester, 'Şifre', password);
      await type(tester, 'Şifre (tekrar)', repetition ?? password);
    }

    testWidgets('every field is required', (WidgetTester tester) async {
      await openRegistration(tester);

      await press(tester, 'Hesap oluştur');

      expect(find.text('Bu alan boş bırakılamaz.'), findsNWidgets(4));
      expect(auth.calls, isEmpty);
    });

    testWidgets('says what the new password needs, and shows it on each',
        (WidgetTester tester) async {
      await openRegistration(tester);
      expect(
        find.text('En az 8 karakter. Uzun bir cümle de olur.'),
        findsOneWidget,
      );

      // An address that shares nothing with the name, so only the name can
      // make the password below a guess.
      await fill(tester, email: 'ali@ornek.com', password: 'kalem73');
      await press(tester, 'Hesap oluştur');
      expect(find.text('Şifre en az 8 karakter olmalı.'), findsOneWidget);

      // The name typed above is a guess about this account.
      await type(tester, 'Şifre', 'Emir2026!');
      await type(tester, 'Şifre (tekrar)', 'Emir2026!');
      await tester.pump();
      expect(
        find.text(AuthFieldLabelsTr.passwordTooCommon),
        findsOneWidget,
      );

      await type(tester, 'Şifre', 'kirmizi kalem');
      await type(tester, 'Şifre (tekrar)', 'kirmizi kale');
      await tester.pump();
      expect(find.text('Şifreler birbirini tutmuyor.'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('creates the account with the name trimmed, then opens the app',
        (WidgetTester tester) async {
      await openRegistration(tester);

      await fill(tester, name: '  Emir Rende ');
      await press(tester, 'Hesap oluştur');

      expect(auth.calls, <String>[
        'register [Emir Rende] emir@ornek.com kirmizi kalem',
      ]);
      expect(find.text('Bugünün antrenmanı'), findsOneWidget);
    });

    testWidgets('an address already in use says so, and stays here',
        (WidgetTester tester) async {
      await openRegistration(tester);
      auth.error = FirebaseAuthException(code: 'email-already-in-use');

      await fill(tester);
      await press(tester, 'Hesap oluştur');

      expect(
        find.text(failureMessagesTr[FailureCode.authEmailInUse]!),
        findsOneWidget,
      );
      expect(find.byType(RegistrationScreen), findsOneWidget);
    });

    testWidgets('an account that was refused, then left, is not saved',
        (WidgetTester tester) async {
      await openRegistration(tester);
      auth.error = FirebaseAuthException(code: 'email-already-in-use');
      await fill(tester);
      await press(tester, 'Hesap oluştur');
      // The snack bar sits over the link until it goes.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tapInView(tester, find.widgetWithText(TextButton, 'Giriş yap'));
      await tester.pumpAndSettle();

      expect(find.byType(RegistrationScreen), findsNothing);
      expect(autofillEnds(tester), isNot(contains(true)));
      expect(autofillEnds(tester), contains(false));
    });

    testWidgets('an account that was made is offered for saving',
        (WidgetTester tester) async {
      await openRegistration(tester);
      await fill(tester);
      await press(tester, 'Hesap oluştur');

      expect(autofillEnds(tester), contains(true));
    });

    testWidgets('autofill knows both passwords are the new one',
        (WidgetTester tester) async {
      await openRegistration(tester);

      for (final String label in <String>['Şifre', 'Şifre (tekrar)']) {
        expect(
          editable(tester, label).autofillHints,
          <String>[AutofillHints.newPassword],
          reason: label,
        );
      }
      expect(
        editable(tester, 'Adınız').autofillHints,
        <String>[AutofillHints.name],
      );
    });

    testWidgets('its login link goes back to login',
        (WidgetTester tester) async {
      await openRegistration(tester);

      await tapInView(tester, find.widgetWithText(TextButton, 'Giriş yap'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(RegistrationScreen), findsNothing);
    });
  });

  group('asking for a new password', () {
    Future<void> openForgot(WidgetTester tester, {String email = ''}) async {
      await openApp(tester);
      await type(tester, 'E-posta', email);
      await tapInView(tester, find.text('Şifremi unuttum'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    }

    testWidgets('sends nothing for an address that is not one',
        (WidgetTester tester) async {
      await openForgot(tester);

      await press(tester, 'Bağlantı gönder');
      expect(find.text('Bu alan boş bırakılamaz.'), findsOneWidget);

      await type(tester, 'E-posta', 'ali@ornek');
      await tester.pump();
      expect(find.text('E-posta adresi geçerli görünmüyor.'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('says where the link went, in words for any address',
        (WidgetTester tester) async {
      await openForgot(tester, email: 'ali@ornek.com');

      await press(tester, 'Bağlantı gönder');

      expect(auth.calls, <String>['reset ali@ornek.com']);
      expect(find.text('E-postanızı kontrol edin'), findsOneWidget);
      expect(
        find.text(
          'ali@ornek.com adresine kayıtlı bir hesap varsa, şifre yenileme '
          'bağlantısı birkaç dakika içinde gelir. Gelmezse istenmeyen '
          'e-postalar klasörüne de bakın.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an address with no account reads exactly the same',
        (WidgetTester tester) async {
      await openForgot(tester, email: 'kimse@ornek.com');
      auth.error = FirebaseAuthException(code: 'user-not-found');

      await press(tester, 'Bağlantı gönder');

      expect(find.text('E-postanızı kontrol edin'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a dropped connection stays on the form and offers a retry',
        (WidgetTester tester) async {
      await openForgot(tester, email: 'ali@ornek.com');
      auth.error = FirebaseAuthException(code: 'network-request-failed');

      await press(tester, 'Bağlantı gönder');

      expect(find.byType(SnackBarAction), findsOneWidget);
      expect(find.text('E-postanızı kontrol edin'), findsNothing);
    });

    testWidgets('the link can be asked for again, then back to login',
        (WidgetTester tester) async {
      await openForgot(tester, email: 'ali@ornek.com');
      await press(tester, 'Bağlantı gönder');

      await tapInView(tester, find.text('Tekrar gönder'));
      await tester.pumpAndSettle();
      expect(auth.calls, <String>[
        'reset ali@ornek.com',
        'reset ali@ornek.com',
      ]);

      await press(tester, 'Girişe dön');
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  testWidgets('the shared parts name their controls for a screen reader',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await openApp(tester);

    expect(find.bySemanticsLabel('Tekrar hoş geldiniz'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Tekrar hoş geldiniz')),
      matchesSemantics(isHeader: true, label: 'Tekrar hoş geldiniz'),
    );
    expect(find.byTooltip(AuthCommonLabelsTr.showPassword), findsOneWidget);
    semantics.dispose();
  });
}

/// Scrolls [target] into view, as a user would, then taps it.
Future<void> tapInView(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
}
