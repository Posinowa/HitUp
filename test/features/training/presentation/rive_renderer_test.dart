import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_messages.dart';
import 'package:hitup/core/media/rive_runtime.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/training/application/training_session_controller.dart';
import 'package:hitup/features/training/data/session_store.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/domain/training_session.dart';
import 'package:hitup/features/training/presentation/exercise_container_screen.dart';
import 'package:hitup/features/training/presentation/renderers/rive_renderer.dart';
import 'package:hitup/shared/providers/auth_providers.dart';

/// A runtime that answers what the test says, when it says.
class _Runtime implements RiveRuntime {
  _Runtime(this.answer);

  final Future<bool> answer;
  int asked = 0;

  @override
  Future<bool> ensureReady() {
    asked++;
    return answer;
  }
}

/// The device's copy of the session, in memory.
class _MemorySessions implements SessionStore {
  TrainingSession? saved;

  @override
  Future<TrainingSession?> load() async => saved;

  @override
  Future<void> save(TrainingSession session) async => saved = session;

  @override
  Future<void> clear() async => saved = null;
}

String _message(String code) => failureMessagesTr[code]!;

void main() {
  late List<String> loaded;
  late int factoriesMade;

  setUp(() {
    loaded = <String>[];
    factoriesMade = 0;
  });

  /// Shows [media] with the runtime answering [ready], and the bundle
  /// answering [load] (a missing file by default).
  Future<void> show(
    WidgetTester tester, {
    required MediaReference? media,
    Future<bool>? ready,
    Future<Uint8List> Function(String path)? load,
    _Runtime? runtime,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          riveRuntimeProvider.overrideWithValue(
            runtime ?? _Runtime(ready ?? Future<bool>.value(true)),
          ),
          riveBytesLoaderProvider.overrideWithValue((String path) {
            loaded.add(path);
            return load?.call(path) ??
                Future<Uint8List>.error(
                  FlutterError('Unable to load asset: "$path".'),
                );
          }),
          // Counted, and never made: reading a real factory loads the native
          // library, which these tests run without.
          riveFactoryProvider.overrideWithValue(() {
            factoriesMade++;
            throw StateError('no factory in these tests');
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: RiveExerciseView(media: media, running: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  const MediaReference lips = MediaReference(
    kind: MediaKind.rive,
    key: 'ux_lips',
    stateMachine: 'LipStates',
  );

  testWidgets('reads the file the content names, from assets/rive/',
      (WidgetTester tester) async {
    await show(tester, media: lips);

    expect(loaded, <String>['assets/rive/ux_lips.riv']);
  });

  testWidgets(
      'a file missing from the app is said to be missing, before anything '
      'reaches the runtime', (WidgetTester tester) async {
    await show(tester, media: lips);

    expect(
      find.text(_message(FailureCode.contentAssetMissing)),
      findsOneWidget,
    );
    expect(factoriesMade, 0);
  });

  testWidgets(
      'where Rive cannot run, says the animation cannot be shown and reads '
      'nothing', (WidgetTester tester) async {
    await show(tester, media: lips, ready: Future<bool>.value(false));

    expect(
      find.text(_message(FailureCode.contentMediaUnavailable)),
      findsOneWidget,
    );
    expect(loaded, isEmpty);
    expect(factoriesMade, 0);
  });

  testWidgets(
      'an exercise with no Rive media is a content mistake, and asks nothing',
      (WidgetTester tester) async {
    for (final MediaReference? media in <MediaReference?>[
      null,
      const MediaReference(kind: MediaKind.audio, key: 'ux_lips'),
    ]) {
      final _Runtime runtime = _Runtime(Future<bool>.value(true));
      await show(tester, media: media, runtime: runtime);

      expect(
        find.text(_message(FailureCode.contentMalformed)),
        findsOneWidget,
        reason: '$media',
      );
      expect(runtime.asked, 0, reason: '$media');
      expect(loaded, isEmpty, reason: '$media');
      // Each case on a fresh view: the same view at the same place would
      // be kept, and the second case never started.
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
      'new media starts a new load, and a load of the old media is dropped',
      (WidgetTester tester) async {
    final Completer<bool> answer = Completer<bool>();
    final _Runtime runtime = _Runtime(answer.future);
    final ValueNotifier<MediaReference> media =
        ValueNotifier<MediaReference>(lips);
    addTearDown(media.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          riveRuntimeProvider.overrideWithValue(runtime),
          riveBytesLoaderProvider.overrideWithValue((String path) {
            loaded.add(path);
            return Future<Uint8List>.error(
              FlutterError('Unable to load asset: "$path".'),
            );
          }),
          riveFactoryProvider.overrideWithValue(() {
            factoriesMade++;
            throw StateError('no factory in these tests');
          }),
        ],
        child: MaterialApp(
          home: ValueListenableBuilder<MediaReference>(
            valueListenable: media,
            builder: (BuildContext context, MediaReference value, Widget? _) =>
                RiveExerciseView(media: value, running: true),
          ),
        ),
      ),
    );

    media.value = const MediaReference(
      kind: MediaKind.rive,
      key: 'placeholder_sample',
      stateMachine: 'PlaceholderStates',
    );
    await tester.pump();
    answer.complete(true);
    await tester.pump();
    await tester.pump();

    expect(runtime.asked, 2);
    expect(loaded, <String>['assets/rive/placeholder_sample.riv']);
    expect(
      find.text(_message(FailureCode.contentAssetMissing)),
      findsOneWidget,
    );
  });

  testWidgets('says it is loading until the runtime answers',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final Completer<bool> answer = Completer<bool>();
    await show(tester, media: lips, ready: answer.future);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.bySemanticsLabel(RiveRendererLabelsTr.loading),
      findsOneWidget,
    );

    answer.complete(false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    semantics.dispose();
  });

  testWidgets('left while it loads, it reads nothing afterwards',
      (WidgetTester tester) async {
    final Completer<bool> answer = Completer<bool>();
    await show(tester, media: lips, ready: answer.future);

    await tester.pumpWidget(const SizedBox());
    answer.complete(true);
    await tester.pump();

    expect(loaded, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('any failure while opening the file is shown, not thrown',
      (WidgetTester tester) async {
    await show(
      tester,
      media: lips,
      load: (String path) async => Uint8List(4),
    );

    expect(factoriesMade, 1);
    expect(
      find.text(_message(FailureCode.contentMediaUnavailable)),
      findsNothing,
      reason: 'a StateError is not a Rive failure',
    );
    expect(find.text(_message(FailureCode.unknown)), findsOneWidget);
  });

  testWidgets(
      'inside the exercise screen, an articulation drill is shown by it, in '
      'the shared chrome', (WidgetTester tester) async {
    const Exercise drill = Exercise(
      id: 'articulation_lips_ux_01',
      title: 'U-X dudak',
      presentationType: ExercisePresentationType.articulation,
      durationSeconds: 30,
      instructions: 'Dudakları öne uzat, sonra yana çek.',
      media: lips,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        sessionStoreProvider.overrideWithValue(_MemorySessions()),
        authStateChangesProvider.overrideWith(
          (Ref ref) => Stream<AuthUser?>.value(null),
        ),
        riveRuntimeProvider.overrideWithValue(
          _Runtime(Future<bool>.value(false)),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ExerciseContainerScreen(
            today: TodayTraining(
              programDay: 1,
              day: ProgramDay(
                day: 1,
                title: 'Gün 1',
                estimatedMinutes: 1,
                exerciseRefs: <DayExerciseRef>[
                  DayExerciseRef(
                    exerciseId: 'articulation_lips_ux_01',
                    position: 1,
                  ),
                ],
              ),
              resolved: ResolvedDay(
                exercises: <Exercise>[drill],
                missingIds: <String>[],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(RiveExerciseView), findsOneWidget);
    expect(find.text('U-X dudak'), findsOneWidget);
    expect(
      find.text(_message(FailureCode.contentMediaUnavailable)),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
