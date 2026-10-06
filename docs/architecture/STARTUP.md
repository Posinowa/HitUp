# Startup

**STATUS: IMPLEMENTED (HIT-014), with the guard that follows the account afterwards (HIT-020) and onboarding itself (HIT-015, `ONBOARDING.md`).** The main app's tabs are placeholder screens until their own issues build them.

## What happens on a cold start

```text
main  ->  AppBootstrap.init   (Firebase, notifications, analytics, crash reporting)
      ->  HitUpApp            (splash, immediately)
      ->  startupProvider     (onboarding flag + auth state)
      ->  redirect            (onboarding | login | home)
```

| File | Holds |
|---|---|
| `app/startup/startup_destination.dart` | Where the app opens, as a pure function |
| `shared/providers/startup_providers.dart` | The two answers, the deadline, and the retry |
| `features/onboarding/data/onboarding_store.dart` | The device's onboarding flag |
| `features/splash/presentation/splash_screen.dart` | The screen itself |
| `app/router/app_router.dart` | The routes and the one redirect |
| `app/router/route_guard.dart` | Where a change of account or of the flag takes the user (`guardedRoute`) |
| `core/widgets/damga_mark.dart` | The mark, drawn rather than loaded |

## The decision

Two answers in, one destination out, and no waiting inside the decision itself:

| Onboarding done | Signed in | Opens |
|---|---|---|
| no | either | onboarding |
| yes | no | login |
| yes | yes | home |

**Onboarding comes before signing in.** It explains the app to someone who has never seen it, and it is the shorter path. A signed-in user who has somehow not seen it, a fresh install with a restored session, sees it too; that cannot leave anyone stuck, while the other order can.

**The flag is a device flag, not an account one.** Onboarding explains the app; a user who signs out has not forgotten it. It also has to be readable before anyone is signed in, which is exactly when startup needs it.

## Nothing is decided on a guess

`startupProvider` is loading until **both** answers are in. Routing on the first one would send a signed-in user home past onboarding they have not seen.

An error on either side is an error for startup, not a default. The splash then says so and offers to try again, which asks both questions again.

## No infinite splash

The flag read is given `startupTimeout`, eight seconds. Nothing in startup is slow by nature: one preference read and the auth state the SDK already holds. A longer wait is something stuck, and a splash that waits forever is the failure a user cannot do anything about. The deadline turns it into the error state, which has a button.

## The screen

Cut paper, and deliberately quiet: a pale sheet, one horizon, the mark, the name. This is seen every single day, so it is built to get out of the way rather than to impress.

There is **no spinner**. On a screen that is usually gone in a blink, a spinner reads as a stutter rather than as progress. A message appears only when there is something to say.

The error message says what the user can act on. The failure itself goes to the crash reporter (`CRASH_REPORTING.md`), not onto the screen.

## The mark is drawn, not loaded

`DamgaMark` paints the geometry from `assets/branding/logo/damga.svg` with a `CustomPainter`. Rendering the SVG at run time would need a package the project does not have, and a PNG would either blur when scaled or ship at a size nothing asks for.

The cost is a copy of the numbers, so a test reads the master and compares every one of them: the stem, the dots, the strokes, the stroke width, the cap, and the gradient's ends, colours and stops. If the master changes and the copy does not, that test fails.

## After the splash: the guard (HIT-020)

Startup's answer is worked out again whenever the account or the onboarding flag changes, and the router asks its redirect again each time. On the splash the answer is the destination, as above. Anywhere else the redirect hands the answer and the location to `guardedRoute`, a pure function, so every case has a test without a router, a device or Firebase:

| Startup's answer now | Where the user is | Taken to |
|---|---|---|
| onboarding | anywhere but onboarding | onboarding |
| login | the main app, or onboarding | login |
| login | the account screens | stays |
| home | login, forgot password, or onboarding | home |
| home | registration | stays |
| home | the main app | stays |

So signing out anywhere in the app leads to login, as does an account that Firebase ends, and a sign-in on the login screen leads home.

**Registration is left alone.** Firebase signs a new account in before its documents are written, and a failed write deletes the account and signs it out again (`AUTH.md`). Following each of those events would show the main app for a moment and then drop the user on login, without the form or the error. The registration screen opens home itself once registration has finished.

**Registration and forgot password are under login** (`/auth/login/register`, `/auth/login/forgot-password`) and are gone to, not pushed. Login stays under each for the back button, and the location the redirect reads is the screen showing: go_router leaves a pushed route out of it, which would make a signed-in user on registration look like one on login.

**Back to the splash only on an error.** Once startup is known, a sign-in, a sign-out or a finished onboarding is worked out from the answers before it while the new one loads, so it never passes through "loading" and the splash. If an answer fails, the redirect does take the user to the splash, which is where the message and the retry are.
