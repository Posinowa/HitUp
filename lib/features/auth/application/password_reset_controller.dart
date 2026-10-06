import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/failure_code.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../shared/providers/auth_providers.dart';
import '../domain/repositories/auth_repository.dart';

/// Asks for a password reset email from the forgot-password screen (HIT-019).
///
/// The state is whether a link was asked for: false, then true once it was,
/// loading while it runs, or the `Failure` it ended in. It can be asked again,
/// for a link that did not arrive.
///
/// **An address with no account gets the same answer as one with.** Firebase
/// sends nothing then, and says so only where email enumeration protection is
/// off; with it on, the default for projects made since September 2023, it
/// answers the same either way. The screen's words are the same in both cases
/// ("if an account has this address"), so which addresses have an account
/// cannot be learned here, as it cannot at sign in (`AUTH.md`).
class PasswordResetController extends AutoDisposeAsyncNotifier<bool> {
  @override
  FutureOr<bool> build() => false;

  /// Asks for a reset link for [email].
  Future<void> submit({required String email}) async {
    if (state.isLoading) {
      return;
    }
    final AuthRepository auth = ref.read(authRepositoryProvider);

    state = const AsyncValue<bool>.loading();
    try {
      await auth.sendPasswordResetEmail(email: email);
      state = const AsyncValue<bool>.data(true);
    } catch (error, stackTrace) {
      final Failure failure = mapErrorToFailure(error);
      // No account has the address: answered as if one did.
      state = failure.code == FailureCode.authInvalidCredentials
          ? const AsyncValue<bool>.data(true)
          : AsyncValue<bool>.error(failure, stackTrace);
    }
  }
}

/// The forgot-password screen's request, gone with the screen.
final AutoDisposeAsyncNotifierProvider<PasswordResetController, bool>
    passwordResetControllerProvider =
    AsyncNotifierProvider.autoDispose<PasswordResetController, bool>(
  PasswordResetController.new,
);
