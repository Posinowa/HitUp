import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../shared/providers/analytics_providers.dart';
import '../../../shared/providers/auth_providers.dart';
import '../domain/repositories/auth_repository.dart';
import 'sign_in_controller.dart';

/// Creates an account from the registration screen (HIT-017).
///
/// The same shape as [SignInController]: data, loading while it runs, or the
/// `Failure` it ended in, and a second submit while one runs is ignored.
///
/// **Loading is the registration in progress** that `AUTH.md` asks the auth
/// guard (HIT-020) to wait for: the account exists, and the auth state says
/// so, before its documents are written, and a rollback signs it out again.
///
/// The name is trimmed here, since the repository takes it as given. The
/// email is trimmed by the repository, and the password is used as typed.
class RegistrationController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Creates an account for [displayName] with [email] and [password].
  Future<void> submit({
    required String displayName,
    required String email,
    required String password,
  }) async {
    if (state.isLoading) {
      return;
    }
    final AuthRepository auth = ref.read(authRepositoryProvider);
    final AnalyticsService analytics = ref.read(analyticsServiceProvider);

    state = const AsyncValue<void>.loading();
    try {
      await auth.register(
        email: email,
        password: password,
        displayName: displayName.trim(),
      );
      unawaited(
        analytics.log(AnalyticsEvent.signUp(method: passwordSignInMethod)),
      );
      state = const AsyncValue<void>.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue<void>.error(mapErrorToFailure(error), stackTrace);
    }
  }
}

/// The registration screen's account creation, gone with the screen.
final AutoDisposeAsyncNotifierProvider<RegistrationController, void>
    registrationControllerProvider =
    AsyncNotifierProvider.autoDispose<RegistrationController, void>(
  RegistrationController.new,
);
