import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/observability/crash_hooks.dart';
import 'package:hitup/core/observability/crash_reporter.dart';

/// A reporter that records what it was asked to report.
class _FakeCrashReporter implements CrashReporter {
  final List<String> reported = <String>[];
  final List<bool> fatalFlags = <bool>[];
  final List<bool> collectionCalls = <bool>[];
  final List<String?> userIds = <String?>[];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async {
    reported.add(error.toString());
    fatalFlags.add(fatal);
  }

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    reported.add(details.exception.toString());
    fatalFlags.add(true);
  }

  @override
  Future<void> setUserId(String? uid) async => userIds.add(uid);

  @override
  Future<void> setCollectionEnabled(bool enabled) async =>
      collectionCalls.add(enabled);
}

void main() {
  late _FakeCrashReporter reporter;
  late VoidCallback restore;

  setUp(() {
    reporter = _FakeCrashReporter();
  });

  tearDown(() => restore());

  test('a framework error is reported and still reaches the old handler', () {
    final List<String> seenByPrevious = <String>[];
    final FlutterExceptionHandler? original = FlutterError.onError;
    FlutterError.onError =
        (FlutterErrorDetails d) => seenByPrevious.add(d.exception.toString());
    addTearDown(() => FlutterError.onError = original);

    restore = CrashHooks.install(reporter);

    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('layout exploded')),
    );

    expect(reporter.reported, <String>['Bad state: layout exploded']);
    expect(reporter.fatalFlags, <bool>[true]);
    expect(seenByPrevious, <String>['Bad state: layout exploded']);
  });

  test('an error outside the framework is reported as fatal and swallowed', () {
    restore = CrashHooks.install(reporter);

    final bool handled = PlatformDispatcher.instance.onError!(
      StateError('nobody awaited me'),
      StackTrace.current,
    );

    // True: the error has been reported, and false would hand it back to the
    // platform to kill the app with.
    expect(handled, isTrue);
    expect(reporter.reported, <String>['Bad state: nobody awaited me']);
    expect(reporter.fatalFlags, <bool>[true]);
  });

  test('the old platform handler is kept and still called', () {
    final List<String> seenByPrevious = <String>[];
    final ErrorCallback? original = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object e, StackTrace s) {
      seenByPrevious.add(e.toString());
      return true;
    };
    addTearDown(() => PlatformDispatcher.instance.onError = original);

    restore = CrashHooks.install(reporter);
    PlatformDispatcher.instance.onError!(
      StateError('both handlers'),
      StackTrace.current,
    );

    expect(seenByPrevious, <String>['Bad state: both handlers']);
    expect(reporter.reported, <String>['Bad state: both handlers']);
  });

  test('installing can be undone, so a test cannot leak its handlers', () {
    final FlutterExceptionHandler? before = FlutterError.onError;
    final ErrorCallback? beforePlatform = PlatformDispatcher.instance.onError;

    restore = CrashHooks.install(reporter);
    expect(FlutterError.onError, isNot(same(before)));

    restore();
    expect(FlutterError.onError, same(before));
    expect(PlatformDispatcher.instance.onError, same(beforePlatform));

    // Undone twice is harmless, which is what lets tearDown call it blindly.
    restore = () {};
  });

  test('both handlers are set, not one of them', () {
    // Half a wiring loses half the crashes, and the half it loses is the one
    // nobody notices: async errors with nobody awaiting.
    final FlutterExceptionHandler? before = FlutterError.onError;
    final ErrorCallback? beforePlatform = PlatformDispatcher.instance.onError;

    restore = CrashHooks.install(reporter);

    expect(FlutterError.onError, isNot(same(before)));
    expect(PlatformDispatcher.instance.onError, isNot(same(beforePlatform)));
  });

  group('the reporter that reports nothing', () {
    test('accepts everything and does nothing with it', () async {
      restore = () {};
      const CrashReporter noop = NoopCrashReporter();

      await noop.recordError(StateError('x'), StackTrace.current);
      await noop.recordError(StateError('x'), null, fatal: true);
      await noop.recordFlutterError(
        FlutterErrorDetails(exception: StateError('x')),
      );
      await noop.setUserId('uid-1');
      await noop.setUserId(null);
      await noop.setCollectionEnabled(true);
    });
  });
}
