import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

/// Central HitUp [ThemeData]. Seafoam baseline, approved in HIT-007.
///
/// See `docs/design/IDENTITY.md` for the token rationale. [AppColors.primary]
/// (not [AppColors.primaryContainer]) carries [Colors.white] foregrounds
/// because the lighter container swatch fails contrast with white text.
abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme = const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.textPrimary,
      tertiary: AppColors.accent,
      onTertiary: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.outline,
      error: AppColors.error,
      onError: Colors.white,
      // Left undeclared, errorContainer falls back to error and
      // onErrorContainer to onError, which paints error text white on Coral
      // Red at 3.82:1, under the 4.5:1 body text needs. These are the tokens
      // that make an error message readable; see AppColors.errorContainer.
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTypography.textTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
