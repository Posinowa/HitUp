import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/shared/providers/analytics_providers.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/crash_providers.dart';
import 'package:hitup/shared/providers/reporting_identity_provider.dart';

import '../../support/recording_analytics.dart';
import '../../support/recording_crash_reporter.dart';

void main() {
  late StreamController<AuthUser?> auth;
  late RecordingAnalytics analytics;
  late RecordingCrashReporter crashes;
  late ProviderContainer container;
  late List<String?> seen;

  setUp(() {
    auth = StreamController<AuthUser?>();
    analytics = RecordingAnalytics();
    crashes = RecordingCrashReporter();
    container = ProviderContainer(
      overrides: <Override>[
        authStateChangesProvider.overrideWith((Ref ref) => auth.stream),
        analyticsServiceProvider.overrideWithValue(analytics),
        crashReporterProvider.overrideWithValue(crashes),
      ],
    );
    seen = <String?>[];
    // Listened to, as the app root does, rather than read.
    container.listen<String?>(
      reportingIdentityProvider,
      (String? previous, String? next) => seen.add(next),
    );
  });

  tearDown(() async {
    container.dispose();
    await auth.close();
  });

  // The provider is rebuilt on a later turn of the event loop than the one
  // the auth stream delivers on, so each step lets the queue run out.
  Future<void> emit(AuthUser? user) async {
    auth.add(user);
    await pumpEventQueue();
  }

  test('a sign-in ties reports to the uid, and a sign-out clears it', () async {
    await emit(const AuthUser(uid: 'uid-1'));
    await emit(null);
    await emit(const AuthUser(uid: 'uid-2'));

    expect(analytics.userIds, <String?>['uid-1', null, 'uid-2']);
    expect(crashes.userIds, <String?>['uid-1', null, 'uid-2']);
    expect(seen, <String?>['uid-1', null, 'uid-2']);
  });

  test('nothing is sent while the account is still being read', () async {
    await pumpEventQueue();

    expect(analytics.userIds, isEmpty);
    expect(crashes.userIds, isEmpty);
  });

  test('nobody signed in, once known, is sent as nobody', () async {
    await emit(null);

    expect(analytics.userIds, <String?>[null]);
    expect(crashes.userIds, <String?>[null]);
  });

  test('the same account arriving again is not sent again', () async {
    await emit(const AuthUser(uid: 'uid-1', email: 'a@example.com'));
    await emit(const AuthUser(uid: 'uid-1', email: 'b@example.com'));

    expect(analytics.userIds, <String?>['uid-1']);
    expect(crashes.userIds, <String?>['uid-1']);
  });

  test('a service that replaces another is told the account too', () async {
    await emit(const AuthUser(uid: 'uid-1'));
    final RecordingAnalytics nextAnalytics = RecordingAnalytics();
    final RecordingCrashReporter nextCrashes = RecordingCrashReporter();

    container.updateOverrides(<Override>[
      authStateChangesProvider.overrideWith((Ref ref) => auth.stream),
      analyticsServiceProvider.overrideWithValue(nextAnalytics),
      crashReporterProvider.overrideWithValue(nextCrashes),
    ]);
    await pumpEventQueue();

    expect(nextAnalytics.userIds, <String?>['uid-1']);
    expect(nextCrashes.userIds, <String?>['uid-1']);
  });

  test('an account that cannot be read ties reports to nobody new', () async {
    auth.addError(StateError('auth unavailable'));
    await pumpEventQueue();

    expect(analytics.userIds, isEmpty);
    expect(crashes.userIds, isEmpty);
  });
}
