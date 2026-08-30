# Local Notifications

**STATUS: implemented (HIT-057).** The reminder *feature* (a settings screen, a stored reminder time,
turning reminders on and off) is HIT-058 and HIT-059; this doc and the code it describes are the
infrastructure those two build on.

`lib/core/services/notification_service.dart` holds both halves: `NotificationService` is the contract
callers depend on, and `LocalNotificationService` is the only code in the repo that talks to the
notification plugin. They live in one file on purpose, so the contract and the single implementation
of it cannot drift apart in separate places.

## Why local notifications and not push

HitUp has no server (`ARCHITECTURE.md` hard rule 2). A daily training reminder does not need one: the
phone already knows what time it is and what the user asked for. Firebase Cloud Messaging would add a
backend dependency, a delivery service to keep working, and a push token to manage, to send a message
the device could have scheduled itself.

The consequence worth knowing: a reminder exists only on the device that scheduled it. A user who
installs HitUp on a second phone gets no reminder there until they set one up on that phone too.
That is a real limitation, and it is the correct trade for MVP.

## Packages

| Package | Why |
|---|---|
| `flutter_local_notifications` | Posting and scheduling. |
| `timezone` | The timezone database. |
| `flutter_timezone` | Asks the operating system which zone the device is actually in. |

The last two are not optional extras. Scheduling "every day at 09:00" is a wall-clock instruction, and
turning a wall-clock time into a real instant needs a zone. Without them `tz.local` stays UTC and every
reminder fires at the wrong hour for everyone not on UTC.

## Reminders are scheduled inexactly, on purpose

`scheduleDaily` uses `AndroidScheduleMode.inexactAllowWhileIdle`. This is a decision, not a default,
and it should not be "upgraded" to an exact alarm.

Android treats exact alarms as a restricted capability. `USE_EXACT_ALARM` is meant for apps whose core
function is precise timing, alarm clocks and calendars, and both it and `SCHEDULE_EXACT_ALARM` are
subject to a Google Play policy that requires justifying the use. Android's own guidance is explicit:

> Most apps can schedule tasks and events using inexact alarms. If your app's core functionality
> depends on a precisely-timed alarm, such as for an alarm clock app or a calendar app, then it's OK
> to use an exact alarm instead.

A training reminder is not a precisely-timed alarm. It arriving at 09:03 instead of 09:00 is not a
defect. Requesting the exact-alarm permission to avoid those three minutes would put a store review at
risk for nothing.

`allowWhileIdle` is the half that does matter. Without it Android is free to hold the notification
until the device leaves low-power idle, which is exactly the state a phone sitting on a bedside table
is in. That is the difference between "a few minutes late" and "silently never arrives".

## What is in the platform files, and why

### Android

`android/app/build.gradle`

- Java 17 and `coreLibraryDesugaringEnabled`, plus the `desugar_jdk_libs` dependency. The plugin is
  built against `java.time`, which does not exist on older Android versions; desugaring is what
  backports it. The plugin builds itself this way, and an app module on Java 8 without desugaring
  fails to link against it. The desugar version matches the one the plugin declares.
- `minSdk = flutter.minSdkVersion` (24). The plugin requires 24, Firebase requires 23, so 24 is the
  floor the dependencies set. This drops Android 6.0 and below.

`android/app/src/main/AndroidManifest.xml`

- `RECEIVE_BOOT_COMPLETED`. A scheduled alarm does not survive a reboot on its own. Without this the
  reminder stops after the user restarts their phone, and it looks like the feature broke.
- `ScheduledNotificationReceiver` posts a scheduled notification when its alarm fires.
  `ScheduledNotificationBootReceiver` re-registers pending alarms after a reboot or an app update.
  The plugin does not declare these in its own manifest, so the app must.
- `POST_NOTIFICATIONS` is deliberately **not** repeated in the app manifest. It already arrives from
  the plugin's own manifest through the merger; declaring it twice creates two places to keep in sync.

### iOS

`ios/Runner/AppDelegate.swift` points `UNUserNotificationCenter.current().delegate` at the app
delegate. Without it iOS hands a notification tap to the system default handler, the plugin never
learns which notification was tapped, and the callback that would route the user into today's training
never fires.

The deployment target moved from 12.0 to 13.0, in `project.pbxproj` and `AppFrameworkInfo.plist`,
because the plugin's podspec requires iOS 13.

There is no `Info.plist` entry to add. iOS asks for notification permission through the API at the
moment the app requests it, not through a usage-description string like the camera or microphone.

## Permission is requested when the user turns reminders on, never at startup

`init()` deliberately does not ask. The Darwin initialisation flags that would prompt during startup
are all set to `false`, and there is a test asserting that no permission call happens during `init()`.

A permission prompt shown before the user knows what it is for is the reliable way to get it refused,
and on both platforms a refusal is close to permanent: the system stops re-prompting, and the only way
back is the settings app. HIT-058 should call `requestPermission()` from the moment the user switches
reminders on, when the prompt has an obvious reason.

`requestPermission()` returns three outcomes, not two. `unknown` is not a refusal; it means the
platform gave no answer, so the caller can tell "the user said no" apart from "we could not find out".

## Notification icon, still outstanding

`AndroidInitializationSettings('@mipmap/ic_launcher')` is a stand-in. Android draws notification icons
as a flat white silhouette, so a full-colour launcher icon renders as a white blob. A proper monochrome
notification icon is part of the icon asset work in HIT-081. That one line is what changes when it
lands.

## What is verified, and what is not

`test/core/services/notification_service_test.dart` runs against a faked platform channel, so it
exercises the real service without a device: that `init` creates the channel and asks for nothing, that
`scheduleDaily` schedules inexactly and repeats daily, and that the next-occurrence calculation is
right, including that a 09:00 reminder stays at 09:00 across a daylight-saving change.

Those tests cannot prove a notification actually appears. That needs a real device or emulator, and
the acceptance criterion in HIT-057 that asks for it is the one item this work leaves open. The check
to run when a device is available:

1. Launch the app and confirm it starts. Notification setup failures are caught and logged, never
   fatal, so a silent failure here looks like a working app with no reminders.
2. In Android system settings, confirm HitUp lists a "Günlük antrenman hatırlatması" channel.
3. Call `requestPermission()` and confirm Android 13+ shows the runtime prompt.
4. Call `showNow(...)` and confirm the notification appears.
5. Call `scheduleDaily(...)` for a minute or two ahead and confirm it arrives.
6. Reboot the device and confirm the scheduled reminder still arrives, which is what the boot receiver
   and `RECEIVE_BOOT_COMPLETED` exist for.

## Related docs

- [`ARCHITECTURE.md`](ARCHITECTURE.md), the no-backend rule this design follows
- [`../../SECURITY.md`](../../SECURITY.md)
