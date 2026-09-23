import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/damga_mark.dart';

/// The first screen of every cold start (HIT-014).
///
/// Deliberately quiet. This is not a screen anyone comes to look at; it is
/// what stands there for the moment it takes to find out where the user
/// belongs, and it is seen every single day. Cut paper is the whole idea: a
/// pale sheet, one horizon, the mark on top of it.
///
/// It shows a message only when startup has something to say. Until then
/// there is no spinner: a spinner on a screen that is usually gone in a blink
/// reads as a stutter rather than as progress.
class SplashScreen extends StatelessWidget {
  /// Shows the splash.
  ///
  /// [message] appears under the mark when startup takes long enough to be
  /// worth explaining, or when it failed. [onRetry] adds a button beside it.
  const SplashScreen({super.key, this.message, this.onRetry});

  /// What to tell the user, if anything.
  final String? message;

  /// What to do when they ask to try again.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _CutPaperHorizon(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Spacer(),
                  const DamgaMark(size: 132),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'HitUp',
                    style: text.headlineLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (message != null)
                    _StartupMessage(message: message!, onRetry: onRetry),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The message and, when there is something to do about it, the button.
class _StartupMessage extends StatelessWidget {
  const _StartupMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        Text(
          message,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        if (onRetry != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ],
    );
  }
}

/// One cut edge across the bottom of the sheet.
///
/// A single curve and a soft shadow under it, which is what makes it read as
/// paper laid on paper rather than as a coloured rectangle.
class _CutPaperHorizon extends StatelessWidget {
  const _CutPaperHorizon();

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _HorizonPainter(),
        // Decoration only: nothing here is worth reading out.
        isComplex: false,
      );
}

class _HorizonPainter extends CustomPainter {
  /// Where the curve sits, as a share of the screen's height.
  static const double horizonHeight = 0.18;

  /// How far the curve rises above that line, as a share of the height.
  static const double rise = 0.05;

  @override
  void paint(Canvas canvas, Size size) {
    final double base = size.height * (1 - horizonHeight);
    final Path paper = Path()
      ..moveTo(0, base)
      ..quadraticBezierTo(
        size.width / 2,
        base - size.height * rise,
        size.width,
        base,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      paper.shift(const Offset(0, -6)),
      Paint()
        ..color = AppColors.textPrimary.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(paper, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(_HorizonPainter oldDelegate) => false;
}
