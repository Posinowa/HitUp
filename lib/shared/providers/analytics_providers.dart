import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics_service.dart';

/// The app's analytics service (HIT-063).
///
/// Exposed as the [AnalyticsService] interface so a screen cannot reach past
/// it into Firebase, and so tests and previews can replace it:
///
/// ```dart
/// ProviderScope(
///   overrides: <Override>[
///     analyticsServiceProvider.overrideWithValue(const NoopAnalyticsService()),
///   ],
///   child: const HitUpApp(),
/// );
/// ```
///
/// The default records nothing. `AppBootstrap` overrides it with the Firebase
/// service once Firebase is initialised, which is also where collection is
/// turned off for debug builds. A provider body cannot await, so it cannot do
/// that itself, and a default that records nothing is the safe way round: a
/// test or a preview that forgets the override logs into a void rather than
/// into the product's numbers.
final Provider<AnalyticsService> analyticsServiceProvider =
    Provider<AnalyticsService>((Ref ref) => const NoopAnalyticsService());
