import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_messages.dart';
import 'package:hitup/features/training/data/asset_curriculum_repository.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/presentation/renderers/tongue_twister_renderer.dart';

// Expected text is written out, not asked of the labels.

void main() {
  late TongueTwisterLibrary library;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The twisters the app ships, loaded once, outside any test's clock.
    library = await AssetCurriculumRepository().loadTongueTwisters();
  });

  Future<void> show(
    WidgetTester tester,
    TongueTwisterConfig? config, {
    ValueNotifier<bool>? running,
    Size? room,
  }) async {
    final ValueNotifier<bool> isRunning = running ?? ValueNotifier<bool>(true);
    final Widget view = ValueListenableBuilder<bool>(
      valueListenable: isRunning,
      builder: (BuildContext context, bool value, Widget? _) =>
          TongueTwisterView(config: config, running: value),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          tongueTwistersProvider.overrideWith((Ref ref) async => library),
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

  const TongueTwisterConfig set = TongueTwisterConfig(
    tongueTwisterIds: <String>['tt_a_01', 'tt_m_01'],
    repetitions: 2,
  );

  testWidgets(
      'the count and its button stay in view when the twister does not fit',
      (WidgetTester tester) async {
    await show(tester, set, room: const Size(300, 160));

    expect(find.text('Tekrar 0 / 2').hitTestable(), findsOneWidget);
    expect(find.text('Söyledim').hitTestable(), findsOneWidget);
    // The twister runs on under the count, where it is scrolled to; the
    // count and the button stay where they are.
    final TongueTwister first = library.byId('tt_a_01')!;
    expect(
      tester.getBottomLeft(find.text(first.text)).dy,
      greaterThan(tester.getTopLeft(find.text('Tekrar 0 / 2')).dy),
    );

    await say(tester);
    expect(find.text('Tekrar 1 / 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows the first twister, its place and its difficulty',
      (WidgetTester tester) async {
    await show(tester, set);

    final TongueTwister first = library.byId('tt_a_01')!;
    expect(find.text(first.text), findsOneWidget);
    expect(find.text('Tekerleme 1 / 2'), findsOneWidget);
    expect(find.text('Tekrar 0 / 2'), findsOneWidget);
    // tt_a_01 is an easy twister in the content.
    expect(first.difficulty, TongueTwisterDifficulty.easy);
    expect(find.text('Kolay'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'counts each saying, moves on after the repetitions, and ends after '
      'the last', (WidgetTester tester) async {
    await show(tester, set);

    await say(tester);
    expect(find.text('Tekrar 1 / 2'), findsOneWidget);
    expect(find.text('Tekerleme 1 / 2'), findsOneWidget);

    await say(tester);
    expect(find.text('Tekerleme 2 / 2'), findsOneWidget);
    expect(find.text('Tekrar 0 / 2'), findsOneWidget);
    expect(find.text(library.byId('tt_m_01')!.text), findsOneWidget);

    await say(tester);
    await say(tester);
    expect(find.text('Hepsi tamam'), findsOneWidget);
    expect(find.text('Söyledim'), findsNothing);

    await tester.tap(find.text('Baştan'));
    await tester.pump();
    expect(find.text('Tekerleme 1 / 2'), findsOneWidget);
    expect(find.text('Tekrar 0 / 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a set of one twister ends after its repetitions',
      (WidgetTester tester) async {
    await show(
      tester,
      const TongueTwisterConfig(
        tongueTwisterIds: <String>['tt_p_b_01'],
        repetitions: 3,
      ),
    );

    await say(tester);
    await say(tester);
    expect(find.text('Tekrar 2 / 3'), findsOneWidget);
    await say(tester);
    expect(find.text('Hepsi tamam'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sayings are not counted while the session is paused',
      (WidgetTester tester) async {
    final ValueNotifier<bool> running = ValueNotifier<bool>(false);
    addTearDown(running.dispose);
    await show(tester, set, running: running);

    await tester.tap(find.text('Söyledim'));
    await tester.pump();
    expect(find.text('Tekrar 0 / 2'), findsOneWidget);

    running.value = true;
    await tester.pump();
    await say(tester);
    expect(find.text('Tekrar 1 / 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('another set starts at its first twister',
      (WidgetTester tester) async {
    final ValueNotifier<TongueTwisterConfig> shown =
        ValueNotifier<TongueTwisterConfig>(set);
    addTearDown(shown.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          tongueTwistersProvider.overrideWith((Ref ref) async => library),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<TongueTwisterConfig>(
              valueListenable: shown,
              builder: (BuildContext context, TongueTwisterConfig value, _) =>
                  TongueTwisterView(config: value, running: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await say(tester);
    await say(tester);
    expect(find.text('Tekerleme 2 / 2'), findsOneWidget);

    shown.value = const TongueTwisterConfig(
      tongueTwisterIds: <String>['tt_r_01', 'tt_l_01'],
      repetitions: 2,
    );
    await tester.pump();

    expect(find.text('Tekerleme 1 / 2'), findsOneWidget);
    expect(find.text(library.byId('tt_r_01')!.text), findsOneWidget);
  });

  testWidgets(
      'a set naming a twister the content lacks, or no config, is a '
      'content mistake', (WidgetTester tester) async {
    for (final TongueTwisterConfig? config in <TongueTwisterConfig?>[
      const TongueTwisterConfig(
        tongueTwisterIds: <String>['tt_a_01', 'tt_nope'],
        repetitions: 2,
      ),
      null,
    ]) {
      await show(tester, config);
      expect(
        find.text(failureMessagesTr[FailureCode.contentMalformed]!),
        findsOneWidget,
        reason: '$config',
      );
      expect(find.text('Söyledim'), findsNothing, reason: '$config');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
