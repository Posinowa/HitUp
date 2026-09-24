import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/failure.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_messages.dart';
import 'package:hitup/core/theme/app_theme.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/progress/domain/models/calendar_day.dart';
import 'package:hitup/features/progress/domain/models/training_history_entry.dart';
import 'package:hitup/features/progress/domain/repositories/user_progress_repository.dart';
import 'package:hitup/features/progress/domain/streak.dart';
import 'package:hitup/features/training/application/finished_day_recorder.dart';
import 'package:hitup/features/training/application/training_day_recorder.dart';
import 'package:hitup/features/training/application/training_session_controller.dart';
import 'package:hitup/features/training/data/pending_day_store.dart';
import 'package:hitup/features/training/data/session_store.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/domain/training_session.dart';
import 'package:hitup/features/training/presentation/exercise_container_screen.dart';
import 'package:hitup/features/training/presentation/renderers/exercise_renderer.dart';
import 'package:hitup/features/training/presentation/renderers/exercise_renderers.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/progress_providers.dart';

typedef _L = ExerciseContainerLabelsTr;

/// Counts exercise completions, as the account would.
class _FakeProgress implements UserProgressRepository {
  final List<String> completions = <String>[];

  @override
  Future<void> saveExerciseCompletion(String uid, String exerciseId) async {
    completions.add(exerciseId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The device's copy of the session, with every write in order.
class _FakeSessionStore implements SessionStore {
  TrainingSession? saved;
  final List<String> ops = <String>[];

  @override
  Future<TrainingSession?> load() async => saved;

  @override
  Future<void> save(TrainingSession session) async {
    ops.add('save ${session.status.name}');
    saved = session;
  }

  @override
  Future<void> clear() async {
    ops.add('clear');
    saved = null;
  }
}

/// Pending days in memory, oldest first, the first session of a date kept.
class _MemoryPending implements PendingDayStore {
  final List<PendingDay> days = <PendingDay>[];

  @override
  Future<List<PendingDay>> load() async => List<PendingDay>.of(days)
    ..sort((PendingDay a, PendingDay b) => a.date.compareTo(b.date));

  @override
  Future<void> add(PendingDay day) async {
    if (!days.any(day.isSameDayAs)) {
      days.add(day);
    }
  }

  @override
  Future<void> remove(PendingDay day) async =>
      days.removeWhere(day.isSameDayAs);
}

/// Records what it was asked to record.
class _FakeRecorder implements TrainingDayRecorder {
  final List<
      ({
        String uid,
        TrainingSession session,
        CalendarDay today,
        Duration elapsed,
      })> calls = <({
    String uid,
    TrainingSession session,
    CalendarDay today,
    Duration elapsed,
  })>[];

  /// Thrown by the next call, then cleared.
  Object? failNext;

  /// When set, calls wait for it, as a write does offline.
  Completer<void>? gate;
  TrainingSaveResult result = TrainingSaveResult.saved;

  @override
  Future<TrainingDayRecord> record({
    required String uid,
    required TrainingSession session,
    required CalendarDay today,
    required Duration elapsed,
  }) async {
    calls.add((uid: uid, session: session, today: today, elapsed: elapsed));
    await gate?.future;
    final Object? failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    return TrainingDayRecord(
      result: result,
      programDay: session.programDay + 1,
      streak: StreakUpdate(
        currentStreak: 3,
        longestStreak: 5,
        lastTrainingDate: today,
        changed: true,
      ),
    );
  }
}

/// Shows its name and the context it was given.
class _Marker implements ExerciseRenderer {
  const _Marker(this.name);

  final String name;

  @override
  Widget build(BuildContext buildContext, ExerciseRenderContext context) =>
      Text(
        '$name ${context.exercise.id} '
        '${context.remaining.inSeconds} ${context.isRunning}',
      );
}

/// A renderer with state of its own, which counts how often it was made.
class _Stateful implements ExerciseRenderer {
  _Stateful();

  int created = 0;

  @override
  Widget build(BuildContext buildContext, ExerciseRenderContext context) =>
      _Counted(onCreate: () => created++);
}

class _Counted extends StatefulWidget {
  const _Counted({required this.onCreate});

  final VoidCallback onCreate;

  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Exercise _exercise(String id, ExercisePresentationType type, int seconds) =>
    Exercise(
      id: id,
      title: 'Başlık $id',
      presentationType: type,
      durationSeconds: seconds,
      instructions: 'Yönerge $id',
    );

/// Day 2: a timer, a text and a breathing exercise.
final List<Exercise> _day = <Exercise>[
  _exercise('a', ExercisePresentationType.timer, 30),
  _exercise('b', ExercisePresentationType.text, 20),
  _exercise('c', ExercisePresentationType.breathing, 60),
];

TodayTraining _today({List<Exercise>? exercises, int programDay = 2}) {
  final List<Exercise> list = exercises ?? _day;
  return TodayTraining(
    programDay: programDay,
    day: ProgramDay(
      day: programDay,
      title: 'Gün $programDay',
      estimatedMinutes: 5,
      exerciseRefs: <DayExerciseRef>[
        for (int i = 0; i < list.length; i++)
          DayExerciseRef(exerciseId: list[i].id, position: i + 1),
      ],
    ),
    resolved: ResolvedDay(exercises: list, missingIds: const <String>[]),
  );
}

void main() {
  late _FakeProgress progress;
  late _FakeSessionStore store;
  late _FakeRecorder recorder;
  late _MemoryPending pending;
  late ProviderContainer container;
  late DateTime now;

  setUp(() {
    progress = _FakeProgress();
    store = _FakeSessionStore();
    recorder = _FakeRecorder();
    pending = _MemoryPending();
    now = DateTime(2026, 9, 18, 10);
  });

  TrainingSession? session() => container.read(
        trainingSessionControllerProvider,
      );

  /// Opens the screen, signed in as [uid] unless it is null.
  Future<void> open(
    WidgetTester tester, {
    TodayTraining? today,
    String? uid = 'uid-1',
    ExerciseRendererRegistry? registry,
    Future<void> Function()? before,
    bool pushed = false,
  }) async {
    container = ProviderContainer(
      overrides: <Override>[
        sessionStoreProvider.overrideWithValue(store),
        userProgressRepositoryProvider.overrideWithValue(progress),
        trainingDayRecorderProvider.overrideWithValue(recorder),
        pendingDayStoreProvider.overrideWithValue(pending),
        authStateChangesProvider.overrideWith(
          (Ref ref) => Stream<AuthUser?>.value(
            uid == null ? null : AuthUser(uid: uid),
          ),
        ),
        if (registry != null)
          exerciseRendererRegistryProvider.overrideWithValue(registry),
      ],
    );
    addTearDown(container.dispose);
    await before?.call();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: pushed
              ? Builder(
                  builder: (BuildContext context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            ExerciseContainerScreen(
                          today: today ?? _today(),
                          now: () => now,
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                )
              : ExerciseContainerScreen(
                  today: today ?? _today(),
                  now: () => now,
                ),
        ),
      ),
    );
    if (pushed) {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }
    // The session starts after the first frame.
    await tester.pump();
  }

  /// Ends the test with the screen gone, so its clock is stopped before the
  /// framework checks for pending timers.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pump();
  }

  group('opening', () {
    testWidgets('starts the day on its first exercise, in the shared chrome',
        (WidgetTester tester) async {
      await open(tester);

      expect(session()!.status, SessionStatus.inProgress);
      expect(session()!.currentIndex, 0);
      expect(find.text('Başlık a'), findsOneWidget);
      expect(find.text('Yönerge a'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('0:30'), findsOneWidget);
      expect(find.text(_L.complete), findsOneWidget);
      expect(find.text(_L.skip), findsOneWidget);
      expect(find.text(_L.pause), findsOneWidget);
      expect(find.byTooltip(_L.finishTooltip), findsOneWidget);
      await close(tester);
    });

    testWidgets('carries on with a session in hand for the same day',
        (WidgetTester tester) async {
      store.saved = TrainingSession(
        programDay: 2,
        exerciseIds: const <String>['a', 'b', 'c'],
        status: SessionStatus.paused,
        currentIndex: 1,
        completedExerciseIds: const <String>['a'],
      );
      await open(
        tester,
        before: () async {
          await container
              .read(trainingSessionControllerProvider.notifier)
              .restore();
        },
      );

      expect(session()!.status, SessionStatus.paused);
      expect(session()!.completedExerciseIds, <String>['a']);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Başlık b'), findsOneWidget);
      expect(find.text(_L.paused), findsOneWidget);
      expect(find.text(_L.resume), findsOneWidget);
      expect(find.text(_L.complete), findsNothing);
      await close(tester);
    });

    testWidgets('replaces a session in hand for another day',
        (WidgetTester tester) async {
      store.saved = TrainingSession(
        programDay: 1,
        exerciseIds: const <String>['a', 'b', 'c'],
        status: SessionStatus.paused,
        currentIndex: 2,
        completedExerciseIds: const <String>['a', 'b'],
      );
      await open(
        tester,
        before: () async {
          await container
              .read(trainingSessionControllerProvider.notifier)
              .restore();
        },
      );

      expect(session()!.programDay, 2);
      expect(session()!.currentIndex, 0);
      expect(session()!.completedExerciseIds, isEmpty);
      expect(find.text('1 / 3'), findsOneWidget);
      await close(tester);
    });

    testWidgets('runs a day that has the same exercise twice',
        (WidgetTester tester) async {
      final Exercise a = _day.first;
      await open(tester, today: _today(exercises: <Exercise>[a, _day[1], a]));

      expect(find.text('1 / 3'), findsOneWidget);
      await tapText(tester, _L.complete);
      await tapText(tester, _L.complete);

      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('Başlık a'), findsOneWidget);
      await close(tester);
    });

    testWidgets('an empty day says so and starts nothing',
        (WidgetTester tester) async {
      await open(
        tester,
        today: const TodayTraining.programFinished(programDay: 30),
      );

      expect(find.text(_L.emptyDay), findsOneWidget);
      expect(session(), isNull);
      await close(tester);
    });
  });

  group('the renderer', () {
    testWidgets(
        'comes from the presentation type, with the fallback for a type '
        'without one', (WidgetTester tester) async {
      await open(
        tester,
        registry: ExerciseRendererRegistry(
          const <ExercisePresentationType, ExerciseRenderer>{
            ExercisePresentationType.text: _Marker('text'),
          },
          fallback: const _Marker('fallback'),
        ),
      );

      expect(find.text('fallback a 30 true'), findsOneWidget);
      await tapText(tester, _L.complete);
      expect(find.text('text b 20 true'), findsOneWidget);
      await tapText(tester, _L.complete);
      expect(find.text('fallback c 60 true'), findsOneWidget);
      await close(tester);
    });

    testWidgets('is told the time left and when the session is paused',
        (WidgetTester tester) async {
      await open(
        tester,
        registry: ExerciseRendererRegistry(
          const <ExercisePresentationType, ExerciseRenderer>{},
          fallback: const _Marker('r'),
        ),
      );

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('r a 26 true'), findsOneWidget);

      await tapText(tester, _L.pause);
      expect(find.text('r a 26 false'), findsOneWidget);
      await close(tester);
    });

    testWidgets('starts fresh on the next exercise, even of the same type',
        (WidgetTester tester) async {
      final _Stateful renderer = _Stateful();
      await open(
        tester,
        registry: ExerciseRendererRegistry(
          const <ExercisePresentationType, ExerciseRenderer>{},
          fallback: renderer,
        ),
      );
      expect(renderer.created, 1);

      // Ticking rebuilds it, and must not remake it.
      await tester.pump(const Duration(seconds: 3));
      expect(renderer.created, 1);

      await tapText(tester, _L.complete);
      expect(renderer.created, 2);
      await close(tester);
    });

    testWidgets('the timer type gets its countdown ring',
        (WidgetTester tester) async {
      await open(tester);

      // The ring, and the thin bar under the title.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tapText(tester, _L.complete);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await close(tester);
    });
  });

  group('the clock', () {
    testWidgets('counts the exercise down while it runs',
        (WidgetTester tester) async {
      await open(tester);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('0:27'), findsOneWidget);
      await close(tester);
    });

    testWidgets('stands still while paused', (WidgetTester tester) async {
      await open(tester);
      await tester.pump(const Duration(seconds: 1));

      await tapText(tester, _L.pause);
      expect(session()!.status, SessionStatus.paused);
      expect(find.text(_L.paused), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));

      await tapText(tester, _L.resume);
      expect(session()!.status, SessionStatus.inProgress);
      expect(find.text('0:29'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:28'), findsOneWidget);
      await close(tester);
    });

    testWidgets('says when the time is up, and does not move on by itself',
        (WidgetTester tester) async {
      await open(tester);

      await tester.pump(const Duration(seconds: 31));

      expect(find.text(_L.timeUp), findsOneWidget);
      expect(session()!.currentIndex, 0);
      expect(session()!.status, SessionStatus.inProgress);
      await close(tester);
    });

    testWidgets('starts again with the next exercise',
        (WidgetTester tester) async {
      await open(tester);
      await tester.pump(const Duration(seconds: 5));

      await tapText(tester, _L.complete);

      expect(find.text('0:20'), findsOneWidget);
      await close(tester);
    });

    testWidgets('pauses the session when the app is left',
        (WidgetTester tester) async {
      await open(tester);
      // One state at a time, as the platform delivers them: the binding
      // fills in the steps between for a real platform message, not for a
      // state set directly.
      void move(List<AppLifecycleState> states) {
        for (final AppLifecycleState state in states) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
      }

      move(<AppLifecycleState>[
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      await tester.pump();

      expect(session()!.status, SessionStatus.paused);
      expect(find.text(_L.resume), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      move(<AppLifecycleState>[
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pump();
      // Still paused on return: the user picks it up.
      expect(session()!.status, SessionStatus.paused);
      await tapText(tester, _L.resume);
      expect(find.text('0:30'), findsOneWidget);
      await close(tester);
    });
  });

  group('moving through the day', () {
    testWidgets('completing counts the exercise and moves on',
        (WidgetTester tester) async {
      await open(tester);

      await tapText(tester, _L.complete);

      expect(session()!.currentIndex, 1);
      expect(session()!.completedExerciseIds, <String>['a']);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Başlık b'), findsOneWidget);
      expect(progress.completions, <String>['a']);
      await close(tester);
    });

    testWidgets('skipping moves on without counting',
        (WidgetTester tester) async {
      await open(tester);

      await tapText(tester, _L.skip);

      expect(session()!.currentIndex, 1);
      expect(session()!.completedExerciseIds, isEmpty);
      expect(progress.completions, isEmpty);
      await close(tester);
    });

    testWidgets('two taps on the last exercise complete it once',
        (WidgetTester tester) async {
      await open(tester);
      await tapText(tester, _L.complete);
      await tapText(tester, _L.complete);

      // Both land before the screen rebuilds.
      await tester.tap(find.text(_L.complete));
      await tester.tap(find.text(_L.complete));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(recorder.calls, hasLength(1));
      expect(progress.completions, <String>['a', 'b', 'c']);
    });
  });

  group('the end of the day', () {
    testWidgets('records the day with what was done and how long it took',
        (WidgetTester tester) async {
      await open(tester);
      await tester.pump(const Duration(seconds: 10));
      await tapText(tester, _L.complete);
      await tester.pump(const Duration(seconds: 5));
      await tapText(tester, _L.complete);
      await tapText(tester, _L.complete);
      await tester.pumpAndSettle();

      expect(recorder.calls, hasLength(1));
      final ({
        String uid,
        TrainingSession session,
        CalendarDay today,
        Duration elapsed,
      }) call = recorder.calls.single;
      expect(call.uid, 'uid-1');
      expect(call.session.status, SessionStatus.completed);
      expect(call.session.completedExerciseIds, <String>['a', 'b', 'c']);
      expect(call.today, CalendarDay(2026, 9, 18));
      expect(call.elapsed, const Duration(seconds: 15));

      expect(find.text(_L.dayDone), findsOneWidget);
      expect(find.text(_L.completedCount(3)), findsOneWidget);
      expect(find.text(_L.streak(3)), findsOneWidget);
      expect(find.text(_L.alreadySaved), findsNothing);
    });

    testWidgets(
        'shows what was done at once, while the recording is still out, '
        'and the streak once it is in', (WidgetTester tester) async {
      recorder.gate = Completer<void>();
      await open(tester, pushed: true);
      for (int i = 0; i < 3; i++) {
        await tapText(tester, _L.complete);
      }
      await tester.pump();

      expect(recorder.calls, hasLength(1));
      expect(find.text(_L.dayDone), findsOneWidget);
      expect(find.text(_L.completedCount(3)), findsOneWidget);
      expect(find.text(_L.saving), findsOneWidget);
      expect(find.text(_L.streak(3)), findsNothing);
      // Not cleared while the recording is out: it is the safety net.
      expect(session()!.status, SessionStatus.completed);

      recorder.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.text(_L.saving), findsNothing);
      expect(find.text(_L.streak(3)), findsOneWidget);
      expect(session(), isNull);
    });

    testWidgets('can be left while the recording is still out, which goes on',
        (WidgetTester tester) async {
      recorder.gate = Completer<void>();
      await open(tester, pushed: true);
      for (int i = 0; i < 3; i++) {
        await tapText(tester, _L.complete);
      }
      await tester.pump();

      await tester.tap(find.text(_L.close));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseContainerScreen), findsNothing);

      recorder.gate!.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(session(), isNull);
      expect(store.ops.last, 'clear');
    });

    testWidgets('closing the finished day leaves the screen',
        (WidgetTester tester) async {
      await open(tester, pushed: true);
      for (int i = 0; i < 3; i++) {
        await tapText(tester, _L.complete);
      }
      await tester.pumpAndSettle();

      await tester.tap(find.text(_L.close));
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseContainerScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('clears the session only once it is recorded',
        (WidgetTester tester) async {
      await open(tester);
      for (int i = 0; i < 3; i++) {
        await tapText(tester, _L.complete);
      }
      await tester.pumpAndSettle();

      expect(session(), isNull);
      expect(store.ops.last, 'clear');
      expect(
        store.ops.indexOf('save completed'),
        lessThan(store.ops.lastIndexOf('clear')),
      );
    });

    testWidgets('time paused is not counted', (WidgetTester tester) async {
      await open(tester);
      await tester.pump(const Duration(seconds: 3));
      await tapText(tester, _L.pause);
      await tester.pump(const Duration(seconds: 10));
      await tapText(tester, _L.resume);
      await tester.pump(const Duration(seconds: 2));
      for (int i = 0; i < 3; i++) {
        await tapText(tester, _L.complete);
      }
      await tester.pumpAndSettle();

      expect(recorder.calls.single.elapsed, const Duration(seconds: 5));
    });

    testWidgets('a day recorded before says so', (WidgetTester tester) async {
      recorder.result = TrainingSaveResult.alreadySaved;
      await open(tester);
      for (int i = 0; i < 3; i++) {
        await tapText(tester, _L.complete);
      }
      await tester.pumpAndSettle();

      expect(find.text(_L.alreadySaved), findsOneWidget);
    });

    testWidgets(
        'a failed recording keeps the session and can be retried, under the '
        'date the day ended on', (WidgetTester tester) async {
      recorder.failNext = const NetworkFailure(
        code: FailureCode.networkOffline,
      );
      now = DateTime(2026, 9, 18, 23, 59);
      await open(tester);
      for (int i = 0; i < 3; i++) {
        await tapText(tester, _L.complete);
      }
      await tester.pumpAndSettle();

      expect(
        find.text(failureMessagesTr[FailureCode.networkOffline]!),
        findsOneWidget,
      );
      expect(session()!.status, SessionStatus.completed);
      expect(store.ops, isNot(contains('clear')));
      // Kept on the device with its date and time, for the next launch.
      expect(pending.days.single.date, CalendarDay(2026, 9, 18));
      expect(pending.days.single.elapsed, recorder.calls.first.elapsed);
      expect(pending.days.single.uid, 'uid-1');

      // Past midnight by the time the user retries.
      now = DateTime(2026, 9, 19, 0, 1);
      await tapText(tester, FailureLabelsTr.retry);
      await tester.pumpAndSettle();

      expect(recorder.calls, hasLength(2));
      expect(recorder.calls.last.today, CalendarDay(2026, 9, 18));
      expect(recorder.calls.last.elapsed, recorder.calls.first.elapsed);
      expect(find.text(_L.dayDone), findsOneWidget);
      expect(session(), isNull);
      expect(pending.days, isEmpty);
    });

    testWidgets('records a day an earlier run left pending first, then its own',
        (WidgetTester tester) async {
      pending.days.add(
        PendingDay(
          uid: 'uid-1',
          session: TrainingSession(
            programDay: 1,
            exerciseIds: const <String>['a'],
            status: SessionStatus.completed,
            currentIndex: 0,
            completedExerciseIds: const <String>['a'],
          ),
          date: CalendarDay(2026, 9, 17),
          elapsed: const Duration(minutes: 4),
        ),
      );
      await open(tester);
      for (int i = 0; i < 3; i++) {
        await tapText(tester, _L.complete);
      }
      await tester.pumpAndSettle();

      expect(
        <int>[for (final c in recorder.calls) c.today.day],
        <int>[17, 18],
      );
      expect(pending.days, isEmpty);
      expect(find.text(_L.dayDone), findsOneWidget);
    });

    testWidgets('signed out, nothing is recorded and the session is kept',
        (WidgetTester tester) async {
      await open(tester, uid: null);
      for (int i = 0; i < 3; i++) {
        await tapText(tester, _L.complete);
      }
      await tester.pumpAndSettle();

      expect(find.text(_L.signedOut), findsOneWidget);
      expect(recorder.calls, isEmpty);
      expect(store.ops, isNot(contains('clear')));
    });
  });

  group('finishing early', () {
    testWidgets('asks first, and the clock stands still while it asks',
        (WidgetTester tester) async {
      await open(tester);
      await tapText(tester, _L.complete);
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.byTooltip(_L.finishTooltip));
      await tester.pumpAndSettle();
      expect(find.text(_L.finishQuestion), findsOneWidget);
      expect(find.text(_L.finishKeeps), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));

      await tester.tap(find.text(_L.resume));
      await tester.pumpAndSettle();

      expect(session()!.status, SessionStatus.inProgress);
      expect(find.text('0:18'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:17'), findsOneWidget);
      expect(recorder.calls, isEmpty);
      await close(tester);
    });

    testWidgets('records what was done', (WidgetTester tester) async {
      await open(tester);
      await tapText(tester, _L.complete);

      await tester.tap(find.byTooltip(_L.finishTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_L.finishConfirm));
      await tester.pumpAndSettle();

      expect(recorder.calls.single.session.completedExerciseIds, <String>[
        'a',
      ]);
      expect(find.text(_L.dayEnded), findsOneWidget);
      expect(find.text(_L.completedCount(1)), findsOneWidget);
    });

    testWidgets('the back button asks the same question',
        (WidgetTester tester) async {
      await open(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(_L.finishQuestion), findsOneWidget);
      expect(find.byType(ExerciseContainerScreen), findsOneWidget);
      expect(session()!.status, SessionStatus.inProgress);
      await tester.tap(find.text(_L.resume));
      await tester.pumpAndSettle();
      await close(tester);
    });

    testWidgets(
        'with nothing done, says it will not be recorded, records nothing '
        'and clears the session after it was saved', (
      WidgetTester tester,
    ) async {
      await open(tester);

      await tester.tap(find.byTooltip(_L.finishTooltip));
      await tester.pumpAndSettle();
      expect(find.text(_L.finishKeepsNothing), findsOneWidget);
      await tester.tap(find.text(_L.finishConfirm));
      await tester.pumpAndSettle();

      expect(find.text(_L.nothingToSave), findsOneWidget);
      expect(recorder.calls, isEmpty);
      expect(session(), isNull);
      // The finished session is saved by the transition, then cleared. The
      // other way round would leave it on the device.
      expect(store.ops.last, 'clear');
      expect(store.saved, isNull);
    });
  });

  group('accessibility', () {
    testWidgets('reads the position and the time left in words',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await open(tester);

      expect(find.bySemanticsLabel(_L.position(1, 3)), findsOneWidget);
      expect(find.bySemanticsLabel(_L.secondsLeft(30)), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.bySemanticsLabel(_L.secondsLeft(29)), findsOneWidget);
      await close(tester);
      semantics.dispose();
    });
  });
}
