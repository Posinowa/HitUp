import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../shared/providers/analytics_providers.dart';
import '../../../shared/providers/startup_providers.dart';
import '../data/onboarding_answers_store.dart';
import '../data/onboarding_store.dart';
import '../domain/onboarding_answers.dart';

/// Where onboarding's answers are kept.
final Provider<OnboardingAnswersStore> onboardingAnswersStoreProvider =
    Provider<OnboardingAnswersStore>(
  (Ref ref) => const PreferencesOnboardingAnswersStore(),
);

/// Finishes onboarding (HIT-015).
///
/// Keeps the answers, if any were given, then the flag that onboarding is
/// done, in that order: a flag written with its answers lost would never ask
/// again. Then startup is asked again, so the router takes the user on from
/// onboarding (`guardedRoute`), and `onboarding_completed` is reported.
/// Skipping is finishing with what was answered so far, usually nothing.
///
/// The state is where it is, as `ERROR_HANDLING.md` describes: loading while
/// it runs, then whether onboarding is finished, or the mapped `Failure`. A
/// second finish, while one runs or once one has worked, is ignored: the
/// screen stays until the router takes the user on, and a tap in that time
/// must not keep the answers and report `onboarding_completed` again.
class OnboardingController extends AutoDisposeAsyncNotifier<bool> {
  @override
  FutureOr<bool> build() => false;

  /// Keeps [answers] and records onboarding as done.
  Future<void> finish(OnboardingAnswers answers) async {
    if (state.isLoading || (state.valueOrNull ?? false)) {
      return;
    }
    // Read before the first await: the screen may be gone by the time the
    // writes end.
    final OnboardingAnswersStore answersStore =
        ref.read(onboardingAnswersStoreProvider);
    final OnboardingStore flag = ref.read(onboardingStoreProvider);
    final AnalyticsService analytics = ref.read(analyticsServiceProvider);

    state = const AsyncValue<bool>.loading();
    try {
      if (!answers.isEmpty) {
        await answersStore.save(answers);
      }
      await flag.markComplete();
      unawaited(analytics.log(AnalyticsEvent.onboardingCompleted()));
      state = const AsyncValue<bool>.data(true);
      ref.invalidate(onboardingCompleteProvider);
    } catch (error, stackTrace) {
      state = AsyncValue<bool>.error(mapErrorToFailure(error), stackTrace);
    }
  }
}

/// The onboarding screen's finish, gone with the screen.
final AutoDisposeAsyncNotifierProvider<OnboardingController, bool>
    onboardingControllerProvider =
    AsyncNotifierProvider.autoDispose<OnboardingController, bool>(
  OnboardingController.new,
);
