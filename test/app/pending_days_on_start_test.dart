import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/app.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/onboarding/data/onboarding_store.dart';
import 'package:hitup/features/progress/domain/models/calendar_day.dart';
import 'package:hitup/features/progress/domain/models/training_history_entry.dart';
import 'package:hitup/features/training/application/finished_day_recorder.dart';
import 'package:hitup/features/training/application/training_day_recorder.dart';
import 'package:hitup/features/training/data/pending_day_store.dart';
import 'package:hitup/features/training/domain/training_session.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/startup_providers.dart';

class _Onboarded implements OnboardingStore {
  @override
  Future<bool> isComplete() async => true;

  @override
  Future<void> markComplete() async {}
}

class _MemoryStore implements PendingDayStore {
  final List<PendingDay> days = <PendingDay>[];

  @override
  Future<List<PendingDay>> load() async => List<PendingDay>.of(days);

  @override
  Future<void> add(PendingDay day) async => days.add(day);

  @override
  Future<void> remove(PendingDay day) async =>
      days.removeWhere(day.isSameDayAs);
}

class _FakeRecorder implements TrainingDayRecorder {
  final List<CalendarDay> dates = <CalendarDay>[];

  @override
  Future<TrainingDayRecord> record({
    required String uid,
    required TrainingSession session,
    required CalendarDay today,
    required Duration elapsed,
  }) async {
    dates.add(today);
    return TrainingDayRecord(
      result: TrainingSaveResult.saved,
      programDay: session.programDay + 1,
      streak: null,
    );
  }
}

void main() {
  testWidgets('the app records the days an earlier run left pending',
      (WidgetTester tester) async {
    final _MemoryStore store = _MemoryStore()
      ..days.add(
        PendingDay(
          uid: 'uid-1',
          session: TrainingSession(
            programDay: 3,
            exerciseIds: const <String>['a'],
            status: SessionStatus.completed,
            currentIndex: 0,
            completedExerciseIds: const <String>['a'],
          ),
          date: CalendarDay(2026, 9, 17),
          elapsed: const Duration(minutes: 6),
        ),
      );
    final _FakeRecorder recorder = _FakeRecorder();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onboardingStoreProvider.overrideWithValue(_Onboarded()),
          authStateChangesProvider.overrideWith(
            (Ref ref) => Stream<AuthUser?>.value(const AuthUser(uid: 'uid-1')),
          ),
          pendingDayStoreProvider.overrideWithValue(store),
          trainingDayRecorderProvider.overrideWithValue(recorder),
        ],
        child: const HitUpApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(recorder.dates, <CalendarDay>[CalendarDay(2026, 9, 17)]);
    expect(store.days, isEmpty);
  });
}
