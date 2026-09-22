import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/observability/crash_reporter.dart';

/// The app's crash reporter (HIT-065).
///
/// Exposed as the [CrashReporter] interface so a caller cannot reach past it
/// into Firebase, and so tests and previews can replace it:
///
/// ```dart
/// ProviderScope(
///   overrides: <Override>[
///     crashReporterProvider.overrideWithValue(const NoopCrashReporter()),
///   ],
///   child: const HitUpApp(),
/// );
/// ```
///
/// The default reports nothing, for the same reason `analyticsServiceProvider`
/// does: `AppBootstrap` replaces it once Firebase is initialised, and a test
/// that forgets the override reports into a void rather than into the console.
///
/// Most code never reads this. Flutter's two uncaught error paths are wired to
/// the reporter by `CrashHooks` at startup; a controller reads it only to
/// report a failure it handled itself.
final Provider<CrashReporter> crashReporterProvider =
    Provider<CrashReporter>((Ref ref) => const NoopCrashReporter());
