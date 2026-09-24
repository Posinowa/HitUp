@Tags(<String>['rive-native'])
library;

import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/failure.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_mapper.dart';
import 'package:hitup/core/media/rive_runtime.dart';
import 'package:rive/rive.dart';

/// Renders a real `.riv` file through the Rive runtime (HIT-032).
///
/// Needs the `rive_native` library for the machine running the tests, which
/// `flutter test` does not fetch, so the `rive-native` tag is skipped unless
/// asked for (`dart_test.yaml`). How to run it: `docs/architecture/RIVE.md`.
///
/// The fixture is `rocket.riv` from the `rive` package's example, shipped
/// under the package's MIT licence (`test/fixtures/rive/README.md`).
void main() {
  late File file;

  setUpAll(() async {
    expect(
      await NativeRiveRuntime().ensureReady(),
      isTrue,
      reason: 'The rive_native library for this machine is missing. '
          'See docs/architecture/RIVE.md, "Running the render test".',
    );
    final File? decoded = await File.decode(
      io.File('test/fixtures/rive/rocket.riv').readAsBytesSync(),
      riveFactory: Factory.flutter,
    );
    expect(decoded, isNotNull, reason: 'rocket.riv did not decode');
    file = decoded!;
  });

  tearDownAll(() => file.dispose());

  test('the file names its artboard and state machine', () {
    final Artboard? artboard = file.defaultArtboard();

    expect(artboard, isNotNull);
    expect(artboard!.stateMachineCount(), 1);
    expect(artboard.stateMachineAt(0)!.name, 'Button');
  });

  testWidgets('the state machine the content names is drawn',
      (WidgetTester tester) async {
    final RiveWidgetController controller = RiveWidgetController(
      file,
      stateMachineSelector: StateMachineSelector.byName('Button'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 240,
            child: RiveWidget(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(RiveWidget), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
      'a Rive file missing from the bundle is reported as a missing asset',
      (WidgetTester tester) async {
    // Here, not with the tests that run everywhere: reading `Factory.flutter`
    // already loads the native library. `File.asset`, not `FileLoader`: the
    // loader also fails a completer nobody listens to (RIVE.md).
    Object? thrown;
    await tester.runAsync(() async {
      try {
        await File.asset(
          'assets/rive/no_such_animation.riv',
          riveFactory: Factory.flutter,
        );
      } catch (error) {
        thrown = error;
      }
    });

    expect(thrown, isA<FlutterError>());
    final Failure failure = mapErrorToFailure(thrown!);
    expect(failure, isA<ContentFailure>());
    expect(failure.code, FailureCode.contentAssetMissing);
  });

  test(
      'a state machine the file does not have is refused, and reported as '
      'media that cannot be shown', () {
    // What a typo in the content's `stateMachine` does: the controller throws
    // while it is built, so the renderer that builds it has to catch it.
    Object? thrown;
    try {
      RiveWidgetController(
        file,
        stateMachineSelector: StateMachineSelector.byName('LipStates'),
      );
    } catch (error) {
      thrown = error;
    }

    expect(thrown, isA<RiveStateMachineException>());
    final Failure failure = mapErrorToFailure(thrown!);
    expect(failure.code, FailureCode.contentMediaUnavailable);
  });
}
