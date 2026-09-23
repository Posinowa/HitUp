import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/training/presentation/renderers/pinned_action_layout.dart';

void main() {
  const Key content = Key('content');

  /// The layout in a room 300 wide and 200 tall, at the top left.
  Future<void> show(WidgetTester tester, {required double tall}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 200,
              child: PinnedActionLayout(
                content: SizedBox(
                  key: content,
                  height: tall,
                  child: const Text('içerik'),
                ),
                action: const Text('eylem'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the action stays in view under content taller than the room',
      (WidgetTester tester) async {
    await show(tester, tall: 1000);

    expect(find.text('eylem').hitTestable(), findsOneWidget);
    expect(tester.getBottomLeft(find.text('eylem')).dy, lessThanOrEqualTo(200));

    // The content scrolls instead, and the action stays where it is.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pump();
    expect(find.text('içerik').hitTestable(), findsNothing);
    expect(find.text('eylem').hitTestable(), findsOneWidget);
  });

  testWidgets('content that fits stays with the action, the two centred',
      (WidgetTester tester) async {
    await show(tester, tall: 40);

    final double contentTop = tester.getTopLeft(find.byKey(content)).dy;
    final double contentBottom = tester.getBottomLeft(find.byKey(content)).dy;
    final double actionTop = tester.getTopLeft(find.text('eylem')).dy;
    final double actionBottom = tester.getBottomLeft(find.text('eylem')).dy;
    // 16 between them, not the rest of the room.
    expect(actionTop - contentBottom, closeTo(16, 0.5));
    // As much room above the pair as below it.
    expect(contentTop, closeTo(200 - actionBottom, 0.5));
  });
}
