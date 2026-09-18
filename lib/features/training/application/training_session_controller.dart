import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/progress_providers.dart';
import '../../progress/domain/repositories/user_progress_repository.dart';
import '../data/session_store.dart';
import '../domain/models/models.dart';
import '../domain/training_session.dart';

/// Holds the session a screen is running, and keeps the device's copy of it
/// up to date (HIT-026).
///
/// The state machine itself is `TrainingSession`, which is a value and knows
/// nothing about storage. This is the thin layer around it: apply the
/// transition, hand the new session to the screen, write it down so the home
/// screen can offer to carry on with it.
///
/// Null means there is no session in hand: none started, or the last one
/// finished and was cleared.
class TrainingSessionController extends Notifier<TrainingSession?> {
  @override
  TrainingSession? build() => null;

  SessionStore get _store => ref.read(sessionStoreProvider);

  UserProgressRepository get _progress =>
      ref.read(userProgressRepositoryProvider);

  /// The signed-in account, or null when nobody is.
  String? get _uid => ref.read(authStateChangesProvider).valueOrNull?.uid;

  /// Loads an unfinished session from the device, if there is one.
  ///
  /// Returns what it found, so the home screen can decide whether to offer a
  /// resume without reading the state back.
  Future<TrainingSession?> restore() async {
    final TrainingSession? saved = await _store.load();
    // A finished session is not worth resuming; it is left over from a run
    // that ended without being cleared.
    if (saved == null || !saved.isResumable) {
      return null;
    }
    state = saved;
    return saved;
  }

  /// Starts a session for [today], replacing anything in hand.
  ///
  /// Throws an [ArgumentError] when the day has nothing to run, which
  /// `TodayTraining.isEmpty` says before this is called.
  TrainingSession begin(TodayTraining today) {
    final TrainingSession session = TrainingSession.forToday(today).start();
    _set(session);
    return session;
  }

  /// Puts the session down.
  void pause() => _apply((TrainingSession s) => s.pause());

  /// Picks it up again.
  void resume() => _apply((TrainingSession s) => s.resume());

  /// Records the current exercise and moves on.
  ///
  /// The completion is also counted on the account (HIT-052). That write is
  /// not waited for and cannot fail the session: the exercise was done on the
  /// device, and whether the count reached the server yet is a separate
  /// question. Offline, the SDK queues it and sends it when it can
  /// (`USER_PROGRESS.md`).
  void completeCurrentExercise() {
    final String? exerciseId = state?.currentExerciseId;
    _apply((TrainingSession s) => s.completeCurrentExercise());
    if (exerciseId != null) {
      _record(exerciseId);
    }
  }

  /// Moves past the current exercise without recording it.
  void skipCurrentExercise() =>
      _apply((TrainingSession s) => s.skipCurrentExercise());

  /// Ends the session where it stands.
  void finish() => _apply((TrainingSession s) => s.finish());

  /// Drops the session, in hand and on the device.
  ///
  /// What a screen calls once a finished session has been recorded
  /// (HIT-052, HIT-053): until then the saved copy is the safety net.
  Future<void> discard() async {
    state = null;
    await _store.clear();
  }

  /// Counts [exerciseId] on the account, if there is one.
  ///
  /// A signed-out user still runs the session; there is simply nowhere to
  /// count it. A failed write is logged and dropped, because the session has
  /// already moved on and the count is not what the user came for.
  void _record(String exerciseId) {
    final String? uid = _uid;
    if (uid == null) {
      return;
    }
    unawaited(
      _progress.saveExerciseCompletion(uid, exerciseId).catchError(
            (Object error) => debugPrint(
              'HIT-052: could not count $exerciseId. Cause: $error',
            ),
          ),
    );
  }

  void _apply(TrainingSession Function(TrainingSession session) transition) {
    final TrainingSession? current = state;
    if (current == null) {
      throw StateError('There is no session to act on.');
    }
    _set(transition(current));
  }

  void _set(TrainingSession session) {
    state = session;
    // Saved, not awaited: the screen moves on with the state it already has,
    // and a write that fails costs a resume, not the session.
    unawaited(_store.save(session));
  }
}

/// Where an unfinished session is kept.
final Provider<SessionStore> sessionStoreProvider =
    Provider<SessionStore>((Ref ref) => const PreferencesSessionStore());

/// The session a screen is running, or null when there is none.
final NotifierProvider<TrainingSessionController, TrainingSession?>
    trainingSessionControllerProvider =
    NotifierProvider<TrainingSessionController, TrainingSession?>(
  TrainingSessionController.new,
);
