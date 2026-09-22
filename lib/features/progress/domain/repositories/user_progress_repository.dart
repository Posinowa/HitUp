import '../models/exercise_progress.dart';
import '../models/training_history_entry.dart';
import '../models/user_preferences.dart';
import '../models/user_profile.dart';

/// Everything the app reads and writes about a user's progress (HIT-079).
///
/// The one path to `users/{uid}` and its subcollections. Screens and
/// controllers use this interface and never Cloud Firestore; there is no second
/// progress layer beside it (`ARCHITECTURE.md`, hard rule 3).
///
/// Every method takes the signed-in user's uid rather than finding it itself,
/// so a call can never quietly act on whoever happens to be signed in by the
/// time it runs.
///
/// **Errors.** Methods throw. A controller turns what it catches into a
/// `Failure` with `mapErrorToFailure`, as `ERROR_HANDLING.md` describes. An
/// argument the security rules would refuse is an [ArgumentError], thrown
/// before anything is written.
///
/// **Offline.** Reads and writes behave as the Firestore SDK does, and that
/// shapes how a caller should wait on them:
///
/// - A write made offline is applied to the local copy at once, and a stream
///   from [watchUserProfile] shows it at once. The returned `Future` completes
///   only when the server has accepted the write, which may be the next time
///   the device is online. A screen should move on without waiting for it.
/// - A read offline returns the local copy if that path was ever synced. If
///   the local copy has nothing, the read fails with a network error rather
///   than reporting the data as missing: "not fetched yet" is not "does not
///   exist".
abstract interface class UserProgressRepository {
  /// The profile, and every later change to it.
  ///
  /// While offline with nothing cached, the stream waits rather than emitting.
  /// If the server confirms there is no profile, it emits an `AppException`
  /// with `FailureCode.dataNotFound`.
  Stream<UserProfile> watchUserProfile(String uid);

  /// The profile as it is now.
  ///
  /// Throws `AppException` with `FailureCode.dataNotFound` if the server says
  /// there is none, and with `FailureCode.networkOffline` if the server could
  /// not be asked and the local copy has no profile.
  Future<UserProfile> getUserProfile(String uid);

  /// The day of the programme the user is on.
  Future<int> getCurrentProgramDay(String uid);

  /// Completed training days, newest first, at most [limit] if given.
  Future<List<TrainingHistoryEntry>> getTrainingHistory(
    String uid, {
    int? limit,
  });

  /// Every exercise the user has completed at least once, in no given order.
  Future<List<ExerciseProgress>> getExerciseProgress(String uid);

  /// Counts one more completion of [exerciseId], stamped with the server time.
  ///
  /// The count is incremented where it is stored, never read and written back,
  /// so two completions racing, or queued offline, both count.
  Future<void> saveExerciseCompletion(String uid, String exerciseId);

  /// Records a completed training day and adds its minutes to the total.
  ///
  /// The history entry and the total are one atomic write: both happen or
  /// neither does. A day already recorded is not recorded again, and its
  /// minutes are not counted again; that returns
  /// [TrainingSaveResult.alreadySaved] rather than throwing.
  ///
  /// Advancing `currentProgramDay` (HIT-053) and the streak fields (HIT-054)
  /// are not written here; those issues decide when they change.
  Future<TrainingSaveResult> saveTrainingCompletion(
    String uid,
    TrainingCompletion completion,
  );

  /// The user's settings.
  Future<UserPreferences> getPreferences(String uid);

  /// Replaces the user's settings with [preferences].
  ///
  /// The whole document is written, so a [UserPreferences.reminderTime] of
  /// null removes a time chosen earlier.
  Future<void> updatePreferences(String uid, UserPreferences preferences);
}
