/// The three states an async screen can be in, drawn the same way everywhere.
///
/// A screen that loads something can show a spinner, nothing, or a problem.
/// Left to each screen, those three end up looking slightly different on every
/// page, and the error case is the one that suffers: it is the state nobody
/// designs and everybody rushes.
///
/// These are the shared answers. Errors in particular always arrive as the same
/// bordered panel on its own surface, so a problem looks like a problem no
/// matter which screen the user is on.
library;

import 'package:flutter/material.dart';

import '../errors/failure.dart';
import '../errors/failure_messages.dart';
import '../errors/failure_presenter.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// A [Failure] shown inline, as a panel on the surface reserved for errors.
///
/// Use this when the problem replaces content the user was waiting for: a
/// screen that could not load, a list that failed to fetch. For a problem that
/// interrupts something the user just did, and that the screen survives, use
/// `showFailureSnackBar` instead; for one the user has to acknowledge before
/// continuing, `showFailureDialog`.
///
/// All three read the same two colour tokens, so the three routes out of a
/// failure look like the same app.
class ErrorView extends StatelessWidget {
  /// Creates an inline error panel for [failure].
  const ErrorView({required this.failure, this.onRetry, super.key});

  /// The failure to describe. Only its mapped sentence is ever shown; the
  /// technical detail stays in logs.
  final Failure failure;

  /// Called when the user asks to try again.
  ///
  /// The retry button appears only when this is supplied *and* the failure is
  /// one where retrying could plausibly help. Offering "try again" on a wrong
  /// password would just waste the user's time.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
          // The border is drawn in the full-strength error tone. The surface
          // behind the text has to stay light enough to read on, so the alert
          // colour lives on the edge and the icon instead, where nothing is
          // written over it.
          border: Border.all(color: colors.error),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.error_outline, color: colors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      failureMessage(failure),
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
              if (failure.canOfferRetry(onRetry)) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onErrorContainer,
                    ),
                    child: const Text(FailureLabelsTr.retry),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The screen is waiting for something.
class LoadingView extends StatelessWidget {
  /// Creates a centred progress indicator.
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// The request succeeded and there is genuinely nothing to show.
///
/// Deliberately not an [ErrorView]. "You have not done anything yet" is not a
/// failure, and dressing it in error colours tells a new user their first
/// screen is broken.
class EmptyView extends StatelessWidget {
  /// Creates an empty-state message.
  const EmptyView({required this.message, this.icon, super.key});

  /// What is missing, in the user's words.
  final String message;

  /// Optional illustration for the state.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 48, color: colors.outline),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
