import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/theme/app_colors.dart';
import 'package:hitup/features/auth/presentation/auth_header.dart';

void main() {
  // 36% of 640 is 230.4 and of 655 is 235.8, so the header's last row of
  // pixels is only partly the header's: less than half of it, where the row
  // is left out, and more, where it is drawn.
  for (final double height in const <double>[640, 655]) {
    testWidgets(
        'meets the form under it without a line, on a phone ${height.toInt()} '
        'points tall', (WidgetTester tester) async {
      await _check(tester, Size(360, height));
    });
  }
}

Future<void> _check(WidgetTester tester, Size phone) async {
  // The test's own screen is 800 by 600; this one is the phone's, so the
  // header and the form under it are drawn whole.
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const double statusBar = 24;
  final GlobalKey boundary = GlobalKey();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: phone,
        padding: const EdgeInsets.only(top: statusBar),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: boundary,
            child: SizedBox.fromSize(
              size: phone,
              child: const ColoredBox(
                color: AppColors.background,
                child: Column(children: <Widget>[AuthHeader()]),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  final RenderRepaintBoundary render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ByteData pixels = (await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await render.toImage();
    final ByteData? bytes =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes;
  }))!;

  /// How far the pixel at ([x], [y]) is from the page's colour, in the
  /// channel that is furthest.
  int offPage(int x, int y) {
    final int i = (y * phone.width.toInt() + x) * 4;
    final int page = AppColors.background.toARGB32();
    return <int>[
      (pixels.getUint8(i) - (page >> 16 & 0xFF)).abs(),
      (pixels.getUint8(i + 1) - (page >> 8 & 0xFF)).abs(),
      (pixels.getUint8(i + 2) - (page & 0xFF)).abs(),
    ].reduce(max);
  }

  // The header is there: its sky, right of the name and above the sun, is
  // not the page. Without this, a header that drew nothing would pass.
  expect(offPage(330, 30), greaterThan(8), reason: 'the header drew nothing');
  // From the row its edge runs through to the bottom: the page, with
  // nothing of the header's spilled onto it.
  final int edge = (statusBar + phone.height * AuthHeader.share).floor();
  for (int y = edge; y < phone.height; y++) {
    for (final int x in <int>[5, 180, 355]) {
      expect(offPage(x, y), lessThanOrEqualTo(2), reason: 'at $x, $y');
    }
  }
}
