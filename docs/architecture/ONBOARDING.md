# Onboarding

**STATUS: IMPLEMENTED (HIT-015).** The answers are kept on the device and nothing reads them yet. Syncing them to `users/{uid}/preferences/settings` needs fields the model and the rules do not have (`FIRESTORE_MODEL.md`), so it waits for whatever reads them first.

## What it is

Shown once per device, before the account screens (`STARTUP.md`): three short pages on what the app is, then two questions, one page each and both optional, then login.

| Page | Heading | About |
|---|---|---|
| 1 | Daha net konuşun | Breathing, letter and tongue-twister exercises |
| 2 | Günde birkaç dakika | A short session a day, as long as the user chooses |
| 3 | Bir alışkanlık edinin | The streak, and progress to see |
| 4 | Neyi geliştirmek istiyorsunuz? | What to get better at: any of four goals, or none |
| 5 | Günde ne kadar zaman ayırabilirsiniz? | Minutes a day: 5, 10, 15 or 20, or none |

Every intro page can be skipped (Atla), and the pages swipe as well as moving on with the button. A question has no skipping of its own: it can be left blank, and the button moves on. Skipping is finishing with what was answered so far, usually nothing: either way, onboarding is not shown again. It is not an assessment, and nothing on it is required.

The pages are the account screens' cut paper (`CutPaperScene`), with the sun rising from page to page.

| File | Holds |
|---|---|
| `features/onboarding/domain/onboarding_answers.dart` | `SpeakingGoal`, `dailyMinuteChoices`, `OnboardingAnswers` |
| `features/onboarding/data/onboarding_store.dart` | The flag startup reads |
| `features/onboarding/data/onboarding_answers_store.dart` | The answers |
| `features/onboarding/application/onboarding_controller.dart` | `OnboardingController.finish` |
| `features/onboarding/presentation/onboarding_screen.dart` | `OnboardingScreen` and its copy |
| `core/widgets/cut_paper_scene.dart` | The scene, shared with the account screens |

## Finishing

`finish` keeps the answers, if any were given, then the flag, in that order: a flag kept with its answers lost would never ask again. Then it reports `onboarding_completed` (`ANALYTICS.md`) and asks startup again, and the guard takes the user on (`STARTUP.md`): to login, or home for an account already signed in, such as one a new install restored. If either write fails, the screen says so and offers to try again, and onboarding stays until the flag is kept. Once it has worked, the buttons stay off until the screen is gone, so a second tap cannot keep the answers and report the event twice.

## What is kept

In the device's preferences, apart from the flag (`onboarding_complete`), so nothing about the answers can hold up a cold start:

| Key | Value |
|---|---|
| `onboarding_goals` | The goals' own keys: `clarity`, `confidence`, `public_speaking`, `pronunciation` |
| `onboarding_daily_minutes` | 5, 10, 15 or 20; absent when the question was left |

A goal is stored by its key, not by its name in Dart or its place in the list, so goals can be renamed, reordered or added without misreading what a device holds. A key this build does not know, stored by a later one, is left out rather than failing the read.

## Tests

`onboarding_test.dart` covers the answers, the store, and the screen from the first page to login, or home for an account already signed in: answering, skipping before and after answering, a second tap, a failed write and its retry, and what a screen reader hears. `onboarding_layout_test.dart` goes through every page at 390x844, 360x640 and 320x568, at normal and 130% text, with the app's fonts: nothing overflows, the button stays in view, and no words run past the screen's edges.
