# Training

**STATUS: TODAY'S TRAINING, THE SESSION, AND RECORDING WHAT WAS DONE, IMPLEMENTED (HIT-025, HIT-026, HIT-052, HIT-053).** The screens are HIT-027 onwards.

## What decides today's training

```text
screen  ->  controller  ->  TodayTrainingEngine
                              CurriculumRepository   ->  bundled JSON
                              UserProgressRepository ->  users/{uid}.currentProgramDay
```

| File | Holds |
|---|---|
| `features/training/domain/today_training_engine.dart` | The whole decision |
| `features/training/domain/models/today_training.dart` | `TodayTraining`: the day, its exercises, both totals, the states below |
| `shared/providers/training_providers.dart` | `curriculumRepositoryProvider`, `todayTrainingEngineProvider` |

Two inputs and no state: the programme comes from the app bundle, the day from the user's profile. The same inputs always produce the same result, and nothing here invents, shuffles or generates content (`CONTENT_SCHEMA.md`, `MVP_CURRICULUM.md`).

`build` takes the programme, the library and a day and returns the answer with nothing to await, so every case below is testable from fixtures. `todayFor(uid)` is that plus the two reads.

## There is no catch-up

The programme day advances when a day is **completed** (HIT-053), not when the calendar turns. A user who trains on Monday and comes back the following Sunday is still on the day after Monday's.

Nothing is skipped and nothing piles up: the streak (HIT-054) is what notices the gap, and it belongs to the user's history, not to what is trained next. This is a decision, not an omission; the issue left catch-up rules open ("if defined") and none are defined for the MVP.

## The states a screen has to handle

| State | What it means | `TodayTraining` |
|---|---|---|
| A day to run | The usual case | `exercises` in order, `day` set |
| Programme finished | `currentProgramDay` is past the last day | `isProgramFinished`, no exercises |
| Short day | Some exercise ids are not in this build | `missingExerciseIds` listed, the rest still runs |
| Empty day | Every id is missing | `isEmpty` with `isProgramFinished` false |
| Assumed day | The profile could not be read | `programDayAssumed`, day one |

**Finished does not loop.** The engine does not return to day one and does not repeat the last day, because either would tell the user they still have training to do. The home screen (#23) owns what to show instead.

**A short day still runs.** A day that names an exercise this build cannot render loses that exercise, not the day (`CONTENT_SCHEMA.md`). The missing ids are reported so the reason a day runs short is visible rather than silent.

**A day below one starts at day one.** The rules allow `currentProgramDay` to be 0 and the model says a new account starts at 1, so 0 means an odd or old document, not a state of its own.

**A programme with no days, or a hole where the day should be, is a content failure**, thrown as `FailureCode.contentMalformed`. Neither is a finished programme: no user action fixes it, and the curriculum test is what should have caught it.

## Offline

The programme is bundled, so it always reads. The user's day may not: before a first sync there is nothing cached, and the repository reports that as `network.offline` rather than as a missing profile (`USER_PROGRESS.md`).

The engine then assumes **day one** and sets `programDayAssumed`, so a first run offline shows a training day instead of an error. A screen can say the day is not confirmed yet. Any other failure, a refusal or a malformed profile, is thrown rather than hidden behind a plausible day.

## Using it

```dart
final TodayTraining today =
    await ref.read(todayTrainingEngineProvider).todayFor(uid);

if (today.isProgramFinished) {
  // Show the finished state.
} else {
  // today.exercises, today.totalDuration, today.estimatedDuration
}
```

`totalDuration` is the sum of the exercises' own durations, which is what the session will take. `estimatedDuration` is the day's authored figure and includes the pauses between exercises, so it is the larger of the two and the honest one to show before starting.

## Running a day (HIT-026)

`TrainingSession` is the state machine. It is a value: each transition returns a new session rather than changing the old one, so the whole thing reads in one file and tests without a widget, a timer or a repository.

```text
notStarted  --start-->  inProgress  --pause-->  paused  --resume-->  inProgress
                            |                                            |
                     complete / skip the last exercise, or finish        ...
                            v
                        completed
```

| File | Holds |
|---|---|
| `features/training/domain/training_session.dart` | The states and the transitions |
| `features/training/application/training_session_controller.dart` | The session a screen is running, and the saving |
| `features/training/data/session_store.dart` | The unfinished session on the device |

**Illegal transitions throw.** Pausing something that was never started, or completing an exercise after the session is over, is a caller bug rather than a state to fall back from. A screen asks first: `canStart`, `canPause`, `canResume`, `canAdvance`, `canFinish`.

**Completing the last exercise completes the session.** Nothing else has to notice that it was the last one.

**Skipping is not completing.** A skipped exercise is passed over and not recorded, so `completedExerciseIds` is what actually happened and `isFullyCompleted` can tell a finished day from an abandoned one.

**Finishing early keeps what was done.** A user who leaves after two of five exercises has two completions, and `isFullyCompleted` is false.

**A double tap records once.** A screen that fires the callback twice before it rebuilds cannot count the same exercise twice.

## Counting completions on the account (HIT-052)

Completing an exercise also counts it on the account: `saveExerciseCompletion` increments `users/{uid}/exerciseProgress/{exerciseId}` (`USER_PROGRESS.md`).

- **Only completions count.** A skipped exercise is not counted, which is what keeps the numbers honest.
- **The write is not waited for and cannot fail the session.** The exercise was done on the device; whether the count reached the server yet is a separate question, and not one the user is doing. A failure is logged and dropped.
- **Offline it is queued** by the Firestore SDK and sent when the device is next online.
- **A signed-out user still runs the session.** There is simply nowhere to count it, and nothing is written under a guessed account.

Recording the finished **day** is separate, and is below.

## Recording a finished day (HIT-053)

`TrainingDayRecorder` writes what a finished session means, in an order chosen so a half-finished run cannot leave a lie behind:

1. **The day itself**, with its minutes, as the one batch `saveTrainingCompletion` makes. A day already recorded stops here.
2. **The programme day**, moved on only if the user is still on the day they just finished.
3. **The streak**, counted for that day (`USER_PROGRESS.md`).

Three operations rather than one, because Firestore has no transaction spanning a batch and two read-decide-writes. The history entry is the record of the day, and the two that follow are idempotent, so running them again after a failure changes nothing. If the first fails, nothing else runs: a programme day moved on for a day that was never recorded would be a number nobody could explain.

**The programme day advances once.** Only when `currentProgramDay` still equals the day just finished, so a second device that already advanced, or the same day finished twice, cannot push anyone forward twice.

**Minutes are rounded up.** A session of forty seconds took a minute of someone's day, and a total that counts it as zero is the one number a user can immediately tell is wrong.

**Only completed exercises are recorded.** A day where everything was skipped is refused: it is not a training day, and the rules refuse an entry with an empty list anyway.

**The session has no clock.** How long a day took is measured by the screen that ran it (HIT-028) and passed in, which is also what keeps the state machine free of timers.

## The unfinished session on the device

`SessionStore` keeps the current session in the device's preferences, so the home screen can offer to carry on with it (#23). The device, not Firestore: a half-finished session is not progress, it is where someone was when the phone rang, and putting it on the account would have two devices arguing about which half-session is current. `FIRESTORE_MODEL.md` has no place for one either.

The controller writes after every transition and does not wait for the write: the screen moves on with the state it already has, and a failed write costs a resume, not the session.

A saved session that cannot be read, or one whose status this build does not know, is refused rather than guessed at. The day starts again, which is a small loss next to resuming into a state the app cannot reason about.

A **finished** session is never offered for resume; it is left over from a run that ended without being cleared. `discard()` is what a screen calls once a finished session has been recorded (#53, #54); until then the saved copy is the safety net.

## Testing

`test/features/training/domain/today_training_engine_test.dart` covers every state above from fixtures, with fake curriculum and progress repositories: each day's order and both totals, determinism, a short day, an empty day, past the last day, a day below one, a hole, an empty programme, and each way the user's day can fail to read.
