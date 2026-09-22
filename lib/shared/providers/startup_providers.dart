import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/startup/startup_destination.dart';
import '../../features/auth/domain/models/auth_user.dart';
import '../../features/onboarding/data/onboarding_store.dart';
import 'auth_providers.dart';

/// How long startup waits for an answer before giving up on it.
///
/// Nothing here is slow by nature: one preference read and the auth state the
/// Firebase SDK already holds. A wait longer than this is something stuck, and
/// a splash that waits forever is the failure users cannot do anything about.
/// The splash then offers to try again.
const Duration startupTimeout = Duration(seconds: 8);

/// Where the onboarding flag is kept.
final Provider<OnboardingStore> onboardingStoreProvider =
    Provider<OnboardingStore>((Ref ref) => const PreferencesOnboardingStore());

/// Whether onboarding has been completed on this device.
final FutureProvider<bool> onboardingCompleteProvider =
    FutureProvider<bool>((Ref ref) async {
  final OnboardingStore store = ref.watch(onboardingStoreProvider);
  return store.isComplete().timeout(startupTimeout);
});

/// Where the app should open (HIT-014).
///
/// Loading while either answer is still missing, an error when one of them
/// failed, and a destination once both are in. The splash reads this and
/// nothing else, so "what do we know" and "where does that lead" stay apart.
final Provider<AsyncValue<StartupDestination>> startupProvider =
    Provider<AsyncValue<StartupDestination>>((Ref ref) {
  final AsyncValue<bool> onboarding = ref.watch(onboardingCompleteProvider);
  final AsyncValue<AuthUser?> auth = ref.watch(authStateChangesProvider);

  // An error on either side is an error for startup: it cannot route on a
  // guess, and hiding it would leave the user on a splash that never moves.
  if (onboarding.hasError) {
    return AsyncValue<StartupDestination>.error(
      onboarding.error!,
      onboarding.stackTrace ?? StackTrace.current,
    );
  }
  if (auth.hasError) {
    return AsyncValue<StartupDestination>.error(
      auth.error!,
      auth.stackTrace ?? StackTrace.current,
    );
  }
  if (!onboarding.hasValue || !auth.hasValue) {
    return const AsyncValue<StartupDestination>.loading();
  }

  return AsyncValue<StartupDestination>.data(
    startupDestination(
      StartupInputs(
        onboardingComplete: onboarding.requireValue,
        signedIn: auth.requireValue != null,
      ),
    ),
  );
});

/// Something the router can listen to, so a resolved startup re-runs its
/// redirect.
///
/// `GoRouter` takes a [Listenable]; Riverpod hands out values. This is the one
/// line between them, and it holds no state of its own beyond a counter.
final Provider<Listenable> startupListenableProvider =
    Provider<Listenable>((Ref ref) {
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);
  ref.onDispose(notifier.dispose);
  ref.listen<AsyncValue<StartupDestination>>(
    startupProvider,
    (_, __) => notifier.value++,
  );
  return notifier;
});

/// Asks both questions again, which is what the splash's retry does.
void retryStartup(WidgetRef ref) {
  ref.invalidate(onboardingCompleteProvider);
  ref.invalidate(authStateChangesProvider);
}
