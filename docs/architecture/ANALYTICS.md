# Analytics

**STATUS: SERVICE AND TAXONOMY IMPLEMENTED (HIT-063); THE TRAINING CALL SITES WIRED (HIT-064); THE SPEAKING CHALLENGE WIRED (HIT-048); SIGN-UP AND LOGIN WIRED WITH THE ACCOUNT SCREENS (HIT-017, HIT-018); ONBOARDING'S WITH ITS SCREEN (HIT-015).** The rest land with the screens that raise them: the reminder (#62), and the programme's end with the home screen (#23), which is where a finished programme is known. Crash reporting is HIT-065.

## The shape

```text
screen / controller  ->  AnalyticsService  ->  Firebase Analytics
                          AnalyticsEvent (the taxonomy)
```

| File | Holds |
|---|---|
| `core/analytics/analytics_event.dart` | Every event, its name and its parameters |
| `core/analytics/analytics_service.dart` | `AnalyticsService`, `FirebaseAnalyticsService`, `NoopAnalyticsService` |
| `shared/providers/analytics_providers.dart` | `analyticsServiceProvider` |
| `shared/providers/reporting_identity_provider.dart` | `reportingIdentityProvider`, which ties reports to the signed-in uid |
| `app/bootstrap/app_bootstrap.dart` | Creates the real service and sets collection for the build |

A caller holds `AnalyticsService` and builds an `AnalyticsEvent`. There is no way to log a name of one's own from a screen, which is the point: `training_completed` spelled two ways is two events in the console and a number nobody trusts.

## The events

| Event | Parameters | Raised when |
|---|---|---|
| `sign_up` | `method` | An account is created (Firebase standard event) |
| `login` | `method` | A returning user signs in (Firebase standard event) |
| `onboarding_completed` | none | Onboarding is finished, answered or skipped |
| `training_started` | `program_day`, `exercise_count` | A training day is started |
| `training_completed` | `program_day`, `exercise_count`, `duration_minutes` | A training day is finished |
| `exercise_started` | `exercise_id`, `presentation_type`, `program_day` | An exercise begins |
| `exercise_completed` | `exercise_id`, `presentation_type`, `program_day` | An exercise ends |
| `tongue_twister_completed` | `tongue_twister_id`, `repetitions` | A twister drill ends |
| `speaking_challenge_started` | `speaking_challenge_id` | A speaking task begins |
| `speaking_challenge_completed` | `speaking_challenge_id`, `duration_seconds` | A speaking task ends |
| `reminder_enabled` | `hour` | The daily reminder is turned on |
| `reminder_disabled` | none | The daily reminder is turned off |
| `streak_advanced` | `current_streak`, `longest_streak` | The streak grows (HIT-054) |
| `program_finished` | `program_day` | The last day of the programme is completed |

`app_open`, `first_open` and `session_start` are Firebase's own and are collected without us; they are reserved names and cannot be logged by hand.

**The reminder carries the hour, not the time.** What the product asks is whether people pick mornings or evenings. An exact minute makes every bucket smaller for no extra answer.

## Where each is raised

Each event is raised once, from the one place that sees the moment happen. A number counted twice is as wrong as one never counted.

| Event | From | Raised when |
|---|---|---|
| `sign_up` | `RegistrationController` | An account is created, with `method` `password`. A registration that fails is not counted. |
| `login` | `SignInController` | A sign-in works, with `method` `password`. A refused one is not counted. |
| `training_started` | `ExerciseContainerScreen` | A day is begun. A day carried on from the device was counted when it began. |
| `exercise_started` | `ExerciseContainerScreen` | The first exercise of a day just begun, and each exercise the day moves on to. |
| `exercise_completed` | `ExerciseContainerScreen` | An exercise is completed. A skipped one is not. |
| `training_completed` | `ExerciseContainerScreen` | The day ends on the screen with something completed: by its last exercise or ended early. `exercise_count` is what was completed, and `duration_minutes` the time worked, rounded up as on the account (`trainingMinutes`). A day with nothing completed is not a training day, and one that had ended before the screen opened was counted when it ended. |
| `tongue_twister_completed` | `TongueTwisterView` | A twister of the set gets its repetitions. |
| `speaking_challenge_started` | `SpeakingChallengeView` | The speaking phase begins, once the preparation is over. |
| `speaking_challenge_completed` | `SpeakingChallengeView` | The speaking ends, by its time or by "Bitirdim". `duration_seconds` is the seconds the clock ran, so time the session spent paused is not counted. A speaking left before its end, for another challenge or another screen, is not completed. |
| `streak_advanced` | `TrainingDayRecorder` | Recording a day moves the streak, which happens once for a date: a retry of a half-recorded day finds it counted. After a gap the run reached is 1. |

**`presentation_type` is the type's name in snake case** (`tongue_twister`, `timed_reading`), since a string value has to be lower case. A test builds the exercise events for every exercise the content ships, so content that could not be reported fails a test instead of a session.

**Nothing waits for analytics.** An event is sent and not awaited, and the service swallows what its calls throw, so a slow or failing report never holds up the day.

## What never goes in an event

- **No personal data.** No email, no display name, no text a user typed or read. Every parameter is an id, a count or a duration, and a string value has to look like a content id: lower case, starting with a letter. An email or a name cannot match that, so `AnalyticsEvent` throws rather than sending it.
- **No exercise content.** Ids only. The words of a twister live in `assets/content/` and can be looked up from the id (`CONTENT_SCHEMA.md`).
- **No audio, ever.** Recording is post-MVP (#78) and is local to the device.
- **The user id is the Firebase uid** and nothing else. `setUserId` takes that uid, which is what the data model already keys on (`FIRESTORE_MODEL.md`). `reportingIdentityProvider` sets it when someone signs in and clears it when they sign out, for analytics and crash reports alike; the app root keeps it listened to. While the account is still being read nothing is sent, since that is not the same as nobody signed in.

## Debug builds do not report

`AppBootstrap` calls `setCollectionEnabled(!kDebugMode)`, so a developer running the app does not add taps to the product's numbers. A release build reports normally.

Under `flutter test` the default provider is `NoopAnalyticsService`, which records nothing: a test that forgets to override logs into a void rather than into the console. Bootstrap overrides the provider with the Firebase service once Firebase is initialised, because a provider body cannot await.

## Failure is never the caller's problem

`FirebaseAnalyticsService` catches what its calls throw and prints one line. A finished exercise must not fail to be saved because the analytics call after it did.

## Verifying it

Analytics events are batched, so they appear in the console with a delay of up to a few hours. For a quick check, turn on debug view for the device and watch events arrive live:

```bash
# Android
adb shell setprop debug.firebase.analytics.app com.posinowa.hitup
# turn it off again
adb shell setprop debug.firebase.analytics.app .none.
```

```bash
# iOS: pass -FIRAnalyticsDebugEnabled as a launch argument in Xcode
```

Then open **Firebase console, Analytics, DebugView**. Note that a debug build has collection off, so to see events in DebugView, run a release build or call `setCollectionEnabled(true)` from the code under test.

Console access is needed for that last step, which the repository cannot do on its own.
