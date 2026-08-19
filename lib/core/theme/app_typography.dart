import 'package:flutter/material.dart';

import 'app_colors.dart';

/// HitUp type scale — Manrope for headings, Plus Jakarta Sans for body,
/// per the HIT-007 baseline in `docs/design/IDENTITY.md`.
abstract final class AppTypography {
  static const String headingFontFamily = 'Manrope';
  static const String bodyFontFamily = 'PlusJakartaSans';

  static TextTheme textTheme() {
    return const TextTheme(
      displaySmall: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 1.15,
        color: AppColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
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
      labelLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
    );
  }
}
