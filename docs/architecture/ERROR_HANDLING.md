# Error Handling

**STATUS: APPROVED (HIT-066)**

Two rules drive everything below:

1. **No raw exception ever reaches the screen.** A user must never see
   `[firebase_auth/wrong-password] The password is invalid`.
2. **No silent swallow.** An error can be handled badly, but it can never be
   caught and dropped, leaving the app doing nothing with no explanation.

## The three steps

```text
thrown error  ->  mapErrorToFailure()  ->  Failure (a code)  ->  failureMessage()  ->  a sentence
                  lib/core/errors/         no user text          failure_messages.dart
```

| File | Holds | Never holds |
|---|---|---|
| `failure_code.dart` | Stable identifiers | Copy |
| `failure.dart` | Failure types, retryability | Copy |
| `failure_mapper.dart` | Every plugin error code we understand | Copy |
| `failure_messages.dart` | **All** user facing copy | Plugin knowledge |
| `failure_presenter.dart` | Snack bar and dialog patterns | Copy, plugin knowledge |

The split exists so that changing a sentence never means touching mapping
logic, and adding a new Firebase error never means touching copy.

## Why the copy is compiled in and not an asset

Error copy is what gets shown **when loading fails**. If the messages lived in
`assets/`, a failure to load assets would leave nothing to show. The table is a
`const` map for that reason, and only for that reason. When real localisation
arrives it replaces `failure_messages.dart`; nothing else changes.

## Failure types

| Type | Meaning | `isRetryable` |
|---|---|---|
| `AuthFailure` | Credentials, session, account state | `false` |
| `NetworkFailure` | Could not reach the service | `true` |
| `PermissionFailure` | Reached it, was refused | `false` |
| `ContentFailure` | Bundled content or media is missing or broken | `false` |
| `DataFailure` | Stored data read or write problem | `true` |
| `UnknownFailure` | Nothing recognised it | `true` |

`Failure` is **sealed**, so a `switch` over it is checked for exhaustiveness. A
new failure type makes every handler that forgot it fail to compile rather than
fall through unnoticed.

`isRetryable` exists so the UI does not offer "try again" on a wrong password,
which only wastes the user's time.

## Example: a repository

Throw `AppException` with a code when the layer already knows what went wrong.
The mapper keeps that meaning instead of guessing.

```dart
Future<TrainingProgram> loadProgram() async {
  final raw = await rootBundle.loadString('assets/content/program.json');
  final json = jsonDecode(raw);
  if (json is! Map<String, dynamic>) {
    throw const AppException(
      'program.json root is not an object',
      code: FailureCode.contentMalformed,
    );
  }
  return TrainingProgram.fromJson(json);
}
```

## Example: a provider or controller

Catch broadly, map once, and hold the `Failure` in state. Never `catch` and
return silently.

```dart
Future<void> signIn(String email, String password) async {
  state = const AsyncValue.loading();
  try {
    await _authRepository.signIn(email, password);
    state = const AsyncValue.data(null);
  } catch (error, stackTrace) {
    // One call handles Firebase, connectivity, platform and anything else.
    state = AsyncValue.error(mapErrorToFailure(error), stackTrace);
  }
}
```

## Example: a screen

Screens never build error text. They hand the failure to a presenter.

```dart
ref.listen<AsyncValue<void>>(signInControllerProvider, (_, next) {
  final error = next.error;
  if (error is Failure) {
    showFailureSnackBar(context, error, onRetry: _submit);
  }
});
```

`onRetry` is optional. The retry action appears only when the failure is
retryable **and** a callback was supplied, so passing one is always safe.

For a blocking problem, use the dialog instead:

```dart
await showFailureDialog(context, failure, onRetry: _reload);
```

## Adding a new failure code

1. Add the constant to `FailureCode` **and to `FailureCode.all`**.
2. Add its sentence to `failureMessagesTr`.
3. Map the underlying error to it in `failure_mapper.dart`.

Steps 1 and 2 are enforced. `failure_messages_test.dart` fails if a constant is
declared but left out of `FailureCode.all`, if a listed code has no copy, or if
the table holds copy no code refers to. Step 3 is not enforced, because only a
human knows which underlying error should produce the new code.

The first of those checks reads `failure_code.dart` as text, because Dart cannot
enumerate static constants at runtime without mirrors. Without it a constant
could be added, left out of `all`, and slip past the other two checks unnoticed.

## Crash reporting

`Failure.technicalDetail` carries the original error text. It is **never**
rendered. It exists so HIT-065 can attach real diagnostics to a Crashlytics
report while the user still sees a plain sentence.

## Related docs

- `ARCHITECTURE.md`
- `CONTENT_SCHEMA.md`
