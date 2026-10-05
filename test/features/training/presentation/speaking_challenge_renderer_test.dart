import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/analytics/analytics_event.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_messages.dart';
import 'package:hitup/core/media/speaking_recorder.dart';
import 'package:hitup/features/training/data/asset_curriculum_repository.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/presentation/renderers/speaking_challenge_renderer.dart';
import 'package:hitup/shared/providers/analytics_providers.dart';

import '../../../support/recording_analytics.dart';

// Expected text is written out, not asked of the labels.

/// Writes down what the challenge tells it, in order.
class _Recorder implements SpeakingRecorder {
  final List<String> calls = <String>[];

  @override
  void start() => calls.add('start');

  @override
  void pause() => calls.add('pause');

  @override
  void resume() => calls.add('resume');

  @override
  void stop() => calls.add('stop');

  @override
  void cancel() => calls.add('cancel');
}

void main() {
  late SpeakingChallengeLibrary library;
  late SpeakingChallenge intro;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The challenges the app ships.
    library = await AssetCurriculumRepository().loadSpeakingChallenges();
    intro = library.byId('sc_intro_60')!;
  });

  Future<void> show(
    WidgetTester tester, {
    String? challengeId = 'sc_intro_60',
    ValueNotifier<bool>? running,
    SpeakingRecorder? recorder,
    RecordingAnalytics? analytics,
    Size? room,
  }) async {
    final ValueNotifier<bool> isRunning = running ?? ValueNotifier<bool>(true);
    final Widget view = ValueListenableBuilder<bool>(
      valueListenable: isRunning,
      builder: (BuildContext context, bool value, Widget? _) =>
          SpeakingChallengeView(
        config: challengeId == null
            ? null
            : SpeakingChallengeConfig(challengeId: challengeId),
        running: value,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          speakingChallengesProvider.overrideWith((Ref ref) async => library),
          if (recorder != null)
            speakingRecorderProvider.overrideWithValue(recorder),
          if (analytics != null)
            analyticsServiceProvider.overrideWithValue(analytics),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: room == null
                ? view
                : Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox.fromSize(size: room, child: view),
                  ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
  }

  /// Through the preparation, into the speaking phase.
  Future<void> toSpeaking(WidgetTester tester) async {
    await tap(tester, 'Hazırlan');
    await tester.pump(Duration(seconds: intro.preparationSeconds));
    // The countdown reports its end after the frame.
    await tester.pump();
  }

  group('analytics', () {
    AnalyticsEvent started() => AnalyticsEvent.speakingChallengeStarted(
          speakingChallengeId: 'sc_intro_60',
        );
    AnalyticsEvent completed(int seconds) =>
        AnalyticsEvent.speakingChallengeCompleted(
          speakingChallengeId: 'sc_intro_60',
          durationSeconds: seconds,
        );

    testWidgets('a speaking ended early is reported with the seconds spoken',
        (WidgetTester tester) async {
      final RecordingAnalytics analytics = RecordingAnalytics();
      await show(tester, analytics: analytics);

      await toSpeaking(tester);
      // Preparing is not speaking: nothing is reported for it.
      expect(analytics.events, <AnalyticsEvent>[started()]);

      await tester.pump(const Duration(seconds: 12));
      await tap(tester, 'Bitirdim');

      expect(analytics.events, <AnalyticsEvent>[started(), completed(12)]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the time running out reports the whole length',
        (WidgetTester tester) async {
      final RecordingAnalytics analytics = RecordingAnalytics();
      await show(tester, analytics: analytics);

      await toSpeaking(tester);
      await tester.pump(Duration(seconds: intro.durationSeconds));
      await tester.pump();

      expect(analytics.events, <AnalyticsEvent>[started(), completed(60)]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('time the session spends paused is not counted as spoken',
        (WidgetTester tester) async {
      final RecordingAnalytics analytics = RecordingAnalytics();
      final ValueNotifier<bool> running = ValueNotifier<bool>(true);
      addTearDown(running.dispose);
      await show(tester, analytics: analytics, running: running);

      await toSpeaking(tester);
      await tester.pump(const Duration(seconds: 10));
      running.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      running.value = true;
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tap(tester, 'Bitirdim');

      expect(analytics.events.last, completed(15));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a speaking left before its end is not reported as completed',
        (WidgetTester tester) async {
      final RecordingAnalytics analytics = RecordingAnalytics();
      await show(tester, analytics: analytics);

      await toSpeaking(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox());

      expect(analytics.events, <AnalyticsEvent>[started()]);
    });

    test('every challenge the content ships can be reported', () {
      expect(library.challenges, isNotEmpty);
      for (final SpeakingChallenge challenge in library.challenges) {
        expect(
          () => AnalyticsEvent.speakingChallengeCompleted(
            speakingChallengeId: challenge.id,
            durationSeconds: challenge.durationSeconds,
          ),
          returnsNormally,
          reason: challenge.id,
        );
      }
    });
  });

  test('the challenge the tests use is the one the content ships', () {
    expect(intro.preparationSeconds, 5);
    expect(intro.durationSeconds, 60);
  });

  testWidgets('shows the prompt and both lengths before anything starts',
      (WidgetTester tester) async {
    await show(tester);

    expect(find.text(intro.prompt), findsOneWidget);
    expect(find.text('Hazırlık 5 sn · Konuşma 60 sn'), findsOneWidget);
    expect(find.text('Hazırlan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('prepares for the challenge length, then gives the time to speak',
      (WidgetTester tester) async {
    await show(tester);

    await tap(tester, 'Hazırlan');
    expect(find.text('Ne anlatacağını düşün'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('1:00'), findsNothing, reason: 'still preparing');

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('1:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 15));
    expect(find.text('0:45'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('in a narrow room the time and its button wrap, not overflow',
      (WidgetTester tester) async {
    // The test font's glyphs are a full em wide, so side by side the time
    // and the button are wider than this room, as real text is at the
    // largest text sizes.
    await show(tester, room: const Size(260, 400));
    await tap(tester, 'Hazırlan');
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.text('1:00'), findsOneWidget);
    expect(find.text('Bitirdim').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('another challenge starts again from its prompt',
      (WidgetTester tester) async {
    final ValueNotifier<String> shown = ValueNotifier<String>('sc_intro_60');
    addTearDown(shown.dispose);
    final _Recorder recorder = _Recorder();
    final RecordingAnalytics analytics = RecordingAnalytics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          speakingChallengesProvider.overrideWith((Ref ref) async => library),
          speakingRecorderProvider.overrideWithValue(recorder),
          analyticsServiceProvider.overrideWithValue(analytics),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: shown,
              builder: (BuildContext context, String id, _) =>
                  SpeakingChallengeView(
                config: SpeakingChallengeConfig(challengeId: id),
                running: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await toSpeaking(tester);
    expect(find.text('1:00'), findsOneWidget);

    shown.value = 'sc_story_120';
    await tester.pump();

    expect(find.text(library.byId('sc_story_120')!.prompt), findsOneWidget);
    expect(find.text('Hazırlan'), findsOneWidget);
    // The last challenge's time does not run on under this one, and what
    // was spoken for it is not kept.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Hazırlan'), findsOneWidget);
    expect(recorder.calls, <String>['start', 'cancel']);
    // Started, and left before its end: not counted as completed.
    expect(analytics.events, <AnalyticsEvent>[
      AnalyticsEvent.speakingChallengeStarted(
        speakingChallengeId: 'sc_intro_60',
      ),
    ]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'tells the recorder when the speaking starts, pauses, resumes '
      'and ends', (WidgetTester tester) async {
    final _Recorder recorder = _Recorder();
    final ValueNotifier<bool> running = ValueNotifier<bool>(true);
    addTearDown(running.dispose);
    await show(tester, running: running, recorder: recorder);

    await tap(tester, 'Hazırlan');
    expect(recorder.calls, isEmpty, reason: 'preparing is not speaking');
    await tester.pump(Duration(seconds: intro.preparationSeconds));
    await tester.pump();
    expect(recorder.calls, <String>['start']);

    running.value = false;
    await tester.pump();
    running.value = true;
    await tester.pump();
    await tap(tester, 'Bitirdim');
    expect(recorder.calls, <String>['start', 'pause', 'resume', 'stop']);

    // Over, it is kept: leaving the screen now cancels nothing.
    await tester.pumpWidget(const SizedBox());
    expect(recorder.calls, <String>['start', 'pause', 'resume', 'stop']);
  });

  testWidgets('the time running out ends the recording as well',
      (WidgetTester tester) async {
    final _Recorder recorder = _Recorder();
    await show(tester, recorder: recorder);
    await toSpeaking(tester);

    await tester.pump(const Duration(seconds: 60));

    expect(recorder.calls, <String>['start', 'stop']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a speaking left before its end is not kept',
      (WidgetTester tester) async {
    final _Recorder recorder = _Recorder();
    await show(tester, recorder: recorder);
    await toSpeaking(tester);

    await tester.pumpWidget(const SizedBox());

    expect(recorder.calls, <String>['start', 'cancel']);
  });

  testWidgets('a preparation broken off records nothing',
      (WidgetTester tester) async {
    final _Recorder recorder = _Recorder();
    final ValueNotifier<bool> running = ValueNotifier<bool>(true);
    addTearDown(running.dispose);
    await show(tester, running: running, recorder: recorder);

    // Called off, and broken off by a pause.
    await tap(tester, 'Hazırlan');
    await tap(tester, 'Vazgeç');
    // The countdown reports its end after the frame.
    await tester.pump();
    await tap(tester, 'Hazırlan');
    running.value = false;
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));

    expect(recorder.calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ends when the time is up', (WidgetTester tester) async {
    await show(tester);
    await toSpeaking(tester);

    await tester.pump(const Duration(seconds: 60));

    expect(find.text('Konuşma bitti'), findsOneWidget);
    expect(find.text('Bitirdim'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('can be ended early, and done again',
      (WidgetTester tester) async {
    await show(tester);
    await toSpeaking(tester);
    await tester.pump(const Duration(seconds: 10));

    await tap(tester, 'Bitirdim');
    expect(find.text('Konuşma bitti'), findsOneWidget);

    await tap(tester, 'Tekrar');
    expect(find.text('Hazırlan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the speaking time stands still while the session is paused',
      (WidgetTester tester) async {
    final ValueNotifier<bool> running = ValueNotifier<bool>(true);
    addTearDown(running.dispose);
    await show(tester, running: running);
    await toSpeaking(tester);
    await tester.pump(const Duration(seconds: 10));

    running.value = false;
    await tester.pump();
    expect(find.text('Duraklatıldı'), findsOneWidget);
    await tester.pump(const Duration(minutes: 3));

    running.value = true;
    await tester.pump();
    expect(find.text('0:50'), findsOneWidget);
    // And it moves again from there.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('0:45'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a preparation broken off by a pause starts again',
      (WidgetTester tester) async {
    final ValueNotifier<bool> running = ValueNotifier<bool>(true);
    addTearDown(running.dispose);
    await show(tester, running: running);
    await tap(tester, 'Hazırlan');
    await tester.pump(const Duration(seconds: 2));

    running.value = false;
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));

    expect(find.text('Hazırlan'), findsOneWidget);
    expect(find.text('1:00'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the preparation can be called off', (WidgetTester tester) async {
    await show(tester);
    await tap(tester, 'Hazırlan');

    await tap(tester, 'Vazgeç');
    await tester.pump();

    expect(find.text('Hazırlan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reads the time left in words', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await show(tester);
    await toSpeaking(tester);
    await tester.pump(const Duration(seconds: 3));

    expect(
      find.bySemanticsLabel('Konuşma: 57 saniye kaldı'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets(
      'a challenge the content does not have, or no config at all, is a '
      'content mistake', (WidgetTester tester) async {
    for (final String? id in <String?>['sc_nope', null]) {
      await show(tester, challengeId: id);
      expect(
        find.text(failureMessagesTr[FailureCode.contentMalformed]!),
        findsOneWidget,
        reason: '$id',
      );
      expect(find.text('Hazırlan'), findsNothing, reason: '$id');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('challenges that cannot be loaded are shown as a failure',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          speakingChallengesProvider.overrideWith(
            (Ref ref) async => throw FlutterError(
              'Unable to load asset: "assets/content/speaking_challenges.json".',
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SpeakingChallengeView(
              config: SpeakingChallengeConfig(challengeId: 'sc_intro_60'),
              running: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(failureMessagesTr[FailureCode.contentAssetMissing]!),
      findsOneWidget,
    );
    expect(find.text('Hazırlan'), findsNothing);
  });
}
