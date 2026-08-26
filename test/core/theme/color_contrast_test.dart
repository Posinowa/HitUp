import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/theme/app_theme.dart';

/// Contrast is a property of the palette, so it is checked against the palette
/// rather than against a screenshot of one screen.
///
/// The pairs below are the ones the app actually paints text with. A change
/// that makes any of them unreadable fails here, at the token, instead of
/// surfacing as "this screen looks a bit washed out" during device QA.
///
/// Threshold is WCAG AA for body text, 4.5:1. Snack bar and error text are
/// 14sp regular, so the large-text allowance of 3:1 does not apply to them.
void main() {
  const double aaBodyText = 4.5;

  double relativeLuminance(Color c) {
    double channel(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  double contrast(Color a, Color b) {
    final double la = relativeLuminance(a);
    final double lb = relativeLuminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  test('the contrast helper matches known reference values', () {
    // Without this the suite could pass because the maths is wrong rather than
    // because the colours are right.
    expect(
      contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.01),
      reason: 'black on white is the theoretical maximum of 21:1',
    );
    expect(
      contrast(const Color(0xFF777777), const Color(0xFFFFFFFF)),
      closeTo(4.48, 0.01),
      reason: 'a documented mid grey on white measures about 4.48:1',
    );
  });

  test('every foreground the app writes text with is readable', () {
    final ColorScheme s = AppTheme.light().colorScheme;

    final Map<String, List<Color>> pairs = <String, List<Color>>{
      'onPrimary on primary': <Color>[s.onPrimary, s.primary],
      'onPrimaryContainer on primaryContainer': <Color>[
        s.onPrimaryContainer,
        s.primaryContainer,
      ],
      'onSecondary on secondary': <Color>[s.onSecondary, s.secondary],
      'onTertiary on tertiary': <Color>[s.onTertiary, s.tertiary],
      'onSurface on surface': <Color>[s.onSurface, s.surface],
      // The one that was failing: error text used to land on the full-strength
      // error tone at 3.82:1, because errorContainer was left undeclared and
      // fell back to error itself.
      'onErrorContainer on errorContainer': <Color>[
        s.onErrorContainer,
        s.errorContainer,
      ],
      'onInverseSurface on inverseSurface': <Color>[
        s.onInverseSurface,
        s.inverseSurface,
      ],
    };

    final List<String> failures = <String>[];
    pairs.forEach((String name, List<Color> pair) {
      final double ratio = contrast(pair[0], pair[1]);
      if (ratio < aaBodyText) {
        failures.add('$name is ${ratio.toStringAsFixed(2)}:1');
      }
    });

    expect(
      failures,
      isEmpty,
      reason: 'these pairs carry body text and must reach $aaBodyText:1. '
          'Raising a swatch is a palette decision, not something to work '
          'around at a call site.',
    );
  });

  test('the error tone stays reserved for marks, not for text behind it', () {
    final ColorScheme s = AppTheme.light().colorScheme;

    // AppColors documents that error is too dark to write body text on, which
    // is the whole reason errorContainer exists. If a future palette change
    // made error light enough to read on, that reasoning would be stale and
    // this test is where it gets noticed.
    expect(
      contrast(s.onErrorContainer, s.error),
      lessThan(aaBodyText),
      reason:
          'if error became readable for body text, AppColors.errorContainer '
          'and the comment explaining it should be revisited',
    );
  });
}
