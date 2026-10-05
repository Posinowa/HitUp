import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app's illustration: layers of cut paper over a rising sun.
///
/// The splash's language carried on: the splash is one cut edge laid on a
/// pale sheet, and this is the same paper, more of it, in the palette's
/// greens from the palest to the deepest. The last layer is the page itself,
/// [AppColors.background], so whatever sits under the scene sits on the
/// paper the hills are cut from. The sun is the one warm thing in it
/// ([AppColors.sunrise]).
///
/// It fills the room it is given and runs under a status bar [top] high, so
/// the sky meets the top of the screen while the hills keep their shape
/// below it. [sunHeight] is where the sun's centre sits, as a share of the
/// room under the status bar, so a sequence of scenes can raise it.
/// Decoration only: nothing here is read out.
class CutPaperScene extends StatelessWidget {
  /// Creates the scene.
  const CutPaperScene({this.top = 0, this.sunHeight = dawn, super.key});

  /// The sun just over the first hills, as the account screens show it.
  static const double dawn = 196 / _CutPaperPainter._frameHeight;

  /// The status bar's height, which the sky covers.
  final double top;

  /// Where the sun's centre is, from the top of the room under the status
  /// bar, as a share of that room's height.
  final double sunHeight;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
          painter: _CutPaperPainter(top: top, sunHeight: sunHeight),
          size: Size.infinite,
        ),
      );
}

/// The sky, the sun and five layers of paper, drawn to the room's size.
///
/// The shapes are on a 390 by 470 frame, scaled to the room below the status
/// bar. Each layer casts a soft shadow on the one behind it, upward, since
/// the one in front is the nearer.
class _CutPaperPainter extends CustomPainter {
  _CutPaperPainter({required this.top, required this.sunHeight});

  final double top;
  final double sunHeight;

  static const double _frameWidth = 390;
  static const double _frameHeight = 470;

  /// Each layer's top edge, as three points and two controls per curve, on
  /// the frame: the start, then two cubic curves to the right edge.
  static const List<List<double>> _edges = <List<double>>[
    <double>[0, 232, 70, 202, 140, 217, 200, 192, 270, 162, 330, 182, 390, 162],
    <double>[0, 272, 80, 242, 150, 267, 230, 242, 300, 220, 350, 237, 390, 224],
    <double>[0, 312, 60, 292, 130, 307, 200, 287, 270, 267, 330, 292, 390, 272],
    <double>[0, 352, 90, 322, 170, 352, 250, 327, 310, 308, 355, 322, 390, 314],
    <double>[0, 420, 80, 395, 170, 425, 260, 400, 320, 384, 360, 395, 390, 388],
  ];

  /// The layers' colours, back to front: the palette's greens from the
  /// palest to the deepest, then the page.
  static final List<Color> _layers = <Color>[
    AppColors.accent,
    Color.lerp(AppColors.accent, AppColors.primaryContainer, 0.5)!,
    AppColors.primaryContainer,
    AppColors.primary,
    AppColors.background,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double height = size.height - top;
    final double sx = size.width / _frameWidth;
    final double sy = height / _frameHeight;
    Offset at(double x, double y) => Offset(x * sx, top + y * sy);

    // The shadows are blurred past the layers' own edges; kept to the room,
    // they do not draw a line across what is below it. The clip's edge is
    // hard: where the room ends partway through a row of pixels, a soft edge
    // would lay every layer into that row partly, each over the last, and
    // the deeper greens would show through as a line.
    canvas.clipRect(Offset.zero & size, doAntiAlias: false);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.lerp(AppColors.background, AppColors.accent, 0.3)!,
    );

    final Offset sun = at(262, sunHeight * _frameHeight);
    final double radius = 74 * sx;
    canvas.drawCircle(
      sun,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.1, -0.2),
          radius: 0.6,
          colors: <Color>[
            Color.lerp(AppColors.sunrise, Colors.white, 0.6)!,
            AppColors.sunrise,
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: radius)),
    );

    for (int i = 0; i < _edges.length; i++) {
      final List<double> e = _edges[i];
      final Path layer = Path()
        ..moveTo(at(e[0], e[1]).dx, at(e[0], e[1]).dy)
        ..cubicTo(
          at(e[2], e[3]).dx,
          at(e[2], e[3]).dy,
          at(e[4], e[5]).dx,
          at(e[4], e[5]).dy,
          at(e[6], e[7]).dx,
          at(e[6], e[7]).dy,
        )
        ..cubicTo(
          at(e[8], e[9]).dx,
          at(e[8], e[9]).dy,
          at(e[10], e[11]).dx,
          at(e[10], e[11]).dy,
          at(e[12], e[13]).dx,
          at(e[12], e[13]).dy,
        )
        // Past the bottom, which the clip cuts: a layer ending on the last
        // row of pixels leaves that row partly covered, and the layers under
        // it show through as a line.
        ..lineTo(size.width, size.height + 12)
        ..lineTo(0, size.height + 12)
        ..close();

      canvas.drawPath(
        layer.shift(const Offset(0, -5)),
        Paint()
          ..color = AppColors.textPrimary.withValues(alpha: 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(layer, Paint()..color = _layers[i]);
    }
  }

  @override
  bool shouldRepaint(_CutPaperPainter oldDelegate) =>
      oldDelegate.top != top || oldDelegate.sunHeight != sunHeight;
}
