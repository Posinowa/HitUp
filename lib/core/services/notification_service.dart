/// Posting and scheduling on-device notifications.
///
/// HitUp has no server and no Firebase Cloud Messaging (see `ARCHITECTURE.md`
/// hard rule 2). Every notification this app will ever show is scheduled by the
/// device, for that same device. See `docs/architecture/NOTIFICATIONS.md` for
/// the decisions behind this file.
///
/// [NotificationService] is the contract callers depend on;
/// [LocalNotificationService] is the only code in the repo that talks to the
/// notification plugin. Presentation code depends on the contract, never on the
/// plugin, for the same reason it does not touch `FirebaseAuth` directly: the
/// plugin is a platform detail, and a fake implementation of the contract is
/// what makes the reminder feature (HIT-058, HIT-059) testable without a real
/// device.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Result of asking the operating system for permission to post notifications.
enum NotificationPermissionResult {
  /// The user allowed notifications.
  granted,

  /// The user refused, or had already refused and the system did not re-prompt.
  ///
  /// The operating system does not distinguish "just said no" from "said no
  /// once, months ago, and will not be asked again" in a way that is reliable
  /// across both platforms. Callers should treat this as "no notifications",
  /// and send the user to the system settings screen rather than asking again.
  denied,

  /// The platform gave no answer at all.
  ///
  /// This is not the same as [denied]. It means the request could not be
  /// resolved (an unsupported platform, or a plugin call that returned null),
  /// so the caller knows the permission state is unknown rather than refused.
  unknown,
}

/// Posts and schedules on-device notifications.
abstract class NotificationService {
  /// Prepares the plugin, the Android notification channel, and the timezone
  /// database.
  ///
  /// Safe to call more than once; later calls do nothing. Must complete before
  /// any other method is called.
  Future<void> init();

  /// Asks the operating system for permission to post notifications.
  ///
  /// Call this when the user turns reminders on, never at startup: a permission
  /// prompt shown before the user knows what it is for is the most common way
  /// to get it refused permanently.
  Future<NotificationPermissionResult> requestPermission();

  /// Whether notifications are currently allowed for this app.
  Future<bool> areNotificationsEnabled();

  /// Shows a notification immediately.
  ///
  /// Used by the reminder settings screen to let the user confirm that
  /// reminders actually arrive on their device.
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// Schedules a notification to repeat every day at [hour]:[minute] in the
  /// user's local time.
  ///
  /// The time is a wall-clock time, not an offset: a reminder set for 09:00
  /// stays at 09:00 after a daylight-saving change or after the user travels.
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  });

  /// Cancels one scheduled or visible notification.
  Future<void> cancel(int id);

  /// Cancels everything this app has scheduled or is showing.
  Future<void> cancelAll();
}

/// [NotificationService] backed by `flutter_local_notifications`.
///
/// Everything platform-specific about notifications lives here and nowhere
/// else. See `docs/architecture/NOTIFICATIONS.md` for the decisions this class
/// implements, in particular why reminders are scheduled inexactly.
class LocalNotificationService implements NotificationService {
  /// Creates the service.
  ///
  /// [plugin] exists so tests can pass their own instance; production code
  /// should use the default.
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Android channel that carries daily training reminders.
  ///
  /// The id is written into every notification and into the system settings
  /// entry the user sees. Changing it orphans the old channel: Android keeps
  /// the previous one, with whatever the user had configured on it, and starts
  /// a fresh one at defaults. Treat this string as permanent.
  static const String remindersChannelId = 'hitup_daily_reminders';

  /// Channel name shown to the user in Android notification settings.
  static const String remindersChannelName = 'Günlük antrenman hatırlatması';

  /// Channel description shown to the user under the channel name.
  static const String remindersChannelDescription =
      'Seçtiğin saatte günlük diksiyon antrenmanını hatırlatır.';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) {
      return;
    }

    await _configureTimezone();

    await _plugin.initialize(
      settings: const InitializationSettings(
        // The launcher icon is a stand-in. Android draws notification icons as
        // a flat white silhouette, so a full-colour launcher icon renders as a
        // white blob. A dedicated monochrome icon is part of the icon asset
        // work in HIT-081; this line is what changes when that lands.
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // All four request flags are false on purpose. Passing true here makes
        // iOS show the permission prompt during startup, before the user has
        // seen anything about reminders. Permission is asked for in
        // requestPermission(), at the moment the user turns reminders on.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          requestProvisionalPermission: false,
        ),
      ),
    );

    await _createAndroidChannel();

    _initialized = true;
  }

  /// Loads the timezone database and points `tz.local` at the device's zone.
  ///
  /// Without this, `tz.local` is UTC and every reminder fires at the wrong
  /// hour for anyone not on UTC, which is everyone using this app.
  Future<void> _configureTimezone() async {
    tz_data.initializeTimeZones();

    try {
      final localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone.identifier));
    } on Object catch (error) {
      // Falling back to UTC is wrong for the user but better than failing
      // startup: the app still runs, and the reminder is off by the user's
      // offset rather than absent. Anything thrown here is either a platform
      // channel failure or a zone name the database does not know, and neither
      // is recoverable at this layer.
      debugPrint(
        'HIT-057: could not resolve the local timezone, '
        'reminders will use UTC. Cause: $error',
      );
    }
  }

  /// Registers the reminder channel with Android.
  ///
  /// Android 8 and later ignore per-notification importance and take it from
  /// the channel, which is fixed at creation time. Creating the channel up
  /// front, rather than on first use, is also what puts the entry in system
  /// settings so the user can find it.
  Future<void> _createAndroidChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return;
    }

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        remindersChannelId,
        remindersChannelName,
        description: remindersChannelDescription,
        importance: Importance.defaultImportance,
      ),
    );
  }

  @override
  Future<NotificationPermissionResult> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      // Android 13 and later gate notifications behind a runtime prompt. On
      // older versions the plugin reports true without showing anything.
      return _toResult(await android.requestNotificationsPermission());
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return _toResult(
        await ios.requestPermissions(alert: true, badge: true, sound: true),
      );
    }

    return NotificationPermissionResult.unknown;
  }

  static NotificationPermissionResult _toResult(bool? granted) =>
      switch (granted) {
        true => NotificationPermissionResult.granted,
        false => NotificationPermissionResult.denied,
        null => NotificationPermissionResult.unknown,
      };

  @override
  Future<bool> areNotificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final permissions = await ios.checkPermissions();
      return permissions?.isEnabled ?? false;
    }

    return false;
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) =>
      _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _reminderDetails,
        payload: payload,
      );

  @override
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) =>
      _plugin.zonedSchedule(
        id: id,
        scheduledDate: nextInstanceOfTime(hour, minute),
        title: title,
        body: body,
        payload: payload,
        notificationDetails: _reminderDetails,
        // Inexact on purpose. Android reserves exact alarms for apps whose core
        // function is precise timing, alarm clocks and calendars, and Google's own
        // guidance is that everything else should schedule inexactly. A training
        // reminder that arrives a few minutes late is not a defect; requesting the
        // exact-alarm permission for it would be, and it puts the release at risk
        // of a Play policy rejection. AllowWhileIdle is what stops the reminder
        // from being swallowed entirely while the phone is in low-power idle,
        // which is exactly the state a phone is in overnight.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Repeat every day at the same wall-clock time.
        matchDateTimeComponents: DateTimeComponents.time,
      );

  static const NotificationDetails _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      remindersChannelId,
      remindersChannelName,
      channelDescription: remindersChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// The next moment at [hour]:[minute] in the device's local zone.
  ///
  /// Returns tomorrow when today's time has already passed.
  ///
  /// [now] defaults to the current time and exists so tests can pin it. This is
  /// the one piece of scheduling logic worth verifying without a device, and it
  /// cannot be verified at all while the answer depends on when the test runs.
  @visibleForTesting
  static tz.TZDateTime nextInstanceOfTime(
    int hour,
    int minute, {
    tz.TZDateTime? now,
  }) {
    now ??= tz.TZDateTime.now(tz.local);
    final today = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (today.isAfter(now)) {
      return today;
    }

    // Built from calendar parts rather than `add(Duration(days: 1))`. A
    // duration is 24 fixed hours, so adding one across a daylight-saving
    // boundary lands an hour early or late; asking for "the same clock time on
    // day + 1" keeps a 09:00 reminder at 09:00. The constructor normalises an
    // out-of-range day into the next month by itself.
    return tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
