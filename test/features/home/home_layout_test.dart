import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/app.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/home/presentation/home_screen.dart';
import 'package:hitup/features/onboarding/data/onboarding_store.dart';
import 'package:hitup/features/progress/domain/models/calendar_day.dart';
import 'package:hitup/features/progress/domain/models/user_profile.dart';
import 'package:hitup/features/training/application/finished_day_recorder.dart';
import 'package:hitup/features/training/application/training_session_controller.dart';
import 'package:hitup/features/training/data/pending_day_store.dart';
import 'package:hitup/features/training/data/session_store.dart';
import 'package:hitup/features/training/domain/training_session.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/clock_provider.dart';
import 'package:hitup/shared/providers/progress_providers.dart';
import 'package:hitup/shared/providers/startup_providers.dart';
import 'package:hitup/shared/providers/training_providers.dart';

import '../../support/fake_progress_repository.dart';
import '../../support/preloaded_curriculum.dart';

class _Onboarded implements OnboardingStore {
  @override
  Future<bool> isComplete() async => true;

  @override
  Future<void> markComplete() async {}
}

class _NoSession implements SessionStore {
  @override
  Future<TrainingSession?> load() async => null;

  @override
  Future<void> save(TrainingSession session) async {}

  @override
  Future<void> clear() async {}
}

class _NothingPending implements PendingDayStore {
  @override
  Future<List<PendingDay>> load() async => const <PendingDay>[];

  @override
  Future<void> add(PendingDay day) async {}

  @override
  Future<void> remove(PendingDay day) async {}
}

/// Home at the phone sizes the other screens are checked at, with the app's
/// own fonts and with text enlarged, in each of its states. An overflow fails
/// the test.
void main() {
  late PreloadedCurriculum curriculum;
  final DateTime now = DateTime(2026, 10, 5, 9, 30);

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    curriculum = await PreloadedCurriculum.load();
    for (final (String family, List<String> weights)
        in const <(String, List<String>)>[
      ('Manrope', <String>['Medium', 'Bold', 'ExtraBold']),
      ('PlusJakartaSans', <String>['Regular', 'Medium', 'SemiBold', 'Bold']),
    ]) {
      final FontLoader loader = FontLoader(family);
      for (final String weight in weights) {
        loader.addFont(
          rootBundle.load('assets/fonts/$family/$family-$weight.ttf'),
        );
      }
      await loader.load();
    }
  });

  Future<void> open(
    WidgetTester tester,
    Size phone,
    double scale,
    FakeProgressRepository progress,
  ) async {
    tester.view.physicalSize = phone * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 24 * 3);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onboardingStoreProvider.overrideWithValue(_Onboarded()),
          authStateChangesProvider.overrideWith(
            (Ref ref) => Stream<AuthUser?>.value(const AuthUser(uid: 'u')),
          ),
          userProgressRepositoryProvider.overrideWithValue(progress),
          curriculumRepositoryProvider.overrideWithValue(curriculum),
          sessionStoreProvider.overrideWithValue(_NoSession()),
          pendingDayStoreProvider.overrideWithValue(_NothingPending()),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const HitUpApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  }

  final Map<String, UserProfile Function()> states =
      <String, UserProfile Function()>{
    'a day to run': () => profileFor(
          'u',
          displayName: 'Muhammed Abdurrahman Karaosmanoğlu',
          currentStreak: 128,
          totalTrainingMinutes: 12840,
        ),
    'done today': () => profileFor(
          'u',
          currentProgramDay: 5,
          currentStreak: 4,
          lastTrainingDate: CalendarDay.fromDateTime(now),
        ),
    'the programme finished': () => profileFor(
          'u',
          currentProgramDay: curriculum.program.days.length + 1,
          totalTrainingMinutes: 190,
          longestStreak: 14,
        ),
  };

  for (final Size phone in const <Size>[
    Size(390, 844),
    Size(360, 640),
    Size(320, 568),
  ]) {
    for (final double scale in const <double>[1, 1.3]) {
      for (final MapEntry<String, UserProfile Function()> state
          in states.entries) {
        testWidgets(
            '${state.key} fits at ${phone.width.toInt()}x'
            '${phone.height.toInt()}, text x$scale',
            (WidgetTester tester) async {
          final FakeProgressRepository progress =
              FakeProgressRepository(state.value());
          addTearDown(progress.close);
          await open(tester, phone, scale, progress);

          expect(tester.takeException(), isNull);
          // No words run past the screen's edges, which a cut-off label does
          // without any overflow being reported.
          for (final Element text in find
              .descendant(
                of: find.byType(HomeScreen),
                matching: find.byType(Text),
              )
              .evaluate()) {
            final Rect at = tester.getRect(
              find.byElementPredicate((Element e) => identical(e, text)),
            );
            expect(at.left, greaterThanOrEqualTo(-0.5), reason: '$text');
            expect(
              at.right,
              lessThanOrEqualTo(phone.width + 0.5),
              reason: '$text',
            );
          }
        });
      }
    }
  }

  testWidgets(
      'on a common phone the way into today is in view without scrolling',
      (WidgetTester tester) async {
    for (final Size phone in const <Size>[Size(390, 844), Size(360, 640)]) {
      final FakeProgressRepository progress =
          FakeProgressRepository(profileFor('u', currentStreak: 3));
      addTearDown(progress.close);
      await open(tester, phone, 1, progress);

      expect(
        find.widgetWithText(ElevatedButton, 'Antrenmana başla').hitTestable(),
        findsOneWidget,
        reason: '$phone',
      );
    }
  });
}
