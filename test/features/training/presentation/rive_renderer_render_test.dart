@Tags(<String>['rive-native'])
library;

import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_messages.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/presentation/renderers/rive_renderer.dart';
import 'package:rive/rive.dart' as rive;

/// The Rive renderer on real files (HIT-033).
///
/// Needs the `rive_native` library for this machine; skipped unless asked
/// for (`dart_test.yaml`, `RIVE.md`). The fixtures stand in for
/// `assets/rive/<key>.riv`: `rocket` and `rating`, from the `rive` package's
/// MIT-licensed example (`test/fixtures/rive/README.md`).
void main() {
  late List<String> loaded;

  setUp(() => loaded = <String>[]);

  /// Shows [media], reading `assets/rive/<key>.riv` from the fixtures, or
  /// [bytes] when given.
  Future<void> show(
    WidgetTester tester,
    MediaReference media, {
    ValueNotifier<bool>? running,
    Uint8List? bytes,
  }) async {
    final ValueNotifier<bool> isRunning = running ?? ValueNotifier<bool>(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          riveBytesLoaderProvider.overrideWithValue((String path) async {
            loaded.add(path);
            return bytes ??
                io.File(
                  path.replaceFirst('assets/rive/', 'test/fixtures/rive/'),
                ).readAsBytesSync();
          }),
          // The Flutter factory draws in a widget test; the app draws with
          // the Rive one.
          riveFactoryProvider.overrideWithValue(() => rive.Factory.flutter),
        ],
        child: MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 240,
              child: ValueListenableBuilder<bool>(
                valueListenable: isRunning,
                builder: (BuildContext context, bool value, Widget? _) =>
                    RiveExerciseView(media: media, running: value),
              ),
            ),
          ),
        ),
      ),
    );
    // Decoding happens off the test's fake clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }

  rive.RiveWidgetController controllerShown(WidgetTester tester) =>
      tester.widget<rive.RiveWidget>(find.byType(rive.RiveWidget)).controller;

  testWidgets(
      'two different content configs are drawn by the same renderer, each '
      'with the state machine it names', (WidgetTester tester) async {
    for (final (String key, String machine) in const <(String, String)>[
      ('rocket', 'Button'),
      ('rating', 'State Machine 1'),
    ]) {
      await show(
        tester,
        MediaReference(kind: MediaKind.rive, key: key, stateMachine: machine),
      );

      expect(find.byType(rive.RiveWidget), findsOneWidget, reason: key);
      expect(controllerShown(tester).stateMachine.name, machine, reason: key);
      expect(tester.takeException(), isNull, reason: key);
      await tester.pumpWidget(const SizedBox());
    }
    expect(loaded, <String>[
      'assets/rive/rocket.riv',
      'assets/rive/rating.riv',
    ]);
  });

  testWidgets('with no state machine named, the default one is used',
      (WidgetTester tester) async {
    await show(
      tester,
      const MediaReference(kind: MediaKind.rive, key: 'rocket'),
    );

    expect(controllerShown(tester).stateMachine.name, 'Button');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('holds still while the session is paused, and moves again',
      (WidgetTester tester) async {
    final ValueNotifier<bool> running = ValueNotifier<bool>(false);
    addTearDown(running.dispose);
    await show(
      tester,
      const MediaReference(
        kind: MediaKind.rive,
        key: 'rocket',
        stateMachine: 'Button',
      ),
      running: running,
    );
    expect(controllerShown(tester).active, isFalse);

    running.value = true;
    await tester.pump();
    expect(controllerShown(tester).active, isTrue);

    running.value = false;
    await tester.pump();
    expect(controllerShown(tester).active, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('moves from one animation to another in the same place',
      (WidgetTester tester) async {
    final ValueNotifier<MediaReference> media = ValueNotifier<MediaReference>(
      const MediaReference(
        kind: MediaKind.rive,
        key: 'rocket',
        stateMachine: 'Button',
      ),
    );
    addTearDown(media.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          riveBytesLoaderProvider.overrideWithValue(
            (String path) async => io.File(
              path.replaceFirst('assets/rive/', 'test/fixtures/rive/'),
            ).readAsBytesSync(),
          ),
          riveFactoryProvider.overrideWithValue(() => rive.Factory.flutter),
        ],
        child: MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 240,
              child: ValueListenableBuilder<MediaReference>(
                valueListenable: media,
                builder:
                    (BuildContext context, MediaReference value, Widget? _) =>
                        RiveExerciseView(media: value, running: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(controllerShown(tester).stateMachine.name, 'Button');

    media.value = const MediaReference(
      kind: MediaKind.rive,
      key: 'rating',
      stateMachine: 'State Machine 1',
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(controllerShown(tester).stateMachine.name, 'State Machine 1');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'a state machine the file does not have is media that cannot be shown',
      (WidgetTester tester) async {
    await show(
      tester,
      const MediaReference(
        kind: MediaKind.rive,
        key: 'rocket',
        stateMachine: 'LipStates',
      ),
    );

    expect(find.byType(rive.RiveWidget), findsNothing);
    expect(
      find.text(failureMessagesTr[FailureCode.contentMediaUnavailable]!),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a file that is not a Rive file is media that cannot be shown',
      (WidgetTester tester) async {
    await show(
      tester,
      const MediaReference(kind: MediaKind.rive, key: 'rocket'),
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8]),
    );

    expect(find.byType(rive.RiveWidget), findsNothing);
    expect(
      find.text(failureMessagesTr[FailureCode.contentMediaUnavailable]!),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
