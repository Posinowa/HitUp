import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure_code.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/clock_provider.dart';
import '../../../shared/providers/progress_providers.dart';
import '../../../shared/providers/training_providers.dart';
import '../../auth/domain/models/auth_user.dart';
import '../../progress/domain/models/calendar_day.dart';
import '../../progress/domain/models/user_profile.dart';
import '../data/pending_day_store.dart';
import '../domain/models/models.dart';
import '../domain/today_training_engine.dart';
import '../domain/training_session.dart';
import 'finished_day_recorder.dart';
import 'training_session_controller.dart';

/// Today's training, and what this device has of it: a session kept to
/// carry on with, and a day finished here and not recorded yet.
///
/// Put together from the training engine, the session store and the pending
/// days, which is why it lives with them; home (#23) shows it.
@immutable
class TodayStatus {
  /// Creates the answer.
  const TodayStatus({
    required this.today,
    required this.unfinished,
    required this.finishedTodayUnrecorded,
    required this.date,
  });

  /// Today's training, from `TodayTrainingEngine`.
  final TodayTraining today;

  /// The session the device kept for this same day, to carry on with, or
  /// null when there is none.
  final TrainingSession? unfinished;

  /// Whether a day was finished today on this device and is waiting to be
  /// recorded: offline, the account does not know it yet, so the programme
  /// day has not moved on and the streak not grown.
  final bool finishedTodayUnrecorded;

  /// The date this was worked out on, by the device's clock.
  final CalendarDay date;

  /// Whether a day was trained today: the account's last training date,
  /// from [profile], is [date], or a day finished today waits on this device
  /// to be recorded. The second matters offline, where the account does not
  /// know the day yet and would offer it again.
  ///
  /// The profile is the caller's, so a screen that watches it follows it as
  /// it arrives.
  bool trainedToday(UserProfile? profile) =>
      finishedTodayUnrecorded || profile?.lastTrainingDate == date;
}

/// [TodayStatus] for the signed-in user.
///
/// Worked out again when the programme day moves on, which is what recording
/// a finished day does. A screen that comes back from a session asks again
/// too, since the session it left may be finished or cleared.
final AutoDisposeFutureProvider<TodayStatus> todayStatusProvider =
    FutureProvider.autoDispose<TodayStatus>((Ref ref) async {
  final String? uid = ref.watch(
    authStateChangesProvider.select(
      (AsyncValue<AuthUser?> auth) => auth.valueOrNull?.uid,
    ),
  );
  if (uid == null) {
    throw const AppException(
      'Today was asked for with nobody signed in',
      code: FailureCode.permissionDenied,
    );
  }

  // Only a move from one known day to another: the profile arriving for the
  // first time is not a change, and asking twice at start costs a read.
  ref.listen<int?>(
    currentUserProfileProvider.select(
      (AsyncValue<UserProfile?> profile) =>
          profile.valueOrNull?.currentProgramDay,
    ),
    (int? before, int? now) {
      if (before != null && now != null && before != now) {
        ref.invalidateSelf();
      }
    },
  );

  final TodayTrainingEngine engine = ref.watch(todayTrainingEngineProvider);
  final TodayTraining fromAccount = await engine.todayFor(uid);
  final List<PendingDay> pending = <PendingDay>[
    for (final PendingDay day
        in await ref.watch(pendingDayStoreProvider).load())
      if (day.uid == uid) day,
  ];

  // A day finished on this device and not recorded yet: offline, the
  // account still has the day before it, and would offer that day again.
  // Today is the day after the latest one waiting.
  final int waiting = pending.fold(
    0,
    (int latest, PendingDay day) => max(latest, day.session.programDay),
  );
  final TodayTraining today = !fromAccount.isProgramFinished &&
          waiting >= fromAccount.programDay
      ? engine.build(
          programDay: waiting + 1,
          program: await ref.watch(curriculumRepositoryProvider).loadProgram(),
          library:
              await ref.watch(curriculumRepositoryProvider).loadExercises(),
          programDayAssumed: fromAccount.programDayAssumed,
        )
      : fromAccount;

  final TrainingSession? saved = await ref.watch(sessionStoreProvider).load();
  final List<String> ids = <String>[
    for (final Exercise exercise in today.exercises) exercise.id,
  ];
  final bool sameDay = saved != null &&
      saved.isResumable &&
      saved.programDay == today.programDay &&
      listEquals(saved.exerciseIds, ids);

  final CalendarDay date = CalendarDay.fromDateTime(ref.watch(clockProvider)());

  return TodayStatus(
    today: today,
    unfinished: sameDay ? saved : null,
    finishedTodayUnrecorded: pending.any((PendingDay day) => day.date == date),
    date: date,
  );
});
