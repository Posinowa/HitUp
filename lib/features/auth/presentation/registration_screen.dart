import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/failure_presenter.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_form_rules.dart';
import '../application/registration_controller.dart';
import 'auth_form_parts.dart';
import 'auth_labels.dart';

/// The registration screen's copy.
abstract final class RegistrationLabelsTr {
  /// The heading.
  static const String title = 'Hesap oluştur';

  /// The line under it.
  static const String subtitle = 'Birkaç bilgi, sonra ilk antrenmanınız.';

  /// The name field.
  static const String name = 'Adınız';

  /// The rule a new password follows, under its field.
  static const String passwordHelp =
      'En az ${AuthFormRules.minPasswordLength} karakter. '
      'Uzun bir cümle de olur.';

  /// The field for the password typed again.
  static const String passwordRepetition = 'Şifre (tekrar)';

  /// The button.
  static const String submit = 'Hesap oluştur';

  /// What the button says to a screen reader while it works.
  static const String submitting = 'Hesap oluşturuluyor';

  /// The question before the link back to login.
  static const String haveAccount = 'Zaten hesabınız var mı?';

  /// The link back to login.
  static const String login = 'Giriş yap';
}

/// Creates an account with a name, an email and a password (HIT-017).
///
/// Every field is required and checked on the device first
/// (`AuthFormRules`): the name within the limit the security rules set, an
/// address shaped like one, a new password of at least eight characters that
/// is not an easy guess, which includes the name and the address being typed,
/// and the same password again. What Firebase refuses, an address already in
/// use for one, comes back as a failure in a snack bar.
///
/// Once the account exists the password manager is told to save it and the
/// app opens. While the account is being made the controller is loading,
/// which is what the auth guard (HIT-020) waits for (`AUTH.md`).
class RegistrationScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _repetition = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _repetitionFocus = FocusNode();
  AutovalidateMode _check = AutovalidateMode.disabled;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _repetition.dispose();
    _passwordFocus.dispose();
    _repetitionFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      setState(() => _check = AutovalidateMode.onUserInteraction);
      return;
    }
    await ref.read(registrationControllerProvider.notifier).submit(
          displayName: _name.text,
          email: _email.text,
          password: _password.text,
        );
  }

  void _toLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(registrationControllerProvider, (
      AsyncValue<void>? previous,
      AsyncValue<void> next,
    ) {
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
    final bool busy = ref.watch(registrationControllerProvider).isLoading;

    return AuthPage(
      title: RegistrationLabelsTr.title,
      subtitle: RegistrationLabelsTr.subtitle,
      children: <Widget>[
        AutofillGroup(
          onDisposeAction: AutofillContextAction.cancel,
          child: Form(
            key: _form,
            autovalidateMode: _check,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _name,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    labelText: RegistrationLabelsTr.name,
                  ),
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const <String>[AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  validator: (String? value) => AuthFieldLabelsTr.of(
                    AuthFormRules.displayName(value ?? ''),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
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
                  helperText: RegistrationLabelsTr.passwordHelp,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _repetitionFocus.requestFocus(),
                  validator: (String? value) => AuthFieldLabelsTr.of(
                    AuthFormRules.newPassword(
                      value ?? '',
                      email: _email.text,
                      name: _name.text,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AuthPasswordField(
                  controller: _repetition,
                  focusNode: _repetitionFocus,
                  enabled: !busy,
                  label: RegistrationLabelsTr.passwordRepetition,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  onFieldSubmitted: (_) => _submit(),
                  validator: (String? value) => AuthFieldLabelsTr.of(
                    AuthFormRules.passwordRepetition(
                      _password.text,
                      value ?? '',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AuthSubmitButton(
          label: RegistrationLabelsTr.submit,
          busyLabel: RegistrationLabelsTr.submitting,
          busy: busy,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.md),
        AuthLinkRow(
          prompt: RegistrationLabelsTr.haveAccount,
          action: RegistrationLabelsTr.login,
          onPressed: busy ? null : _toLogin,
        ),
      ],
    );
  }
}
