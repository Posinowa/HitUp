# Home

**STATUS: IMPLEMENTED (HIT-021B, #23).** The first of the main app's tabs: today's training, with one way into it.

## What it shows

Under the app's cut paper, with the sun where it stands at this hour (`sunHeightAt`: rising in the morning, highest early in the afternoon, behind the hills at night), the user is greeted by the hour and their first name, with the date as Turkish writes it, then their streak and the minutes on the account, then today.

| Today | The card says | The button |
|---|---|---|
| A day to run | The day by its title ("1. gün: Nefesin temeli"), its exercises and the minutes it takes | "Antrenmana başla" |
| A session the device kept for this same day | How far it got ("7 egzersizin 3 tanesi tamam") | "Kaldığınız yerden devam edin" |
| A day trained today | "Bugünkü antrenman tamam", and the next day | None; a quiet "Sıradaki günü şimdi başlat", since the programme allows it (`TRAINING.md`) |
| A day finished today, still on its way to the account | The same, and that it will be recorded once online | None |
| The programme finished | "Programı tamamladınız", the minutes and the longest streak | None |
| A day with nothing to run | "Bugün çalışılacak egzersiz yok." | None |

One primary button at most, as the issue asks.

**The day's own notes.** A day assumed while offline with nothing kept (`TRAINING.md`) says it will be confirmed once online; a day some of whose exercises this build lacks says how many, and runs without them.

| File | Holds |
|---|---|
| `features/home/presentation/home_screen.dart` | `HomeScreen`, `HomeLabelsTr`, `sunHeightAt` |
| `features/home/application/home_providers.dart` | The finished programme's report |
| `features/training/application/today_status.dart` | `TodayStatus`, `todayStatusProvider` |
| `features/training/presentation/open_today.dart` | `openToday` |
| `shared/providers/clock_provider.dart` | `clockProvider`, the wall clock a test can set |

Today lives with training, not with home: it is put together from the training engine, the session store and the pending days, and home only shows it.

## Where today comes from

`todayStatusProvider` puts together what the screen shows (`TodayStatus`):

1. **Today's training** is `TodayTrainingEngine.todayFor` (`TRAINING.md`).
2. **A day finished on this device and not recorded yet moves today on.** Offline, the account still has the day before it, and would offer that day again; today is the day after the latest one waiting for this account (`TodayTrainingEngine.build`). Once it is recorded, the account says the same.
3. **A session the device kept** is offered to carry on with only when it is unfinished and for this same day, with the same exercises. A session for another day, or one already finished, is left for the exercise screen to replace.
4. **A day finished today and not yet recorded** is found among the same pending days, by today's date.

It is worked out again when the programme day moves on, which is what recording a finished day does, and when the screen comes back from a session, since the session it left may be finished or cleared.

**A day trained today** (`TodayStatus.trainedToday`) is the account's `lastTrainingDate` being today, or a pending day for today. The second matters offline: the streak and the programme day are transactions and wait for the network, so without it the finished day would be offered again.

## Opening a day

`openToday` pushes the exercise screen over the tabs, at `/app/session`, with today's training (`TodayTraining`). With a session kept for the day, it first restores that session into `TrainingSessionController`, so the screen carries on with it rather than starting again (`TRAINING.md`). The route takes its day from the push and has no link of its own: opened without one, from a link or a restored location, it goes home. It is under `/app/`, so the guard keeps it from anyone signed out (`STARTUP.md`).

## The finished programme is reported once

Home is where a finished programme is known: the engine says so once the programme day has moved past the last day. `program_finished` (`ANALYTICS.md`) is reported the first time home sees that for an account, and the day reported is kept on the device (`program_finished_reported_<uid>`), so later visits do not report it again. A new install reports it once more, which is the price of keeping it off the account.

## When the account cannot be read

Offline with nothing kept, the engine assumes day one and home says the day will be confirmed. Any other failure, a profile that cannot be read, is shown with a way to try again (`ERROR_HANDLING.md`); a pull down asks again too. A pull down that fails shows the same failure and is caught there: let through, it would reach the crash reporter as a crash (`CRASH_REPORTING.md`).

## Tests

`test/features/home/home_screen_test.dart` covers every row above with fakes for the account, the device's session and pending days, and the bundled content read once beforehand: the greeting, the date and the figures, starting and coming back, carrying on with a kept session and not with another day's, another exercise list's or a finished one, a day trained today and a day finished but not yet recorded, another account's pending day, the programme day moving on, the finished programme reported once and not again, offline, a failure and its retry, and the training day's route without a day. `home_layout_test.dart` shows a day to run, a day done and the finished programme at 390x844, 360x640 and 320x568, at normal and 130% text, with the app's fonts, and checks the start button is in view without scrolling on the first two.
