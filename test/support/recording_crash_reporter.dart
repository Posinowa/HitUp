import 'package:flutter/foundation.dart';
import 'package:hitup/core/observability/crash_reporter.dart';

/// A [CrashReporter] that keeps the user ids it is given, in order.
class RecordingCrashReporter implements CrashReporter {
  /// The user ids set, oldest first.
  final List<String?> userIds = <String?>[];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async {}

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) async {}

  @override
  Future<void> setUserId(String? uid) async => userIds.add(uid);

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}
