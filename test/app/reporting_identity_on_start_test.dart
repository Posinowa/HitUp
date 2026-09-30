import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/app.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/onboarding/data/onboarding_store.dart';
import 'package:hitup/features/training/application/finished_day_recorder.dart';
import 'package:hitup/features/training/data/pending_day_store.dart';
import 'package:hitup/shared/providers/analytics_providers.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/crash_providers.dart';
import 'package:hitup/shared/providers/startup_providers.dart';

import '../support/recording_analytics.dart';
import '../support/recording_crash_reporter.dart';

class _Onboarded implements OnboardingStore {
  @override
  Future<bool> isComplete() async => true;

  @override
  Future<void> markComplete() async {}
}

class _NothingPending implements PendingDayStore {
  @override
  Future<List<PendingDay>> load() async => const <PendingDay>[];

  @override
  Future<void> add(PendingDay day) async {}

  @override
  Future<void> remove(PendingDay day) async {}
}

void main() {
  testWidgets('the app ties analytics and crash reports to who is signed in',
      (WidgetTester tester) async {
    final RecordingAnalytics analytics = RecordingAnalytics();
    final RecordingCrashReporter crashes = RecordingCrashReporter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onboardingStoreProvider.overrideWithValue(_Onboarded()),
          authStateChangesProvider.overrideWith(
            (Ref ref) => Stream<AuthUser?>.value(const AuthUser(uid: 'uid-1')),
          ),
          pendingDayStoreProvider.overrideWithValue(_NothingPending()),
          analyticsServiceProvider.overrideWithValue(analytics),
          crashReporterProvider.overrideWithValue(crashes),
        ],
        child: const HitUpApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(analytics.userIds, <String?>['uid-1']);
    expect(crashes.userIds, <String?>['uid-1']);
  });
}
