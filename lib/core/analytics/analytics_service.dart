import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'analytics_event.dart';

/// Records what people do in the app, in the shape `ANALYTICS.md` defines.
///
/// Callers hold this interface, never `FirebaseAnalytics`, so a screen cannot
/// log a name of its own invention and a test can count what was logged.
///
/// Nothing here throws on the caller's behalf. Analytics is a side channel: a
/// failed log must not fail the action the user was taking.
abstract interface class AnalyticsService {
  /// Records [event].
  Future<void> log(AnalyticsEvent event);

  /// Ties later events to an account, or to nobody when [uid] is null.
  ///
  /// The Firebase uid only. Never the email or the display name: those are
  /// personal data, and the uid is what the rest of the data model already
  /// keys on (`FIRESTORE_MODEL.md`).
  Future<void> setUserId(String? uid);

  /// Turns collection on or off for this install.
  ///
  /// `AppBootstrap` turns it off in debug builds, so development taps do not
  /// land in the product's numbers.
  Future<void> setCollectionEnabled(bool enabled);
}

/// [AnalyticsService] over Firebase Analytics.
///
/// Thin on purpose: every decision about what an event is called and what it
/// carries lives in [AnalyticsEvent], which is where the tests are. This class
/// makes the calls and swallows their failures.
class FirebaseAnalyticsService implements AnalyticsService {
  /// Creates a service over [analytics].
  const FirebaseAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> log(AnalyticsEvent event) => _guard(
        'log ${event.name}',
        () => _analytics.logEvent(
          name: event.name,
          parameters: event.parameters.isEmpty ? null : event.parameters,
        ),
      );

  @override
  Future<void> setUserId(String? uid) =>
      _guard('set user id', () => _analytics.setUserId(id: uid));

  @override
  Future<void> setCollectionEnabled(bool enabled) => _guard(
        'set collection enabled',
        () => _analytics.setAnalyticsCollectionEnabled(enabled),
      );

  /// Runs [call], reporting a failure without letting it reach the caller.
  ///
  /// A dropped event is worth a log line and nothing more. Letting it throw
  /// would mean a finished exercise could fail to be saved because the
  /// analytics call after it did.
  static Future<void> _guard(
    String what,
    Future<void> Function() call,
  ) async {
    try {
      await call();
    } on Object catch (error) {
      debugPrint('HIT-063: analytics could not $what. Cause: $error');
    }
  }
}

/// An [AnalyticsService] that records nothing.
///
/// What tests, previews and any build without Firebase use. It is a real
/// implementation rather than a null check at every call site.
class NoopAnalyticsService implements AnalyticsService {
  /// Creates the service.
  const NoopAnalyticsService();

  @override
  Future<void> log(AnalyticsEvent event) async {}

  @override
  Future<void> setUserId(String? uid) async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}
