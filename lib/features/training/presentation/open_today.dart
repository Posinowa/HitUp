import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../application/today_status.dart';
import '../application/training_session_controller.dart';

/// Opens today's training day over the tabs, then asks for today again on
/// the way back, since the session it left may be finished or cleared.
///
/// With a session the device kept for this same day
/// ([TodayStatus.unfinished]), that session is restored into
/// `TrainingSessionController` first: the exercise screen carries on with a
/// session in hand for its day, and starts a new one otherwise
/// (`TRAINING.md`).
Future<void> openToday(
  BuildContext context,
  WidgetRef ref,
  TodayStatus status,
) async {
  if (status.unfinished != null) {
    await ref.read(trainingSessionControllerProvider.notifier).restore();
  }
  if (!context.mounted) {
    return;
  }
  await context.push(RouteNames.session, extra: status.today);
  // As before the push: a screen gone meanwhile has no ref to use.
  if (!context.mounted) {
    return;
  }
  ref.invalidate(todayStatusProvider);
}
