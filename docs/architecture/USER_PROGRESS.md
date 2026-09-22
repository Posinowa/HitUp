# User Progress

**STATUS: IMPLEMENTED (HIT-079).** The one path to `users/{uid}` and its subcollections. When the program day advances is HIT-053, the streak is HIT-054, and the screens come after them.

## Layers

```text
screen  ->  controller  ->  UserProgressRepository         (domain interface)
                             FirebaseUserProgressRepository  (data, every decision)
                               ProgressStore  ->  Cloud Firestore
```

| File | Holds |
|---|---|
| `features/progress/domain/models/` | `UserProfile`, `TrainingHistoryEntry`, `TrainingCompletion`, `ExerciseProgress`, `UserPreferences`, and the value types `CalendarDay` and `ReminderTime`. No Firebase type |
| `features/progress/domain/repositories/user_progress_repository.dart` | The interface every caller uses |
| `features/progress/data/firebase_user_progress_repository.dart` | Paths, fields, what a missing document means, same day handling, the limits the rules enforce |
| `features/progress/data/progress_store.dart` | The storage seam: documents in, documents out |
| `features/progress/data/firestore_progress_store.dart` | The Firestore calls and type conversions, and nothing else |
| `shared/providers/progress_providers.dart` | `userProgressRepositoryProvider`, `currentUserProfileProvider` |

Every method takes the uid. A call never finds the signed-in user by itself, so it cannot act on whoever happens to be signed in by the time it runs.

## Days are `CalendarDay`

`lastTrainingDate` and the history document id are the user's local day as `"yyyy-MM-dd"` (`FIRESTORE_MODEL.md`). In Dart that string is a `CalendarDay`. `CalendarDay.fromDateTime(DateTime.now())` is the day the user sees on their own clock, and `CalendarDay(2026, 2, 30)` throws instead of rolling into March.

## Saving a training day

`saveTrainingCompletion` returns `saved` or `alreadySaved`; completing the same day twice is not an error.

1. The limits the rules enforce are checked first, and a value outside them is an `ArgumentError`: program day at least 1, 1 to 50 exercises, 0 to 1440 minutes. From the server those would come back as a permission error that names no field.
2. The local copy is asked whether today is already recorded. It answers at once, online or not. If it is, nothing is written.
3. The history entry and `totalTrainingMinutes` are written in **one batch**, the minutes as an increment. The rules refuse any write to an existing entry, and a refused batch takes its minutes with it, so a day is never counted twice.
4. If the batch is refused with a permission error, the entry is read back. Only when the **server** confirms it exists is the result `alreadySaved`, for instance after the day was completed on another device. Otherwise the original error is thrown: a signed-out user gets the same refusal.

`currentProgramDay` and the streak fields are not written here. HIT-053 and HIT-054 decide when they change, and the streak needs a transaction (`FIRESTORE_MODEL.md`).

## Offline

The Firestore SDK does the work. What a caller needs to know:

- **A write returns a `Future` that completes only when the server has accepted it.** Offline, that is whenever the device is next online. The local copy, and `watchUserProfile`, show the write at once. A screen should move on without awaiting the save.
- **A read offline returns the local copy.** If the local copy has nothing, the repository throws `AppException` with `FailureCode.networkOffline`, not `dataNotFound`: "not fetched yet" is not "does not exist". An empty history list from the local copy is reported the same way, because the local copy cannot tell an empty history from one it never fetched.
- **`watchUserProfile` waits** while offline with nothing cached, instead of emitting a missing profile.

## Errors

The repository **throws**. A controller maps what it catches once with `mapErrorToFailure`, as `ERROR_HANDLING.md` describes.

| Situation | Failure code |
|---|---|
| The server says the profile or settings document does not exist | `data.not_found` |
| The server could not be asked and the local copy has nothing | `network.offline` |
| A field of the wrong type, or an unreadable date or time | `data.unknown`, naming the field and the document id |
| Firestore `permission-denied`, other than a day already saved | `permission.denied` |
| Firestore `unavailable`, `deadline-exceeded` | `network.unavailable`, `network.timeout` |

## Using it

```dart
final UserProgressRepository progress = ref.read(userProgressRepositoryProvider);
final TrainingSaveResult result = await progress.saveTrainingCompletion(
  uid,
  TrainingCompletion(
    date: CalendarDay.fromDateTime(DateTime.now()),
    programDay: 4,
    completedExerciseIds: ids,
    durationMinutes: 13,
  ),
);

ref.watch(currentUserProfileProvider); // AsyncValue<UserProfile?>, null when signed out
```

In tests and previews, override `userProgressRepositoryProvider` with a fake.

## Testing

`test/features/progress/data/firebase_user_progress_repository_test.dart` holds every decision above against a fake `ProgressStore` that can be online or offline, hold different documents on the server and in the local copy, and fail on request. It also reads `firestore.rules` and checks that the fields written to each collection are the ones the rules allow.

The writes themselves, built the same way, were run against `firestore.rules` on the emulator: a training day and its minutes in one batch, the same day refused a second time without its minutes counting, an exercise completion creating and then incrementing its document, and preferences written with and without a reminder time.

`FirestoreProgressStore` holds no decision of its own; it needs a device or an emulator, not a unit test.
