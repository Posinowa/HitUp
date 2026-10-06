import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/app.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/auth/presentation/auth_header.dart';
import 'package:hitup/features/auth/presentation/forgot_password_screen.dart';
import 'package:hitup/features/auth/presentation/login_screen.dart';
import 'package:hitup/features/auth/presentation/registration_screen.dart';
import 'package:hitup/features/onboarding/data/onboarding_store.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/startup_providers.dart';

import '../../../support/fake_auth_repository.dart';

class _Onboarded implements OnboardingStore {
  @override
  Future<bool> isComplete() async => true;

  @override
  Future<void> markComplete() async {}
}

/// The account screens at the phone sizes the exercise screen is checked at,
/// with the app's own fonts and with text enlarged, as someone with large
/// text set on their phone sees them. An overflow fails the test.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The app's fonts, not the test font, whose square glyphs are far wider
    // than real text: what fits here fits on a phone.
    for (final (String family, List<String> weights)
        in const <(String, List<String>)>[
      ('Manrope', <String>['Medium', 'Bold', 'ExtraBold']),
      ('PlusJakartaSans', <String>['Regular', 'Medium', 'SemiBold', 'Bold']),
    ]) {
      final FontLoader loader = FontLoader(family);
      for (final String weight in weights) {
        loader.addFont(
          rootBundle.load('assets/fonts/$family/$family-$weight.ttf'),
        );
      }
      await loader.load();
    }
  });

  const List<Size> phones = <Size>[
    Size(390, 844),
    Size(360, 640),
    Size(320, 568),
  ];
  const List<double> scales = <double>[1, 1.3];

  /// The app on a phone of [size], with a status bar, text at [scale],
  /// signed out: the login screen.
  Future<void> open(WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 24 * 3);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onboardingStoreProvider.overrideWithValue(_Onboarded()),
          authStateChangesProvider.overrideWith(
            (Ref ref) => Stream<AuthUser?>.value(null),
          ),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const HitUpApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  }

  for (final Size phone in phones) {
    for (final double scale in scales) {
      final String at = '${phone.width.toInt()}x${phone.height.toInt()}, '
          'text x$scale';

      testWidgets('login fits at $at', (WidgetTester tester) async {
        await open(tester, phone, scale);
        expect(tester.takeException(), isNull);
      });

      testWidgets('registration fits at $at', (WidgetTester tester) async {
        await open(tester, phone, scale);
        await tapInView(tester, find.text('Kayıt ol'));
        await tester.pumpAndSettle();

        expect(find.byType(RegistrationScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('forgot password fits, asked and sent, at $at',
          (WidgetTester tester) async {
        await open(tester, phone, scale);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'E-posta'),
          'uzun.bir.adres.ornegi@ornek-alan-adi.com.tr',
        );
        await tapInView(tester, find.text('Şifremi unuttum'));
        await tester.pumpAndSettle();
        expect(find.byType(ForgotPasswordScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Bağlantı gönder'),
        );
        await tester
            .tap(find.widgetWithText(ElevatedButton, 'Bağlantı gönder'));
        await tester.pumpAndSettle();
        expect(find.text('E-postanızı kontrol edin'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'on a common phone the whole login is in view, the button included, '
      'without scrolling', (WidgetTester tester) async {
    for (final Size phone in <Size>[
      const Size(390, 844),
      const Size(360, 640),
    ]) {
      await open(tester, phone, 1);

      expect(
        find.widgetWithText(ElevatedButton, 'Giriş yap').hitTestable(),
        findsOneWidget,
        reason: '$phone',
      );
      expect(find.text('Kayıt ol').hitTestable(), findsOneWidget);
    }
  });

  testWidgets(
      'the header grows with the screen within its limits, under the '
      'status bar', (WidgetTester tester) async {
    for (final (Size phone, double expected) in <(Size, double)>[
      // 36% of 844 is past the tallest header.
      (const Size(390, 844), AuthHeader.maxHeight),
      (const Size(360, 640), 640 * AuthHeader.share),
      // 36% of 460 is under the shortest.
      (const Size(320, 460), AuthHeader.minHeight),
    ]) {
      await open(tester, phone, 1);

      expect(
        tester.getSize(find.byType(AuthHeader)).height,
        closeTo(24 + expected, 0.01),
        reason: '$phone',
      );
      expect(tester.getTopLeft(find.byType(AuthHeader)).dy, 0);
    }
  });
}

/// Scrolls [target] into view, as a user would, then taps it.
Future<void> tapInView(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
}
