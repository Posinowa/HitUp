import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'crash_reporter.dart';

/// Sends the errors nothing else caught to a [CrashReporter] (HIT-065).
///
/// Flutter has two of these, and both have to be set or half the crashes never
/// leave the device:
///
/// - `FlutterError.onError` is raised for an error inside the framework, for
///   example a build or a layout that threw.
/// - `PlatformDispatcher.instance.onError` is raised for an error outside it,
///   typically one thrown in an async callback with nobody awaiting.
class CrashHooks {
  const CrashHooks._();

  /// Routes both of Flutter's uncaught error paths to [reporter].
  ///
  /// The handler Flutter had is kept and still called, so an error keeps
  /// appearing in the console during development and whatever the framework
  /// wanted to do with it still happens. Replacing it outright would trade the
  /// local report for the remote one.
  ///
  /// Returns a function that puts the previous handlers back, which is what
  /// lets a test install these without leaking them into the next test.
  static VoidCallback install(CrashReporter reporter) {
    final FlutterExceptionHandler? previousFlutterHandler =
        FlutterError.onError;
    final ErrorCallback? previousPlatformHandler =
        PlatformDispatcher.instance.onError;

    FlutterError.onError = (FlutterErrorDetails details) {
      // Reported first: the previous handler may be the one that prints and
      // rethrows in a test, and the report should not depend on surviving it.
      reporter.recordFlutterError(details);
      previousFlutterHandler?.call(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      reporter.recordError(error, stack, fatal: true);
      // True either way: the error has been reported, and returning false
      // would hand it back to the platform to kill the app with. If Flutter
      // had a handler of its own, its answer is kept.
      previousPlatformHandler?.call(error, stack);
      return true;
    };

    return () {
      FlutterError.onError = previousFlutterHandler;
      PlatformDispatcher.instance.onError = previousPlatformHandler;
    };
  }
}
