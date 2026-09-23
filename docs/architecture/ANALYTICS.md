# Analytics

**STATUS: SERVICE AND TAXONOMY IMPLEMENTED (HIT-063).** The call sites land with the screens that raise these events (HIT-064 wiring, #18 onwards). Crash reporting is HIT-065.

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
| `app/bootstrap/app_bootstrap.dart` | Creates the real service and sets collection for the build |

A caller holds `AnalyticsService` and builds an `AnalyticsEvent`. There is no way to log a name of one's own from a screen, which is the point: `training_completed` spelled two ways is two events in the console and a number nobody trusts.

## The events

| Event | Parameters | Raised when |
|---|---|---|
| `sign_up` | `method` | An account is created (Firebase standard event) |
| `login` | `method` | A returning user signs in (Firebase standard event) |
| `onboarding_completed` | none | Onboarding is finished |
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

## What never goes in an event

- **No personal data.** No email, no display name, no text a user typed or read. Every parameter is an id, a count or a duration, and a string value has to look like a content id: lower case, starting with a letter. An email or a name cannot match that, so `AnalyticsEvent` throws rather than sending it.
- **No exercise content.** Ids only. The words of a twister live in `assets/content/` and can be looked up from the id (`CONTENT_SCHEMA.md`).
- **No audio, ever.** Recording is post-MVP (#78) and is local to the device.
- **The user id is the Firebase uid** and nothing else. `setUserId` takes that uid, which is what the data model already keys on (`FIRESTORE_MODEL.md`).

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
