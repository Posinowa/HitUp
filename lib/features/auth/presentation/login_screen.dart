import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/failure_presenter.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_form_rules.dart';
import '../application/sign_in_controller.dart';
import 'auth_form_parts.dart';
import 'auth_labels.dart';

/// The login screen's copy.
abstract final class LoginLabelsTr {
  /// The heading.
  static const String title = 'Tekrar hoş geldiniz';

  /// The line under it.
  static const String subtitle = 'Günlük antrenmanınız sizi bekliyor.';

  /// The link to the forgot-password screen.
  static const String forgotPassword = 'Şifremi unuttum';

  /// The button.
  static const String submit = 'Giriş yap';

  /// What the button says to a screen reader while it works.
  static const String submitting = 'Giriş yapılıyor';

  /// The question before the link to registration.
  static const String noAccount = 'Hesabınız yok mu?';

  /// The link to registration.
  static const String register = 'Kayıt ol';
}

/// Signs a returning user in with email and password (HIT-018).
///
/// The fields are checked on the device first (`AuthFormRules`): an address
/// shaped like one and a password that was typed, whatever its length, since
/// an account may predate the rules for new ones. What Firebase refuses comes
/// back as a failure in a snack bar, with a retry only where one could help
/// (`ERROR_HANDLING.md`). A wrong password and an unknown address read the
/// same, as `AUTH.md` requires.
///
/// Once signed in, the password manager is told to save what was typed and
/// the app opens. A failed attempt is not offered for saving, even when the
/// screen is left.
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  /// Off until the first submit, so nothing is marked wrong before the user
  /// has tried; after it, each field is checked as it is edited.
  AutovalidateMode _check = AutovalidateMode.disabled;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      setState(() => _check = AutovalidateMode.onUserInteraction);
      return;
    }
    await ref
        .read(signInControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(signInControllerProvider, (
      AsyncValue<void>? previous,
      AsyncValue<void> next,
    ) {
      // Only the end of an attempt: the first build and a new attempt are
      // not news.
      if (!(previous?.isLoading ?? false) || next.isLoading) {
        return;
      }
      final Object? error = next.error;
      if (error is Failure) {
        showFailureSnackBar(context, error, onRetry: _submit);
        return;
      }
      TextInput.finishAutofillContext();
      context.go(RouteNames.home);
    });
    final bool busy = ref.watch(signInControllerProvider).isLoading;

    return AuthPage(
      title: LoginLabelsTr.title,
      subtitle: LoginLabelsTr.subtitle,
      children: <Widget>[
        AutofillGroup(
          onDisposeAction: AutofillContextAction.cancel,
          child: Form(
            key: _form,
            autovalidateMode: _check,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AuthEmailField(
                  controller: _email,
                  enabled: !busy,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  validator: (String? value) =>
                      AuthFieldLabelsTr.of(AuthFormRules.email(value ?? '')),
                ),
                const SizedBox(height: AppSpacing.md),
                AuthPasswordField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  enabled: !busy,
                  label: AuthCommonLabelsTr.password,
                  autofillHints: const <String>[AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  validator: (String? value) => AuthFieldLabelsTr.of(
                    AuthFormRules.signInPassword(value ?? ''),
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: busy
                ? null
                : () => context.push(
                      RouteNames.forgotPassword,
                      extra: _email.text.trim(),
                    ),
            child: const Text(LoginLabelsTr.forgotPassword),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AuthSubmitButton(
          label: LoginLabelsTr.submit,
          busyLabel: LoginLabelsTr.submitting,
          busy: busy,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.md),
        AuthLinkRow(
          prompt: LoginLabelsTr.noAccount,
          action: LoginLabelsTr.register,
          onPressed: busy ? null : () => context.push(RouteNames.register),
        ),
      ],
    );
  }
}
