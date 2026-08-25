import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/environment.dart';
import '../../core/services/notification_service.dart';
import '../../shared/providers/notification_providers.dart';

/// Application bootstrap for foundation initialization.
///
/// Firebase client initialization belongs to HIT-009 once owner-provided
/// config (`firebase_options.dart` / platform files) exists.
/// Do NOT invent Firebase config files in this repository.
class AppBootstrap {
  const AppBootstrap._();

  /// Prepares everything that must exist before the first frame, and returns
  /// the provider overrides the app should start with.
  ///
  /// Services whose setup is asynchronous are created and initialised here,
  /// then handed to Riverpod as an override. A provider body cannot await, so
  /// letting the provider build these itself would hand callers an instance
  /// that has not finished starting up.
  static Future<List<Override>> init() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Environment is local/dev until a formal env strategy is wired (HIT-009+).
    assert(() {
      // ignore: avoid_print
      print('HitUp bootstrap — environment: ${Environment.current.name}');
      return true;
    }());

    // TODO(HIT-009): Initialize Firebase when firebase_options.dart is available.
    // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    final NotificationService notifications = await _initNotifications();

    return <Override>[
      notificationServiceProvider.overrideWithValue(notifications),
    ];
  }

  /// Creates and initialises the notification service (HIT-057).
  ///
  /// Failure here is deliberately not fatal. Reminders are one optional
  /// feature; a device that cannot set them up, or a platform channel that is
  /// unavailable, is not a reason to refuse to open the app. The service is
  /// still returned, so the reminder settings screen can report the real state
  /// through [NotificationService.areNotificationsEnabled] rather than the app
  /// pretending reminders work.
  static Future<NotificationService> _initNotifications() async {
    final LocalNotificationService service = LocalNotificationService();

    try {
      await service.init();
    } on Object catch (error, stackTrace) {
      debugPrint('HIT-057: notification setup failed. Cause: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    return service;
  }
}
