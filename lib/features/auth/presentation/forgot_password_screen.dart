import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/failure_presenter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_form_rules.dart';
import '../application/password_reset_controller.dart';
import 'auth_form_parts.dart';
import 'auth_labels.dart';

/// The forgot-password screen's copy.
abstract final class ForgotPasswordLabelsTr {
  /// The heading.
  static const String title = 'Şifrenizi mi unuttunuz?';

  /// The line under it.
  static const String subtitle =
      'E-posta adresinizi yazın, şifrenizi yenilemeniz için bir bağlantı '
      'gönderelim.';

  /// The button.
  static const String submit = 'Bağlantı gönder';

  /// What the button says to a screen reader while it works.
  static const String submitting = 'Bağlantı gönderiliyor';

  /// The heading once a link was asked for.
  static const String sentTitle = 'E-postanızı kontrol edin';

  /// What happens next, for [address]. The same whether an account has the
  /// address or not, so the screen cannot tell anyone which one it was.
  static String sentBody(String address) =>
      '$address adresine kayıtlı bir hesap varsa, şifre yenileme bağlantısı '
      'birkaç dakika içinde gelir. Gelmezse istenmeyen e-postalar klasörüne '
      'de bakın.';

  /// Asking again.
  static const String resend = 'Tekrar gönder';

  /// Back to the login screen.
  static const String backToLogin = 'Girişe dön';
}

/// Asks Firebase to email a password reset link (HIT-019).
///
/// The address typed on the login screen comes along, so it is not typed
/// twice. It is checked on the device for its shape, and once the link is
/// asked for the screen says where it went, in words that are the same
/// whether an account has the address or not (`PasswordResetController`).
/// It can be asked for again from there.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  /// Creates the screen, with [initialEmail] already in its field.
  const ForgotPasswordScreen({this.initialEmail = '', super.key});

  /// The address the login screen had.
  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  AutovalidateMode _check = AutovalidateMode.disabled;

  /// The address the link was asked for, once it was.
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      setState(() => _check = AutovalidateMode.onUserInteraction);
      return;
    }
    await _ask(_email.text.trim());
  }

  Future<void> _ask(String address) =>
      ref.read(passwordResetControllerProvider.notifier).submit(email: address);

  void _toLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(passwordResetControllerProvider, (
      AsyncValue<bool>? previous,
      AsyncValue<bool> next,
    ) {
      if (!(previous?.isLoading ?? false) || next.isLoading) {
        return;
      }
      final Object? error = next.error;
      if (error is Failure) {
        showFailureSnackBar(
          context,
          error,
          onRetry: _sentTo == null ? _submit : () => _ask(_sentTo!),
        );
        return;
      }
      if (next.valueOrNull ?? false) {
        setState(() => _sentTo ??= _email.text.trim());
      }
    });
    final bool busy = ref.watch(passwordResetControllerProvider).isLoading;
    final String? sentTo = _sentTo;

    if (sentTo != null) {
      return AuthPage(
        title: ForgotPasswordLabelsTr.sentTitle,
        subtitle: ForgotPasswordLabelsTr.sentBody(sentTo),
        children: <Widget>[
          AuthSubmitButton(
            label: ForgotPasswordLabelsTr.backToLogin,
            busyLabel: ForgotPasswordLabelsTr.submitting,
            busy: false,
            onPressed: _toLogin,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: busy ? null : () => _ask(sentTo),
            child: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: ForgotPasswordLabelsTr.submitting,
                    ),
                  )
                : const Text(ForgotPasswordLabelsTr.resend),
          ),
        ],
      );
    }

    return AuthPage(
      title: ForgotPasswordLabelsTr.title,
      subtitle: ForgotPasswordLabelsTr.subtitle,
      children: <Widget>[
        Form(
          key: _form,
          autovalidateMode: _check,
          child: AuthEmailField(
            controller: _email,
            enabled: !busy,
            textInputAction: TextInputAction.send,
            onFieldSubmitted: (_) => _submit(),
            validator: (String? value) =>
                AuthFieldLabelsTr.of(AuthFormRules.email(value ?? '')),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AuthSubmitButton(
          label: ForgotPasswordLabelsTr.submit,
          busyLabel: ForgotPasswordLabelsTr.submitting,
          busy: busy,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: busy ? null : _toLogin,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text(ForgotPasswordLabelsTr.backToLogin),
          ),
        ),
      ],
    );
  }
}
