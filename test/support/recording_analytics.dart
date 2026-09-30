import 'package:hitup/core/analytics/analytics_event.dart';
import 'package:hitup/core/analytics/analytics_service.dart';

/// An [AnalyticsService] that keeps every event it is given, in order, so a
/// test can say what a flow reported.
class RecordingAnalytics implements AnalyticsService {
  /// The events logged, oldest first.
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];

  /// The user ids set, oldest first.
  final List<String?> userIds = <String?>[];

  @override
  Future<void> log(AnalyticsEvent event) async => events.add(event);

  @override
  Future<void> setUserId(String? uid) async => userIds.add(uid);

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}
