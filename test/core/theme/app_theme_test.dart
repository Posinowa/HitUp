import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/theme/app_colors.dart';
import 'package:hitup/core/theme/app_radius.dart';
import 'package:hitup/core/theme/app_theme.dart';
import 'package:hitup/core/theme/app_typography.dart';

/// Proves the issue's second acceptance criterion: a token is not just
/// declared, it actually reaches the widgets.
///
/// Asserting `isNotNull` on a colour would pass even if every token were
/// wrong. These tests compare against the token values themselves, so
/// changing a token and forgetting to wire it fails here.
void main() {
  group('colour tokens reach the ColorScheme', () {
    final scheme = AppTheme.light().colorScheme;

    test('brand colours map to their tokens', () {
      expect(scheme.primary, AppColors.primary);
      expect(scheme.primaryContainer, AppColors.primaryContainer);
      expect(scheme.secondary, AppColors.secondary);
      expect(scheme.tertiary, AppColors.accent);
    });

    test('surfaces and text map to their tokens', () {
      expect(scheme.surface, AppColors.surface);
      expect(scheme.onSurface, AppColors.textPrimary);
      expect(scheme.outline, AppColors.outline);
      expect(scheme.error, AppColors.error);
      expect(AppTheme.light().scaffoldBackgroundColor, AppColors.background);
    });
  });

  group('the contrast decision from IDENTITY.md holds', () {
    final scheme = AppTheme.light().colorScheme;

    test('the light swatch is a container, never the interactive role', () {
      // Seafoam fails contrast against white text, so the darker Deep Teal
      // carries `primary` and Seafoam sits in `primaryContainer`. Swapping
      // them would look fine in review and fail accessibility in the store.
      expect(scheme.primary, isNot(AppColors.primaryContainer));
      expect(scheme.primaryContainer, isNot(AppColors.primary));
    });

    test('foregrounds follow that split', () {
      expect(scheme.onPrimary, Colors.white);
      expect(scheme.onPrimaryContainer, AppColors.textPrimary);
      expect(scheme.onSecondary, AppColors.textPrimary);
    });
  });

  group('type and radius tokens reach the theme', () {
    final theme = AppTheme.light();

    test('headings use the heading family, body uses the body family', () {
      expect(
        theme.textTheme.titleLarge?.fontFamily,
        AppTypography.headingFontFamily,
      );
      expect(
        theme.textTheme.headlineMedium?.fontFamily,
        AppTypography.headingFontFamily,
      );
      expect(
        theme.textTheme.bodyLarge?.fontFamily,
        AppTypography.bodyFontFamily,
      );
      expect(
        theme.textTheme.labelLarge?.fontFamily,
        AppTypography.bodyFontFamily,
      );
    });

    test('the button radius comes from the radius scale', () {
      final style = theme.elevatedButtonTheme.style;
      final shape = style?.shape?.resolve({});

      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppRadius.md),
      );
    });
  });

  group('widgets read the tokens, not hard coded values', () {
    testWidgets('Theme.of hands a widget the token values', (tester) async {
      late ColorScheme seenScheme;
      late TextStyle? seenTitle;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              seenScheme = Theme.of(context).colorScheme;
              seenTitle = Theme.of(context).textTheme.titleLarge;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(seenScheme.primary, AppColors.primary);
      expect(seenScheme.onPrimaryContainer, AppColors.textPrimary);
      expect(seenTitle?.fontFamily, AppTypography.headingFontFamily);
      expect(seenTitle?.color, AppColors.textPrimary);
    });

    testWidgets('a real button paints with the primary token', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ElevatedButton(onPressed: () {}, child: const Text('start')),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.byType(Material),
        ),
      );

      expect(material.color, AppColors.primary);
    });

    testWidgets('the scaffold paints the background token', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      final resolved = scaffold.backgroundColor ??
          Theme.of(tester.element(find.byType(Scaffold)))
              .scaffoldBackgroundColor;

      expect(resolved, AppColors.background);
    });
  });
}
