import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  void completeCurrentExercise() =>
      _apply((TrainingSession s) => s.completeCurrentExercise());

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
