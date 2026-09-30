import 'package:flutter/material.dart';

import 'app_colors.dart';

/// HitUp type scale: Manrope for headings, Plus Jakarta Sans for body,
/// per the HIT-007 baseline in `docs/design/IDENTITY.md`.
///
/// **Every one of Material's fifteen slots is here.** A slot left out is not
/// left alone: `ThemeData` fills it from Material's own scale, in the
/// platform's font, Roboto on Android. Widgets reach for slots screens never
/// name, a dialog title for `headlineSmall`, a field's error and helper text
/// for `bodySmall`, so a missing one shows up as the wrong face in places
/// nobody wrote. Sizes and line heights not chosen here are Material 3's, and
/// every weight is one the app bundles (`pubspec.yaml`).
abstract final class AppTypography {
  static const String headingFontFamily = 'Manrope';
  static const String bodyFontFamily = 'PlusJakartaSans';

  static TextTheme textTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 57,
        fontWeight: FontWeight.w800,
        height: 1.12,
        color: AppColors.textPrimary,
      ),
      displayMedium: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 45,
        fontWeight: FontWeight.w800,
        height: 1.16,
        color: AppColors.textPrimary,
      ),
      displaySmall: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 1.15,
        color: AppColors.textPrimary,
      ),
      headlineLarge: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: AppColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.33,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: AppColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.43,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.33,
        color: AppColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.33,
        color: AppColors.textPrimary,
      ),
      labelSmall: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.45,
        color: AppColors.textPrimary,
      ),
    );
  }
}
