import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../shared/providers/analytics_providers.dart';
import '../../../shared/providers/auth_providers.dart';
import '../domain/repositories/auth_repository.dart';

/// The sign-in method analytics names (`ANALYTICS.md`): Firebase's own id for
/// email and password.
const String passwordSignInMethod = 'password';

/// Signs in from the login screen (HIT-018).
///
/// The state is where the attempt is, as `ERROR_HANDLING.md` describes: data
/// before and after, loading while it runs, and the `Failure` it ended in.
/// Where the app goes next is the auth state's business, not this one's.
///
/// A second submit while one runs is ignored, which is what a disabled button
/// promises and what a double tap would otherwise break.
class SignInController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Signs in with [email] and [password].
  Future<void> submit({required String email, required String password}) async {
    if (state.isLoading) {
      return;
    }
    // Read before the first await: the screen, and this controller with it,
    // may be gone by the time the answer comes.
    final AuthRepository auth = ref.read(authRepositoryProvider);
    final AnalyticsService analytics = ref.read(analyticsServiceProvider);

    state = const AsyncValue<void>.loading();
    try {
      await auth.signIn(email: email, password: password);
      unawaited(
        analytics.log(AnalyticsEvent.login(method: passwordSignInMethod)),
      );
      state = const AsyncValue<void>.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue<void>.error(mapErrorToFailure(error), stackTrace);
    }
  }
}

/// The login screen's sign-in, gone with the screen.
final AutoDisposeAsyncNotifierProvider<SignInController, void>
    signInControllerProvider =
    AsyncNotifierProvider.autoDispose<SignInController, void>(
  SignInController.new,
);
