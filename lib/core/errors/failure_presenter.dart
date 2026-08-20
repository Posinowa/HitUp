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
      content: Text(failureMessage(failure)),
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
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(failureMessage(failure)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text(FailureLabelsTr.dismiss),
        ),
        if (failure.canOfferRetry(onRetry))
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onRetry!();
            },
            child: const Text(FailureLabelsTr.retry),
          ),
      ],
    ),
  );
}
