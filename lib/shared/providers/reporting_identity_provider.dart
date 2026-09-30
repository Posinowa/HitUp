import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/models/auth_user.dart';
import 'analytics_providers.dart';
import 'auth_providers.dart';
import 'crash_providers.dart';

/// The account analytics and crash reports are tied to: the signed-in uid,
/// or null.
///
/// The Firebase uid and nothing else (`ANALYTICS.md`,
/// `CRASH_REPORTING.md`). Set when someone signs in and cleared when they
/// sign out, so what a shared device reports after a sign-out is not put on
/// the account that left. Nothing is sent while the account is still being
/// read, which is not the same as nobody signed in, and the same user
/// arriving again from the auth stream is not sent twice.
///
/// The app root keeps it listened to, so it follows the account from the
/// start. The services are watched, so one that replaces another is told
/// the account too. Neither call is awaited: both services swallow what they
/// throw.
final Provider<String?> reportingIdentityProvider = Provider<String?>((
  Ref ref,
) {
  final (bool known, String? uid) = ref.watch(
    authStateChangesProvider.select(
      (AsyncValue<AuthUser?> auth) => (auth.hasValue, auth.valueOrNull?.uid),
    ),
  );
  if (known) {
    unawaited(ref.watch(analyticsServiceProvider).setUserId(uid));
    unawaited(ref.watch(crashReporterProvider).setUserId(uid));
  }
  return uid;
});
