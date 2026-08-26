import 'package:flutter/material.dart';
import 'package:hitup/core/errors/failure.dart';
import 'package:hitup/core/errors/failure_messages.dart';

/// How a [Failure] reaches the user.
///
/// Screens call these instead of building their own error UI, so every error
/// in the app looks and behaves the same way, and so no screen is ever in a
/// position to print a raw exception.
///
/// A retry action appears only when the failure is worth retrying and the
/// caller supplied something to retry with. Offering "try again" on a wrong
/// password would just waste the user's time.
extension FailurePresenter on Failure {
  /// Whether a retry action should be offered for this failure.
  bool canOfferRetry(VoidCallback? onRetry) => isRetryable && onRetry != null;
}

/// Shows [failure] as a snack bar. Use for recoverable, non blocking problems.
void showFailureSnackBar(
  BuildContext context,
  Failure failure, {
  VoidCallback? onRetry,
}) {
  final colors = Theme.of(context).colorScheme;
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      // The message needs its colour named here, next to the background it
      // sits on. A SnackBar whose content carries no colour falls back to
      // Material's default, onInverseSurface, which is the pair for the
      // default inverseSurface background, not for the errorContainer this
      // call substitutes. The two happen to resolve to the same value in the
      // current scheme, so nothing looks wrong yet; that is a coincidence, not
      // a guarantee, and the retry action below already names its colour.
      content: Text(
        failureMessage(failure),
        style: TextStyle(color: colors.onErrorContainer),
      ),
      backgroundColor: colors.errorContainer,
      behavior: SnackBarBehavior.floating,
      action: failure.canOfferRetry(onRetry)
          ? SnackBarAction(
              label: FailureLabelsTr.retry,
              textColor: colors.onErrorContainer,
              onPressed: onRetry!,
            )
          : null,
    ),
  );
}

/// Shows [failure] as a dialog. Use when the user cannot continue without
/// acknowledging the problem.
Future<void> showFailureDialog(
  BuildContext context,
  Failure failure, {
  VoidCallback? onRetry,
  String title = FailureLabelsTr.dialogTitle,
}) {
  final colors = Theme.of(context).colorScheme;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      // Same two tokens as the snack bar and ErrorView. All three ways a
      // failure reaches the user sit on the error surface with the error text
      // colour on it, so a problem is recognisable as a problem before the
      // sentence is even read.
      backgroundColor: colors.errorContainer,
      icon: Icon(Icons.error_outline, color: colors.error),
      title: Text(title, style: TextStyle(color: colors.onErrorContainer)),
      content: Text(
        failureMessage(failure),
        style: TextStyle(color: colors.onErrorContainer),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          style: TextButton.styleFrom(
            foregroundColor: colors.onErrorContainer,
          ),
          child: const Text(FailureLabelsTr.dismiss),
        ),
        if (failure.canOfferRetry(onRetry))
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onRetry!();
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.onErrorContainer,
              foregroundColor: colors.errorContainer,
            ),
            child: const Text(FailureLabelsTr.retry),
          ),
      ],
    ),
  );
}
