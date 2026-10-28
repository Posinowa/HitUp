import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hitup/app/app.dart';
import 'package:hitup/app/router/route_names.dart';
import 'package:hitup/core/analytics/analytics_event.dart';
import 'package:hitup/core/errors/app_exception.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/home/application/home_providers.dart';
import 'package:hitup/features/home/presentation/home_screen.dart';
import 'package:hitup/features/onboarding/data/onboarding_store.dart';
import 'package:hitup/features/progress/domain/models/calendar_day.dart';
import 'package:hitup/features/training/application/finished_day_recorder.dart';
import 'package:hitup/features/training/application/today_status.dart';
import 'package:hitup/features/training/application/training_session_controller.dart';
import 'package:hitup/features/training/data/pending_day_store.dart';
import 'package:hitup/features/training/data/session_store.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/domain/training_session.dart';
import 'package:hitup/features/training/presentation/exercise_container_screen.dart';
import 'package:hitup/shared/providers/analytics_providers.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/clock_provider.dart';
import 'package:hitup/shared/providers/progress_providers.dart';
import 'package:hitup/shared/providers/startup_providers.dart';
import 'package:hitup/shared/providers/training_providers.dart';

import '../../support/fake_progress_repository.dart';
import '../../support/preloaded_curriculum.dart';
import '../../support/recording_analytics.dart';

class _Onboarded implements OnboardingStore {
  @override
  Future<bool> isComplete() async => true;

  @override
  Future<void> markComplete() async {}
}

class _MemorySessions implements SessionStore {
  TrainingSession? saved;

  @override
  Future<TrainingSession?> load() async => saved;

  @override
  Future<void> save(TrainingSession session) async => saved = session;

  @override
  Future<void> clear() async => saved = null;
}

class _MemoryPending implements PendingDayStore {
  final List<PendingDay> days = <PendingDay>[];

  @override
  Future<List<PendingDay>> load() async => List<PendingDay>.of(days);

  @override
  Future<void> add(PendingDay day) async => days.add(day);

  @override
  Future<void> remove(PendingDay day) async =>
      days.removeWhere(day.isSameDayAs);
}

class _MemoryReported implements ReportedFinishStore {
  final Map<String, int> reported = <String, int>{};

  @override
  Future<int?> load(String uid) async => reported[uid];

  @override
  Future<void> save(String uid, int programDay) async =>
      reported[uid] = programDay;
}

const String _uid = 'uid-1';

/// A Monday morning.
final DateTime _now = DateTime(2026, 10, 5, 9, 30);
final CalendarDay _today = CalendarDay.fromDateTime(_now);

void main() {
  late FakeProgressRepository progress;
  late _MemorySessions sessions;
  late _MemoryPending pending;
  late _MemoryReported reported;
  late RecordingAnalytics analytics;
  late PreloadedCurriculum curriculum;
  late TrainingProgram program;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    curriculum = await PreloadedCurriculum.load();
    program = curriculum.program;
  });

  setUp(() {
    progress = FakeProgressRepository(
      profileFor(_uid, currentStreak: 3, totalTrainingMinutes: 42),
    );
    sessions = _MemorySessions();
    pending = _MemoryPending();
    reported = _MemoryReported();
    analytics = RecordingAnalytics();
  });
  tearDown(() => progress.close());

  /// The app, signed in on a 390 by 844 phone: it opens on home.
  Future<ProviderContainer> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onboardingStoreProvider.overrideWithValue(_Onboarded()),
          authStateChangesProvider.overrideWith(
            (Ref ref) => Stream<AuthUser?>.value(const AuthUser(uid: _uid)),
          ),
          userProgressRepositoryProvider.overrideWithValue(progress),
          curriculumRepositoryProvider.overrideWithValue(curriculum),
          sessionStoreProvider.overrideWithValue(sessions),
          pendingDayStoreProvider.overrideWithValue(pending),
          reportedFinishStoreProvider.overrideWithValue(reported),
          analyticsServiceProvider.overrideWithValue(analytics),
          clockProvider.overrideWithValue(() => _now),
        ],
        child: const HitUpApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
  }

  ProgramDay day(int number) =>
      program.days.firstWhere((ProgramDay d) => d.day == number);

  Finder button(String label) => find.widgetWithText(ElevatedButton, label);

  group('today', () {
    testWidgets('greets the user and shows the streak and the minutes',
        (WidgetTester tester) async {
      await open(tester);

      expect(find.text('Günaydın, Deniz'), findsOneWidget);
      expect(find.text('5 Ekim Pazartesi'), findsOneWidget);
      expect(find.text('3 günlük seri'), findsOneWidget);
      expect(find.text('Toplam 42 dk'), findsOneWidget);
    });

    testWidgets('shows the day by its title, how long it takes, and one start',
        (WidgetTester tester) async {
      await open(tester);

      expect(find.text('Bugünün antrenmanı'), findsOneWidget);
      expect(find.text(day(1).title), findsOneWidget);
      expect(
        find.textContaining(
          'egzersiz · yaklaşık ${day(1).estimatedMinutes} dk',
        ),
        findsOneWidget,
      );
      expect(button('Antrenmana başla'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Kaldığınız yerden devam edin'), findsNothing);
    });

    testWidgets('starting opens the training day, and home asks again after',
        (WidgetTester tester) async {
      final ProviderContainer container = await open(tester);

      await tester.tap(button('Antrenmana başla'));
      await tester.pumpAndSettle();

      final ExerciseContainerScreen screen = tester.widget(
        find.byType(ExerciseContainerScreen),
      );
      expect(screen.today.programDay, 1);
      expect(screen.today.day, day(1));

      GoRouter.of(tester.element(find.byType(ExerciseContainerScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      // The day was left after it started, so it is offered to carry on.
      expect(sessions.saved, isNotNull);
      expect(button('Kaldığınız yerden devam edin'), findsOneWidget);
      expect(
        container.read(todayStatusProvider).valueOrNull?.unfinished,
        isNotNull,
      );
    });
  });

  group('a session the device kept', () {
    TrainingSession sessionFor(
      int programDay, {
      SessionStatus status = SessionStatus.inProgress,
      List<String>? ids,
    }) {
      final List<String> exerciseIds = ids ??
          <String>[
            for (final DayExerciseRef ref in day(programDay).exerciseRefs)
              ref.exerciseId,
          ];
      return TrainingSession(
        programDay: programDay,
        exerciseIds: exerciseIds,
        status: status,
        // Past two, one of them skipped: how far it got is one done.
        currentIndex: 2,
        completedExerciseIds: <String>[exerciseIds.first],
      );
    }

    testWidgets('on the same day is offered to carry on, with how far it got',
        (WidgetTester tester) async {
      sessions.saved = sessionFor(1);
      final TrainingSession kept = sessions.saved!;
      final ProviderContainer container = await open(tester);

      expect(button('Kaldığınız yerden devam edin'), findsOneWidget);
      expect(button('Antrenmana başla'), findsNothing);
      expect(
        find.text(
          '${day(1).exerciseRefs.length} egzersizin 1 tanesi tamam',
        ),
        findsOneWidget,
      );

      await tester.tap(button('Kaldığınız yerden devam edin'));
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseContainerScreen), findsOneWidget);
      // Restored before the screen opened, so the screen carries on with it.
      final TrainingSession? running =
          container.read(trainingSessionControllerProvider);
      expect(running?.programDay, 1);
      expect(running?.currentIndex, kept.currentIndex);
      expect(running?.completedExerciseIds, kept.completedExerciseIds);
    });

    testWidgets('on another day is not offered, even with the same exercises',
        (WidgetTester tester) async {
      sessions.saved = sessionFor(
        2,
        ids: <String>[
          for (final DayExerciseRef ref in day(1).exerciseRefs) ref.exerciseId,
        ],
      );
      await open(tester);

      expect(button('Antrenmana başla'), findsOneWidget);
      expect(find.text('Kaldığınız yerden devam edin'), findsNothing);
    });

    testWidgets('with other exercises than the day has is not offered',
        (WidgetTester tester) async {
      sessions.saved =
          sessionFor(1, ids: <String>['someone_else_01', 'x_02', 'x_03']);
      await open(tester);

      expect(button('Antrenmana başla'), findsOneWidget);
    });

    testWidgets('that was finished is not offered',
        (WidgetTester tester) async {
      sessions.saved = sessionFor(1, status: SessionStatus.completed);
      await open(tester);

      expect(button('Antrenmana başla'), findsOneWidget);
    });
  });

  group('a day trained today', () {
    testWidgets('with the next day started and left, offers to carry on',
        (WidgetTester tester) async {
      progress.profile = profileFor(
        _uid,
        currentProgramDay: 2,
        lastTrainingDate: _today,
      );
      final List<String> ids = <String>[
        for (final DayExerciseRef ref in day(2).exerciseRefs) ref.exerciseId,
      ];
      sessions.saved = TrainingSession(
        programDay: 2,
        exerciseIds: ids,
        status: SessionStatus.paused,
        currentIndex: 1,
        completedExerciseIds: <String>[ids.first],
      );
      await open(tester);

      expect(button('Kaldığınız yerden devam edin'), findsOneWidget);
      expect(find.text('Bugünkü antrenman tamam'), findsNothing);
    });

    testWidgets('shows as done, with the next day and a quiet way into it',
        (WidgetTester tester) async {
      progress.profile = profileFor(
        _uid,
        currentProgramDay: 2,
        currentStreak: 4,
        lastTrainingDate: _today,
      );
      await open(tester);

      expect(find.text('Bugünkü antrenman tamam'), findsOneWidget);
      expect(find.text('Sıradaki: ${day(2).title}'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(
        find.widgetWithText(TextButton, 'Sıradaki günü şimdi başlat'),
        findsOneWidget,
      );

      await tester.tap(find.text('Sıradaki günü şimdi başlat'));
      await tester.pumpAndSettle();
      final ExerciseContainerScreen screen = tester.widget(
        find.byType(ExerciseContainerScreen),
      );
      expect(screen.today.programDay, 2);
    });

    testWidgets(
        'finished but not yet recorded shows as done, saying it will be, '
        'and offers nothing more', (WidgetTester tester) async {
      // Offline: the day waits on the device, and recording it waits for the
      // network.
      progress.holdDays = Completer<void>();
      pending.days.add(
        PendingDay(
          uid: _uid,
          session: TrainingSession(
            programDay: 1,
            exerciseIds: const <String>['intro_text_01'],
            status: SessionStatus.completed,
            currentIndex: 0,
            completedExerciseIds: const <String>['intro_text_01'],
          ),
          date: _today,
          elapsed: const Duration(minutes: 12),
        ),
      );
      await open(tester);

      expect(find.text('Bugünkü antrenman tamam'), findsOneWidget);
      expect(
        find.text('Bağlantı gelince hesabınıza kaydedilecek.'),
        findsOneWidget,
      );
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('Sıradaki günü şimdi başlat'), findsNothing);
    });

    testWidgets(
        'another account\'s day waiting on the device is not this one\'s',
        (WidgetTester tester) async {
      pending.days.add(
        PendingDay(
          uid: 'someone-else',
          session: TrainingSession(
            programDay: 1,
            exerciseIds: const <String>['intro_text_01'],
            status: SessionStatus.completed,
            currentIndex: 0,
            completedExerciseIds: const <String>['intro_text_01'],
          ),
          date: _today,
          elapsed: const Duration(minutes: 12),
        ),
      );
      await open(tester);

      expect(button('Antrenmana başla'), findsOneWidget);
    });

    testWidgets('moving the programme day on, as a recording does, asks again',
        (WidgetTester tester) async {
      await open(tester);
      expect(button('Antrenmana başla'), findsOneWidget);

      progress.profile = profileFor(
        _uid,
        currentProgramDay: 2,
        lastTrainingDate: _today,
      );
      await tester.pumpAndSettle();

      expect(find.text('Bugünkü antrenman tamam'), findsOneWidget);
      expect(find.text('Sıradaki: ${day(2).title}'), findsOneWidget);
    });
  });

  group('a day waiting from an earlier date', () {
    testWidgets(
        'a day finished on an earlier date and still waiting leads to the '
        'day after it, not done', (WidgetTester tester) async {
      progress.holdDays = Completer<void>();
      pending.days.add(
        PendingDay(
          uid: _uid,
          session: TrainingSession(
            programDay: 1,
            exerciseIds: const <String>['intro_text_01'],
            status: SessionStatus.completed,
            currentIndex: 0,
            completedExerciseIds: const <String>['intro_text_01'],
          ),
          date: CalendarDay.fromDateTime(
            _now.subtract(const Duration(days: 1)),
          ),
          elapsed: const Duration(minutes: 12),
        ),
      );
      await open(tester);

      expect(find.text(day(2).title), findsOneWidget);
      expect(button('Antrenmana başla'), findsOneWidget);
      expect(find.text('Bugünkü antrenman tamam'), findsNothing);
    });
  });

  group('a finished programme', () {
    testWidgets('says so with what it came to, and is reported once',
        (WidgetTester tester) async {
      final int last = program.days.length;
      progress.profile = profileFor(
        _uid,
        currentProgramDay: last + 1,
        totalTrainingMinutes: 190,
        longestStreak: 9,
      );
      final ProviderContainer container = await open(tester);

      expect(find.text('Programı tamamladınız'), findsOneWidget);
      expect(
        find.text('Toplam 190 dakika çalıştınız; en uzun seriniz 9 gün.'),
        findsOneWidget,
      );
      expect(find.byType(ElevatedButton), findsNothing);
      expect(analytics.events, <AnalyticsEvent>[
        AnalyticsEvent.programFinished(programDay: last),
      ]);

      // Seen again, it is not finished again.
      container.invalidate(todayStatusProvider);
      await tester.pumpAndSettle();
      expect(find.text('Programı tamamladınız'), findsOneWidget);
      expect(analytics.events, hasLength(1));
      expect(reported.reported[_uid], last);
    });

    testWidgets('already reported on this device is not reported again',
        (WidgetTester tester) async {
      final int last = program.days.length;
      reported.reported[_uid] = last;
      progress.profile = profileFor(_uid, currentProgramDay: last + 1);
      await open(tester);

      expect(find.text('Programı tamamladınız'), findsOneWidget);
      expect(analytics.events, isEmpty);
    });
  });

  group('a day not quite as usual', () {
    /// Home over a day the test makes, rather than the engine's.
    Future<void> openWith(WidgetTester tester, TodayTraining today) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            onboardingStoreProvider.overrideWithValue(_Onboarded()),
            authStateChangesProvider.overrideWith(
              (Ref ref) => Stream<AuthUser?>.value(const AuthUser(uid: _uid)),
            ),
            userProgressRepositoryProvider.overrideWithValue(progress),
            curriculumRepositoryProvider.overrideWithValue(curriculum),
            sessionStoreProvider.overrideWithValue(sessions),
            pendingDayStoreProvider.overrideWithValue(pending),
            clockProvider.overrideWithValue(() => _now),
            todayStatusProvider.overrideWith(
              (Ref ref) async => TodayStatus(
                today: today,
                unfinished: null,
                finishedTodayUnrecorded: false,
                date: CalendarDay.fromDateTime(_now),
              ),
            ),
          ],
          child: const HitUpApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a short day says how many it lacks, and still starts',
        (WidgetTester tester) async {
      final ProgramDay first = day(1);
      await openWith(
        tester,
        TodayTraining(
          programDay: 1,
          day: first,
          resolved: ResolvedDay(
            exercises: <Exercise>[
              curriculum.exercises.byId(first.exerciseRefs.first.exerciseId)!,
            ],
            missingIds: const <String>['gone_01', 'gone_02'],
          ),
        ),
      );

      expect(
        find.text('2 egzersiz bu sürümde yok; gün onlarsız sürüyor.'),
        findsOneWidget,
      );
      // The day's own minutes, which count the pauses between exercises,
      // not the one exercise left's.
      expect(
        find.text('1 egzersiz · yaklaşık ${first.estimatedMinutes} dk'),
        findsOneWidget,
      );
      expect(button('Antrenmana başla'), findsOneWidget);
    });

    testWidgets('an empty day says so and offers nothing to start',
        (WidgetTester tester) async {
      await openWith(
        tester,
        TodayTraining(
          programDay: 1,
          day: day(1),
          resolved: const ResolvedDay(
            exercises: <Exercise>[],
            missingIds: <String>['gone_01'],
          ),
        ),
      );

      expect(find.text('Bugün çalışılacak egzersiz yok.'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.textContaining('bu sürümde yok'), findsNothing);
    });
  });

  group('when the account cannot be read', () {
    testWidgets('offline with nothing kept, starts from day one and says so',
        (WidgetTester tester) async {
      progress.offline = true;
      await open(tester);

      expect(find.text(day(1).title), findsOneWidget);
      expect(
        find.text(
          'Gününüz bağlantı gelince doğrulanacak; şimdilik ilk günden başlıyor.',
        ),
        findsOneWidget,
      );
      expect(button('Antrenmana başla'), findsOneWidget);
      // No figures from an account it could not read.
      expect(find.textContaining('günlük seri'), findsNothing);
    });

    testWidgets('a failure says so, and trying again can work',
        (WidgetTester tester) async {
      // Not the network, which starts from day one: a profile that cannot be
      // read is shown, with a way to try again.
      progress.failWith = const AppException(
        'A field of the wrong type',
        code: FailureCode.dataUnknown,
      );
      await open(tester);

      expect(button('Antrenmana başla'), findsNothing);
      expect(find.text('Tekrar dene'), findsOneWidget);

      progress.failWith = null;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();

      expect(button('Antrenmana başla'), findsOneWidget);
    });

    testWidgets(
        'a failure, shorter than the screen, can still be pulled down to try '
        'again', (WidgetTester tester) async {
      progress.failWith = const AppException(
        'A field of the wrong type',
        code: FailureCode.dataUnknown,
      );
      await open(tester);
      expect(find.text('Tekrar dene'), findsOneWidget);
      // Nothing to scroll: the failure leaves the list shorter than the
      // screen, which is where a pull down would otherwise go unnoticed.
      final ScrollPosition list = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      expect(list.maxScrollExtent, 0);

      progress.failWith = null;
      await tester.fling(
        find.descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(ListView),
        ),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(button('Antrenmana başla'), findsOneWidget);
    });

    testWidgets('a pull down that fails shows the failure, and is not a crash',
        (WidgetTester tester) async {
      await open(tester);
      progress.failWith = const AppException(
        'A field of the wrong type',
        code: FailureCode.dataUnknown,
      );

      await tester.fling(
        find.descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(ListView),
        ),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      // A failure let through would have failed the test as uncaught.
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(button('Antrenmana başla'), findsNothing);
    });
  });

  testWidgets(
      'the training day has no link of its own: without a day it goes '
      'home', (WidgetTester tester) async {
    await open(tester);

    GoRouter.of(tester.element(find.byType(HomeScreen))).go(RouteNames.session);
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseContainerScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  group('the copy', () {
    test('greets by the hour, with the name when there is one', () {
      expect(
        HomeLabelsTr.greeting(DateTime(2026, 1, 1, 7), 'Ada'),
        'Günaydın, Ada',
      );
      expect(
        HomeLabelsTr.greeting(DateTime(2026, 1, 1, 13), 'Ada'),
        'İyi günler, Ada',
      );
      expect(
        HomeLabelsTr.greeting(DateTime(2026, 1, 1, 19), ''),
        'İyi akşamlar',
      );
      expect(
        HomeLabelsTr.greeting(DateTime(2026, 1, 1, 23), ''),
        'İyi geceler',
      );
      expect(HomeLabelsTr.greeting(DateTime(2026, 1, 1, 3), ''), 'İyi geceler');
    });

    test('writes the date as Turkish does', () {
      expect(HomeLabelsTr.date(DateTime(2026, 10, 5)), '5 Ekim Pazartesi');
      expect(HomeLabelsTr.date(DateTime(2026, 2, 1)), '1 Şubat Pazar');
    });

    test('names a day by its title, or by its number without one', () {
      expect(HomeLabelsTr.day(3, '3. gün: Dil'), '3. gün: Dil');
      expect(HomeLabelsTr.day(3, '  '), 'Gün 3');
    });
  });

  group('the sun', () {
    test('is highest early in the afternoon, and low at either end of the day',
        () {
      final double noon = sunHeightAt(DateTime(2026, 6, 1, 13));
      final double morning = sunHeightAt(DateTime(2026, 6, 1, 7));
      final double evening = sunHeightAt(DateTime(2026, 6, 1, 19));
      expect(noon, closeTo(0.12, 0.001));
      expect(morning, greaterThan(noon));
      expect(morning, closeTo(evening, 0.001));
    });

    test('is behind the hills at night', () {
      expect(sunHeightAt(DateTime(2026, 6, 1, 23)), 0.8);
      expect(sunHeightAt(DateTime(2026, 6, 1, 4)), 0.8);
    });
  });
}
