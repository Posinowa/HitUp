import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/notification_service.dart';

/// The app's notification service.
///
/// Exposed as the [NotificationService] interface rather than the concrete
/// implementation so callers cannot reach past it into the plugin, and so tests
/// and previews can override it with a fake:
///
/// ```dart
/// ProviderScope(
///   overrides: <Override>[
///     notificationServiceProvider.overrideWithValue(FakeNotificationService()),
///   ],
///   child: const HitUpApp(),
/// );
/// ```
///
/// The instance is created here but initialised in `AppBootstrap`, because
/// `init()` is async and touches platform channels, which a provider body
/// cannot wait for.
final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>((Ref ref) => LocalNotificationService());
