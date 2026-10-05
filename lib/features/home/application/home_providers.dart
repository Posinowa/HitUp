import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../shared/providers/analytics_providers.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../auth/domain/models/auth_user.dart';

/// Where the device keeps which finished programme was reported, per account.
abstract interface class ReportedFinishStore {
  /// The last programme day reported as finished for [uid], or null.
  Future<int?> load(String uid);

  /// Keeps [programDay] as reported for [uid].
  Future<void> save(String uid, int programDay);
}

/// [ReportedFinishStore] over the device's preferences.
class PreferencesReportedFinishStore implements ReportedFinishStore {
  /// Creates a store.
  const PreferencesReportedFinishStore();

  /// The key for [uid]'s value.
  static String keyFor(String uid) => 'program_finished_reported_$uid';

  @override
  Future<int?> load(String uid) async =>
      (await SharedPreferences.getInstance()).getInt(keyFor(uid));

  @override
  Future<void> save(String uid, int programDay) async =>
      (await SharedPreferences.getInstance()).setInt(keyFor(uid), programDay);
}

/// Where finished programmes are kept as reported.
final Provider<ReportedFinishStore> reportedFinishStoreProvider =
    Provider<ReportedFinishStore>(
  (Ref ref) => const PreferencesReportedFinishStore(),
);

/// Reports `program_finished` once, the first time home sees a finished
/// programme for an account (`ANALYTICS.md`).
///
/// Home is where a finished programme is known: the engine says so once the
/// programme day has moved past the last day. Seeing it again, on every
/// visit after, is not the programme being finished again, so the day
/// reported is kept on the device and not reported twice. A new install
/// reports it once more, which is the price of keeping it off the account.
Future<void> reportProgramFinished(
  Ref ref, {
  required String uid,
  required int lastDay,
}) async {
  final ReportedFinishStore store = ref.read(reportedFinishStoreProvider);
  if (await store.load(uid) == lastDay) {
    return;
  }
  await store.save(uid, lastDay);
  unawaited(
    ref
        .read(analyticsServiceProvider)
        .log(AnalyticsEvent.programFinished(programDay: lastDay)),
  );
}

/// Reports the finished programme home has just seen, once.
final AutoDisposeFutureProviderFamily<void, int> programFinishedReportProvider =
    FutureProvider.autoDispose.family<void, int>((Ref ref, int lastDay) async {
  final String? uid = ref.watch(
    authStateChangesProvider.select(
      (AsyncValue<AuthUser?> auth) => auth.valueOrNull?.uid,
    ),
  );
  if (uid != null) {
    await reportProgramFinished(ref, uid: uid, lastDay: lastDay);
  }
});
