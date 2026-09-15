import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/bootstrap/app_bootstrap.dart';
import 'package:hitup/core/services/notification_service.dart';
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

/// Reads back the service a set of overrides carries.
NotificationService serviceFrom(List<Override> overrides) {
  final ProviderContainer container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container.read(notificationServiceProvider);
}

/// Stands in for Firebase, which has no platform channel under `flutter test`.
Future<void> _skipFirebase() async {}

/// [AppBootstrap.init] with Firebase replaced, so startup can be exercised
/// without a device. Tests that are about Firebase pass their own initializer.
Future<List<Override>> boot({
  required NotificationServiceFactory createNotificationService,
  FirebaseInitializer initializeFirebase = _skipFirebase,
}) =>
    AppBootstrap.init(
      initializeFirebase: initializeFirebase,
      createNotificationService: createNotificationService,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppBootstrap.init', () {
    test('it hands the app a notification service', () async {
      final _FakeNotificationService fake = _FakeNotificationService();

      final List<Override> overrides =
          await boot(createNotificationService: () => fake);

      expect(overrides, hasLength(1));
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

      expect(overrides, hasLength(1));
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
