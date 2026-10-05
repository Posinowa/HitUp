import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/damga_mark.dart';

/// The top of the account screens: layers of cut paper over a rising sun,
/// with the mark and the name on the sky (HIT-017 to HIT-019).
///
/// The splash's language carried on: the splash is one cut edge laid on a
/// pale sheet, and these screens are the same paper, more of it, in the
/// palette's greens from the palest to the deepest. The last layer is the
/// page itself, so the form sits on the paper the hills are cut from. The
/// sun is the one warm thing on the screen ([AppColors.sunrise]).
///
/// It runs under the status bar, so the sky meets the top of the screen, and
/// grows with the screen within [minHeight] and [maxHeight], so a short phone
/// keeps its room for the form. Nothing here is read out: the name is the
/// app's, and the screen's heading follows it.
class AuthHeader extends StatelessWidget {
  /// Creates the header.
  const AuthHeader({super.key});

  /// The header's height, not counting the status bar, on the shortest
  /// screens.
  static const double minHeight = 180;

  /// Its height on the tallest.
  static const double maxHeight = 300;

  /// Its share of the screen's height between those two.
  static const double share = 0.36;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double height =
        (media.size.height * share).clamp(minHeight, maxHeight);
    final double top = media.padding.top;

    return ExcludeSemantics(
      child: SizedBox(
        height: top + height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CustomPaint(painter: _CutPaperPainter(top: top)),
            Positioned(
              left: AppSpacing.lg,
              top: top + AppSpacing.md,
              child: Row(
                children: <Widget>[
                  const DamgaMark(size: 36),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'HitUp',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sky, the sun and five layers of paper, drawn to the header's size.
///
/// The shapes are the comparison's, on a 390 by 470 frame, scaled to the
/// room below the status bar. Each layer casts a soft shadow on the one
/// behind it, upward, since the one in front is the nearer.
class _CutPaperPainter extends CustomPainter {
  _CutPaperPainter({required this.top});

  /// The status bar's height, which the sky covers and the shapes start
  /// under.
  final double top;

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

    // The shadows are blurred past the layers' own edges; kept to the header,
    // they do not draw a line across the form below it. The clip's edge is
    // hard: where the header ends partway through a row of pixels, a soft
    // edge would lay every layer into that row partly, each over the last,
    // and the deeper greens would show through as a line.
    canvas.clipRect(Offset.zero & size, doAntiAlias: false);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.lerp(AppColors.background, AppColors.accent, 0.3)!,
    );

    final Offset sun = at(262, 196);
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
  bool shouldRepaint(_CutPaperPainter oldDelegate) => oldDelegate.top != top;
}
