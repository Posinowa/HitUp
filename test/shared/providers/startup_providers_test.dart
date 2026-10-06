import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/startup/startup_destination.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/onboarding/data/onboarding_store.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/startup_providers.dart';

/// The onboarding flag, in memory.
class _Flag implements OnboardingStore {
  bool complete = false;

  @override
  Future<bool> isComplete() async => complete;

  @override
  Future<void> markComplete() async => complete = true;
}

void main() {
  // The router's redirect shows the splash while startup is loading, so a
  // change that went back to loading would flash the splash between two
  // screens (HIT-020).
  test(
      'once known, a finished onboarding, a sign-in and a sign-out each go '
      'straight to the next destination, never back to loading', () async {
    final _Flag flag = _Flag();
    final StreamController<AuthUser?> account =
        StreamController<AuthUser?>.broadcast();
    addTearDown(account.close);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        onboardingStoreProvider.overrideWithValue(flag),
        authStateChangesProvider.overrideWith((Ref ref) async* {
          yield null;
          yield* account.stream;
        }),
      ],
    );
    addTearDown(container.dispose);
    final List<AsyncValue<StartupDestination>> seen =
        <AsyncValue<StartupDestination>>[];
    container.listen<AsyncValue<StartupDestination>>(
      startupProvider,
      (_, AsyncValue<StartupDestination> next) => seen.add(next),
      fireImmediately: true,
    );
    await pumpEventQueue();
    expect(seen.last.value, StartupDestination.onboarding);

    // What finishing onboarding does: the flag is kept, then read again.
    flag.complete = true;
    container.invalidate(onboardingCompleteProvider);
    await pumpEventQueue();
    expect(seen.last.value, StartupDestination.auth);

    account.add(const AuthUser(uid: 'uid-1'));
    await pumpEventQueue();
    expect(seen.last.value, StartupDestination.home);

    account.add(null);
    await pumpEventQueue();
    expect(seen.last.value, StartupDestination.auth);

    expect(
      seen.skipWhile((AsyncValue<StartupDestination> v) => !v.hasValue),
      everyElement(
        isA<AsyncData<StartupDestination>>(),
      ),
    );
  });
}
