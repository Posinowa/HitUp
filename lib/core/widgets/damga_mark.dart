import 'package:flutter/material.dart';

/// The HitUp mark, drawn rather than loaded.
///
/// The geometry is the one in `assets/branding/logo/damga.svg`, the master
/// every launcher and notification icon is generated from
/// (`docs/design/IDENTITY.md`). It is repeated here in Dart, not read from the
/// file, because rendering an SVG at run time needs a package the project does
/// not have, and a PNG would either blur when scaled up or ship at a size
/// nothing on screen asks for.
///
/// Repeating the numbers costs a rule: **if the master changes, this changes
/// with it.** A test compares the two, so the copy cannot drift in silence.
class DamgaMark extends StatelessWidget {
  /// Draws the mark at [size] by [size].
  const DamgaMark({required this.size, super.key});

  /// The square the coordinates below are written on, from the master's
  /// `viewBox`.
  static const double canvasSize = 512;

  /// The stem: an upright quadrilateral, slightly wider at the foot.
  static const List<Offset> stem = <Offset>[
    Offset(186, 97),
    Offset(230, 85),
    Offset(230, 454),
    Offset(186, 454),
  ];

  /// The two dots beside the stem, as centre and radius.
  static const List<(Offset, double)> dots = <(Offset, double)>[
    (Offset(119, 226), 24),
    (Offset(119, 317), 24),
  ];

  /// The three strokes rising from the stem, as their two ends.
  static const List<(Offset, Offset)> strokes = <(Offset, Offset)>[
    (Offset(222, 367), Offset(319, 316)),
    (Offset(222, 271), Offset(363, 196)),
    (Offset(222, 175), Offset(407, 77)),
  ];

  /// How thick a stroke is drawn, on the 512 canvas.
  static const double strokeWidth = 42;

  /// Where the gradient starts and ends, and its three stops.
  static const Offset gradientStart = Offset(106, 446);

  /// The gradient's far end.
  static const Offset gradientEnd = Offset(422, 79);

  /// Deep Teal to Seafoam, as `IDENTITY.md` sets them.
  static const List<Color> gradientColors = <Color>[
    Color(0xFF1B5C50),
    Color(0xFF257C6C),
    Color(0xFF48BCA2),
  ];

  /// Where each colour sits along the gradient.
  static const List<double> gradientStops = <double>[0, 0.55, 1];

  /// The width and height to draw at.
  final double size;

  /// Draws the mark on [canvas], filling [size].
  ///
  /// Public so anything that needs the mark on a canvas of its own, and the
  /// test that checks it actually draws, can call it without going through a
  /// widget.
  static void paintOn(Canvas canvas, Size size) {
    final double scale = size.shortestSide / canvasSize;
    canvas.save();
    canvas.scale(scale);

    final Shader shader = const LinearGradient(
      colors: gradientColors,
      stops: gradientStops,
    ).createShader(Rect.fromPoints(gradientStart, gradientEnd));

    final Path body = Path()..addPolygon(stem, true);
    for (final (Offset centre, double radius) in dots) {
      body.addOval(Rect.fromCircle(center: centre, radius: radius));
    }
    canvas.drawPath(body, Paint()..shader = shader);

    final Paint strokePaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      // Butt caps, as the master has them: a rounded cap would lengthen every
      // stroke by half its width and close the gaps the mark is drawn around.
      ..strokeCap = StrokeCap.butt;
    for (final (Offset from, Offset to) in strokes) {
      canvas.drawLine(from, to, strokePaint);
    }

    canvas.restore();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        // Painted shapes say nothing to a screen reader on their own, and this
        // one is the app's name written as a mark.
        label: 'HitUp',
        image: true,
        child: SizedBox(
          width: size,
          height: size,
          child: const CustomPaint(painter: _DamgaPainter()),
        ),
      );
}

class _DamgaPainter extends CustomPainter {
  const _DamgaPainter();

  @override
  void paint(Canvas canvas, Size size) => DamgaMark.paintOn(canvas, size);

  @override
  bool shouldRepaint(_DamgaPainter oldDelegate) => false;
}
