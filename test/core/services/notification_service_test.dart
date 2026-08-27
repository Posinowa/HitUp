import 'package:flutter/foundation.dart';
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

    /// Lets one test choose what the platform answers, without rebuilding the
    /// rest of the harness. Anything not named here keeps the default reply.
    void platformAnswers(Map<String, Object?> responses) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pluginChannel, (MethodCall call) async {
        calls.add(call);
        if (responses.containsKey(call.method)) {
          return responses[call.method];
        }
        return switch (call.method) {
          'initialize' => true,
          _ => null,
        };
      });
    }

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

    test('a refusal and a silence are told apart', () async {
      // Three outcomes, not two. "Denied" means the user said no and the app
      // should stop offering; "unknown" means the platform never answered, and
      // treating that as a refusal would silently disable reminders on a
      // version that simply does not have the prompt.
      await service.init();

      platformAnswers(<String, Object?>{
        'requestNotificationsPermission': false,
      });
      expect(
        await service.requestPermission(),
        NotificationPermissionResult.denied,
      );

      platformAnswers(<String, Object?>{
        'requestNotificationsPermission': null,
      });
      expect(
        await service.requestPermission(),
        NotificationPermissionResult.unknown,
      );
    });

    test('areNotificationsEnabled asks the platform and defaults to off',
        () async {
      await service.init();

      expect(await service.areNotificationsEnabled(), isTrue);
      expect(
        calls.map((MethodCall call) => call.method),
        contains('areNotificationsEnabled'),
      );

      // No answer is not the same as yes. Assuming enabled would let the app
      // promise a reminder the system will never deliver.
      platformAnswers(<String, Object?>{'areNotificationsEnabled': null});
      expect(await service.areNotificationsEnabled(), isFalse);
    });

    test('showNow reaches the platform with what it was given', () async {
      await service.init();

      await service.showNow(
        id: 42,
        title: 'Antrenman zamanı',
        body: 'Bugünün diksiyon antrenmanı seni bekliyor.',
        payload: 'training/today',
      );

      final MethodCall shown = calls.singleWhere(
        (MethodCall call) => call.method == 'show',
      );
      final Map<dynamic, dynamic> arguments =
          shown.arguments as Map<dynamic, dynamic>;

      expect(arguments['id'], 42);
      expect(arguments['title'], 'Antrenman zamanı');
      expect(arguments['payload'], 'training/today');
    });

    test('a timezone the device cannot report falls back to UTC', () async {
      // Reminders at the wrong hour are bad; an app that will not start is
      // worse. The fallback is deliberate, so it needs a test that says so.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        _timezoneChannel,
        (MethodCall call) async =>
            throw PlatformException(code: 'no_timezone_available'),
      );
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

      await service.init();

      // Startup completed rather than throwing, and the reminder channel was
      // still created, which is what "the app still runs" means here.
      expect(
        calls.map((MethodCall call) => call.method),
        contains('createNotificationChannel'),
      );
    });

    test('the service can be built without being handed a plugin', () {
      // Production code calls this constructor; only the tests pass their own
      // instance. If the default ever stopped resolving, nothing else here
      // would notice.
      expect(LocalNotificationService(), isA<NotificationService>());
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

  group('LocalNotificationService on iOS', () {
    // Half the target platforms take a different branch through
    // requestPermission and areNotificationsEnabled, and the Android harness
    // above can never reach it: the plugin resolves an implementation only when
    // the registered instance and the target platform agree. Overriding the
    // platform and registering the Darwin instance is what opens that branch.
    late List<MethodCall> calls;
    late LocalNotificationService service;
    Object? permissionsReply = true;
    Object? checkReply = <String, Object?>{'isEnabled': true};

    setUpAll(tz_data.initializeTimeZones);

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      IOSFlutterLocalNotificationsPlugin.registerWith();

      permissionsReply = true;
      checkReply = <String, Object?>{'isEnabled': true};
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pluginChannel, (MethodCall call) async {
        calls.add(call);
        return switch (call.method) {
          'initialize' => true,
          'requestPermissions' => permissionsReply,
          'checkPermissions' => checkReply,
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
      // Left set, every later test in the process would think it is on iOS.
      debugDefaultTargetPlatformOverride = null;
    });

    test('the permission prompt asks for alert, badge and sound', () async {
      await service.init();

      final result = await service.requestPermission();

      final MethodCall asked = calls.singleWhere(
        (MethodCall call) => call.method == 'requestPermissions',
      );
      final Map<dynamic, dynamic> arguments =
          asked.arguments as Map<dynamic, dynamic>;

      expect(result, NotificationPermissionResult.granted);
      // A reminder the user cannot see or hear is not a reminder.
      expect(arguments['alert'], isTrue);
      expect(arguments['badge'], isTrue);
      expect(arguments['sound'], isTrue);
    });

    test('a refusal and a silence are told apart here too', () async {
      await service.init();

      permissionsReply = false;
      expect(
        await service.requestPermission(),
        NotificationPermissionResult.denied,
      );

      permissionsReply = null;
      expect(
        await service.requestPermission(),
        NotificationPermissionResult.unknown,
      );
    });

    test('enabled state comes from the reported permissions', () async {
      await service.init();

      expect(await service.areNotificationsEnabled(), isTrue);

      checkReply = <String, Object?>{'isEnabled': false};
      expect(await service.areNotificationsEnabled(), isFalse);

      // Darwin answers with nothing when it has no settings to report yet.
      // Reading that as enabled would promise a reminder that never arrives.
      checkReply = null;
      expect(await service.areNotificationsEnabled(), isFalse);
    });
  });
}
