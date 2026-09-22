import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/presentation/renderers/countdown_renderer.dart';
import 'package:hitup/features/training/presentation/renderers/exercise_renderer.dart';
import 'package:hitup/features/training/presentation/renderers/exercise_renderers.dart';

class _Marker implements ExerciseRenderer {
  const _Marker(this.name);

  final String name;

  @override
  Widget build(BuildContext buildContext, ExerciseRenderContext context) =>
      Text(name);
}

Exercise _exercise(ExercisePresentationType type, {int seconds = 40}) =>
    Exercise(
      id: 'x',
      title: 'x',
      presentationType: type,
      durationSeconds: seconds,
      instructions: 'x',
    );

void main() {
  group('the registry', () {
    test('picks the renderer registered for a type', () {
      final ExerciseRendererRegistry registry = ExerciseRendererRegistry(
        const <ExercisePresentationType, ExerciseRenderer>{
          ExercisePresentationType.breathing: _Marker('breathing'),
        },
        fallback: const _Marker('fallback'),
      );

      expect(
        (registry.rendererFor(ExercisePresentationType.breathing) as _Marker)
            .name,
        'breathing',
      );
    });

    test('falls back for every type without one', () {
      final ExerciseRendererRegistry registry = ExerciseRendererRegistry(
        const <ExercisePresentationType, ExerciseRenderer>{},
        fallback: const _Marker('fallback'),
      );

      for (final ExercisePresentationType type
          in ExercisePresentationType.values) {
        expect(
          (registry.rendererFor(type) as _Marker).name,
          'fallback',
          reason: type.name,
        );
      }
    });

    test('keeps its own copy of the map it was given', () {
      final Map<ExercisePresentationType, ExerciseRenderer> renderers =
          <ExercisePresentationType, ExerciseRenderer>{};
      final ExerciseRendererRegistry registry = ExerciseRendererRegistry(
        renderers,
        fallback: const _Marker('fallback'),
      );

      renderers[ExercisePresentationType.text] = const _Marker('late');

      expect(
        (registry.rendererFor(ExercisePresentationType.text) as _Marker).name,
        'fallback',
      );
    });
  });

  group('the renderers this build has', () {
    late ExerciseRendererRegistry registry;

    setUp(() {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      registry = container.read(exerciseRendererRegistryProvider);
    });

    test('a countdown for timer, and the plain body for everything else', () {
      for (final ExercisePresentationType type
          in ExercisePresentationType.values) {
        expect(
          registry.rendererFor(type),
          type == ExercisePresentationType.timer
              ? isA<CountdownRenderer>()
              : isA<PlainExerciseRenderer>(),
          reason: type.name,
        );
      }
    });
  });

  group('the countdown', () {
    Future<CircularProgressIndicator> ring(
      WidgetTester tester, {
      required Duration remaining,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => const CountdownRenderer().build(
              context,
              ExerciseRenderContext(
                exercise: _exercise(ExercisePresentationType.timer),
                remaining: remaining,
                isRunning: true,
              ),
            ),
          ),
        ),
      );
      return tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
    }

    testWidgets('empties as the time runs out', (WidgetTester tester) async {
      expect(
        (await ring(tester, remaining: const Duration(seconds: 40))).value,
        1,
      );
      expect(
        (await ring(tester, remaining: const Duration(seconds: 10))).value,
        0.25,
      );
      expect((await ring(tester, remaining: Duration.zero)).value, 0);
    });

    testWidgets('never draws past full', (WidgetTester tester) async {
      expect(
        (await ring(tester, remaining: const Duration(seconds: 90))).value,
        1,
      );
    });

    testWidgets('is not read aloud; the time line says it',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await ring(tester, remaining: const Duration(seconds: 10));

      // A progress indicator reads its value as a number out of 100; left in
      // the tree this one would say "25".
      expect(find.semantics.byValue('25'), findsNothing);
      semantics.dispose();
    });
  });

  testWidgets('the plain body adds nothing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) =>
              const PlainExerciseRenderer().build(
            context,
            ExerciseRenderContext(
              exercise: _exercise(ExercisePresentationType.text),
              remaining: const Duration(seconds: 5),
              isRunning: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Text), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
