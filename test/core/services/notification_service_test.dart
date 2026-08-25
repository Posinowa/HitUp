import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The channel `flutter_local_notifications` talks to. Faking it is what lets
/// these tests exercise the real service without a device or an emulator.
const MethodChannel _pluginChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

/// The channel `flutter_timezone` talks to.
const MethodChannel _timezoneChannel = MethodChannel('flutter_timezone');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('nextInstanceOfTime', () {
    setUpAll(tz_data.initializeTimeZones);

    test('returns today when the time has not passed yet', () {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      final now = tz.TZDateTime(tz.local, 2026, 8, 24, 7, 30);

      final next = LocalNotificationService.nextInstanceOfTime(9, 0, now: now);

      expect(next.year, 2026);
      expect(next.month, 8);
      expect(next.day, 24);
      expect(next.hour, 9);
      expect(next.minute, 0);
    });

    test('returns tomorrow when the time has already passed today', () {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      final now = tz.TZDateTime(tz.local, 2026, 8, 24, 21, 0);

      final next = LocalNotificationService.nextInstanceOfTime(9, 0, now: now);

      expect(next.day, 25);
      expect(next.hour, 9);
    });

    test('treats the exact reminder minute as already passed', () {
      // Otherwise a reminder scheduled at the very moment it is due would be
      // handed to the platform as "now", which fires immediately instead of
      // tomorrow.
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      final now = tz.TZDateTime(tz.local, 2026, 8, 24, 9, 0);

      final next = LocalNotificationService.nextInstanceOfTime(9, 0, now: now);

      expect(next.day, 25);
      expect(next.hour, 9);
    });

    test('rolls over into the next month', () {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      final now = tz.TZDateTime(tz.local, 2026, 1, 31, 23, 0);

      final next = LocalNotificationService.nextInstanceOfTime(9, 0, now: now);

      expect(next.month, 2);
      expect(next.day, 1);
      expect(next.hour, 9);
    });

    test('rolls over into the next year', () {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      final now = tz.TZDateTime(tz.local, 2026, 12, 31, 23, 0);

      final next = LocalNotificationService.nextInstanceOfTime(9, 0, now: now);

      expect(next.year, 2027);
      expect(next.month, 1);
      expect(next.day, 1);
      expect(next.hour, 9);
    });

    test('keeps the wall-clock hour across a daylight-saving change', () {
      // Europe/Berlin springs forward at 02:00 on 29 March 2026, so that day is
      // 23 hours long. Adding a fixed 24-hour Duration would land at 10:00 and
      // move a 09:00 reminder for every user who observes DST. Istanbul is not
      // used here precisely because Turkey stopped changing its clocks, so it
      // cannot catch this class of bug.
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
      final now = tz.TZDateTime(tz.local, 2026, 3, 28, 23, 0);

      final next = LocalNotificationService.nextInstanceOfTime(9, 0, now: now);

      expect(next.day, 29);
      expect(next.hour, 9, reason: 'a 09:00 reminder must stay at 09:00');
      expect(next.minute, 0);
    });
  });

  group('LocalNotificationService', () {
    late List<MethodCall> calls;
    late LocalNotificationService service;

    setUpAll(tz_data.initializeTimeZones);

    setUp(() {
      // On a device the Flutter engine registers the platform implementation
      // during plugin registration. A unit test has no engine, so the plugin's
      // platform instance is never set and every call throws before it reaches
      // the channel. Registering it by hand is what makes the real service
      // testable off-device.
      AndroidFlutterLocalNotificationsPlugin.registerWith();

      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pluginChannel, (MethodCall call) async {
        calls.add(call);
        return switch (call.method) {
          'initialize' => true,
          'requestNotificationsPermission' => true,
          'requestPermissions' => true,
          'areNotificationsEnabled' => true,
          _ => null,
        };
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        _timezoneChannel,
        (MethodCall call) async => 'Europe/Istanbul',
      );

      service = LocalNotificationService(
        plugin: FlutterLocalNotificationsPlugin(),
      );
    });

    tearDown(() {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_pluginChannel, null);
      messenger.setMockMethodCallHandler(_timezoneChannel, null);
    });

    test('init creates the reminder channel', () async {
      await service.init();

      final createChannel = calls
          .where(
              (MethodCall call) => call.method == 'createNotificationChannel')
          .toList();

      expect(createChannel, hasLength(1));
      expect(
        (createChannel.single.arguments as Map<dynamic, dynamic>)['id'],
        LocalNotificationService.remindersChannelId,
      );
    });

    test('init runs only once no matter how often it is called', () async {
      await service.init();
      final int afterFirst = calls.length;

      await service.init();

      expect(calls.length, afterFirst);
    });

    test('init does not ask for permission', () async {
      // The permission prompt belongs to the moment the user turns reminders
      // on. Asking during startup is the reliable way to get it refused.
      await service.init();

      expect(
        calls.map((MethodCall call) => call.method),
        isNot(contains('requestNotificationsPermission')),
      );
      expect(
        calls.map((MethodCall call) => call.method),
        isNot(contains('requestPermissions')),
      );
    });

    test('requestPermission reports a granted result', () async {
      await service.init();

      final result = await service.requestPermission();

      expect(result, NotificationPermissionResult.granted);
    });

    test('scheduleDaily schedules inexactly and repeats on time', () async {
      await service.init();

      await service.scheduleDaily(
        id: 1,
        hour: 9,
        minute: 0,
        title: 'Antrenman zamanı',
        body: 'Bugünün diksiyon antrenmanı seni bekliyor.',
      );

      final scheduled = calls.singleWhere(
        (MethodCall call) => call.method == 'zonedSchedule',
      );
      final arguments = scheduled.arguments as Map<dynamic, dynamic>;

      // An exact alarm would need a restricted permission this app must not
      // request. See docs/architecture/NOTIFICATIONS.md.
      final platformSpecifics =
          arguments['platformSpecifics'] as Map<dynamic, dynamic>;
      expect(
        platformSpecifics['scheduleMode'],
        AndroidScheduleMode.inexactAllowWhileIdle.name,
      );
      // Repeat daily at the same wall-clock time.
      expect(
        arguments['matchDateTimeComponents'],
        DateTimeComponents.time.index,
      );
    });

    test('cancel and cancelAll reach the platform', () async {
      await service.init();

      await service.cancel(7);
      await service.cancelAll();

      expect(
        calls.map((MethodCall call) => call.method),
        containsAllInOrder(<String>['cancel', 'cancelAll']),
      );
    });
  });
}
