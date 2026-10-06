import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'auth_header.dart';

/// Copy the three account screens share.
abstract final class AuthCommonLabelsTr {
  /// The email field.
  static const String email = 'E-posta';

  /// The password field.
  static const String password = 'Şifre';

  /// The button that shows a hidden password.
  static const String showPassword = 'Şifreyi göster';

  /// The button that hides it again.
  static const String hidePassword = 'Şifreyi gizle';
}

/// The page an account screen is laid out on: the cut-paper header
/// ([AuthHeader]), a heading, then the form (HIT-017 to HIT-019).
///
/// Everything scrolls as one, and the scaffold makes room for the keyboard,
/// so the field being typed in is never behind it. Dragging the form puts
/// the keyboard away. The header runs under the status bar; the rest keeps
/// clear of the screen's edges and notches.
class AuthPage extends StatelessWidget {
  /// Lays out [children] under [title] and [subtitle].
  const AuthPage({
    required this.title,
    required this.subtitle,
    required this.children,
    super.key,
  });

  /// The heading, read out as one.
  final String title;

  /// A line under it.
  final String subtitle;

  /// The form and its buttons.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AuthHeader(),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: text.headlineMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: text.bodyLarge
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ...children,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An email field: the keyboard for addresses, no autocorrect, and the hint
/// autofill needs to offer a saved address.
class AuthEmailField extends StatelessWidget {
  /// Creates the field.
  const AuthEmailField({
    required this.controller,
    required this.validator,
    required this.enabled,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    super.key,
  });

  /// What was typed.
  final TextEditingController controller;

  /// What is wrong with it, or null.
  final String? Function(String? value) validator;

  /// False while the form is being sent.
  final bool enabled;

  /// The keyboard's action key.
  final TextInputAction textInputAction;

  /// What that key does.
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        enabled: enabled,
        decoration: const InputDecoration(labelText: AuthCommonLabelsTr.email),
        keyboardType: TextInputType.emailAddress,
        autofillHints: const <String>[AutofillHints.email],
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
      );
}

/// A password field with a button that shows what was typed.
///
/// [autofillHints] says which password it is: an existing one to fill in,
/// or a new one the platform may offer to generate and save.
class AuthPasswordField extends StatefulWidget {
  /// Creates the field.
  const AuthPasswordField({
    required this.controller,
    required this.label,
    required this.autofillHints,
    required this.validator,
    required this.enabled,
    this.focusNode,
    this.helperText,
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
    super.key,
  });

  /// What was typed.
  final TextEditingController controller;

  /// The field's label.
  final String label;

  /// [AutofillHints.password] or [AutofillHints.newPassword].
  final List<String> autofillHints;

  /// What is wrong with it, or null.
  final String? Function(String? value) validator;

  /// False while the form is being sent.
  final bool enabled;

  /// Where focus goes to reach it.
  final FocusNode? focusNode;

  /// A line under the field, for the rule a new password follows.
  final String? helperText;

  /// The keyboard's action key.
  final TextInputAction textInputAction;

  /// What that key does.
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        obscureText: _hidden,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        autofillHints: widget.autofillHints,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onFieldSubmitted,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helperText,
          helperMaxLines: 2,
          errorMaxLines: 3,
          suffixIcon: IconButton(
            tooltip: _hidden
                ? AuthCommonLabelsTr.showPassword
                : AuthCommonLabelsTr.hidePassword,
            icon: Icon(
              _hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
      );
}

/// The button that sends a form. While [busy] it cannot be pressed and says
/// so, with [busyLabel] for a screen reader.
class AuthSubmitButton extends StatelessWidget {
  /// Creates the button.
  const AuthSubmitButton({
    required this.label,
    required this.busyLabel,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  /// What it does.
  final String label;

  /// What it is doing, while it does it.
  final String busyLabel;

  /// Whether the form is being sent.
  final bool busy;

  /// Sends the form.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: busy
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  semanticsLabel: busyLabel,
                ),
              )
            : Text(label),
      );
}

/// A line that leads to another account screen: a question and a link.
class AuthLinkRow extends StatelessWidget {
  /// Creates the row.
  const AuthLinkRow({
    required this.prompt,
    required this.action,
    required this.onPressed,
    super.key,
  });

  /// The question, "Hesabınız yok mu?".
  final String prompt;

  /// The link's words.
  final String action;

  /// Where it goes; null while the form is being sent.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            prompt,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          TextButton(onPressed: onPressed, child: Text(action)),
        ],
      );
}
