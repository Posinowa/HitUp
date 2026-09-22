import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/bootstrap/app_bootstrap.dart';
import 'package:hitup/core/analytics/analytics_event.dart';
import 'package:hitup/core/analytics/analytics_service.dart';
import 'package:hitup/core/observability/crash_reporter.dart';
import 'package:hitup/core/services/notification_service.dart';
import 'package:hitup/shared/providers/analytics_providers.dart';
import 'package:hitup/shared/providers/crash_providers.dart';
import 'package:hitup/shared/providers/notification_providers.dart';

/// A notification service that records what was asked of it and never touches
/// a platform channel.
///
/// Every method beyond [init] throws. Bootstrap is only entitled to call
/// [init]; anything else it did at startup would be a permission prompt or a
/// scheduled reminder the user never asked for, and these tests should fail if
/// that ever changes rather than quietly allow it.
class _FakeNotificationService implements NotificationService {
  _FakeNotificationService({this.failOnInit = false});

  /// Whether [init] throws, standing in for a device or channel that cannot
  /// set notifications up.
  final bool failOnInit;

  /// How many times [init] was called.
  int initCalls = 0;

  @override
  Future<void> init() async {
    initCalls++;
    if (failOnInit) {
      throw StateError('notification setup failed');
    }
  }

  @override
  Future<NotificationPermissionResult> requestPermission() =>
      throw UnimplementedError('bootstrap must not ask for permission');

  @override
  Future<bool> areNotificationsEnabled() =>
      throw UnimplementedError('bootstrap must not read permission state');

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) =>
      throw UnimplementedError('bootstrap must not post a notification');

  @override
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) =>
      throw UnimplementedError('bootstrap must not schedule anything');

  @override
  Future<void> cancel(int id) =>
      throw UnimplementedError('bootstrap must not cancel anything');

  @override
  Future<void> cancelAll() =>
      throw UnimplementedError('bootstrap must not cancel anything');
}

/// An analytics service that records what startup asked of it.
///
/// Logging throws: startup has nothing to report yet, and an event sent before
/// the first frame would be one nobody asked for.
class _FakeAnalyticsService implements AnalyticsService {
  _FakeAnalyticsService({this.failOnSetup = false});

  /// Whether [setCollectionEnabled] throws, standing in for a platform
  /// channel that is not there.
  final bool failOnSetup;

  /// What [setCollectionEnabled] was called with, in order.
  final List<bool> collectionCalls = <bool>[];

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionCalls.add(enabled);
    if (failOnSetup) {
      throw StateError('analytics setup failed');
    }
  }

  @override
  Future<void> log(AnalyticsEvent event) =>
      throw UnimplementedError('bootstrap must not log an event');

  @override
  Future<void> setUserId(String? uid) =>
      throw UnimplementedError('bootstrap must not set a user id');
}

/// A crash reporter that records what startup asked of it.
///
/// Reporting throws: startup has no error to report, and one sent before the
/// first frame would be an error nobody hit.
class _FakeCrashReporter implements CrashReporter {
  _FakeCrashReporter({this.failOnSetup = false});

  /// Whether [setCollectionEnabled] throws.
  final bool failOnSetup;

  /// What [setCollectionEnabled] was called with, in order.
  final List<bool> collectionCalls = <bool>[];

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionCalls.add(enabled);
    if (failOnSetup) {
      throw StateError('crash reporting setup failed');
    }
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) =>
      throw UnimplementedError('bootstrap must not report an error');

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) =>
      throw UnimplementedError('bootstrap must not report an error');

  @override
  Future<void> setUserId(String? uid) =>
      throw UnimplementedError('bootstrap must not set a user id');
}

/// Reads back the service a set of overrides carries.
NotificationService serviceFrom(List<Override> overrides) {
  final ProviderContainer container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container.read(notificationServiceProvider);
}

/// Reads back the analytics service a set of overrides carries.
AnalyticsService analyticsFrom(List<Override> overrides) {
  final ProviderContainer container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container.read(analyticsServiceProvider);
}

/// Reads back the crash reporter a set of overrides carries.
CrashReporter crashesFrom(List<Override> overrides) {
  final ProviderContainer container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container.read(crashReporterProvider);
}

/// Stands in for Firebase, which has no platform channel under `flutter test`.
Future<void> _skipFirebase() async {}

/// [AppBootstrap.init] with Firebase replaced, so startup can be exercised
/// without a device. Tests that are about Firebase pass their own initializer.
Future<List<Override>> boot({
  required NotificationServiceFactory createNotificationService,
  FirebaseInitializer initializeFirebase = _skipFirebase,
  AnalyticsServiceFactory createAnalyticsService = _FakeAnalyticsService.new,
  bool collectAnalytics = false,
  CrashReporterFactory createCrashReporter = _FakeCrashReporter.new,
  bool reportCrashes = false,
}) =>
    AppBootstrap.init(
      initializeFirebase: initializeFirebase,
      createNotificationService: createNotificationService,
      createAnalyticsService: createAnalyticsService,
      collectAnalytics: collectAnalytics,
      createCrashReporter: createCrashReporter,
      reportCrashes: reportCrashes,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppBootstrap.init', () {
    test('it hands the app a notification service', () async {
      final _FakeNotificationService fake = _FakeNotificationService();

      final List<Override> overrides =
          await boot(createNotificationService: () => fake);

      expect(overrides, hasLength(3));
      expect(serviceFrom(overrides), same(fake));
    });

    test('it initialises the service before handing it over', () async {
      final _FakeNotificationService fake = _FakeNotificationService();

      await boot(createNotificationService: () => fake);

      expect(fake.initCalls, 1);
    });

    test('a service that cannot start up does not stop the app opening',
        () async {
      // The promise this file makes in prose. Without a test, removing the
      // catch below would leave the app refusing to open on any device where
      // notification setup fails, and nothing here would go red.
      final _FakeNotificationService fake =
          _FakeNotificationService(failOnInit: true);

      final List<Override> overrides =
          await boot(createNotificationService: () => fake);

      expect(overrides, hasLength(3));
    });

    test('the failed service is still the one the app gets', () async {
      // Not null, and not a different instance. The reminder screen asks the
      // service whether notifications are enabled and reports the real answer;
      // it cannot do that if startup swallowed the service along with the
      // error.
      final _FakeNotificationService fake =
          _FakeNotificationService(failOnInit: true);

      final List<Override> overrides =
          await boot(createNotificationService: () => fake);

      expect(serviceFrom(overrides), same(fake));
      expect(fake.initCalls, 1);
    });

    test('it hands the app an analytics service, collection set for the build',
        () async {
      final _FakeAnalyticsService analytics = _FakeAnalyticsService();

      final List<Override> overrides = await boot(
        createNotificationService: _FakeNotificationService.new,
        createAnalyticsService: () => analytics,
        collectAnalytics: true,
      );

      expect(analyticsFrom(overrides), same(analytics));
      expect(analytics.collectionCalls, <bool>[true]);
    });

    test('a debug build starts with collection off', () async {
      // The promise the file makes in prose: development taps do not land in
      // the product's numbers. This calls init without collectAnalytics on
      // purpose, so the default itself is what gets tested. Tests run in debug,
      // so the default has to come out false.
      final _FakeAnalyticsService analytics = _FakeAnalyticsService();
      final FlutterExceptionHandler? before = FlutterError.onError;
      addTearDown(() => FlutterError.onError = before);

      await AppBootstrap.init(
        initializeFirebase: _skipFirebase,
        createNotificationService: _FakeNotificationService.new,
        createAnalyticsService: () => analytics,
        createCrashReporter: _FakeCrashReporter.new,
      );

      expect(kDebugMode, isTrue, reason: 'this test assumes a debug run');
      expect(analytics.collectionCalls, <bool>[false]);
    });

    test('analytics that cannot start up does not stop the app opening',
        () async {
      final _FakeAnalyticsService analytics =
          _FakeAnalyticsService(failOnSetup: true);

      final List<Override> overrides = await boot(
        createNotificationService: _FakeNotificationService.new,
        createAnalyticsService: () => analytics,
      );

      expect(overrides, hasLength(3));
      // Still the one the app gets, so call sites need no null check.
      expect(analyticsFrom(overrides), same(analytics));
    });

    test('startup logs no event of its own', () async {
      // Logging throws on the fake. An event sent before the first frame is
      // one nobody asked for, and this is what would catch it.
      final _FakeAnalyticsService analytics = _FakeAnalyticsService();

      await boot(
        createNotificationService: _FakeNotificationService.new,
        createAnalyticsService: () => analytics,
      );
    });

    test('it hands the app a crash reporter, collection set for the build',
        () async {
      final _FakeCrashReporter crashes = _FakeCrashReporter();
      final FlutterExceptionHandler? before = FlutterError.onError;
      addTearDown(() => FlutterError.onError = before);

      final List<Override> overrides = await boot(
        createNotificationService: _FakeNotificationService.new,
        createCrashReporter: () => crashes,
        reportCrashes: true,
      );

      expect(crashesFrom(overrides), same(crashes));
      expect(crashes.collectionCalls, <bool>[true]);
    });

    test('a debug build starts with crash reporting off', () async {
      final _FakeCrashReporter crashes = _FakeCrashReporter();
      final FlutterExceptionHandler? before = FlutterError.onError;
      addTearDown(() => FlutterError.onError = before);

      await AppBootstrap.init(
        initializeFirebase: _skipFirebase,
        createNotificationService: _FakeNotificationService.new,
        createAnalyticsService: _FakeAnalyticsService.new,
        createCrashReporter: () => crashes,
      );

      expect(crashes.collectionCalls, <bool>[false]);
    });

    test('startup wires the error handlers to the reporter', () async {
      // The promise: an error nothing caught reaches the reporter. Without the
      // install call, the handler would still be Flutter's own and a crash
      // would never leave the device.
      final _FakeCrashReporter crashes = _FakeCrashReporter();
      final FlutterExceptionHandler? before = FlutterError.onError;
      addTearDown(() => FlutterError.onError = before);

      await boot(
        createNotificationService: _FakeNotificationService.new,
        createCrashReporter: () => crashes,
      );

      expect(FlutterError.onError, isNot(same(before)));
    });

    test('a reporter that cannot start up does not stop the app opening',
        () async {
      final _FakeCrashReporter crashes = _FakeCrashReporter(failOnSetup: true);
      final FlutterExceptionHandler? before = FlutterError.onError;
      addTearDown(() => FlutterError.onError = before);

      final List<Override> overrides = await boot(
        createNotificationService: _FakeNotificationService.new,
        createCrashReporter: () => crashes,
      );

      expect(overrides, hasLength(3));
      expect(crashesFrom(overrides), same(crashes));
      // And the handlers are still wired, so later errors are still reported.
      expect(FlutterError.onError, isNot(same(before)));
    });

    test('startup asks the service for nothing but init', () async {
      // Every other method on the fake throws. If bootstrap ever starts
      // requesting permission or scheduling at startup, this fails.
      final _FakeNotificationService fake = _FakeNotificationService();

      await expectLater(
        boot(createNotificationService: () => fake),
        completes,
      );
    });

    test('the service is built once, not per override', () async {
      int built = 0;

      await boot(
        createNotificationService: () {
          built++;
          return _FakeNotificationService();
        },
      );

      expect(built, 1);
    });

    test('Firebase is initialised before the notification service is built',
        () async {
      // Auth, progress and sync sit on Firebase, so it comes first.
      final List<String> order = <String>[];

      await boot(
        initializeFirebase: () async => order.add('firebase'),
        createNotificationService: () {
          order.add('notifications');
          return _FakeNotificationService();
        },
      );

      expect(order, <String>['firebase', 'notifications']);
    });

    test('a Firebase failure is not swallowed', () async {
      // The opposite of the notification promise above, and deliberately so.
      // Firebase.initializeApp reads config compiled into the app; when it
      // throws, the build is broken. If a catch were added around it, the
      // app would open normally with nothing under it, and this would fail.
      int built = 0;

      await expectLater(
        boot(
          initializeFirebase: () async =>
              throw StateError('firebase config broken'),
          createNotificationService: () {
            built++;
            return _FakeNotificationService();
          },
        ),
        throwsA(isA<StateError>()),
      );
      expect(built, 0);
    });
  });
}
