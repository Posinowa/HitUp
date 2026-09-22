import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/widgets/damga_mark.dart';

/// Every number in `damga.svg` that the Dart copy repeats.
///
/// The mark is drawn in Dart rather than loaded, so the two can drift. These
/// read the master and compare, which is the only thing that keeps the copy
/// honest.
void main() {
  final String master =
      File('assets/branding/logo/damga.svg').readAsStringSync();

  /// Every captured number in [pattern], read out of the master in order.
  List<double> numbersIn(RegExp pattern) {
    final List<double> found = <double>[];
    for (final RegExpMatch match in pattern.allMatches(master)) {
      for (int group = 1; group <= match.groupCount; group++) {
        found.add(double.parse(match.group(group)!));
      }
    }
    return found;
  }

  group('the Dart mark matches the master svg', () {
    test('the canvas is the one the master is drawn on', () {
      expect(master, contains('viewBox="0 0 512 512"'));
      expect(DamgaMark.canvasSize, 512);
    });

    test('the stem is the same four corners', () {
      final List<double> svg = numbersIn(
        RegExp(r'M(\d+) (\d+) L(\d+) (\d+) L(\d+) (\d+) L(\d+) (\d+) Z'),
      );
      final List<double> dart =
          DamgaMark.stem.expand((Offset o) => <double>[o.dx, o.dy]).toList();
      expect(dart, svg);
    });

    test('the dots are the same centres and radius', () {
      final List<double> svg = numbersIn(
        RegExp(r'<circle cx="(\d+)" cy="(\d+)" r="(\d+)"/>'),
      );
      final List<double> dart = DamgaMark.dots
          .expand(((Offset, double) d) => <double>[d.$1.dx, d.$1.dy, d.$2])
          .toList();
      expect(dart, svg);
    });

    test('the three strokes are the same ends, and the same width', () {
      final List<double> svg = numbersIn(
        RegExp(r'<path d="M(\d+) (\d+) L(\d+) (\d+)"/>'),
      );
      final List<double> dart = DamgaMark.strokes
          .expand(
            ((Offset, Offset) s) =>
                <double>[s.$1.dx, s.$1.dy, s.$2.dx, s.$2.dy],
          )
          .toList();
      expect(dart, svg);
      expect(
        master,
        contains('stroke-width="${DamgaMark.strokeWidth.toInt()}"'),
      );
      // Butt caps: a round cap would lengthen every stroke by half its width
      // and close the gaps the mark is drawn around.
      expect(master, contains('stroke-linecap="butt"'));
    });

    test('the gradient runs between the same points, in the same colours', () {
      expect(
        master,
        contains('x1="${DamgaMark.gradientStart.dx.toInt()}" '
            'y1="${DamgaMark.gradientStart.dy.toInt()}" '
            'x2="${DamgaMark.gradientEnd.dx.toInt()}" '
            'y2="${DamgaMark.gradientEnd.dy.toInt()}"'),
      );
      const List<String> hexes = <String>['#1B5C50', '#257C6C', '#48BCA2'];
      for (int i = 0; i < hexes.length; i++) {
        expect(master, contains('stop-color="${hexes[i]}"'));
        expect(
          DamgaMark.gradientColors[i]
              .toARGB32()
              .toRadixString(16)
              .toUpperCase(),
          'FF${hexes[i].substring(1)}',
        );
      }
      expect(DamgaMark.gradientStops, <double>[0, 0.55, 1]);
      expect(master, contains('offset="0.55"'));
    });
  });

  group('drawing it', () {
    testWidgets('takes the size it is given', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: DamgaMark(size: 96))),
      );

      expect(tester.getSize(find.byType(DamgaMark)), const Size(96, 96));
    });

    testWidgets('tells a screen reader what it is',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: DamgaMark(size: 96))),
      );

      expect(find.bySemanticsLabel('HitUp'), findsOneWidget);
    });

    test('actually paints, and stays inside its box', () async {
      // A painter that drew nothing would still lay out at the right size.
      // This records the drawing into a picture and counts what landed.
      const double side = 120;
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      DamgaMark.paintOn(Canvas(recorder), const Size(side, side));
      final ui.Image image =
          await recorder.endRecording().toImage(side.toInt(), side.toInt());
      final ByteData pixels =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;

      int painted = 0;
      for (int i = 3; i < pixels.lengthInBytes; i += 4) {
        if (pixels.getUint8(i) > 8) {
          painted++;
        }
      }

      // Enough to be the mark, and far from the whole box: the mark is a few
      // strokes on a square, not a filled square.
      expect(painted, greaterThan(600), reason: 'the mark drew nothing');
      expect(painted, lessThan((side * side * 0.5).round()));

      /// Whether the pixel at a point on the 512 canvas was painted.
      bool paintedAt(double x, double y) {
        final int px = (x * side / DamgaMark.canvasSize).round();
        final int py = (y * side / DamgaMark.canvasSize).round();
        return pixels.getUint8((py * side.toInt() + px) * 4 + 3) > 8;
      }

      // Each part of the mark, checked where only that part can be: a count
      // alone passes when the stem and the dots are gone and the strokes
      // still fill the box.
      expect(paintedAt(208, 300), isTrue, reason: 'the stem is missing');
      expect(paintedAt(119, 226), isTrue, reason: 'the upper dot is missing');
      expect(paintedAt(119, 317), isTrue, reason: 'the lower dot is missing');
      expect(paintedAt(270, 341), isTrue, reason: 'a stroke is missing');
      expect(paintedAt(315, 430), isFalse, reason: 'the mark spilled');
    });
  });
}
