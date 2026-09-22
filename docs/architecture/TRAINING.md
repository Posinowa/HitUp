# Training

**STATUS: TODAY'S TRAINING IMPLEMENTED (HIT-025).** The session state machine is HIT-026, the screens are HIT-027 onwards.

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

## Testing

`test/features/training/domain/today_training_engine_test.dart` covers every state above from fixtures, with fake curriculum and progress repositories: each day's order and both totals, determinism, a short day, an empty day, past the last day, a day below one, a hole, an empty programme, and each way the user's day can fail to read.
