import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cut_paper_scene.dart';
import '../../../core/widgets/damga_mark.dart';

/// The top of the account screens: the app's cut paper and sun
/// ([CutPaperScene]), with the mark and the name on the sky (HIT-017 to
/// HIT-019).
///
/// The scene's last layer is the page itself, so the form sits on the paper
/// the hills are cut from. It runs under the status bar, so the sky meets the
/// top of the screen, and grows with the screen within [minHeight] and
/// [maxHeight], so a short phone keeps its room for the form. Nothing here is
/// read out: the name is the app's, and the screen's heading follows it.
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
            CutPaperScene(top: top),
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
