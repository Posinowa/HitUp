import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/media/rive_runtime.dart';
import 'package:hitup/core/theme/app_theme.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/training/application/training_session_controller.dart';
import 'package:hitup/features/training/data/asset_curriculum_repository.dart';
import 'package:hitup/features/training/data/session_store.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/domain/training_session.dart';
import 'package:hitup/features/training/presentation/exercise_container_screen.dart';
import 'package:hitup/features/training/presentation/renderers/breathing_renderer.dart';
import 'package:hitup/features/training/presentation/renderers/letter_ladder_renderer.dart';
import 'package:hitup/features/training/presentation/renderers/tongue_twister_renderer.dart';
import 'package:hitup/shared/providers/auth_providers.dart';

/// A Rive runtime that does not run, so Rive exercises show their fallback
/// without the native library.
class _NoRive implements RiveRuntime {
  @override
  Future<bool> ensureReady() async => false;
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

/// Every exercise the app ships, in the exercise screen, at the sizes of a
/// large, a common and a small phone, with normal and enlarged text. A
/// layout that overflows fails the test, so this is where content that does
/// not fit shows up.
void main() {
  late ExerciseLibrary library;
  late TongueTwisterLibrary twisters;
  late LetterLadderLibrary letters;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    library = await AssetCurriculumRepository().loadExercises();
    // Loaded here, once, and handed to every screen. The asset bundle keeps
    // the future of a load; one started inside a test's fake clock and left
    // unfinished when that test ends never completes, and every later test
    // waiting on it hangs.
    twisters = await AssetCurriculumRepository().loadTongueTwisters();
    letters = await AssetCurriculumRepository().loadLetters();
    // The app's own fonts, not the test font, whose square glyphs are far
    // wider than real text: a layout that fits here fits on a phone.
    for (final (String family, List<String> files)
        in const <(String, List<String>)>[
      (
        'Manrope',
        <String>['Medium', 'Bold', 'ExtraBold'],
      ),
      (
        'PlusJakartaSans',
        <String>['Regular', 'Medium', 'SemiBold', 'Bold'],
      ),
    ]) {
      final FontLoader loader = FontLoader(family);
      for (final String weight in files) {
        loader.addFont(
          rootBundle.load('assets/fonts/$family/$family-$weight.ttf'),
        );
      }
      await loader.load();
    }
  });

  Future<void> showExercise(
    WidgetTester tester,
    Exercise exercise,
    Size screen, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = screen * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        sessionStoreProvider.overrideWithValue(_MemorySessions()),
        authStateChangesProvider.overrideWith(
          (Ref ref) => Stream<AuthUser?>.value(null),
        ),
        riveRuntimeProvider.overrideWithValue(_NoRive()),
        tongueTwistersProvider.overrideWith((Ref ref) async => twisters),
        letterLaddersProvider.overrideWith((Ref ref) async => letters),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: ExerciseContainerScreen(
            today: TodayTraining(
              programDay: 1,
              day: ProgramDay(
                day: 1,
                title: 'Gün 1',
                estimatedMinutes: 3,
                exerciseRefs: <DayExerciseRef>[
                  DayExerciseRef(exerciseId: exercise.id, position: 1),
                ],
              ),
              resolved: ResolvedDay(
                exercises: <Exercise>[exercise],
                missingIds: const <String>[],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  // A large phone, the most common small Android size, and the smallest
  // phone the app is laid out for.
  const List<(Size, double)> screens = <(Size, double)>[
    (Size(390, 844), 1),
    (Size(360, 640), 1),
    (Size(320, 568), 1),
    (Size(390, 844), 1.3),
    (Size(360, 640), 1.3),
    (Size(320, 568), 1.3),
  ];

  for (final (Size screen, double scale) in screens) {
    testWidgets(
        'every exercise in the content, of every type, fits at '
        '${screen.width.toInt()}x${screen.height.toInt()}, text x$scale',
        (WidgetTester tester) async {
      expect(library.exercises.length, greaterThan(40));
      for (final Exercise exercise in library.exercises) {
        await showExercise(tester, exercise, screen, textScale: scale);
        expect(tester.takeException(), isNull, reason: exercise.id);
        await tester.pumpWidget(const SizedBox());
      }
    });
  }

  for (final (Size screen, double scale) in screens) {
    testWidgets(
        'every breathing exercise runs and fits at '
        '${screen.width.toInt()}x${screen.height.toInt()}, text x$scale',
        (WidgetTester tester) async {
      final List<Exercise> drills = library.exercises
          .where(
            (Exercise e) =>
                e.presentationType == ExercisePresentationType.breathing,
          )
          .toList();
      expect(drills, isNotEmpty);

      for (final Exercise drill in drills) {
        await showExercise(tester, drill, screen, textScale: scale);
        await tester.pump(const Duration(seconds: 2));
        // What the exercise is followed by is in view, not below the fold.
        expect(
          find
              .text('Tur 1 / ${drill.configAs<BreathingConfig>()!.cycles}')
              .hitTestable(),
          findsOneWidget,
          reason: drill.id,
        );
        expect(
          find
              .byWidgetPredicate(
                (Widget w) =>
                    w is Text &&
                    const <String>{'Al', 'Tut', 'Ver'}.contains(w.data),
              )
              .hitTestable(),
          findsOneWidget,
          reason: drill.id,
        );
        expect(tester.takeException(), isNull, reason: drill.id);

        // Paused, the longest word is in view and in one piece.
        await tester.tap(find.text('Duraklat'));
        await tester.pump();
        final Finder paused = find.descendant(
          of: find.byType(BreathingView),
          matching: find.text('Duraklatıldı'),
        );
        expect(paused.hitTestable(), findsOneWidget, reason: drill.id);
        // One line of the title style (22 at a line height of 1.25).
        expect(
          tester.getSize(paused).height,
          lessThan(22 * 1.25 * scale * 1.5),
          reason: drill.id,
        );
        expect(tester.takeException(), isNull, reason: drill.id);
        await tester.pumpWidget(const SizedBox());
      }
    });
  }

  for (final (Size screen, double scale) in screens) {
    testWidgets(
        'every letter exercise shows its ladder and fits at '
        '${screen.width.toInt()}x${screen.height.toInt()}, text x$scale',
        (WidgetTester tester) async {
      final List<Exercise> drills = library.exercises
          .where(
            (Exercise e) =>
                e.presentationType == ExercisePresentationType.letter,
          )
          .toList();
      expect(drills, hasLength(14));

      for (final Exercise drill in drills) {
        await showExercise(tester, drill, screen, textScale: scale);
        await tester.pump();
        final LetterConfig config = drill.configAs<LetterConfig>()!;
        final LetterLadder ladder = letters.byKey(config.letterKey)!;
        expect(find.text(ladder.letter), findsOneWidget, reason: drill.id);
        // The button every saying is counted with is in view.
        expect(
          find.text('Söyledim').hitTestable(),
          findsOneWidget,
          reason: drill.id,
        );
        // So is the whole letter above it, but on the smallest phone at 130%
        // text, where the rung scrolls under the count.
        if (screen != const Size(320, 568) || scale == 1) {
          final Rect room = tester.getRect(
            find.descendant(
              of: find.byType(LetterLadderView),
              matching: find.byType(SingleChildScrollView),
            ),
          );
          expect(
            tester.getRect(find.text(ladder.letter)).bottom,
            lessThanOrEqualTo(room.bottom + 0.5),
            reason: drill.id,
          );
        }
        expect(tester.takeException(), isNull, reason: drill.id);
        await tester.pumpWidget(const SizedBox());
      }
    });
  }

  for (final (Size screen, double scale) in screens) {
    testWidgets(
        'every tongue twister set shows its twisters and fits at '
        '${screen.width.toInt()}x${screen.height.toInt()}, text x$scale',
        (WidgetTester tester) async {
      final List<Exercise> sets = library.exercises
          .where(
            (Exercise e) =>
                e.presentationType == ExercisePresentationType.tongueTwister,
          )
          .toList();
      expect(sets, isNotEmpty);

      for (final Exercise set in sets) {
        await showExercise(tester, set, screen, textScale: scale);
        await tester.pump();
        final TongueTwisterConfig config = set.configAs<TongueTwisterConfig>()!;
        // The first twister is shown, which means every id resolved.
        expect(
          find.text(twisters.byId(config.tongueTwisterIds.first)!.text),
          findsOneWidget,
          reason: set.id,
        );
        // The button every saying is counted with is in view.
        expect(
          find.text('Söyledim').hitTestable(),
          findsOneWidget,
          reason: set.id,
        );
        expect(tester.takeException(), isNull, reason: set.id);
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
