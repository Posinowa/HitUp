import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Reports crashes and errors that reached nobody else (HIT-065).
///
/// Callers hold this interface, never `FirebaseCrashlytics`. Most of the app
/// never calls it at all: the handlers in `crash_hooks.dart` are what send the
/// errors nothing caught. A controller calls [recordError] only for a failure
/// it handled but still wants reported.
///
/// What a report may carry is the same rule analytics follows: no email, no
/// display name, no text a user typed. The Firebase uid identifies a report
/// (`ANALYTICS.md`).
abstract interface class CrashReporter {
  /// Reports an error and where it came from.
  ///
  /// [fatal] marks a crash the app cannot continue from, which is how the
  /// console separates a crash from a handled failure.
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  });

  /// Reports an error the framework raised.
  Future<void> recordFlutterError(FlutterErrorDetails details);

  /// Ties later reports to an account, or to nobody when [uid] is null.
  Future<void> setUserId(String? uid);

  /// Turns collection on or off for this install.
  Future<void> setCollectionEnabled(bool enabled);
}

/// [CrashReporter] over Firebase Crashlytics.
///
/// Thin on purpose, like `FirebaseAnalyticsService`: it makes the calls and
/// swallows their failures. A reporter that threw would turn a handled error
/// into an unhandled one, which is the opposite of its job.
class FirebaseCrashReporter implements CrashReporter {
  /// Creates a reporter over [crashlytics].
  const FirebaseCrashReporter(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) =>
      _guard(
        'record an error',
        () => _crashlytics.recordError(error, stackTrace, fatal: fatal),
      );

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) => _guard(
        'record a framework error',
        () => _crashlytics.recordFlutterFatalError(details),
      );

  @override
  Future<void> setUserId(String? uid) => _guard(
        'set the user id',
        () => _crashlytics.setUserIdentifier(uid ?? ''),
      );

  @override
  Future<void> setCollectionEnabled(bool enabled) => _guard(
        'set collection enabled',
        () => _crashlytics.setCrashlyticsCollectionEnabled(enabled),
      );

  static Future<void> _guard(String what, Future<void> Function() call) async {
    try {
      await call();
    } on Object catch (error) {
      debugPrint('HIT-065: crash reporting could not $what. Cause: $error');
    }
  }
}

/// A [CrashReporter] that reports nothing.
///
/// What tests and previews use, and the default the app starts from until
/// `AppBootstrap` replaces it.
class NoopCrashReporter implements CrashReporter {
  /// Creates the reporter.
  const NoopCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async {}

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) async {}

  @override
  Future<void> setUserId(String? uid) async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}
