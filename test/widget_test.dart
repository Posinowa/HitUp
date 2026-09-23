import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/app.dart';
import 'package:hitup/core/theme/app_theme.dart';
import 'package:hitup/core/widgets/damga_mark.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/onboarding/data/onboarding_store.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/startup_providers.dart';

/// An onboarding flag that answers only when the test lets it, so the app can
/// be looked at while it is still on the splash.
class _HeldOnboardingStore implements OnboardingStore {
  final Completer<bool> _answer = Completer<bool>();

  void answer({required bool complete}) => _answer.complete(complete);

  @override
  Future<bool> isComplete() => _answer.future;

  @override
  Future<void> markComplete() async {}
}

void main() {
  testWidgets('the app builds and opens on the splash', (
    WidgetTester tester,
  ) async {
    // The two answers startup waits for are overridden here, because the real
    // ones reach a preferences channel and Firebase, neither of which exists
    // under `flutter test`. Where the app goes next is `test/app/startup`.
    final _HeldOnboardingStore onboarding = _HeldOnboardingStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onboardingStoreProvider.overrideWithValue(onboarding),
          authStateChangesProvider.overrideWith(
            (Ref ref) => const Stream<AuthUser?>.empty(),
          ),
        ],
        child: const HitUpApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(DamgaMark), findsOneWidget);
    expect(find.text('HitUp'), findsOneWidget);

    // Answered before the test ends, so the deadline timer does not outlive
    // it: a pending timer is a failure in itself, and a real one for an app
    // that would keep waiting after the screen is gone.
    onboarding.answer(complete: false);
    await tester.pumpAndSettle();
  });

  test('AppTheme.light provides Material 3 ColorScheme', () {
    final ThemeData theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, isNotNull);
  });
}
