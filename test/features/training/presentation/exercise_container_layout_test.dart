import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/theme/app_theme.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/training/application/training_session_controller.dart';
import 'package:hitup/features/training/data/asset_curriculum_repository.dart';
import 'package:hitup/features/training/data/session_store.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/domain/training_session.dart';
import 'package:hitup/features/training/presentation/exercise_container_screen.dart';
import 'package:hitup/shared/providers/auth_providers.dart';

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

/// The exercise screen at the sizes of a large and a small phone, with the
/// app's own fonts and with text enlarged, as someone with large text set on
/// their phone sees it. A layout that overflows fails the test.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The app's fonts, not the test font, whose square glyphs are far wider
    // than real text: what fits here fits on a phone.
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

  // The longest instructions and title the content ships, so the check is
  // against the real worst case, not a sentence written to fit.
  late Exercise exercise;

  setUpAll(() async {
    final ExerciseLibrary library =
        await AssetCurriculumRepository().loadExercises();
    final Exercise longest = library.exercises.reduce(
      (Exercise a, Exercise b) =>
          a.instructions.length >= b.instructions.length ? a : b,
    );
    exercise = Exercise(
      id: 'layout_check',
      title: library.exercises
          .reduce(
            (Exercise a, Exercise b) =>
                a.title.length >= b.title.length ? a : b,
          )
          .title,
      presentationType: ExercisePresentationType.timer,
      durationSeconds: 60,
      instructions: longest.instructions,
    );
  });

  for (final (Size screen, double scale) in const <(Size, double)>[
    (Size(390, 844), 1),
    (Size(320, 568), 1),
    (Size(390, 844), 1.3),
    (Size(320, 568), 1.3),
  ]) {
    testWidgets(
        'the controls fit at ${screen.width.toInt()}x${screen.height.toInt()}'
        ', text x$scale, running and paused', (WidgetTester tester) async {
      tester.view.physicalSize = screen * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          sessionStoreProvider.overrideWithValue(_MemorySessions()),
          authStateChangesProvider.overrideWith(
            (Ref ref) => Stream<AuthUser?>.value(null),
          ),
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
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: ExerciseContainerScreen(
              today: TodayTraining(
                programDay: 1,
                day: const ProgramDay(
                  day: 1,
                  title: 'Gün 1',
                  estimatedMinutes: 1,
                  exerciseRefs: <DayExerciseRef>[
                    DayExerciseRef(exerciseId: 'layout_check', position: 1),
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
      expect(tester.takeException(), isNull, reason: 'running');
      expect(find.text(ExerciseContainerLabelsTr.complete), findsOneWidget);

      await tester.tap(find.text(ExerciseContainerLabelsTr.pause));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'paused');
      expect(find.text(ExerciseContainerLabelsTr.resume), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  }
}
