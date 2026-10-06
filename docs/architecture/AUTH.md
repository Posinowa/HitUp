# Authentication

**STATUS: IMPLEMENTED (HIT-016)** for email and password, **with the rules and controllers of its forms (HIT-017 to HIT-019)**. The screens follow, and the auth guard is HIT-020.

## Layers

```text
screen  ->  controller  ->  AuthRepository       (domain interface)
                             FirebaseAuthRepository   (data, every decision)
                               AuthGateway        ->  Firebase Auth
                               UserProfileStore   ->  Cloud Firestore
```

| File | Holds |
|---|---|
| `features/auth/domain/models/auth_user.dart` | `AuthUser`: uid, email, display name. No Firebase type |
| `features/auth/domain/repositories/auth_repository.dart` | The interface every caller uses |
| `features/auth/data/firebase_auth_repository.dart` | Registration, rollback, trimming, the name limit |
| `features/auth/data/auth_gateway.dart` | The Firebase Auth calls, and nothing else |
| `features/auth/data/user_profile_store.dart` | The documents a new account starts with |
| `shared/providers/auth_providers.dart` | `authRepositoryProvider`, `authStateChangesProvider` |

No widget touches `FirebaseAuth` or `FirebaseFirestore`. CI enforces that for `lib/app` and every `presentation` folder.

## Registration is one step

`register` either leaves an account with its documents, or leaves nothing:

1. The display name is checked against the 100 character limit the rules enforce. Longer is refused before any account exists.
2. The account is created, and named if a name was given.
3. `users/{uid}` and `users/{uid}/preferences/settings` are written in one batch, with the defaults `FIRESTORE_MODEL.md` defines.
4. If step 2's naming or step 3 fails, the new account is deleted again and the original error is thrown.

Without step 4, a failed profile write leaves an account that can sign in but has no `users/{uid}`, a user the data model says cannot exist.

## What the auth guard needs to know (HIT-020)

`authStateChanges` emits the new user **as soon as the account exists**, which is before its documents are written in step 3. If registration then rolls back, deleting the account signs it out and the stream emits null again. Firebase signs a user in when `createUserWithEmailAndPassword` succeeds, so this is the provider's order, not something this repository can change.

Two consequences for whoever builds the guard and the screens behind it:

- A guard that routes on every event sends a registering user to the main screens and, on a rollback, straight back. The registration controller knows when a registration is in progress; the guard should hold its redirect until it finishes.
- A screen reached right after registration can briefly find no `users/{uid}`. That is "not written yet", not an error to show.

## The forms' rules and controllers

What the login, registration and forgot-password screens check and send (HIT-017 to HIT-019); the screens themselves follow.

| File | Holds |
|---|---|
| `features/auth/application/auth_form_rules.dart` | `AuthFormRules`: what each field accepts, as an `AuthFieldProblem` |
| `features/auth/application/common_passwords.dart` | The passwords a new one may not be |
| `features/auth/application/sign_in_controller.dart` | `SignInController` |
| `features/auth/application/registration_controller.dart` | `RegistrationController` |
| `features/auth/application/password_reset_controller.dart` | `PasswordResetController` |
| `features/auth/presentation/auth_labels.dart` | The copy for each `AuthFieldProblem` |

Each controller holds where its request is, as `ERROR_HANDLING.md` describes: loading while it runs, then data or the mapped `Failure`. A second submit while one runs is ignored.

### What the fields accept

| Field | Rule |
|---|---|
| Name (registration) | Required; trimmed, at most 100 characters, the limit the rules enforce |
| Email | Required; trimmed, something, an at sign, something with a dot. Firebase checks the rest |
| Password (login) | Typed. Nothing else: an account may predate the rules below |
| New password | At least 8 characters. No rule about mixing letters, digits and symbols, and no upper limit below Firebase's. Not one of the most used passwords, not one character repeated, not a run of digits, and not the app's name, a word for password, the email, its name part or a part of the name given, with or without digits and symbols around it |
| Repetition | The same password, exactly |

**Why eight.** NIST SP 800-63B (August 2025) asks for no composition rules and for new passwords to be checked against a list of common ones, both of which these rules follow. It asks for 15 characters where a password is the only factor; eight was chosen for this app on purpose, since an account holds a training history rather than anything sensitive, and a long first form costs sign-ups.

**The list** is taken from two public lists in SecLists (MIT licensed): the first 1,000 of the NCSC's 100,000 most used passwords, and the 150 most common Turkish ones, keeping those of eight characters or more. `common_passwords.dart` names both files.

**These rules run on the device.** What the server enforces is Firebase's password policy: six characters by default, or what is set as the password policy in the Firebase console's Authentication settings. Setting its minimum to eight there makes the rule hold for any client; it is a console setting, not something the code can do.

### An unknown address

With email enumeration protection on, the default for Firebase projects made since September 2023, Firebase answers a reset request the same for an address with an account and one without. Where it is off, it reports an unknown address, and `PasswordResetController` treats that as sent. Which addresses have an account cannot be learned from a reset, as it cannot at sign in.

## Errors

The repository **throws**; it does not return failures. The controller calling it maps the error once with `mapErrorToFailure`, as `ERROR_HANDLING.md` describes. Firebase's codes already have a meaning there, for example:

| Firebase | Failure code |
|---|---|
| `wrong-password`, `user-not-found`, `invalid-credential` | `auth.invalid_credentials`, one code on purpose so sign in cannot reveal which emails have an account |
| `email-already-in-use` | `auth.email_in_use` |
| `network-request-failed` | `network.offline` |

## Credentials and personal data

- **Email is trimmed**, because a trailing space from a keyboard suggestion is not part of an address. **Passwords are used exactly as given.**
- Nothing logs a password.
- `AuthUser.toString()` prints the uid only. A user object reaches logs through string interpolation more easily than anyone intends, and the email and name are personal data.

## Using it

```dart
final AuthRepository auth = ref.read(authRepositoryProvider);
await auth.signIn(email: email, password: password);

ref.watch(authStateChangesProvider); // AsyncValue<AuthUser?>
```

In tests and previews, override `authRepositoryProvider` with a fake.

## Testing

`test/features/auth/data/firebase_auth_repository_test.dart` holds every decision above against fake gateway and store implementations. It also reads `firestore.rules` and checks that every field registration writes is one the rules allow, so a field added in Dart but not in the rules fails a test instead of the first real registration.

`FirebaseAuthGateway` and `FirestoreUserProfileStore` are thin enough to hold no logic; they need a device or an emulator, not a unit test.

## Adding a provider later

Google or Apple sign in means a new method on `AuthRepository` and `AuthGateway`, and a profile created the same way on first sign in. No existing caller changes, because `AuthUser` carries no provider type.
