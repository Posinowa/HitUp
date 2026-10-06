import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/app.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/onboarding/data/onboarding_store.dart';
import 'package:hitup/features/onboarding/presentation/onboarding_screen.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/startup_providers.dart';

class _NewDevice implements OnboardingStore {
  @override
  Future<bool> isComplete() async => false;

  @override
  Future<void> markComplete() async {}
}

/// Onboarding at the phone sizes the other screens are checked at, with the
/// app's own fonts and with text enlarged. An overflow fails the test.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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

  for (final Size phone in const <Size>[
    Size(390, 844),
    Size(360, 640),
    Size(320, 568),
  ]) {
    for (final double scale in const <double>[1, 1.3]) {
      testWidgets(
          'every page fits, with its buttons in view, at '
          '${phone.width.toInt()}x${phone.height.toInt()}, text x$scale',
          (WidgetTester tester) async {
        tester.view.physicalSize = phone * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = const FakeViewPadding(top: 24 * 3);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              onboardingStoreProvider.overrideWithValue(_NewDevice()),
              authStateChangesProvider.overrideWith(
                (Ref ref) => Stream<AuthUser?>.value(null),
              ),
            ],
            child: const HitUpApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingScreen), findsOneWidget);

        for (int page = 0; page < 5; page++) {
          expect(tester.takeException(), isNull, reason: 'page $page');
          // The way on is always in view, whatever the page scrolls.
          final String button = page < 4 ? 'İleri' : 'Başla';
          expect(
            find.widgetWithText(ElevatedButton, button).hitTestable(),
            findsOneWidget,
            reason: 'page $page',
          );
          // No words run past the screen's edges, which a cut-off label
          // does without any overflow being reported.
          for (final Element text in find
              .descendant(
                of: find.byType(OnboardingScreen),
                matching: find.byType(Text),
              )
              .evaluate()) {
            final Rect at = tester.getRect(
              find.byElementPredicate((Element e) => identical(e, text)),
            );
            expect(at.left, greaterThanOrEqualTo(-0.5), reason: '$text');
            expect(
              at.right,
              lessThanOrEqualTo(phone.width + 0.5),
              reason: '$text',
            );
          }
          if (page < 4) {
            await tester.tap(find.widgetWithText(ElevatedButton, button));
            await tester.pumpAndSettle();
          }
        }
      });
    }
  }
}
