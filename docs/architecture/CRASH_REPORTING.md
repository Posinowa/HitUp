# Crash Reporting

**STATUS: IMPLEMENTED (HIT-065).** The Gradle side was configured with the Firebase apps (HIT-009); this is the Dart side and the wiring.

## The shape

```text
uncaught error  ->  CrashHooks  ->  CrashReporter  ->  Firebase Crashlytics
```

| File | Holds |
|---|---|
| `core/observability/crash_reporter.dart` | `CrashReporter`, `FirebaseCrashReporter`, `NoopCrashReporter` |
| `core/observability/crash_hooks.dart` | Flutter's two uncaught error paths, routed to the reporter |
| `shared/providers/crash_providers.dart` | `crashReporterProvider` |
| `app/bootstrap/app_bootstrap.dart` | Creates the reporter, sets collection, installs the hooks |

Almost nothing in the app calls the reporter. The hooks send what nothing caught; a controller reads the provider only to report a failure it handled itself and still wants to see.

## Both handlers, or half the crashes stay on the device

Flutter raises uncaught errors in two places, and they are separate:

- `FlutterError.onError` for an error inside the framework, such as a build or a layout that threw.
- `PlatformDispatcher.instance.onError` for an error outside it, typically thrown in an async callback with nobody awaiting.

`CrashHooks.install` sets both. It **keeps the handler Flutter had** and calls it as well, so an error still prints during development and whatever the framework wanted to do with it still happens. It returns a function that puts the previous handlers back, which is what lets a test install the hooks without leaking them into the next test.

The platform handler returns true, meaning handled. False would hand the error back to the platform to end the app with, after it has already been reported.

## Debug builds do not report

`AppBootstrap` calls `setCollectionEnabled(!kDebugMode)`, so a crash while developing does not land in the console next to real ones.

The **hooks are installed either way**. They only send to the reporter, and the reporter decides whether anything leaves the device, so installing them in debug costs nothing and keeps one code path instead of two, one of them untested.

Under `flutter test` the default provider is `NoopCrashReporter`, which reports nothing.

## Failure is never the caller's problem

`FirebaseCrashReporter` catches what its calls throw and prints one line. A reporter that threw would turn a handled error into an unhandled one, which is the opposite of its job. A setup failure at startup is not fatal either: the app opens, and the reporter is still handed over so no call site needs a null check.

## What a report may carry

The same rule as analytics (`ANALYTICS.md`): no email, no display name, no text a user typed. `setUserId` takes the Firebase uid, which is what the data model already keys on. Stack traces and error messages come from the code, not from user input; a message built by interpolating user data into it would break that rule, which is why `AuthUser` and `UserProfile` print their uid only.

## Verifying it

There is **no crash button in the app**, in any build. A deliberate crash shipped to users is a crash they experience.

To check reporting end to end, run a release build with collection on and raise one error from a temporary line you then remove:

```dart
// Temporary, never committed:
FirebaseCrashlytics.instance.crash();        // a native crash
throw StateError('HIT-065 verification');    // an uncaught Dart error
```

Crashlytics sends a report on the **next app start**, not at the moment of the crash, so the app has to be reopened before the report appears. New reports show in the Firebase console within a few minutes.

That last step needs console access, which the repository cannot do on its own.
