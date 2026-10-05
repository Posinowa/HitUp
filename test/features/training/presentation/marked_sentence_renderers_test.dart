import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_messages.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/presentation/renderers/exercise_renderer.dart';
import 'package:hitup/features/training/presentation/renderers/marked_sentence_renderers.dart';

// Expected text is written out here, not asked of the labels: a test that
// asks the code what to expect passes whatever the code says.

Exercise _exercise(ExercisePresentationType type, ExerciseConfig? config) =>
    Exercise(
      id: 'x',
      title: 'x',
      presentationType: type,
      durationSeconds: 90,
      instructions: 'x',
      config: config,
    );

Future<void> _show(
  WidgetTester tester,
  ExerciseRenderer renderer,
  Exercise exercise,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => renderer.build(
            context,
            ExerciseRenderContext(
              exercise: exercise,
              remaining: const Duration(seconds: 90),
              isRunning: true,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('the pause drill', () {
    const PauseConfig config = PauseConfig(
      text: 'Konuşurken acele etmeyen kişi, dinleyene düşünecek zaman bırakır.',
      pauseAfterWordIndexes: <int>[2, 5],
      pauseMilliseconds: 400,
    );

    testWidgets('marks a pause after each word the content names',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _show(
        tester,
        const PauseRenderer(),
        _exercise(ExercisePresentationType.pause, config),
      );

      expect(find.text('/'), findsNWidgets(2));
      expect(find.bySemanticsLabel('duraklama'), findsNWidgets(2));
      // Each mark sits right after its word: "etmeyen" (2) and "düşünecek"
      // (5), and nowhere else.
      for (final (String word, bool marked) in const <(String, bool)>[
        ('etmeyen', true),
        ('düşünecek', true),
        ('acele', false),
        ('bırakır.', false),
      ]) {
        final Finder row = find.ancestor(
          of: find.text(word),
          matching: find.byType(Row),
        );
        expect(
          find.descendant(of: row.first, matching: find.text('/')),
          marked ? findsOneWidget : findsNothing,
          reason: word,
        );
      }
      semantics.dispose();
    });

    testWidgets('says how long to pause, with a Turkish decimal comma',
        (WidgetTester tester) async {
      for (final (int ms, String hint) in const <(int, String)>[
        (400, 'Her / işaretinde yaklaşık 0,4 saniye dur.'),
        (500, 'Her / işaretinde yaklaşık 0,5 saniye dur.'),
        (1000, 'Her / işaretinde yaklaşık 1 saniye dur.'),
        (1500, 'Her / işaretinde yaklaşık 1,5 saniye dur.'),
      ]) {
        await _show(
          tester,
          const PauseRenderer(),
          _exercise(
            ExercisePresentationType.pause,
            PauseConfig(
              text: config.text,
              pauseAfterWordIndexes: config.pauseAfterWordIndexes,
              pauseMilliseconds: ms,
            ),
          ),
        );
        expect(find.text(hint), findsOneWidget, reason: '$ms');
      }
    });
  });

  group('the intonation drill', () {
    const IntonationConfig config = IntonationConfig(
      text: 'Bugün hava güzel, dışarı çıkmak iyi gelecek.',
      contour: <IntonationPoint>[
        IntonationPoint(wordIndex: 0, direction: ContourDirection.rise),
        IntonationPoint(wordIndex: 3, direction: ContourDirection.flat),
        IntonationPoint(wordIndex: 6, direction: ContourDirection.fall),
      ],
    );

    testWidgets('puts the arrow for each direction over its word',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _show(
        tester,
        const IntonationRenderer(),
        _exercise(ExercisePresentationType.intonation, config),
      );

      for (final (String word, IconData arrow, String spoken)
          in const <(String, IconData, String)>[
        ('Bugün', Icons.north_east, 'Bugün, yükselen'),
        ('dışarı', Icons.east, 'dışarı, düz'),
        ('gelecek.', Icons.south_east, 'gelecek., düşen'),
      ]) {
        final Finder column = find
            .ancestor(of: find.text(word), matching: find.byType(Column))
            .first;
        expect(
          find.descendant(of: column, matching: find.byIcon(arrow)),
          findsOneWidget,
          reason: word,
        );
        expect(find.bySemanticsLabel(spoken), findsOneWidget, reason: word);
      }
      // An unmarked word carries no arrow.
      final Finder hava = find
          .ancestor(of: find.text('hava'), matching: find.byType(Column))
          .first;
      expect(
        find.descendant(of: hava, matching: find.byType(Icon)),
        findsNothing,
      );
      semantics.dispose();
    });

    testWidgets('explains the three arrows', (WidgetTester tester) async {
      await _show(
        tester,
        const IntonationRenderer(),
        _exercise(ExercisePresentationType.intonation, config),
      );

      expect(find.text('yükselen'), findsOneWidget);
      expect(find.text('düz'), findsOneWidget);
      expect(find.text('düşen'), findsOneWidget);
    });

    testWidgets(
        'a direction this build does not know leaves its word unmarked, '
        'rather than guessing an arrow', (WidgetTester tester) async {
      await _show(
        tester,
        const IntonationRenderer(),
        _exercise(
          ExercisePresentationType.intonation,
          const IntonationConfig(
            text: 'Bugün hava güzel.',
            contour: <IntonationPoint>[
              IntonationPoint(
                wordIndex: 0,
                direction: ContourDirection.unknown,
              ),
            ],
          ),
        ),
      );

      final Finder bugun = find
          .ancestor(of: find.text('Bugün'), matching: find.byType(Column))
          .first;
      expect(
        find.descendant(of: bugun, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the emphasis drill', () {
    const EmphasisConfig config = EmphasisConfig(
      text: 'Bu kitabı sana ben aldım.',
      wordIndexes: <int>[0, 3, 4],
    );

    testWidgets('stresses one marked word per reading, in turn, and wraps',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _show(
        tester,
        const EmphasisRenderer(),
        _exercise(ExercisePresentationType.emphasis, config),
      );

      for (final (String reading, String stressed) in const <(String, String)>[
        ('Okuyuş 1 / 3: "Bu" öne çıksın', 'Bu, vurgulu'),
        ('Okuyuş 2 / 3: "ben" öne çıksın', 'ben, vurgulu'),
        ('Okuyuş 3 / 3: "aldım." öne çıksın', 'aldım., vurgulu'),
        ('Okuyuş 1 / 3: "Bu" öne çıksın', 'Bu, vurgulu'),
      ]) {
        expect(find.text(reading), findsOneWidget);
        expect(find.bySemanticsLabel(stressed), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('vurgulu')), findsOneWidget);
        await tester.tap(find.text('Sonraki okuyuş'));
        await tester.pump();
      }
      semantics.dispose();
    });

    testWidgets('a single stressed word needs no next reading',
        (WidgetTester tester) async {
      await _show(
        tester,
        const EmphasisRenderer(),
        _exercise(
          ExercisePresentationType.emphasis,
          const EmphasisConfig(text: 'Yarın gel.', wordIndexes: <int>[0]),
        ),
      );

      expect(find.text('Okuyuş 1 / 1: "Yarın" öne çıksın'), findsOneWidget);
      expect(find.text('Sonraki okuyuş'), findsNothing);
    });

    testWidgets('another sentence starts at its first reading',
        (WidgetTester tester) async {
      final ValueNotifier<EmphasisConfig> shown =
          ValueNotifier<EmphasisConfig>(config);
      addTearDown(shown.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<EmphasisConfig>(
              valueListenable: shown,
              builder: (BuildContext context, EmphasisConfig value, _) =>
                  EmphasisView(config: value),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sonraki okuyuş'));
      await tester.pump();
      expect(find.text('Okuyuş 2 / 3: "ben" öne çıksın'), findsOneWidget);

      shown.value = const EmphasisConfig(
        text: 'Yarın sabah erkenden yola çıkacağız.',
        wordIndexes: <int>[0, 2],
      );
      await tester.pump();

      expect(find.text('Okuyuş 1 / 2: "Yarın" öne çıksın'), findsOneWidget);
    });
  });

  testWidgets('each drill without its config is a content mistake',
      (WidgetTester tester) async {
    for (final (ExerciseRenderer renderer, ExercisePresentationType type)
        in const <(ExerciseRenderer, ExercisePresentationType)>[
      (PauseRenderer(), ExercisePresentationType.pause),
      (IntonationRenderer(), ExercisePresentationType.intonation),
      (EmphasisRenderer(), ExercisePresentationType.emphasis),
    ]) {
      await _show(tester, renderer, _exercise(type, null));
      expect(
        find.text(failureMessagesTr[FailureCode.contentMalformed]!),
        findsOneWidget,
        reason: type.name,
      );
      await tester.pumpWidget(const SizedBox());
    }
  });
}
