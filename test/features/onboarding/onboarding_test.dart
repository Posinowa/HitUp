import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/app.dart';
import 'package:hitup/app/shell/main_shell.dart';
import 'package:hitup/core/analytics/analytics_event.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/auth/presentation/login_screen.dart';
import 'package:hitup/features/onboarding/application/onboarding_controller.dart';
import 'package:hitup/features/onboarding/data/onboarding_answers_store.dart';
import 'package:hitup/features/onboarding/data/onboarding_store.dart';
import 'package:hitup/features/onboarding/domain/onboarding_answers.dart';
import 'package:hitup/features/onboarding/presentation/onboarding_screen.dart';
import 'package:hitup/features/training/application/finished_day_recorder.dart';
import 'package:hitup/features/training/data/pending_day_store.dart';
import 'package:hitup/shared/providers/analytics_providers.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/startup_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/recording_analytics.dart';

/// The onboarding flag, in memory, and what was asked of it in order.
class _Flag implements OnboardingStore {
  bool complete = false;
  Object? error;
  final List<String> calls;

  /// While set, a read waits for it.
  Completer<void>? held;

  /// While set, keeping the flag waits for it.
  Completer<void>? heldWrite;

  _Flag(this.calls);

  @override
  Future<bool> isComplete() async {
    await held?.future;
    return complete;
  }

  @override
  Future<void> markComplete() async {
    calls.add('flag');
    await heldWrite?.future;
    if (error != null) {
      throw error!;
    }
    complete = true;
  }
}

/// No training day waiting to be recorded, for an account signed in.
class _NothingPending implements PendingDayStore {
  @override
  Future<List<PendingDay>> load() async => const <PendingDay>[];

  @override
  Future<void> add(PendingDay day) async {}

  @override
  Future<void> remove(PendingDay day) async {}
}

/// The answers, in memory.
class _Answers implements OnboardingAnswersStore {
  OnboardingAnswers? saved;
  final List<String> calls;

  _Answers(this.calls);

  @override
  Future<OnboardingAnswers> load() async => saved ?? const OnboardingAnswers();

  @override
  Future<void> save(OnboardingAnswers answers) async {
    calls.add('answers');
    saved = answers;
  }
}

void main() {
  group('the answers', () {
    test('a goal is chosen and chosen again to take it back', () {
      const OnboardingAnswers none = OnboardingAnswers();
      final OnboardingAnswers one = none.toggling(SpeakingGoal.clarity);
      expect(one.goals, <SpeakingGoal>{SpeakingGoal.clarity});
      expect(one.toggling(SpeakingGoal.clarity), none);
      expect(none.isEmpty, isTrue);
      expect(one.isEmpty, isFalse);
    });

    test('one choice of minutes, which can be taken back', () {
      const OnboardingAnswers none = OnboardingAnswers();
      expect(none.choosing(10).dailyMinutes, 10);
      expect(none.choosing(10).choosing(15).dailyMinutes, 15);
      expect(none.choosing(10).choosing(10).dailyMinutes, isNull);
      // Minutes alone are an answer, kept like any other.
      expect(none.choosing(10).isEmpty, isFalse);
    });

    test('one answer leaves the other as it was', () {
      const OnboardingAnswers none = OnboardingAnswers();
      expect(
        none.choosing(10).toggling(SpeakingGoal.clarity).dailyMinutes,
        10,
      );
      expect(
        none.toggling(SpeakingGoal.clarity).choosing(10).goals,
        <SpeakingGoal>{SpeakingGoal.clarity},
      );
    });

    test('compare by what was chosen, in any order', () {
      final OnboardingAnswers a = const OnboardingAnswers()
          .toggling(SpeakingGoal.clarity)
          .toggling(SpeakingGoal.confidence);
      final OnboardingAnswers b = const OnboardingAnswers()
          .toggling(SpeakingGoal.confidence)
          .toggling(SpeakingGoal.clarity);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.choosing(5), isNot(a));
    });

    test('every goal has its own stored key, read back to itself', () {
      final Set<String> keys = <String>{};
      for (final SpeakingGoal goal in SpeakingGoal.values) {
        expect(keys.add(goal.key), isTrue, reason: goal.key);
        expect(SpeakingGoal.fromKey(goal.key), goal);
      }
      expect(SpeakingGoal.fromKey('uydurma'), isNull);
      // What devices hold: a key changed here strands what was kept under it.
      expect(keys, <String>{
        'clarity',
        'confidence',
        'public_speaking',
        'pronunciation',
      });
    });
  });

  group('the device store', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('keeps the answers, and reads them back', () async {
      const PreferencesOnboardingAnswersStore store =
          PreferencesOnboardingAnswersStore();
      final OnboardingAnswers answers = const OnboardingAnswers()
          .toggling(SpeakingGoal.publicSpeaking)
          .choosing(15);

      await store.save(answers);

      expect(await store.load(), answers);
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      expect(
        preferences.getStringList(PreferencesOnboardingAnswersStore.goalsKey),
        <String>['public_speaking'],
      );
      expect(
        preferences.getInt(PreferencesOnboardingAnswersStore.minutesKey),
        15,
      );
    });

    test('minutes taken back are not kept', () async {
      const PreferencesOnboardingAnswersStore store =
          PreferencesOnboardingAnswersStore();
      await store.save(const OnboardingAnswers().choosing(10));
      await store.save(const OnboardingAnswers());

      expect((await store.load()).dailyMinutes, isNull);
    });

    test('a goal a later build stored is left out, not a failure', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesOnboardingAnswersStore.goalsKey: <String>[
          'clarity',
          'a_goal_from_later',
        ],
      });

      expect(
        (await const PreferencesOnboardingAnswersStore().load()).goals,
        <SpeakingGoal>{SpeakingGoal.clarity},
      );
    });

    test('nothing kept reads as nothing answered', () async {
      expect(
        await const PreferencesOnboardingAnswersStore().load(),
        const OnboardingAnswers(),
      );
    });
  });

  group('finishing', () {
    test('a second finish while one runs is ignored', () async {
      final List<String> calls = <String>[];
      final _Flag flag = _Flag(calls)..heldWrite = Completer<void>();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          onboardingStoreProvider.overrideWithValue(flag),
          onboardingAnswersStoreProvider.overrideWithValue(_Answers(calls)),
          analyticsServiceProvider.overrideWithValue(RecordingAnalytics()),
        ],
      );
      addTearDown(container.dispose);
      // Kept, as the screen keeps it while it shows.
      container.listen<AsyncValue<bool>>(
        onboardingControllerProvider,
        (_, __) {},
      );
      final OnboardingController controller =
          container.read(onboardingControllerProvider.notifier);

      final Future<void> first = controller.finish(const OnboardingAnswers());
      final Future<void> second = controller.finish(const OnboardingAnswers());
      flag.heldWrite!.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(calls, <String>['flag']);
      expect(container.read(onboardingControllerProvider).value, isTrue);
    });
  });

  group('the screen', () {
    late List<String> calls;
    late _Flag flag;
    late _Answers answers;
    late RecordingAnalytics analytics;

    setUp(() {
      calls = <String>[];
      flag = _Flag(calls);
      answers = _Answers(calls);
      analytics = RecordingAnalytics();
    });

    /// The app on a new device, with [user] signed in or nobody: it opens on
    /// onboarding.
    Future<void> open(WidgetTester tester, {AuthUser? user}) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            onboardingStoreProvider.overrideWithValue(flag),
            onboardingAnswersStoreProvider.overrideWithValue(answers),
            analyticsServiceProvider.overrideWithValue(analytics),
            authStateChangesProvider.overrideWith(
              (Ref ref) => Stream<AuthUser?>.value(user),
            ),
            pendingDayStoreProvider.overrideWithValue(_NothingPending()),
          ],
          child: const HitUpApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    }

    Future<void> press(WidgetTester tester, String label) async {
      await tester.tap(find.widgetWithText(ElevatedButton, label));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'three pages, then each question on a page of its own, then the '
        'account screens', (WidgetTester tester) async {
      await open(tester);
      expect(find.text('Daha net konuşun'), findsOneWidget);

      await press(tester, 'İleri');
      expect(find.text('Günde birkaç dakika'), findsOneWidget);
      await press(tester, 'İleri');
      expect(find.text('Bir alışkanlık edinin'), findsOneWidget);
      await press(tester, 'İleri');
      // The first question, alone, with no skipping: it can be left blank.
      expect(find.text('Neyi geliştirmek istiyorsunuz?'), findsOneWidget);
      expect(find.text('Günde ne kadar zaman ayırabilirsiniz?'), findsNothing);
      expect(find.text('Atla'), findsNothing);

      await tester.tap(find.text('Topluluk önünde konuşmak'));
      await tester.tap(find.text('Daha net konuşmak'));
      await tester.pump();
      // What was chosen shows as chosen.
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Daha net konuşmak'),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Telaffuzumu düzeltmek'),
            )
            .value,
        isFalse,
      );

      await press(tester, 'İleri');
      // The second question, alone, where the way on is to start.
      expect(
        find.text('Günde ne kadar zaman ayırabilirsiniz?'),
        findsOneWidget,
      );
      expect(find.text('Neyi geliştirmek istiyorsunuz?'), findsNothing);
      expect(find.text('Atla'), findsNothing);
      await tester.tap(find.text('10 dk'));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '10 dk'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '5 dk'))
            .selected,
        isFalse,
      );
      await press(tester, 'Başla');

      // The answers before the flag: a flag kept with its answers lost would
      // never ask again.
      expect(calls, <String>['answers', 'flag']);
      expect(
        answers.saved,
        const OnboardingAnswers(
          goals: <SpeakingGoal>{
            SpeakingGoal.publicSpeaking,
            SpeakingGoal.clarity,
          },
          dailyMinutes: 10,
        ),
      );
      expect(analytics.events, <AnalyticsEvent>[
        AnalyticsEvent.onboardingCompleted(),
      ]);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('the pages swipe too', (WidgetTester tester) async {
      await open(tester);

      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(find.text('Günde birkaç dakika'), findsOneWidget);
    });

    testWidgets('skipping finishes with nothing answered',
        (WidgetTester tester) async {
      await open(tester);

      await tester.tap(find.text('Atla'));
      await tester.pumpAndSettle();

      expect(calls, <String>['flag']);
      expect(answers.saved, isNull);
      expect(flag.complete, isTrue);
      expect(analytics.events, hasLength(1));
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('skipping after answering keeps what was answered',
        (WidgetTester tester) async {
      await open(tester);
      for (int i = 0; i < 3; i++) {
        await press(tester, 'İleri');
      }
      await tester.tap(find.text('Daha net konuşmak'));
      await tester.pump();
      // Back from the first question to the third page, where skipping is
      // offered.
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Atla'));
      await tester.pumpAndSettle();

      expect(
        answers.saved,
        const OnboardingAnswers(goals: <SpeakingGoal>{SpeakingGoal.clarity}),
      );
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('a second tap is not a second finish',
        (WidgetTester tester) async {
      await open(tester);
      for (int i = 0; i < 4; i++) {
        await press(tester, 'İleri');
      }
      await tester.tap(find.text('10 dk'));
      await tester.pump();

      // Both before the next frame, so the button is still enabled for the
      // second, though the first may have finished by then.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Başla'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Başla'));
      await tester.pumpAndSettle();

      expect(calls, <String>['answers', 'flag']);
      expect(analytics.events, hasLength(1));
    });

    testWidgets('once finished, nothing can be pressed until the screen goes',
        (WidgetTester tester) async {
      await open(tester);
      for (int i = 0; i < 4; i++) {
        await press(tester, 'İleri');
      }
      // Startup's second look at the flag is slow, so the screen stays a
      // while after the finish has worked.
      flag.held = Completer<void>();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Başla'));
      await tester.pump();
      await tester.pump();

      expect(flag.complete, isTrue);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '10 dk'))
            .onSelected,
        isNull,
      );
      // Nor the first question's, swiped back to.
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .onChanged,
        isNull,
      );

      flag.held!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(calls, <String>['flag']);
    });

    testWidgets('an account already signed in goes home after it, not to login',
        (WidgetTester tester) async {
      await open(tester, user: const AuthUser(uid: 'uid-1'));

      await tester.tap(find.text('Atla'));
      await tester.pumpAndSettle();

      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('questions left blank keep nothing but the flag',
        (WidgetTester tester) async {
      await open(tester);
      for (int i = 0; i < 4; i++) {
        await press(tester, 'İleri');
      }

      await press(tester, 'Başla');

      expect(calls, <String>['flag']);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('a flag that cannot be kept says so and offers a retry',
        (WidgetTester tester) async {
      await open(tester);
      flag.error = Exception('disk full');

      await tester.tap(find.text('Atla'));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(SnackBarAction), findsOneWidget);
      expect(analytics.events, isEmpty);

      flag.error = null;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();

      expect(flag.complete, isTrue);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('the page is read out with where it is',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await open(tester);

      expect(find.bySemanticsLabel('Sayfa 1 / 5'), findsOneWidget);
      await press(tester, 'İleri');
      expect(find.bySemanticsLabel('Sayfa 2 / 5'), findsOneWidget);
      semantics.dispose();
    });
  });
}
