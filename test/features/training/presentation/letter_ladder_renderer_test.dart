import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_messages.dart';
import 'package:hitup/features/training/data/asset_curriculum_repository.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/presentation/renderers/letter_ladder_renderer.dart';

// Expected text is written out, not asked of the labels.

void main() {
  late LetterLadderLibrary library;
  late LetterLadder ladderA;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The ladders the app ships, loaded once, outside any test's clock.
    library = await AssetCurriculumRepository().loadLetters();
    ladderA = library.byKey('a')!;
  });

  Future<void> show(
    WidgetTester tester,
    LetterConfig? config, {
    ValueNotifier<bool>? running,
    LetterLadderLibrary? ladders,
    Size? room,
  }) async {
    final ValueNotifier<bool> isRunning = running ?? ValueNotifier<bool>(true);
    final Widget view = ValueListenableBuilder<bool>(
      valueListenable: isRunning,
      builder: (BuildContext context, bool value, Widget? _) =>
          LetterLadderView(config: config, running: value),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          letterLaddersProvider.overrideWith(
            (Ref ref) async => ladders ?? library,
          ),
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

  Future<void> say(WidgetTester tester) async {
    await tester.tap(find.text('Söyledim'));
    await tester.pump();
  }

  const LetterConfig config = LetterConfig(letterKey: 'a', repetitions: 2);

  testWidgets(
      'the count and its button stay in view when the ladder does not fit',
      (WidgetTester tester) async {
    await show(tester, config, room: const Size(300, 160));

    expect(find.text('Tekrar 0 / 2').hitTestable(), findsOneWidget);
    expect(find.text('Söyledim').hitTestable(), findsOneWidget);
    // The note runs on under the count, where it is scrolled to; the count
    // and the button stay where they are.
    expect(
      tester.getBottomLeft(find.text(ladderA.notes!)).dy,
      greaterThan(tester.getTopLeft(find.text('Tekrar 0 / 2')).dy),
    );

    await say(tester);
    expect(find.text('Tekrar 1 / 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('starts on the sound, with the letter and its note',
      (WidgetTester tester) async {
    await show(tester, config);

    expect(find.text('Ses · Basamak 1 / 3'), findsOneWidget);
    expect(find.text(ladderA.letter), findsOneWidget);
    expect(find.text(ladderA.notes!), findsOneWidget);
    expect(find.text('Tekrar 0 / 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('climbs from the sound to the syllables to the words',
      (WidgetTester tester) async {
    await show(tester, config);

    await say(tester);
    await say(tester);
    expect(find.text('Heceler · Basamak 2 / 3'), findsOneWidget);
    for (final String syllable in ladderA.syllables) {
      expect(find.text(syllable), findsOneWidget, reason: syllable);
    }

    await say(tester);
    await say(tester);
    expect(find.text('Kelimeler · Basamak 3 / 3'), findsOneWidget);
    for (final String word in ladderA.words) {
      expect(find.text(word), findsOneWidget, reason: word);
    }

    await say(tester);
    await say(tester);
    expect(find.text('Merdiven tamam'), findsOneWidget);
    expect(find.text('Söyledim'), findsNothing);

    await tester.tap(find.text('Baştan'));
    await tester.pump();
    expect(find.text('Ses · Basamak 1 / 3'), findsOneWidget);
    expect(find.text('Tekrar 0 / 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sayings are not counted while the session is paused',
      (WidgetTester tester) async {
    final ValueNotifier<bool> running = ValueNotifier<bool>(false);
    addTearDown(running.dispose);
    await show(tester, config, running: running);

    await tester.tap(find.text('Söyledim'));
    await tester.pump();
    expect(find.text('Tekrar 0 / 2'), findsOneWidget);

    running.value = true;
    await tester.pump();
    await say(tester);
    expect(find.text('Tekrar 1 / 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('another letter starts at its own sound',
      (WidgetTester tester) async {
    final ValueNotifier<LetterConfig> shown =
        ValueNotifier<LetterConfig>(config);
    addTearDown(shown.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          letterLaddersProvider.overrideWith((Ref ref) async => library),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<LetterConfig>(
              valueListenable: shown,
              builder: (BuildContext context, LetterConfig value, _) =>
                  LetterLadderView(config: value, running: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await say(tester);
    await say(tester);
    expect(find.text('Heceler · Basamak 2 / 3'), findsOneWidget);

    final LetterLadder other = library.ladders.firstWhere(
      (LetterLadder l) => l.key != 'a',
    );
    shown.value = LetterConfig(letterKey: other.key, repetitions: 2);
    await tester.pump();

    expect(find.text('Ses · Basamak 1 / 3'), findsOneWidget);
    expect(find.text(other.letter), findsOneWidget);
  });

  testWidgets('a ladder with no words is that much shorter',
      (WidgetTester tester) async {
    await show(
      tester,
      const LetterConfig(letterKey: 'x', repetitions: 1),
      ladders: LetterLadderLibrary(
        envelope: library.envelope,
        ladders: <LetterLadder>[
          const LetterLadder(
            key: 'x',
            letter: 'X',
            syllables: <String>['XA'],
            words: <String>[],
          ),
        ],
      ),
    );

    expect(find.text('Ses · Basamak 1 / 2'), findsOneWidget);
    await say(tester);
    expect(find.text('Heceler · Basamak 2 / 2'), findsOneWidget);
    await say(tester);
    expect(find.text('Merdiven tamam'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a letter the content lacks, or no config, is a content mistake',
      (WidgetTester tester) async {
    for (final LetterConfig? broken in <LetterConfig?>[
      const LetterConfig(letterKey: 'zzz', repetitions: 2),
      null,
    ]) {
      await show(tester, broken);
      expect(
        find.text(failureMessagesTr[FailureCode.contentMalformed]!),
        findsOneWidget,
        reason: '$broken',
      );
      expect(find.text('Söyledim'), findsNothing, reason: '$broken');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('ladders that cannot be loaded are shown as a failure',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          letterLaddersProvider.overrideWith(
            (Ref ref) async => throw FlutterError(
              'Unable to load asset: "assets/content/letters.json".',
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LetterLadderView(
              config: LetterConfig(letterKey: 'a', repetitions: 2),
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
    expect(find.text('Söyledim'), findsNothing);
  });
}
