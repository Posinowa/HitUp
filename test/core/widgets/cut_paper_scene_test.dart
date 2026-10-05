import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/theme/app_colors.dart';
import 'package:hitup/core/widgets/cut_paper_scene.dart';

/// The pixels of [scene], drawn [sceneHeight] high at the top of a box of the
/// page's colour, [width] by [height], at one pixel to the point.
Future<ByteData> _paint(
  WidgetTester tester,
  CutPaperScene scene, {
  required int width,
  required int height,
  required double sceneHeight,
}) async {
  final GlobalKey boundary = GlobalKey();
  await tester.pumpWidget(
    Center(
      child: RepaintBoundary(
        key: boundary,
        child: ColoredBox(
          color: AppColors.background,
          child: SizedBox(
            width: width.toDouble(),
            height: height.toDouble(),
            child: Column(
              children: <Widget>[
                SizedBox(height: sceneHeight, child: scene),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  final RenderRepaintBoundary render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await render.toImage();
    final ByteData? bytes =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes;
  }))!;
}

/// The pixel at ([x], [y]) of an image [width] wide, as red, green, blue.
List<int> _rgb(ByteData pixels, int width, int x, int y) {
  final int i = (y * width + x) * 4;
  return <int>[
    pixels.getUint8(i),
    pixels.getUint8(i + 1),
    pixels.getUint8(i + 2),
  ];
}

/// How far [rgb] is from the page's colour, in the channel that is furthest.
int _offPage(List<int> rgb) {
  final int page = AppColors.background.toARGB32();
  return <int>[
    (rgb[0] - (page >> 16 & 0xFF)).abs(),
    (rgb[1] - (page >> 8 & 0xFF)).abs(),
    (rgb[2] - (page & 0xFF)).abs(),
  ].reduce(max);
}

void main() {
  // A height worked out as a share of the screen's rarely ends on a whole
  // pixel, so the scene's last row of pixels is only partly the scene's: less
  // than half of it, where the row is left out, and more, where it is drawn.
  for (final double sceneHeight in const <double>[150.4, 150.7]) {
    testWidgets(
        'meets the page under it without a line, ending $sceneHeight '
        'points down', (WidgetTester tester) async {
      const int width = 200;
      const int height = 200;
      final ByteData pixels = await _paint(
        tester,
        const CutPaperScene(),
        width: width,
        height: height,
        sceneHeight: sceneHeight,
      );

      // The scene is there: its sky is not the page. Without this, a scene
      // that drew nothing would pass.
      expect(
        _offPage(_rgb(pixels, width, 10, 5)),
        greaterThan(8),
        reason: 'the scene drew nothing',
      );
      // From the row its edge runs through to the bottom: the page, with
      // nothing of the scene's spilled onto it.
      for (int y = sceneHeight.floor(); y < height; y++) {
        for (final int x in <int>[5, 100, 195]) {
          expect(
            _offPage(_rgb(pixels, width, x, y)),
            lessThanOrEqualTo(2),
            reason: 'at $x, $y',
          );
        }
      }
    });
  }

  testWidgets('draws the sun where it is asked to',
      (WidgetTester tester) async {
    // The frame's own size, so a point on it is a pixel here.
    const int width = 390;
    const int height = 470;
    bool warmAt(ByteData pixels, int y) {
      final List<int> rgb = _rgb(pixels, width, 262, y);
      return rgb[0] - rgb[2] > 40;
    }

    final ByteData high = await _paint(
      tester,
      const CutPaperScene(sunHeight: 0.1),
      width: width,
      height: height,
      sceneHeight: height.toDouble(),
    );
    expect(warmAt(high, 47), isTrue, reason: 'no sun where it was asked for');

    final ByteData low = await _paint(
      tester,
      const CutPaperScene(),
      width: width,
      height: height,
      sceneHeight: height.toDouble(),
    );
    expect(warmAt(low, 47), isFalse, reason: 'the sun did not move');
    expect(warmAt(low, 160), isTrue, reason: 'no sun at dawn');
  });
}
