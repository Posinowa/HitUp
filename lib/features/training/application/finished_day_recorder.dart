import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/auth_providers.dart';
import '../../auth/domain/models/auth_user.dart';
import '../data/pending_day_store.dart';
import 'training_day_recorder.dart';

/// Records finished days so that none is lost to the app being closed
/// (HIT-028).
///
/// A finished day is written to the device first, as a [PendingDay], and
/// forgotten only once `TrainingDayRecorder` has recorded it. Offline the
/// recording does not complete until the device is back online, and the user
/// can close the app well before that; the pending day is what is left to
/// record it from.
///
/// **Oldest first.** Recording a day also records every older day the same
/// account left pending, in date order, because that is the only order the
/// streak can be counted in. A failure stops there and leaves the rest
/// pending, to be tried again.
///
/// **Kept at once, recorded in turn.** Two queues, because they wait for
/// different things:
///
/// - Keeping a day on the device, or forgetting one, is a read, a change and
///   a write of the list, and two of them interleaving would lose a day. They
///   take turns with each other only, and each is over in moments.
/// - Recordings take turns with each other. Offline one can wait until the
///   device is back online, and a day finished meanwhile must not wait
///   behind it to be kept: closing the app would lose it.
class FinishedDayRecorder {
  /// Creates a recorder over [recorder], keeping pending days in [store].
  FinishedDayRecorder({
    required TrainingDayRecorder recorder,
    required PendingDayStore store,
  })  : _recorder = recorder,
        _store = store;

  final TrainingDayRecorder _recorder;
  final PendingDayStore _store;

  Future<void> _lastRecording = Future<void>.value();
  Future<void> _lastStoreChange = Future<void>.value();

  /// What recording each day returned, by account and date, whichever call
  /// recorded it. A call can find its day already recorded by one queued
  /// before it, and still has to say what that did.
  final Map<String, TrainingDayRecord> _recorded =
      <String, TrainingDayRecord>{};

  static String _keyOf(PendingDay day) => '${day.uid}|${day.date.key}';

  /// Keeps [day] on the device, then records it and any older pending day
  /// of the same account.
  ///
  /// Returns what recording [day]'s date did. Throws what the recording
  /// threw; [day] stays pending.
  Future<TrainingDayRecord> record(PendingDay day) {
    // Kept now, not in turn: see the class comment. The recording is queued
    // in the same moment, so its place in line is fixed by this call.
    final Future<void> kept = _changeStore(() => _store.add(day));
    return _inTurn(() async {
      await kept;
      await _recordPending(day.uid);
      // By account and date: an earlier session on the same date is the one
      // kept, as the account keeps it, and a call queued before this one may
      // be what recorded it.
      final TrainingDayRecord? record = _recorded[_keyOf(day)];
      if (record == null) {
        throw StateError('${day.date.key} was neither pending nor recorded');
      }
      return record;
    });
  }

  /// Records every day [uid] left pending, oldest first.
  ///
  /// What the app calls when it starts, so a day the app was closed on is
  /// recorded before anything is built on it. Days of another account stay
  /// pending for that account. Returns what was recorded, oldest first.
  Future<List<TrainingDayRecord>> recordPending(String uid) =>
      _inTurn(() => _recordPending(uid));

  Future<List<TrainingDayRecord>> _recordPending(String uid) async {
    final List<TrainingDayRecord> records = <TrainingDayRecord>[];
    for (final PendingDay pending in await _store.load()) {
      if (pending.uid != uid) {
        continue;
      }
      final TrainingDayRecord record = await _recorder.record(
        uid: pending.uid,
        session: pending.session,
        today: pending.date,
        elapsed: pending.elapsed,
      );
      _recorded[_keyOf(pending)] = record;
      records.add(record);
      try {
        await _changeStore(() => _store.remove(pending));
      } catch (error) {
        // The day is recorded. Left pending, it is recorded again next time,
        // which the recorder treats as already done (HIT-100).
        debugPrint('HIT-028: could not forget a recorded day. Cause: $error');
      }
    }
    return records;
  }

  Future<T> _inTurn<T>(Future<T> Function() work) {
    final Future<T> result = _lastRecording.then((_) => work());
    // The next one waits for this one to end, however it ends.
    _lastRecording = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _changeStore(Future<void> Function() change) {
    final Future<void> result = _lastStoreChange.then((_) => change());
    _lastStoreChange = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

/// Where finished days wait to be recorded.
final Provider<PendingDayStore> pendingDayStoreProvider =
    Provider<PendingDayStore>((Ref ref) => const PreferencesPendingDayStore());

/// Records finished days, keeping each on the device until it is recorded.
final Provider<FinishedDayRecorder> finishedDayRecorderProvider =
    Provider<FinishedDayRecorder>(
  (Ref ref) => FinishedDayRecorder(
    recorder: ref.watch(trainingDayRecorderProvider),
    store: ref.watch(pendingDayStoreProvider),
  ),
);

/// Records the days an earlier run left pending, for whoever is signed in.
///
/// Runs when someone signs in and again when the account changes; the app
/// root keeps it listened to, so it starts with the app. The list on the
/// device is read first, and the account is not reached at all when that
/// account has nothing pending, which is almost every launch.
///
/// A screen that builds today's training can wait for it, briefly: offline
/// it does not complete until the device is back online, and today's
/// training should not wait that long. A failure is held here, not thrown;
/// the days stay pending for the next launch or the next finished day.
final FutureProvider<List<TrainingDayRecord>> pendingDaysProvider =
    FutureProvider<List<TrainingDayRecord>>((Ref ref) async {
  final String? uid = ref.watch(
    authStateChangesProvider.select(
      (AsyncValue<AuthUser?> auth) => auth.valueOrNull?.uid,
    ),
  );
  if (uid == null) {
    return const <TrainingDayRecord>[];
  }
  try {
    final List<PendingDay> pending =
        await ref.watch(pendingDayStoreProvider).load();
    if (!pending.any((PendingDay day) => day.uid == uid)) {
      return const <TrainingDayRecord>[];
    }
    return await ref.read(finishedDayRecorderProvider).recordPending(uid);
  } catch (error) {
    debugPrint('HIT-028: pending days not recorded yet. Cause: $error');
    rethrow;
  }
});
